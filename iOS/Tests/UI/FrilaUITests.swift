import XCTest

@MainActor
final class FrilaUITests: XCTestCase {
    func testCatalogoAbreEmPortugues() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Frila UI"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Continuar"].exists)
    }

    func testCatalogoComTamanhoDeAcessibilidade() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Frila UI"].waitForExistence(timeout: 5))
    }

    func testConflitoTipadoDoClienteChegaATela() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "vaga-preenchida"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Validação do cliente"].waitForExistence(timeout: 5))
        app.buttons["Simular vaga preenchida"].tap()
        XCTAssertTrue(app.staticTexts["Esta vaga acabou de ser preenchida. Escolha outra oportunidade."].waitForExistence(timeout: 5))
    }

    func testSolicitacaoDeAcessoChegaAoClienteSemExporOEmailNaTelaDeResultado() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success"]
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
        app.launchArguments = ["-FRILA_SCENARIO", "success"]
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
