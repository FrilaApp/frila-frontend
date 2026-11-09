import XCTest

/// Testes de interface e capturas do Lote 4 e Lote 5 (#B-L4).
/// Cobre: T1c, T1c-sem-resultado, T2b, T6b, T6c, T3b, T3c, T4b, T4b-horario-comecou, T4c, T4c-mensagem-enviada, T7b.
@MainActor
final class FrilaUITestsLote4: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func iniciar(argumento: String, ax5: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_SCENARIO", "success",
            "-FRILA_MODO_CLARO",
            "-AppleLanguages", "(pt-BR)",
            "-AppleLocale", "pt_BR",
            "-FRILA_SEM_ANIMACOES",
            argumento
        ]
        if ax5 {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
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
        let pasta = ProcessInfo.processInfo.environment["FRILA_CAPTURAS_DIR"] ?? ProcessInfo.processInfo.environment["TEST_RUNNER_FRILA_CAPTURAS_DIR"] ?? ProcessInfo.processInfo.environment["FRILA_CAPTURAS"]
        if let pasta, !pasta.isEmpty {
            try? FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
            try? captura.pngRepresentation.write(to: URL(fileURLWithPath: "\(pasta)/\(nome).png"))
        }
    }

    // MARK: - Lote 4

    func testT1cPontoBase() {
        let app = iniciar(argumento: "-FRILA_ABRIR_PONTO_BASE")
        XCTAssertTrue(app.descendants(matching: .any)["tela-escolha-ponto-base"].waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(app.buttons["ponto-base-concluir"].exists)
        capturar("T1c-padrao")
    }

    func testT1cPontoBaseAX5() {
        let app = iniciar(argumento: "-FRILA_ABRIR_PONTO_BASE", ax5: true)
        XCTAssertTrue(app.descendants(matching: .any)["tela-escolha-ponto-base"].waitForExistence(timeout: Espera.aparecer))
        capturar("T1c-ax5")
    }

    func testT1cSemResultado() {
        let app = iniciar(argumento: "-FRILA_ABRIR_PONTO_BASE_VAZIO")
        XCTAssertTrue(app.descendants(matching: .any)["ponto-base-sem-resultado"].waitForExistence(timeout: Espera.aparecer))
        capturar("T1c-sem-resultado")
    }

    func testT2bFiltrosVagas() {
        let app = iniciar(argumento: "-FRILA_ABRIR_FILTROS_VAGAS")
        XCTAssertTrue(app.descendants(matching: .any)["tela-filtros-vagas"].waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(app.buttons["filtros-concluir"].exists)
        capturar("T2b-padrao")
    }

    func testT2bFiltrosVagasAX5() {
        let app = iniciar(argumento: "-FRILA_ABRIR_FILTROS_VAGAS", ax5: true)
        XCTAssertTrue(app.descendants(matching: .any)["tela-filtros-vagas"].waitForExistence(timeout: Espera.aparecer))
        capturar("T2b-ax5")
    }

    func testT6bConfirmarCodigo() {
        let app = iniciar(argumento: "-FRILA_ABRIR_T6B_CODIGO")
        XCTAssertTrue(app.staticTexts["Confira seu e-mail"].waitForExistence(timeout: Espera.aparecer))
        capturar("T6b-padrao")
    }

    func testT6bConfirmarCodigoAX5() {
        let app = iniciar(argumento: "-FRILA_ABRIR_T6B_CODIGO", ax5: true)
        XCTAssertTrue(app.staticTexts["Confira seu e-mail"].waitForExistence(timeout: Espera.aparecer))
        capturar("T6b-ax5")
    }

    func testT6cDizerNome() {
        let app = iniciar(argumento: "-FRILA_ABRIR_T6C_NOME")
        XCTAssertTrue(app.descendants(matching: .any)["tela-dizer-nome"].waitForExistence(timeout: Espera.aparecer))
        capturar("T6c-padrao")
    }

    func testT6cDizerNomeAX5() {
        let app = iniciar(argumento: "-FRILA_ABRIR_T6C_NOME", ax5: true)
        XCTAssertTrue(app.descendants(matching: .any)["tela-dizer-nome"].waitForExistence(timeout: Espera.aparecer))
        capturar("T6c-ax5")
    }

    // MARK: - Lote 5

    func testT3bPerfilDaCasa() {
        let app = iniciar(argumento: "-FRILA_ABRIR_PERFIL_CASA")
        XCTAssertTrue(app.descendants(matching: .any)["tela-perfil-casa"].waitForExistence(timeout: Espera.aparecer))
        capturar("T3b-padrao")
    }

    func testT3bPerfilDaCasaAX5() {
        let app = iniciar(argumento: "-FRILA_ABRIR_PERFIL_CASA", ax5: true)
        XCTAssertTrue(app.descendants(matching: .any)["tela-perfil-casa"].waitForExistence(timeout: Espera.aparecer))
        capturar("T3b-ax5")
    }

    func testT3cVagaComCandidatura() {
        let app = iniciar(argumento: "-FRILA_ABRIR_VAGA_CANDIDATURA")
        XCTAssertTrue(app.descendants(matching: .any)["tela-vaga-candidatura"].waitForExistence(timeout: Espera.aparecer))
        capturar("T3c-padrao")
    }

    func testT3cVagaComCandidaturaAX5() {
        let app = iniciar(argumento: "-FRILA_ABRIR_VAGA_CANDIDATURA", ax5: true)
        XCTAssertTrue(app.descendants(matching: .any)["tela-vaga-candidatura"].waitForExistence(timeout: Espera.aparecer))
        capturar("T3c-ax5")
    }

    func testT4bCancelarTurno() {
        let app = iniciar(argumento: "-FRILA_ABRIR_CANCELAR_TURNO")
        XCTAssertTrue(app.descendants(matching: .any)["folha-cancelar-turno"].waitForExistence(timeout: Espera.aparecer))
        capturar("T4b-padrao")
    }

    func testT4bCancelarTurnoAX5() {
        let app = iniciar(argumento: "-FRILA_ABRIR_CANCELAR_TURNO", ax5: true)
        XCTAssertTrue(app.descendants(matching: .any)["folha-cancelar-turno"].waitForExistence(timeout: Espera.aparecer))
        capturar("T4b-ax5")
    }

    func testT4bHorarioComecou() {
        let app = iniciar(argumento: "-FRILA_ABRIR_CANCELAR_TURNO_COMECOU")
        XCTAssertTrue(app.buttons["cancelar-turno-sair-do-turno"].waitForExistence(timeout: Espera.aparecer))
        capturar("T4b-horario-comecou")
    }

    func testT4cChatSuporte() {
        let app = iniciar(argumento: "-FRILA_ABRIR_CHAT_SUPORTE")
        XCTAssertTrue(app.descendants(matching: .any)["tela-chat-suporte"].waitForExistence(timeout: Espera.aparecer))
        capturar("T4c-padrao")
    }

    func testT4cChatSuporteAX5() {
        let app = iniciar(argumento: "-FRILA_ABRIR_CHAT_SUPORTE", ax5: true)
        XCTAssertTrue(app.descendants(matching: .any)["tela-chat-suporte"].waitForExistence(timeout: Espera.aparecer))
        capturar("T4c-ax5")
    }

    func testT4cMensagemEnviada() {
        let app = iniciar(argumento: "-FRILA_ABRIR_CHAT_SUPORTE_ENVIADA")
        XCTAssertTrue(app.descendants(matching: .any)["chat-suporte-conversa"].waitForExistence(timeout: Espera.aparecer))
        capturar("T4c-mensagem-enviada")
    }

    func testT7bResumoTurno() {
        let app = iniciar(argumento: "-FRILA_ABRIR_RESUMO_TURNO")
        XCTAssertTrue(app.descendants(matching: .any)["tela-resumo-turno"].waitForExistence(timeout: Espera.aparecer))
        capturar("T7b-padrao")
    }

    func testT7bResumoTurnoAX5() {
        let app = iniciar(argumento: "-FRILA_ABRIR_RESUMO_TURNO", ax5: true)
        XCTAssertTrue(app.descendants(matching: .any)["tela-resumo-turno"].waitForExistence(timeout: Espera.aparecer))
        capturar("T7b-ax5")
    }
}
