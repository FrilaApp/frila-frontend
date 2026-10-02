import XCTest

/// Publicar vaga a partir de Minhas vagas: o contratante que já tem estabelecimento publica a
/// segunda vaga sem passar pelo cadastro. No dublê, pelo fluxo de produto.
@MainActor
final class PublicarVagaEmMinhasVagasUITests: XCTestCase {
    private func abrir(_ outros: [String] = [], cenario: String = "contratante") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", cenario] + outros
        app.launch()
        return app
    }

    private func vagas(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-contratante-'"))
    }

    private func preencherEPublicar(_ app: XCUIApplication) {
        XCTAssertTrue(app.descendants(matching: .any)["publicar-vaga-formulario"].waitForExistence(timeout: 10))
        // O endereço da casa vem preenchido: é o que a leitura do cadastro traz.
        XCTAssertEqual(app.textFields["Endereço do turno"].value as? String, "CLS 405, Asa Sul, Brasília - DF")

        app.buttons["Função, Selecione uma função"].tap()
        app.buttons["Garçom"].firstMatch.tap()
        // O responsável vai primeiro: o teclado numérico do valor não tem como ser fechado, e
        // cobriria o campo de baixo.
        let responsavel = app.textFields["Quem recebe no local"]
        responsavel.tap()
        responsavel.digitarEEsperar("Marina")
        let valor = app.textFields["Valor por posição"]
        valor.tap()
        valor.digitarEEsperar("18000", esperado: "180,00")
        app.swipeUp()
        app.buttons["publicar-vaga-botao"].tap()
    }

    func testContratanteComEstabelecimentoPublicaASegundaVagaEElaApareceNaLista() {
        let app = abrir()

        XCTAssertTrue(app.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 15))
        XCTAssertTrue(vagas(app).firstMatch.waitForExistence(timeout: 10))
        let antes = vagas(app).count
        let entrada = app.buttons["publicar-vaga-entrada"]
        XCTAssertTrue(entrada.isHittable, "a entrada fica à vista com a lista cheia, e não só na lista vazia")
        entrada.tap()

        preencherEPublicar(app)

        XCTAssertTrue(app.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 10))
        let depois = NSPredicate(format: "count == %d", antes + 1)
        expectation(for: depois, evaluatedWith: vagas(app))
        waitForExpectations(timeout: 10)
        XCTAssertTrue(app.buttons["publicar-vaga-entrada"].exists)
    }

    func testCancelarVoltaParaMinhasVagasSemPublicar() {
        let app = abrir()

        XCTAssertTrue(vagas(app).firstMatch.waitForExistence(timeout: 15))
        let antes = vagas(app).count
        app.buttons["publicar-vaga-entrada"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["publicar-vaga-formulario"].waitForExistence(timeout: 10))

        app.buttons["cancelar-publicacao"].tap()

        XCTAssertTrue(vagas(app).firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(vagas(app).count, antes)
    }

    func testPublicarPorMinhasVagasMostraAExplicacaoDaNotificacao() {
        let app = abrir(["-FRILA_PERMISSAO_PUSH", "nao-pedida"])

        XCTAssertTrue(app.buttons["publicar-vaga-entrada"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.descendants(matching: .any)["explicacao-do-push"].exists)
        app.buttons["publicar-vaga-entrada"].tap()

        preencherEPublicar(app)

        XCTAssertTrue(app.staticTexts["Ative as notificações"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Confirmação de quem vai trabalhar"].exists)
    }

    func testPublicarPorMinhasVagasOfereceModoSelecao() {
        let app = abrir()

        XCTAssertTrue(app.buttons["publicar-vaga-entrada"].waitForExistence(timeout: 15))
        app.buttons["publicar-vaga-entrada"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["publicar-vaga-formulario"].waitForExistence(timeout: 10))

        let modo = app.segmentedControls["modo-vaga-picker"]
        rolarAte(modo, em: app)
        XCTAssertTrue(modo.exists, "o formulário de publicação por Minhas vagas oferece o seletor de modo")
        XCTAssertTrue(modo.buttons["Urgência"].isSelected)
        XCTAssertTrue(modo.buttons["Seleção"].exists)

        let explicacao = app.staticTexts["modo-vaga-explicacao"]
        XCTAssertEqual(explicacao.label, "O primeiro profissional que aceitar é confirmado na hora.")

        modo.buttons["Seleção"].tap()
        XCTAssertTrue(modo.buttons["Seleção"].isSelected)
        XCTAssertTrue(explicacao.label.contains("O início precisa estar a mais de 24 horas"), explicacao.label)
    }

    func testErroAoLerEstabelecimentoMostraMensagemEVoltarReencontraLista() {
        let app = abrir(cenario: "erro-ao-ler-meu-estabelecimento")

        XCTAssertTrue(app.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 15))
        XCTAssertTrue(vagas(app).firstMatch.waitForExistence(timeout: 10))

        let entrada = app.buttons["publicar-vaga-entrada"]
        XCTAssertTrue(entrada.waitForExistence(timeout: 5))
        entrada.tap()

        let telaErro = app.descendants(matching: .any)["publicar-vaga-erro"]
        XCTAssertTrue(telaErro.waitForExistence(timeout: 10), "ao falhar a leitura de meu_estabelecimento, a tela de erro é exibida")
        XCTAssertTrue(app.staticTexts["Não foi possível concluir esta ação. Tente novamente."].exists)

        let voltar = app.buttons["voltar-para-minhas-vagas"]
        XCTAssertTrue(voltar.waitForExistence(timeout: 5))
        voltar.tap()

        XCTAssertTrue(app.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 10))
        XCTAssertTrue(vagas(app).firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["publicar-vaga-entrada"].exists)
    }

    private func rolarAte(_ elemento: XCUIElement, em app: XCUIApplication, tentativas: Int = 10) {
        let janela = app.windows.firstMatch.frame
        for _ in 0..<tentativas {
            guard elemento.exists else {
                app.swipeUp(velocity: .slow)
                continue
            }
            let quadro = elemento.frame
            if elemento.isHittable, quadro.minY >= 120, quadro.maxY <= janela.height - 60 { return }
            if quadro.minY < 120 {
                app.swipeDown(velocity: .slow)
            } else {
                app.swipeUp(velocity: .slow)
            }
        }
    }
}

