import XCTest

/// Receita temporária de prova visual da fatia 6. Remover antes do commit.
@MainActor
final class CapturasAutenticacaoPerfilUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func abrir(_ argumentos: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = argumentos + ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        AjudanteDeLancamentoUITests.preparar(app)
        app.launch()
        return app
    }

    private func salvar(_ nome: String) {
        let anexo = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)
    }

    private func rolarAte(_ elemento: XCUIElement, app: XCUIApplication) {
        XCTAssertTrue(elemento.waitForExistence(timeout: Espera.aparecer))
        for _ in 0..<8 where !elemento.isHittable { app.swipeUp() }
        XCTAssertTrue(elemento.isHittable)
    }

    func testAutenticacao() {
        let app = abrir(["-FRILA_ENTRADA", "-FRILA_SCENARIO", "primeiro-acesso"])
        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: Espera.aparecer))
        salvar("entrada")
        email.tap()
        email.digitarEEsperar("novo@frila.app")
        tocar(app.buttons["entrada-receber-codigo"])
        let codigo = app.textFields["codigo-campo"]
        XCTAssertTrue(codigo.waitForExistence(timeout: Espera.aparecer))
        salvar("codigo")
        codigo.tap()
        codigo.typeText("123456")
        XCTAssertTrue(app.buttons["cadastro-perfil-profissional"].waitForExistence(timeout: Espera.aparecer))
        salvar("cadastro")
        let continuar = app.buttons["cadastro-continuar"]
        rolarAte(continuar, app: app)
        salvar("cadastro-campos")
    }

    func testPerfilProfissional() {
        let app = abrir(["-FRILA_SCENARIO", "success"])
        tocar(app.buttons["abrir-meu-perfil"])
        XCTAssertTrue(app.navigationBars["Meu perfil"].waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(app.buttons["perfil-historico-turnos"].waitForExistence(timeout: Espera.aparecer))
        salvar("perfil-profissional")
        tocar(app.buttons["perfil-historico-turnos"])
        XCTAssertTrue(app.buttons["historico-exportar"].waitForExistence(timeout: Espera.aparecer))
        salvar("historico")
        app.navigationBars.buttons.firstMatch.tap()
        let porQue = app.buttons["perfil-por-que-recebo"]
        rolarAte(porQue, app: app)
        tocar(porQue)
        XCTAssertTrue(app.descendants(matching: .any)["criterios-funcoes"].waitForExistence(timeout: Espera.aparecer))
        salvar("por-que-recebo")
        let contestar = app.buttons["botao-contestar-despacho"]
        rolarAte(contestar, app: app)
        salvar("por-que-recebo-fim")
        tocar(app.buttons["fechar-explicacao-vagas"])
        let ajuda = app.buttons["perfil-ajuda"]
        rolarAte(ajuda, app: app)
        tocar(ajuda)
        XCTAssertTrue(app.links["perfil-termos"].waitForExistence(timeout: Espera.aparecer))
        salvar("ajuda")
    }

    func testPerfilEstabelecimento() {
        let app = abrir(["-FRILA_SCENARIO", "contratante"])
        tocar(app.buttons["abrir-perfil-estabelecimento"])
        XCTAssertTrue(app.buttons["estabelecimento-historico-turnos"].waitForExistence(timeout: Espera.aparecer))
        salvar("perfil-estabelecimento")
    }
}
