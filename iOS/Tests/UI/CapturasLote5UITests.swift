import XCTest

@MainActor
final class CapturasLote5UITests: XCTestCase {
    private let pastaProvas = "/Users/cauecarneiro/Documents/Projetos/Frila/orquestracao/retornos/B-L5-provas"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func iniciar(argumentos: [String], ax5: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_MODO_CLARO",
            "-AppleLanguages", "(pt-BR)",
            "-AppleLocale", "pt_BR",
            "-FRILA_SEM_ANIMACOES"
        ] + argumentos
        if ax5 {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityXXXL"
            ]
        }
        AjudanteDeLancamentoUITests.preparar(app)
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: Espera.aparecer)
        return app
    }

    private func capturar(_ screenshot: XCUIScreenshot, nome: String) {
        let anexo = XCTAttachment(screenshot: screenshot)
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)

        try? FileManager.default.createDirectory(atPath: pastaProvas, withIntermediateDirectories: true)
        let destino = URL(fileURLWithPath: "\(pastaProvas)/\(nome).png")
        try? screenshot.pngRepresentation.write(to: destino)
    }

    private func rolarAte(_ elemento: XCUIElement, em app: XCUIApplication, tentativas: Int = 10) {
        let altura = app.windows.firstMatch.frame.height
        for _ in 0..<tentativas {
            if elemento.exists, elemento.isHittable, elemento.frame.minY > 100, elemento.frame.maxY < altura - 40 { return }
            if elemento.exists, elemento.frame.minY <= 100 { app.swipeDown() } else { app.swipeUp() }
        }
    }

    // 1. TelaTurnoDoContratante
    private func turnoDoContratante(ax5: Bool) {
        let app = iniciar(argumentos: ["-FRILA_SCENARIO", "checkin-manual-pendente"], ax5: ax5)
        let botao = app.buttons["acompanhar-turno-82000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(botao.waitForExistence(timeout: 15))
        botao.tap()
        XCTAssertTrue(app.staticTexts["Chegada"].waitForExistence(timeout: 10))
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        capturar(app.screenshot(), nome: "turno-do-contratante-\(ax5 ? "ax5" : "padrao")")
    }

    // 2. CandidatosDaVaga (com selo 'da equipe')
    private func candidatosDaVaga(ax5: Bool) {
        let app = iniciar(argumentos: ["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "selecao-com-candidatos"], ax5: ax5)
        let vagaID = "40000000-0000-0000-0000-000000000001"
        let cartao = app.buttons["vaga-contratante-\(vagaID)"]
        XCTAssertTrue(cartao.waitForExistence(timeout: 15))
        cartao.tap()
        let candidatos = app.descendants(matching: .any)["candidatos-da-vaga"]
        XCTAssertTrue(candidatos.waitForExistence(timeout: 10))
        let selo = app.staticTexts["Da sua equipe"]
        rolarAte(selo, em: app)
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        capturar(app.screenshot(), nome: "candidatos-da-vaga-\(ax5 ? "ax5" : "padrao")")
    }

    // 3. RepublicarPosicoesRestantes (o botão)
    private func republicarPosicoesRestantes(ax5: Bool) {
        let app = iniciar(argumentos: ["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "selecao-encerrada-sem-escolha"], ax5: ax5)
        XCTAssertTrue(app.staticTexts["Minhas vagas"].waitForExistence(timeout: 15))
        let botao = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "republicar-urgencia-vaga-")).firstMatch
        XCTAssertTrue(botao.waitForExistence(timeout: 15))
        rolarAte(botao, em: app)
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        capturar(app.screenshot(), nome: "republicar-posicoes-restantes-\(ax5 ? "ax5" : "padrao")")
    }

    // 4. TelaAcompanharChamadas
    private func acompanharChamadas(ax5: Bool) {
        let app = iniciar(argumentos: ["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "chamadas-enviadas"], ax5: ax5)
        let vaga = "C1000000-0000-0000-0000-000000000002"
        let cartao = app.buttons["vaga-contratante-\(vaga)"]
        XCTAssertTrue(cartao.waitForExistence(timeout: 15))
        rolarAte(cartao, em: app)
        cartao.tap()
        let acompanhar = app.buttons["acompanhar-chamadas-\(vaga)"]
        XCTAssertTrue(acompanhar.waitForExistence(timeout: 10))
        rolarAte(acompanhar, em: app)
        acompanhar.tap()
        XCTAssertTrue(app.navigationBars["Acompanhar chamadas"].waitForExistence(timeout: 10))
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        capturar(app.screenshot(), nome: "acompanhar-chamadas-\(ax5 ? "ax5" : "padrao")")
    }

    // 5. TelaDetalheChamadaRecebida
    private func detalheChamadaRecebida(ax5: Bool) {
        let app = iniciar(argumentos: [
            "-FRILA_SCENARIO", "chamada-recebida",
            "-FRILA_PUSH", "chamada_recebida",
            "-FRILA_PUSH_CHAMADA_ID", "c2000000-0000-0000-0000-000000000001"
        ], ax5: ax5)
        let aceitar = app.buttons["aceitar-chamada"]
        XCTAssertTrue(aceitar.waitForExistence(timeout: 15))
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        capturar(app.screenshot(), nome: "detalhe-chamada-recebida-\(ax5 ? "ax5" : "padrao")")
    }

    // 6. TelaCadastroEstabelecimento
    private func cadastroEstabelecimento(ax5: Bool) {
        let app = iniciar(argumentos: [
            "-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO",
            "-FRILA_CADASTRO_UI_TEST"
        ], ax5: ax5)
        XCTAssertTrue(app.staticTexts["Dados do negócio"].waitForExistence(timeout: 15))
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        capturar(app.screenshot(), nome: "cadastro-estabelecimento-\(ax5 ? "ax5" : "padrao")")
    }

    func testTurnoDoContratantePadrao() { turnoDoContratante(ax5: false) }
    func testTurnoDoContratanteAX5() { turnoDoContratante(ax5: true) }

    func testCandidatosDaVagaPadrao() { candidatosDaVaga(ax5: false) }
    func testCandidatosDaVagaAX5() { candidatosDaVaga(ax5: true) }

    func testRepublicarPosicoesRestantesPadrao() { republicarPosicoesRestantes(ax5: false) }
    func testRepublicarPosicoesRestantesAX5() { republicarPosicoesRestantes(ax5: true) }

    func testAcompanharChamadasPadrao() { acompanharChamadas(ax5: false) }
    func testAcompanharChamadasAX5() { acompanharChamadas(ax5: true) }

    func testDetalheChamadaRecebidaPadrao() { detalheChamadaRecebida(ax5: false) }
    func testDetalheChamadaRecebidaAX5() { detalheChamadaRecebida(ax5: true) }

    func testCadastroEstabelecimentoPadrao() { cadastroEstabelecimento(ax5: false) }
    func testCadastroEstabelecimentoAX5() { cadastroEstabelecimento(ax5: true) }
}
