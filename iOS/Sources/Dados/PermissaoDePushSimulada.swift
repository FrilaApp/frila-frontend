import Foundation
import FrilaDominio

/// A permissão de notificação sem o sistema: testes, prévias e o esquema Local, onde o pedido de
/// verdade deixaria os testes de interface à mercê do que o simulador já respondeu.
public final class PermissaoDePushSimulada: PermissaoDePush, @unchecked Sendable {
    private let trava = NSLock()
    private var atual: EstadoDaPermissaoDePush
    private let resposta: EstadoDaPermissaoDePush
    private var contagem = 0

    /// `resposta` é o que a pessoa responde quando o pedido do sistema aparece.
    public init(estado: EstadoDaPermissaoDePush = .concedida, resposta: EstadoDaPermissaoDePush = .concedida) {
        atual = estado
        self.resposta = resposta
    }

    /// Quantas vezes o pedido do sistema apareceu.
    public var pedidos: Int { trava.withLock { contagem } }

    public func estado() async -> EstadoDaPermissaoDePush { trava.withLock { atual } }

    public func pedir() async -> EstadoDaPermissaoDePush {
        trava.withLock {
            // Como no sistema: o pedido só aparece para quem ainda não respondeu.
            if atual == .naoPedida {
                contagem += 1
                atual = resposta
            }
            return atual
        }
    }

    /// A pessoa mudou a permissão nos Ajustes do sistema.
    public func mudarNosAjustes(para estado: EstadoDaPermissaoDePush) { trava.withLock { atual = estado } }
}
