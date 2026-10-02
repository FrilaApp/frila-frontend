import Foundation

/// O que o sistema diz da permissão de notificação deste app.
public enum EstadoDaPermissaoDePush: String, Equatable, Sendable {
    /// O sistema ainda não perguntou: é o único estado em que o pedido aparece.
    case naoPedida = "nao-pedida"
    case concedida
    /// A pessoa recusou, ou desligou nos Ajustes. O pedido do sistema não aparece de novo: o
    /// caminho de volta é pelos Ajustes.
    case negada
}

public protocol PermissaoDePush: Sendable {
    func estado() async -> EstadoDaPermissaoDePush
    /// Mostra o pedido do sistema, que só aparece uma vez na vida do app, e devolve a resposta.
    func pedir() async -> EstadoDaPermissaoDePush
}
