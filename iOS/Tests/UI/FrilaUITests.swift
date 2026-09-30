import XCTest

@MainActor
final class FrilaUITests: XCTestCase {
    func testCatalogoAbreEmPortugues() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_CATALOGO", "-FRILA_SCENARIO", "success", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Frila UI"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Continuar"].exists)
    }

    func testCatalogoComTamanhoDeAcessibilidade() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_CATALOGO", "-FRILA_SCENARIO", "success", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Frila UI"].waitForExistence(timeout: 5))
    }

    func testConflitoTipadoDoClienteChegaATela() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_CATALOGO", "-FRILA_SCENARIO", "vaga-preenchida"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Validação do cliente"].waitForExistence(timeout: 5))
        app.buttons["Simular vaga preenchida"].tap()
        XCTAssertTrue(app.staticTexts["Esta vaga acabou de ser preenchida. Escolha outra oportunidade."].waitForExistence(timeout: 5))
    }

    func testSolicitacaoDeAcessoChegaAoClienteSemExporOEmailNaTelaDeResultado() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_CATALOGO", "-FRILA_SCENARIO", "success"]
        app.launch()

        let email = app.textFields["validacao-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        email.typeText("teste@frila.app")
        app.buttons["Enviar código"].tap()

        XCTAssertTrue(app.staticTexts["Código enviado. Consulte a caixa de entrada do e-mail de teste."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["teste@frila.app"].exists)
    }

    func testConfirmarCodigoAbreASessaoSemMostrarDadosDeAcesso() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_CATALOGO", "-FRILA_SCENARIO", "success"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Nenhuma sessão neste aparelho."].waitForExistence(timeout: 5))
        let email = app.textFields["validacao-email"]
        email.tap()
        email.typeText("teste@frila.app")
        app.buttons["Enviar código"].tap()
        XCTAssertTrue(app.staticTexts["Código enviado. Consulte a caixa de entrada do e-mail de teste."].waitForExistence(timeout: 5))

        let codigo = app.textFields["validacao-codigo"]
        codigo.tap()
        codigo.typeText("123456")
        app.buttons["Confirmar código"].tap()

        XCTAssertTrue(app.staticTexts["Sessão ativa neste aparelho."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["teste@frila.app"].exists)
        XCTAssertFalse(app.staticTexts["123456"].exists)
    }
}

/// Fluxo real do profissional (#104): o esquema Local abre na lista, sem argumento especial.
@MainActor
final class VagasUITests: XCTestCase {
    func testLocalAbreNaListaEODetalheTemOAvisoDaRN10SemTelefone() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
        let primeira = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-'")).firstMatch
        XCTAssertTrue(primeira.waitForExistence(timeout: 10))
        primeira.tap()

        let aviso = app.descendants(matching: .any)["aviso-rn10"]
        XCTAssertTrue(aviso.waitForExistence(timeout: 10))
        XCTAssertTrue(aviso.label.contains("seu telefone e WhatsApp serão mostrados"))
        // O detalhe não mostra telefone nem documento do estabelecimento.
        let comTelefone = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", ".*\\(?\\d{2}\\)? ?9? ?\\d{4}-?\\d{4}.*"))
        XCTAssertEqual(comTelefone.count, 0)
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'CNPJ' OR label CONTAINS[c] 'CPF'")).firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["detalhe-reputacao"].exists)
    }

    func testFiltroSemVagasMostraOEstadoVazio() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
        // O dublê só tem vaga de Garçom; filtrar por Bartender deixa a lista vazia.
        app.descendants(matching: .any)["filtro-funcao"].tap()
        let bartender = app.buttons["Bartender"]
        XCTAssertTrue(bartender.waitForExistence(timeout: 5))
        bartender.tap()
        XCTAssertTrue(app.descendants(matching: .any)["vagas-vazio"].waitForExistence(timeout: 10))
    }

    func testErroDaAPIMostraOEstadoDeErroComTentarNovamente() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "erro-na-lista"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["vagas-erro"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Tentar novamente"].exists)
    }

    func testSemRedeMostraOEstadoSemConexao() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "sem-rede"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["vagas-sem-conexao"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Tentar novamente"].exists)
    }

    func testListaComTamanhoDeAcessibilidadeMantemTituloEFiltros() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["filtro-funcao"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["filtro-data"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["filtro-distancia"].exists)
    }

    func testCatalogoSoAbreComPedidoExplicito() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.navigationBars["Frila UI"].exists)
        // Em Debug, o catálogo continua acessível pelo botão da barra.
        app.buttons["Catálogo"].tap()
        XCTAssertTrue(app.navigationBars["Frila UI"].waitForExistence(timeout: 10))
    }
}

/// Candidatura (#105) pela tela real: lista -> detalhe -> Candidatar-me -> resultado.
@MainActor
final class CandidaturaUITests: XCTestCase {
    private func abrirDetalheECandidatar(_ cenario: String, argumentos: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", cenario] + argumentos
        app.launch()
        let primeira = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-'")).firstMatch
        XCTAssertTrue(primeira.waitForExistence(timeout: 10))
        primeira.tap()
        let candidatar = app.buttons["candidatar"]
        XCTAssertTrue(candidatar.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["aviso-rn10"].exists, "o aviso da RN10 vem antes de Candidatar-me")
        candidatar.tap()
        return app
    }

    func testConfirmadaAbreMeuTurnoComOContato() {
        let app = abrirDetalheECandidatar("success")
        XCTAssertTrue(app.descendants(matching: .any)["resultado-confirmada"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["contato-do-turno"].exists)
        app.buttons["voltar-para-lista"].tap()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["1 vagas abertas"].waitForExistence(timeout: 10), "a lista é atualizada após a confirmação")
    }

    func testVagaPreenchidaTemTelaPropriaEVoltaParaALista() {
        let app = abrirDetalheECandidatar("vaga-preenchida")
        XCTAssertTrue(app.descendants(matching: .any)["resultado-vaga-preenchida"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["resultado-vaga-encerrada"].exists)
        app.buttons["voltar-para-lista-navegacao"].tap()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
    }

    func testVagaEncerradaTemTelaPropriaDiferenteDaPreenchida() {
        let app = abrirDetalheECandidatar("vaga-encerrada")
        XCTAssertTrue(app.descendants(matching: .any)["resultado-vaga-encerrada"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["resultado-vaga-preenchida"].exists)
        app.buttons["voltar-para-lista"].tap()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
    }

    func testTurnoSobrepostoMostraOConflitoSemApontarTurno() {
        let app = abrirDetalheECandidatar("inelegivel")
        XCTAssertTrue(app.descendants(matching: .any)["resultado-turno-sobreposto"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["ver-meu-turno"].exists, "sem link para um turno específico")
        app.buttons["voltar-para-lista"].tap()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
    }

    func testContaSuspensaMostraOMotivoEContestarDesabilitado() {
        let app = abrirDetalheECandidatar("inelegivel-suspenso")
        XCTAssertTrue(app.descendants(matching: .any)["resultado-conta-suspensa"].waitForExistence(timeout: 10))
        let contestar = app.buttons["contestar"]
        XCTAssertTrue(contestar.exists)
        XCTAssertFalse(contestar.isEnabled)
    }

    func testResultadoComTamanhoDeAcessibilidadeMantemOBotaoDeVolta() {
        let app = abrirDetalheECandidatar("vaga-preenchida", argumentos: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(app.descendants(matching: .any)["resultado-vaga-preenchida"].waitForExistence(timeout: 10))
        let voltar = app.buttons["voltar-para-lista"]
        XCTAssertTrue(voltar.waitForExistence(timeout: 5))
        voltar.tap()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
    }

    func testRotaPorVagaIDAbreODetalheSemCandidatar() {
        let app = XCUIApplication()
        // vaga.json do dublê.
        app.launchArguments = ["-FRILA_SCENARIO", "success", "-FRILA_VAGA_ID", "40000000-0000-0000-0000-000000000001"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["tela-detalhe-vaga"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["candidatar"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["resultado-confirmada"].exists, "a rota abre o detalhe, nunca aceita sozinha")
        app.buttons["candidatar"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["resultado-confirmada"].waitForExistence(timeout: 10))
    }
}
