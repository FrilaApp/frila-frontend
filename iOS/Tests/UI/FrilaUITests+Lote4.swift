import XCTest

/// Testes de interface e capturas do Lote 4 (#B-L4).
/// Cobre as telas reais do app:
/// - T4b (FolhaDeCancelamento)
/// - T4c (FolhaSuporteTurno) e estado enviado
/// - T6b (TelaCodigo)
/// - T3c (CandidaturaEmSelecao)
@MainActor
final class FrilaUITestsLote4: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func capturar(_ nome: String) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        let captura = XCUIScreen.main.screenshot()
        let anexo = XCTAttachment(screenshot: captura)
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)
        let pasta = ProcessInfo.processInfo.environment["FRILA_CAPTURAS_DIR"] ?? ProcessInfo.processInfo.environment["TEST_RUNNER_FRILA_CAPTURAS_DIR"] ?? ProcessInfo.processInfo.environment["FRILA_CAPTURAS"]
        if let pasta, !pasta.isEmpty {
            try? FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
            try? captura.pngRepresentation.write(to: URL(fileURLWithPath: "\(pasta)/\(nome).png"))
        }
    }

    // MARK: - T6b · TelaCodigo

    func testT6bCodigoReal() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_SCENARIO", "primeiro-acesso",
            "-FRILA_MODO_CLARO",
            "-AppleLanguages", "(pt-BR)",
            "-AppleLocale", "pt_BR",
            "-FRILA_SEM_ANIMACOES"
        ]
        app.launch()

        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.typeText("ju.ramos@email.com")

        let receber = app.buttons["entrada-receber-codigo"]
        if receber.waitForExistence(timeout: 5) {
            receber.tap()
        }

        let codigo = app.textFields["Código de acesso"]
        XCTAssertTrue(codigo.waitForExistence(timeout: 10))
        capturar("T6b-padrao")
    }

    func testT6bCodigoRealAX5() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_SCENARIO", "primeiro-acesso",
            "-FRILA_MODO_CLARO",
            "-AppleLanguages", "(pt-BR)",
            "-AppleLocale", "pt_BR",
            "-FRILA_SEM_ANIMACOES",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()

        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.typeText("ju.ramos@email.com")

        let receber = app.buttons["entrada-receber-codigo"]
        if receber.waitForExistence(timeout: 5) {
            receber.tap()
        }

        let codigo = app.textFields["Código de acesso"]
        XCTAssertTrue(codigo.waitForExistence(timeout: 10))
        capturar("T6b-ax5")
    }

    // MARK: - T4b · FolhaDeCancelamento

    func testT4bCancelamentoReal() {
        let app = XCUIApplication()
        let turnoID = "23000000-0000-0000-0000-000000000001"
        app.launchArguments = [
            "-FRILA_SCENARIO", "turno-confirmado-longe",
            "-FRILA_CACHE_VAZIO_UI_TEST",
            "-FRILA_MODO_CLARO",
            "-AppleLanguages", "(pt-BR)",
            "-AppleLocale", "pt_BR",
            "-FRILA_SEM_ANIMACOES"
        ]
        app.launch()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: Espera.aparecer))
        app.tabBars.buttons["Meus turnos"].tap()

        let cartao = app.buttons["meu-turno-\(turnoID)"]
        XCTAssertTrue(cartao.waitForExistence(timeout: 10))
        cartao.tap()

        let cancelar = app.buttons["cancelar-turno"]
        XCTAssertTrue(cancelar.waitForExistence(timeout: Espera.aparecer))
        app.swipeUp()
        for _ in 0..<4 where !cancelar.isHittable {
            app.swipeUp()
        }
        cancelar.tap()

        let folha = app.descendants(matching: .any)["folha-de-cancelamento"].firstMatch
        XCTAssertTrue(folha.waitForExistence(timeout: Espera.aparecer))
        capturar("T4b-padrao")
    }

    func testT4bCancelamentoRealAX5() {
        let app = XCUIApplication()
        let turnoID = "23000000-0000-0000-0000-000000000001"
        app.launchArguments = [
            "-FRILA_SCENARIO", "turno-confirmado-longe",
            "-FRILA_CACHE_VAZIO_UI_TEST",
            "-FRILA_MODO_CLARO",
            "-AppleLanguages", "(pt-BR)",
            "-AppleLocale", "pt_BR",
            "-FRILA_SEM_ANIMACOES",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: Espera.aparecer))
        app.tabBars.buttons["Meus turnos"].tap()

        let cartao = app.buttons["meu-turno-\(turnoID)"]
        XCTAssertTrue(cartao.waitForExistence(timeout: 10))
        cartao.tap()

        let cancelar = app.buttons["cancelar-turno"]
        XCTAssertTrue(cancelar.waitForExistence(timeout: Espera.aparecer))
        app.swipeUp()
        for _ in 0..<4 where !cancelar.isHittable {
            app.swipeUp()
        }
        cancelar.tap()

        let folha = app.descendants(matching: .any)["folha-de-cancelamento"].firstMatch
        XCTAssertTrue(folha.waitForExistence(timeout: Espera.aparecer))
        capturar("T4b-ax5")
    }

    // MARK: - T4c · FolhaSuporteTurno

    func testT4cSuporteReal() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_ABRIR_SUPORTE_TURNO",
            "-FRILA_SCENARIO", "success",
            "-FRILA_CACHE_VAZIO_UI_TEST",
            "-FRILA_MODO_CLARO",
            "-AppleLanguages", "(pt-BR)",
            "-AppleLocale", "pt_BR",
            "-FRILA_SEM_ANIMACOES"
        ]
        app.launch()

        let folha = app.descendants(matching: .any)["folha-suporte-turno"]
        XCTAssertTrue(folha.waitForExistence(timeout: 10))
        capturar("T4c-padrao")
    }

    func testT4cSuporteRealAX5() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_ABRIR_SUPORTE_TURNO",
            "-FRILA_SCENARIO", "success",
            "-FRILA_CACHE_VAZIO_UI_TEST",
            "-FRILA_MODO_CLARO",
            "-AppleLanguages", "(pt-BR)",
            "-AppleLocale", "pt_BR",
            "-FRILA_SEM_ANIMACOES",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()

        let folha = app.descendants(matching: .any)["folha-suporte-turno"]
        XCTAssertTrue(folha.waitForExistence(timeout: 10))
        capturar("T4c-ax5")
    }

    func testT4cSuporteMensagemEnviada() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_ABRIR_SUPORTE_TURNO",
            "-FRILA_SCENARIO", "success",
            "-FRILA_CACHE_VAZIO_UI_TEST",
            "-FRILA_MODO_CLARO",
            "-AppleLanguages", "(pt-BR)",
            "-AppleLocale", "pt_BR",
            "-FRILA_SEM_ANIMACOES"
        ]
        app.launch()

        let folha = app.descendants(matching: .any)["folha-suporte-turno"]
        XCTAssertTrue(folha.waitForExistence(timeout: 10))

        let campoRelato = app.descendants(matching: .any)["campo-relato-suporte"]
        if campoRelato.waitForExistence(timeout: 5) {
            campoRelato.tap()
            campoRelato.typeText("Trabalhei o turno todo, mas a presenca nao foi marcada.")
            if app.buttons["recolher-teclado"].exists {
                app.buttons["recolher-teclado"].tap()
            }
        }

        let botaoEnviar = app.descendants(matching: .any)["botao-enviar-email-suporte"]
        if botaoEnviar.waitForExistence(timeout: 5) {
            app.swipeUp()
            if botaoEnviar.isHittable {
                botaoEnviar.tap()
            }
        }

        capturar("T4c-mensagem-enviada")
    }

    // MARK: - T3c · CandidaturaEmSelecao

    func testT3cCandidaturaPendenteReal() {
        let app = XCUIApplication()
        let candidaturaID = "6F1C2A4E-2B7D-4C5E-9A1F-3D2E1C0B9A88"
        app.launchArguments = [
            "-FRILA_SCENARIO", "candidatura-pendente",
            "-FRILA_CACHE_VAZIO_UI_TEST",
            "-FRILA_MODO_CLARO",
            "-AppleLanguages", "(pt-BR)",
            "-AppleLocale", "pt_BR",
            "-FRILA_SEM_ANIMACOES"
        ]
        app.launch()

        let aba = app.tabBars.buttons["Candidaturas"]
        XCTAssertTrue(aba.waitForExistence(timeout: 15))
        aba.tap()

        let pendente = app.buttons["candidatura-\(candidaturaID)"]
        XCTAssertTrue(pendente.waitForExistence(timeout: 10))
        pendente.tap()

        let enviada = app.descendants(matching: .any)["candidatura-enviada"]
        XCTAssertTrue(enviada.waitForExistence(timeout: 10))
        capturar("T3c-padrao")
    }

    func testT3cCandidaturaPendenteRealAX5() {
        let app = XCUIApplication()
        let candidaturaID = "6F1C2A4E-2B7D-4C5E-9A1F-3D2E1C0B9A88"
        app.launchArguments = [
            "-FRILA_SCENARIO", "candidatura-pendente",
            "-FRILA_CACHE_VAZIO_UI_TEST",
            "-FRILA_MODO_CLARO",
            "-AppleLanguages", "(pt-BR)",
            "-AppleLocale", "pt_BR",
            "-FRILA_SEM_ANIMACOES",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()

        let aba = app.tabBars.buttons["Candidaturas"]
        XCTAssertTrue(aba.waitForExistence(timeout: 15))
        aba.tap()

        let pendente = app.buttons["candidatura-\(candidaturaID)"]
        XCTAssertTrue(pendente.waitForExistence(timeout: 10))
        pendente.tap()

        let enviada = app.descendants(matching: .any)["candidatura-enviada"]
        XCTAssertTrue(enviada.waitForExistence(timeout: 10))
        capturar("T3c-ax5")
    }
}
