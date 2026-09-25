import Foundation
import FrilaDominio

public actor SincronizadorAcoes {
    private let fila: any FilaDeAcoes
    private let api: any ApiCliente

    public init(fila: any FilaDeAcoes, api: any ApiCliente) {
        self.fila = fila
        self.api = api
    }

    public func sincronizar() async {
        guard let acoes = try? await fila.pendentes() else { return }
        for acao in acoes {
            do {
                // Check-in, check-out e avaliação são idempotentes pela chave natural do turno (contrato 0.2.11);
                // a `chave` da ação fica só na fila local.
                switch acao.tipo {
                case .checkin:
                    _ = try await api.fazerCheckin(
                        turnoID: acao.turnoID,
                        distanciaMetros: acao.distanciaMetros,
                        registradoEm: acao.instanteDoToque
                    )
                case .checkout:
                    _ = try await api.fazerCheckout(
                        turnoID: acao.turnoID,
                        distanciaMetros: acao.distanciaMetros,
                        registradoEm: acao.instanteDoToque
                    )
                case .avaliacao:
                    guard let resposta = acao.resposta else { continue }
                    _ = try await api.avaliar(turnoID: acao.turnoID, resposta: resposta)
                }
                try await fila.remover(id: acao.id)
            } catch let erro as ErroDaApi where erro.codigo == .semRede {
                return
            } catch {
                // A ação permanece para uma nova tentativa idempotente.
                continue
            }
        }
    }
}
