import Foundation

/// O lado do sistema do push neste aparelho: de onde vem o token e o que já foi entregue.
public protocol CanalDePush: Sendable {
    /// Liga o aparelho ao serviço de push. O token chega depois, a quem o canal foi ligado, e
    /// chega de novo sempre que trocar. Chamado a cada abertura com conta e permissão.
    func ativar() async
    /// Tira da central de notificações o que já foi entregue: é o que a conta que saiu deixaria
    /// à vista de quem pegar o aparelho depois (RN15).
    func limparEntregues() async
}
