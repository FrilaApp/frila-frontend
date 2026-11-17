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

    /// O teclado fecha quando o campo perde o foco, e é isso que a espera confere. Antes ela esperava 5 s o
    /// teclado de software sumir (`app.keyboards`), e caiu na CI do TestFlight da main 590ab63e (fatia 4)
    /// sem mudança no teste nem no componente. O teclado de software depende do simulador (com o de
    /// hardware ligado ele nem aparece); o foco é o estado do próprio campo.
    private func aguardarTecladoFechado(_ campo: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let semFoco = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == false"), object: campo)
        XCTAssertEqual(XCTWaiter.wait(for: [semFoco], timeout: Espera.aparecer), .completed, "O campo deveria ter perdido o foco (teclado fechado).", file: file, line: line)
    }

    private func digitar(_ texto: String, em campo: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        tocar(campo, file: file, line: line)
        // Logo depois de abrir a tela, o 1º toque às vezes não dá o foco (visto no simulador local): toca de novo.
        campo.garantirFocoDoTeclado(file: file, line: line)
        XCTAssertTrue(esperarFocoDoTeclado(campo, timeout: 2), "O campo deveria receber o foco.", file: file, line: line)
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
        digitar("bar", em: campo)

        tocar(app.staticTexts["categoria-Bar"])

        aguardarTecladoFechado(campo)
        XCTAssertEqual(campo.value as? String, "bar", "Tocar fora fecha o teclado e mantém o filtro.")
    }

    func testBuscaDeFuncaoFechaOTecladoComReturn() {
        let app = abrirCriacaoDePerfil()
        abrirListaDeFuncoes(app)
        let campo = app.textFields["campo-busca-funcao"]
        digitar("bar", em: campo)

        campo.typeText("\n")

        aguardarTecladoFechado(campo)
        XCTAssertEqual(campo.value as? String, "bar")
    }

    func testBotaoDeLimparFechaOTecladoEApagaOTexto() {
        let app = abrirCriacaoDePerfil()
        abrirListaDeFuncoes(app)
        let campo = app.textFields["campo-busca-funcao"]
        digitar("bar", em: campo)

        tocar(app.buttons["botao-fechar-busca-funcao"])

        aguardarTecladoFechado(campo)
        XCTAssertNotEqual(campo.value as? String, "bar", "Limpar apaga o texto.")
        XCTAssertFalse(app.buttons["botao-fechar-busca-funcao"].exists, "Sem uso, o botão de limpar some.")
    }

    // MARK: - Ponto base

    func testPontoBaseFechaOTecladoAoTocarFora() {
        let app = abrirCriacaoDePerfil()
        let campo = app.textFields["campo-ponto-base"]
        digitar("Guará", em: campo)

        tocar(app.staticTexts["titulo-secao-horarios"])

        aguardarTecladoFechado(campo)
        XCTAssertEqual(campo.value as? String, "Guará", "Tocar fora fecha o teclado e mantém o endereço digitado.")
    }

    func testPontoBaseFechaOTecladoComReturnEBusca() {
        let app = abrirCriacaoDePerfil()
        let campo = app.textFields["campo-ponto-base"]
        digitar("Guará", em: campo)

        campo.typeText("\n")

        aguardarTecladoFechado(campo)
        XCTAssertTrue(app.buttons["botao-buscar-endereco"].exists, "A ação de buscar continua no campo.")
    }
}
