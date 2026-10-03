import Foundation
import FrilaDominio

public actor SincronizadorAcoes {
    private let fila: any FilaDeAcoes
    private let avaliacaoJaRegistrada: @Sendable (AcaoPendente) -> Void
    private let api: any ApiCliente

    public init(fila: any FilaDeAcoes, api: any ApiCliente,
                avaliacaoJaRegistrada: @escaping @Sendable (AcaoPendente) -> Void = { _ in }) {
        self.fila = fila
        self.api = api
        self.avaliacaoJaRegistrada = avaliacaoJaRegistrada
    }

    public func sincronizar() async {
        guard let acoes = try? await fila.pendentes() else { return }
        for acao in acoes {
            do {
                // Check-in, check-out e avaliação são idempotentes pela chave natural do turno (contrato 0.2.18);
                // a `chave` da ação fica só na fila local.
                switch acao.tipo {
                case .checkin:
                    guard let turnoID = acao.turnoID else { continue }
                    _ = try await api.fazerCheckin(
                        turnoID: turnoID,
                        distanciaMetros: acao.distanciaMetros,
                        registradoEm: acao.instanteDoToque
                    )
                case .checkout:
                    guard let turnoID = acao.turnoID else { continue }
                    _ = try await api.fazerCheckout(
                        turnoID: turnoID,
                        distanciaMetros: acao.distanciaMetros,
                        registradoEm: acao.instanteDoToque
                    )
                case .avaliacao:
                    guard let turnoID = acao.turnoID, let resposta = acao.resposta,
                          let contaID = acao.contaID else { continue }
                    if try await api.minhaConta().id != contaID { continue }
                    _ = try await api.avaliar(turnoID: turnoID, resposta: resposta)
                case .publicacaoVaga:
                    guard let publicacao = acao.publicacao else { continue }
                    _ = try await api.publicarVaga(publicacao)
                case .republicacaoVaga:
                    guard let republicacao = acao.republicacao else { continue }
                    _ = try await api.republicarVaga(
                        id: republicacao.vagaID,
                        periodo: republicacao.periodo,
                        chave: acao.chave
                    )
                }
                try await fila.remover(id: acao.id)
            } catch let erro as ErroDaApi where erro.codigo == .semRede {
                return
            } catch let erro as ErroDaApi where acao.tipo == .avaliacao && erro.codigo == .avaliacaoJaRegistrada {
                // A resposta da fila foi recusada: não pode continuar aparecendo como resposta dada.
                avaliacaoJaRegistrada(acao)
                try? await fila.remover(id: acao.id)
            } catch let erro as ErroDaApi {
                // Sem o registro persistido, a ação continua para não perder o aviso da recusa.
                if await recusaDefinitiva(erro, acao: acao) {
                    try? await fila.recusar(acao, codigo: erro.codigo)
                }
            } catch {
                // A ação permanece para uma nova tentativa idempotente.
                continue
            }
        }
    }

    private func recusaDefinitiva(_ erro: ErroDaApi, acao: AcaoPendente) async -> Bool {
        switch acao.tipo {
        case .checkin, .checkout:
            if acao.tipo == .checkout, erro.codigo == .checkinPendente {
                // O check-in pode ter falhado por rede/5xx nesta passagem; não descarta a saída dele.
                guard let pendentes = try? await fila.pendentes() else { return false }
                return !pendentes.contains { $0.tipo == .checkin && $0.turnoID == acao.turnoID }
            }
            switch erro.codigo {
            case .semPermissao, .contaSuspensa, .naoEncontrado, .vagaEncerrada,
                 .campoObrigatorio, .campoInvalido, .foraDaJanela, .registroNoFuturo:
                return true
            default:
                return false
            }
        case .publicacaoVaga:
            return erro.codigo.recusaDefinitivaDePublicacao
        case .republicacaoVaga:
            return erro.codigo.recusaDefinitivaDePublicacao || erro.codigo == .vagaOculta
        case .avaliacao:
            return false
        }
    }
}
