import SwiftUI
import UIKit

/// Uma janela opaca da própria cena cobre a raiz e todas as apresentações modais (A4).
/// Os avisos síncronos do UIKit mostram a cortina antes da foto do seletor de apps;
/// somente a reativação da cena a esconde. A janela nunca se torna chave nem entra no VoiceOver.
public struct CortinaDePrivacidade: ViewModifier {
    public init() {}

    nonisolated public static func esconde(_ fase: ScenePhase) -> Bool {
        fase != .active
    }

    public func body(content: Content) -> some View {
        content.background { PonteDaCortina().frame(width: 0, height: 0) }
    }
}

/// A ponte obtém a cena da janela que contém esta raiz, sem escolher outra cena do aplicativo.
private struct PonteDaCortina: UIViewRepresentable {
    func makeUIView(context: Context) -> AncoraDaCortina { AncoraDaCortina() }
    func updateUIView(_ uiView: AncoraDaCortina, context: Context) {}

    static func dismantleUIView(_ uiView: AncoraDaCortina, coordinator: ()) {
        uiView.desligar()
    }
}

private final class AncoraDaCortina: UIView {
    private weak var cena: UIWindowScene?
    private var cortina: UIWindow?
    private var observadores: [NSObjectProtocol] = []

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Uma tela cheia pode retirar a raiz da janela até ser dispensada. A cortina
        // continua observando essa cena; somente o dismantle definitivo a desliga.
        guard let novaCena = window?.windowScene else { return }
        guard cena !== novaCena else { return }
        desligar()
        cena = novaCena

        let janela = JanelaDaCortina(windowScene: novaCena)
        janela.frame = novaCena.coordinateSpace.bounds
        janela.windowLevel = .alert + 1
        janela.isUserInteractionEnabled = false
        janela.accessibilityElementsHidden = true
        let controlador = UIViewController()
        controlador.view.backgroundColor = FrilaCor.fundoUIKit
        controlador.view.isOpaque = true
        controlador.view.accessibilityIdentifier = "cortina-de-privacidade"
        controlador.view.accessibilityElementsHidden = true
        janela.rootViewController = controlador
        cortina = janela

        observar(UIScene.willDeactivateNotification, na: novaCena, esconderConteudo: true)
        observar(UIScene.didEnterBackgroundNotification, na: novaCena, esconderConteudo: true)
        observar(UIScene.willEnterForegroundNotification, na: novaCena, esconderConteudo: true)
        observar(UIScene.didActivateNotification, na: novaCena, esconderConteudo: false)
        atualizar(esconderConteudo: novaCena.activationState != .foregroundActive)
    }

    private func observar(_ aviso: Notification.Name, na cena: UIWindowScene, esconderConteudo: Bool) {
        observadores.append(NotificationCenter.default.addObserver(forName: aviso, object: cena, queue: .main) { [weak self] _ in
            // Os avisos de cena são entregues pelo UIKit na thread principal. Atualizar aqui,
            // sem Task nem animação, evita aguardar outra renderização SwiftUI antes da captura.
            MainActor.assumeIsolated { self?.atualizar(esconderConteudo: esconderConteudo) }
        })
    }

    private func atualizar(esconderConteudo: Bool) {
        cortina?.isHidden = !esconderConteudo
    }

    func desligar() {
        for observador in observadores { NotificationCenter.default.removeObserver(observador) }
        observadores.removeAll()
        cortina?.isHidden = true
        cortina?.rootViewController = nil
        cortina = nil
        cena = nil
    }
}

private final class JanelaDaCortina: UIWindow {
    override var canBecomeKey: Bool { false }
}

extension View {
    public func cortinaDePrivacidade() -> some View {
        modifier(CortinaDePrivacidade())
    }
}
