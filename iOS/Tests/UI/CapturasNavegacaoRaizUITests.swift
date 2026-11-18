import XCTest

/// Navegação raiz do redesign: a barra de abas do profissional e da casa, com o ícone da aba ativa na cor de ação e
/// o conteúdo de cada aba na tinta. Passa por todas as abas e confere que continuam as mesmas, com rótulo.
/// `FRILA_CAPTURAS_DIR` (opcional) grava as imagens; sem ela, os anexos ficam só no resultado do teste.
@MainActor
final class CapturasNavegacaoRaizUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func iniciar(cenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", cenario, "-FRILA_MODO_CLARO", "-AppleLanguages", "(pt-BR)",
                               "-AppleLocale", "pt_BR", "-FRILA_SEM_ANIMACOES"]
        app.launch()
        return app
    }

    private func capturar(_ nome: String) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let captura = XCUIScreen.main.screenshot()
        let anexo = XCTAttachment(screenshot: captura)
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)
        if let pasta = ProcessInfo.processInfo.environment["FRILA_CAPTURAS_DIR"], !pasta.isEmpty {
            try? FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
            try? captura.pngRepresentation.write(to: URL(fileURLWithPath: "\(pasta)/\(nome).png"))
        }
    }

    /// Toca em cada aba, na ordem, confere que ela fica selecionada e captura a tela.
    private func percorrerAbas(cenario: String, prefixo: String, quantidade: Int) {
        let app = iniciar(cenario: cenario)
        let barra = app.tabBars.firstMatch
        XCTAssertTrue(barra.waitForExistence(timeout: Espera.aparecer), "a barra de abas deve aparecer")
        XCTAssertEqual(barra.buttons.count, quantidade, "as abas continuam as mesmas")
        for indice in 0..<quantidade {
            let aba = barra.buttons.element(boundBy: indice)
            XCTAssertFalse(aba.label.trimmingCharacters(in: .whitespaces).isEmpty, "a aba \(indice) tem rótulo")
            aba.tap()
            XCTAssertTrue(aba.isSelected, "a aba \(aba.label) fica selecionada depois do toque")
            capturar(String(format: "nav-raiz-%@-%02d", prefixo, indice))
        }
    }

    func testAbasDoProfissional() { percorrerAbas(cenario: "success", prefixo: "profissional", quantidade: 4) }

    func testAbasDaCasa() { percorrerAbas(cenario: "contratante", prefixo: "casa", quantidade: 2) }
}
