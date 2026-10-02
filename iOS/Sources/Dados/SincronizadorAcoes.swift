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
            } catch let erro as ErroDaApi where acao.tipo == .publicacaoVaga && erro.codigo.recusaDefinitivaDePublicacao {
                // Respostas definitivas recusadas não serão aceitas numa repetição da mesma chave.
                try? await fila.remover(id: acao.id)
            } catch let erro as ErroDaApi where acao.tipo == .republicacaoVaga && (erro.codigo.recusaDefinitivaDePublicacao || erro.codigo == .vagaOculta) {
                // Respostas definitivas recusadas não serão aceitas numa repetição da mesma chave.
                try? await fila.remover(id: acao.id)
            } catch {
                // A ação permanece para uma nova tentativa idempotente.
                continue
            }
        }
    }
}
