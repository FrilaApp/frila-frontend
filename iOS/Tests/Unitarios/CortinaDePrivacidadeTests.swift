import FrilaApresentacao
import SwiftUI
import Testing
import UIKit

@Suite("Cortina de privacidade no seletor de apps", .serialized)
struct CortinaDePrivacidadeTests {
    @Test("Esconde fora de .active: no seletor de apps (.inactive) e em segundo plano")
    func escondeForaDeAtivo() {
        #expect(!CortinaDePrivacidade.esconde(.active))
        #expect(CortinaDePrivacidade.esconde(.inactive))
        #expect(CortinaDePrivacidade.esconde(.background))
    }

    @MainActor
    @Test("A janela opaca fica acima da folha e da tela cheia sem tomar o foco",
          arguments: [UIModalPresentationStyle.pageSheet, .fullScreen])
    func cobreApresentacaoModal(estilo: UIModalPresentationStyle) async throws {
        let cena = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive })
        let chaveAnterior = cena.windows.first { $0.isKeyWindow }
        let janelasAnteriores = Set(cena.windows.map(ObjectIdentifier.init))
        let raiz = UIHostingController(rootView: Color.red.cortinaDePrivacidade())
        let janela = UIWindow(windowScene: cena)
        janela.rootViewController = raiz
        janela.isHidden = false
        defer {
            NotificationCenter.default.post(name: UIScene.didActivateNotification, object: cena)
            janela.isHidden = true
            janela.rootViewController = nil
        }
        // A ponte SwiftUI precisa entrar na hierarquia antes da apresentação UIKit.
        try await Task.sleep(for: .milliseconds(200))
        let folha = UIViewController()
        folha.view.backgroundColor = .red
        folha.modalPresentationStyle = estilo
        await withCheckedContinuation { continuacao in
            raiz.present(folha, animated: false) { continuacao.resume() }
        }
        #expect(raiz.presentedViewController === folha)

        // A mesma notificação síncrona que o UIKit envia antes da foto do seletor de apps.
        NotificationCenter.default.post(name: UIScene.willDeactivateNotification, object: cena)
        let cortina = try #require(cena.windows.first {
            !janelasAnteriores.contains(ObjectIdentifier($0)) && !$0.isHidden
                && $0.rootViewController?.view.accessibilityIdentifier == "cortina-de-privacidade"
        }, "O overlay antigo não cria uma janela acima da apresentação modal")
        #expect(cortina.windowLevel > janela.windowLevel)
        #expect(cena.windows.filter { !$0.isHidden }.allSatisfy { $0.windowLevel <= cortina.windowLevel })
        #expect(cortina.bounds == cena.coordinateSpace.bounds)
        #expect(cortina.rootViewController?.view.isOpaque == true)
        #expect(cortina.rootViewController?.view.backgroundColor?.cgColor.alpha == 1)
        #expect(!cortina.isKeyWindow)
        #expect(cena.windows.first { $0.isKeyWindow } === chaveAnterior)
        #expect(cortina.accessibilityElementsHidden)

        NotificationCenter.default.post(name: UIScene.didEnterBackgroundNotification, object: cena)
        #expect(!cortina.isHidden)
        NotificationCenter.default.post(name: UIScene.willEnterForegroundNotification, object: cena)
        #expect(!cortina.isHidden, "A volta ao primeiro plano ainda inativo mantém a proteção")
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: cena)
        #expect(cortina.isHidden)
        #expect(raiz.presentedViewController === folha, "Voltar preserva a folha aberta")
        #expect(cena.windows.first { $0.isKeyWindow } === chaveAnterior)
    }
}
