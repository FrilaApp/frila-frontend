import XCTest

/// B-L0 (pele nova): a lista de vagas (cartão) e o detalhe (botão primário) no tamanho padrão e em AX5.
/// `FRILA_CAPTURAS_DIR` (opcional) grava as imagens; sem ela, os anexos ficam só no resultado do teste.
@MainActor
final class CapturasPeleNovaUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func iniciar(extra: [String], ax5: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success", "-FRILA_MODO_CLARO", "-AppleLanguages", "(pt-BR)",
                               "-AppleLocale", "pt_BR", "-FRILA_SEM_ANIMACOES"] + extra
        if ax5 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
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

    private func listaDeVagas(ax5: Bool) {
        let app = iniciar(extra: [], ax5: ax5)
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: Espera.aparecer), "O feed de vagas deve abrir")
        capturar("pele-nova-lista-de-vagas-\(ax5 ? "ax5" : "padrao")")
    }

    private func detalheDaVaga(ax5: Bool) {
        let app = iniciar(extra: ["-FRILA_VAGA_ID", "40000000-0000-0000-0000-000000000001", "-FRILA_HORARIO_VAGA", "amanha-23h30"], ax5: ax5)
        XCTAssertTrue(app.descendants(matching: .any)["tela-detalhe-vaga"].waitForExistence(timeout: Espera.aparecer))
        let botao = app.buttons["candidatar"]
        XCTAssertTrue(botao.waitForExistence(timeout: Espera.aparecer), "o botão primário aparece")
        XCTAssertGreaterThanOrEqual(botao.frame.height, 44, "o alvo de toque do botão primário tem ao menos 44 pt")
        capturar("pele-nova-detalhe-botao-primario-\(ax5 ? "ax5" : "padrao")")
    }

    func testListaDeVagasNoTamanhoPadrao() { listaDeVagas(ax5: false) }

    func testListaDeVagasEmAX5() { listaDeVagas(ax5: true) }

    func testDetalheComBotaoPrimarioNoTamanhoPadrao() { detalheDaVaga(ax5: false) }

    func testDetalheComBotaoPrimarioEmAX5() { detalheDaVaga(ax5: true) }
}
