import SwiftUI

/// A cortina sobre o app no seletor de apps (auditoria de 03/10/2026). O sistema tira a foto da
/// tela quando o app deixa de estar ativo, e a foto fica no seletor e no disco: telefone da outra
/// parte, endereço do turno e o relato de uma denúncia não devem estar nela. Com a cena fora de
/// `.active`, uma superfície opaca cobre o conteúdo; ao voltar, ela some.
///
/// Uso, na raiz do app: `.cortinaDePrivacidade()`. A cena é lida do ambiente, então o modificador
/// não precisa de estado de quem o aplica.
public struct CortinaDePrivacidade: ViewModifier {
    @Environment(\.scenePhase) private var fase

    public init() {}

    /// Esconde fora de `.active`: `.inactive` é o seletor de apps e a central de notificações, e
    /// `.background` vem depois dele.
    public static func esconde(_ fase: ScenePhase) -> Bool {
        fase != .active
    }

    public func body(content: Content) -> some View {
        content.overlay {
            if Self.esconde(fase) {
                FrilaCor.fundo
                    .ignoresSafeArea()
                    .accessibilityIdentifier("cortina-de-privacidade")
                    .accessibilityHidden(true)
            }
        }
    }
}

extension View {
    public func cortinaDePrivacidade() -> some View {
        modifier(CortinaDePrivacidade())
    }
}
