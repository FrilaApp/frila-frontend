import XCTest

/// Critério de aceite do `FrilaSearchBar`: o campo de busca de funções e o campo de ponto base fecham o
/// teclado pelo padrão do app (toque fora, Return e botão de limpar), sem perder o texto digitado quando
/// o fechamento é por toque fora ou Return.
final class FrilaSearchBarUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func abrirCriacaoDePerfil() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "sem-perfil-profissional"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["tela-perfil-profissional"].waitForExistence(timeout: Espera.aparecer))
        return app
    }

    private func aguardarTecladoFechado(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let sumiu = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [sumiu], timeout: 5), .completed, "O teclado deveria ter fechado.", file: file, line: line)
    }

    private func digitar(_ texto: String, em campo: XCUIElement, _ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        tocar(campo, file: file, line: line)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), file: file, line: line)
        campo.typeText(texto)
    }

    private func abrirListaDeFuncoes(_ app: XCUIApplication) {
        tocar(app.buttons["botao-expandir-funcoes"])
        XCTAssertTrue(app.textFields["campo-busca-funcao"].waitForExistence(timeout: Espera.aparecer))
    }

    // MARK: - Busca de funções

    func testBuscaDeFuncaoFechaOTecladoAoTocarFora() {
        let app = abrirCriacaoDePerfil()
        abrirListaDeFuncoes(app)
        let campo = app.textFields["campo-busca-funcao"]
        digitar("bar", em: campo, app)

        tocar(app.descendants(matching: .any)["tela-perfil-profissional"])

        aguardarTecladoFechado(app)
        XCTAssertEqual(campo.value as? String, "bar", "Tocar fora fecha o teclado e mantém o filtro.")
    }

    func testBuscaDeFuncaoFechaOTecladoComReturn() {
        let app = abrirCriacaoDePerfil()
        abrirListaDeFuncoes(app)
        let campo = app.textFields["campo-busca-funcao"]
        digitar("bar", em: campo, app)

        campo.typeText("\n")

        aguardarTecladoFechado(app)
        XCTAssertEqual(campo.value as? String, "bar")
    }

    func testBotaoDeLimparFechaOTecladoEApagaOTexto() {
        let app = abrirCriacaoDePerfil()
        abrirListaDeFuncoes(app)
        let campo = app.textFields["campo-busca-funcao"]
        digitar("bar", em: campo, app)

        tocar(app.buttons["botao-fechar-busca-funcao"])

        aguardarTecladoFechado(app)
        XCTAssertNotEqual(campo.value as? String, "bar", "Limpar apaga o texto.")
        XCTAssertFalse(app.buttons["botao-fechar-busca-funcao"].exists, "Sem uso, o botão de limpar some.")
    }

    // MARK: - Ponto base

    func testPontoBaseFechaOTecladoAoTocarFora() {
        let app = abrirCriacaoDePerfil()
        let campo = app.textFields["campo-ponto-base"]
        digitar("Guará", em: campo, app)

        tocar(app.descendants(matching: .any)["tela-perfil-profissional"])

        aguardarTecladoFechado(app)
        XCTAssertEqual(campo.value as? String, "Guará", "Tocar fora fecha o teclado e mantém o endereço digitado.")
    }

    func testPontoBaseFechaOTecladoComReturnEBusca() {
        let app = abrirCriacaoDePerfil()
        let campo = app.textFields["campo-ponto-base"]
        digitar("Guará", em: campo, app)

        campo.typeText("\n")

        aguardarTecladoFechado(app)
        XCTAssertTrue(app.buttons["botao-buscar-endereco"].exists, "A ação de buscar continua no campo.")
    }
}
