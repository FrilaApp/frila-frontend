import XCTest

@MainActor
final class CadastroEstabelecimentoUITests: XCTestCase {
    func testCadastroSegueParaPublicarVaga() {
        let app = XCUIApplication()
        app.launchArguments += ["-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO", "-FRILA_CADASTRO_UI_TEST"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Cadastrar estabelecimento"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Responsável"].exists)
        app.buttons["continuar-cadastro"].tap()
        XCTAssertTrue(app.staticTexts["Publicar vaga"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["publicar-vaga-provisorio"].exists)
    }
}
