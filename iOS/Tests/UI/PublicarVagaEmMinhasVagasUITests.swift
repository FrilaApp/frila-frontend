import XCTest

/// Publicar vaga a partir de Minhas vagas: o contratante que já tem estabelecimento publica a
/// segunda vaga sem passar pelo cadastro. No dublê, pelo fluxo de produto.
@MainActor
final class PublicarVagaEmMinhasVagasUITests: XCTestCase {
    private func abrir(_ outros: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "contratante"] + outros
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
        responsavel.typeText("Marina\n")
        let valor = app.textFields["Valor por posição"]
        valor.tap()
        valor.typeText("18000")
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
}
