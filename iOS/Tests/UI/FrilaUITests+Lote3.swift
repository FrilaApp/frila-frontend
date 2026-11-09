import XCTest

/// Testes de interface e capturas do Lote 3 (#B-L3).
/// Cobre: T5 (Avaliação), T6 (Entrada), T9 (Perfil e Conta).
@MainActor
final class FrilaUITestsLote3: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func iniciar(argumentos: [String], ax5: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var args = [
            "-FRILA_MODO_CLARO",
            "-AppleLanguages", "(pt-BR)",
            "-AppleLocale", "pt_BR",
            "-FRILA_SEM_ANIMACOES"
        ]
        if !argumentos.contains("-FRILA_SCENARIO") {
            args += ["-FRILA_SCENARIO", "success"]
        }
        args += argumentos
        if ax5 {
            args += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments = args
        app.launch()
        return app
    }

    private func capturar(_ nome: String) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        let captura = XCUIScreen.main.screenshot()
        let anexo = XCTAttachment(screenshot: captura)
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)
        let pasta = ProcessInfo.processInfo.environment["FRILA_CAPTURAS_DIR"]
            ?? "/Users/cauecarneiro/Documents/Projetos/Frila/orquestracao/retornos/B-L3-provas/simulador"
        try? FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
        try? captura.pngRepresentation.write(to: URL(fileURLWithPath: "\(pasta)/\(nome).png"))
    }

    // MARK: - T5: Avaliação

    func testT5Avaliacao() {
        let app = iniciar(argumentos: ["-FRILA_ABRIR_AVALIACAO_UI_TEST"])
        XCTAssertTrue(app.descendants(matching: .any)["tela-avaliacao"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["pergunta-avaliacao"].exists)
        XCTAssertTrue(app.buttons["resposta-sim"].exists)
        XCTAssertTrue(app.buttons["resposta-nao"].exists)
        capturar("T5-padrao")
    }

    func testT5AvaliacaoAX5() {
        let app = iniciar(argumentos: ["-FRILA_ABRIR_AVALIACAO_UI_TEST"], ax5: true)
        XCTAssertTrue(app.descendants(matching: .any)["tela-avaliacao"].waitForExistence(timeout: 10))
        capturar("T5-ax5")
    }

    // MARK: - T6: Entrada

    func testT6Entrada() {
        let app = iniciar(argumentos: ["-FRILA_ENTRADA", "-FRILA_SCENARIO", "primeiro-acesso"])
        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["entrada-receber-codigo"].exists)
        capturar("T6-padrao")
    }

    func testT6EntradaAX5() {
        let app = iniciar(argumentos: ["-FRILA_ENTRADA", "-FRILA_SCENARIO", "primeiro-acesso"], ax5: true)
        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        capturar("T6-ax5")
    }

    // MARK: - T9: Perfil e Conta

    func testT9Perfil() {
        let app = iniciar(argumentos: [])
        let perfil = app.tabBars.buttons["Conta"]
        XCTAssertTrue(perfil.waitForExistence(timeout: 20))
        perfil.tap()
        capturar("T9-padrao")
    }

    func testT9PerfilAX5() {
        let app = iniciar(argumentos: [], ax5: true)
        let perfil = app.tabBars.buttons["Conta"]
        XCTAssertTrue(perfil.waitForExistence(timeout: 20))
        perfil.tap()
        capturar("T9-ax5")
    }
}
