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
                switch acao.tipo {
                case .checkin:
                    try await api.fazerCheckin(
                        turnoID: acao.turnoID,
                        distanciaMetros: acao.distanciaMetros,
                        registradoEm: acao.instanteDoToque,
                        chave: acao.chave
                    )
                case .checkout:
                    try await api.fazerCheckout(
                        turnoID: acao.turnoID,
                        distanciaMetros: acao.distanciaMetros,
                        registradoEm: acao.instanteDoToque,
                        chave: acao.chave
                    )
                case .avaliacao:
                    guard let resposta = acao.resposta else { continue }
                    _ = try await api.avaliar(turnoID: acao.turnoID, resposta: resposta, chave: acao.chave)
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
