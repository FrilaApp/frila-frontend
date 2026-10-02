import XCTest

@MainActor
final class FluxoDoContratanteUITests: XCTestCase {
    func testContratanteComEstabelecimentoAbreMinhasVagasESai() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "contratante"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 10))
        let captura = XCTAttachment(screenshot: app.screenshot())
        captura.lifetime = .keepAlways
        add(captura)
        let sair = app.buttons["sair-fluxo-contratante"]
        XCTAssertTrue(sair.isHittable)
        sair.tap()
        XCTAssertTrue(app.textFields["entrada-email"].waitForExistence(timeout: 10))
    }

    func testPrimeiroAcessoDoContratanteAbreCadastroComResponsavelDaConta() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ENTRADA", "-FRILA_SCENARIO", "primeiro-acesso"]
        app.launch()

        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.typeText("contratante@frila.app")
        app.buttons["entrada-receber-codigo"].tap()
        let codigo = app.textFields["Código de acesso"]
        XCTAssertTrue(codigo.waitForExistence(timeout: 10))
        codigo.tap()
        codigo.typeText("123456")
        app.buttons["codigo-entrar"].tap()

        let perfil = app.buttons["cadastro-perfil-contratante"]
        XCTAssertTrue(perfil.waitForExistence(timeout: 10))
        perfil.tap()
        let nome = app.textFields["cadastro-nome"]
        nome.tap()
        nome.typeText("Responsável do Café")
        let telefone = app.textFields["cadastro-telefone"]
        telefone.tap()
        telefone.typeText("61988887777")
        let nascimento = app.textFields["cadastro-nascimento"]
        nascimento.tap()
        nascimento.typeText("15/05/1995")
        app.buttons["cadastro-maior-de-idade"].tap()
        app.buttons["cadastro-termos"].tap()
        app.buttons["cadastro-continuar"].tap()

        XCTAssertTrue(app.buttons["continuar-cadastro"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Responsável do Café"].exists)
        XCTAssertTrue(app.staticTexts["+5561988887777"].exists)
        let captura = XCTAttachment(screenshot: app.screenshot())
        captura.lifetime = .keepAlways
        add(captura)
        let sair = app.buttons["sair-fluxo-contratante"]
        XCTAssertTrue(sair.isHittable)
        sair.tap()
        XCTAssertTrue(app.textFields["entrada-email"].waitForExistence(timeout: 10))
    }
}
