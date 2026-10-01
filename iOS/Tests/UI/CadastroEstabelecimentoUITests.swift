import XCTest

@MainActor
final class CadastroEstabelecimentoUITests: XCTestCase {
    func testCadastroSegueParaPublicarVaga() {
        let app = XCUIApplication()
        app.launchArguments += ["-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO", "-FRILA_CADASTRO_UI_TEST"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Cadastrar estabelecimento"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Responsável"].exists)
        // Obrigatória desde o contrato 0.2.20: o roteiro de teste já a traz preenchida.
        XCTAssertTrue(app.staticTexts["Região Administrativa"].exists)
        app.buttons["continuar-cadastro"].tap()
        XCTAssertTrue(app.staticTexts["Publicar vaga"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["publicar-vaga-formulario"].exists)
        XCTAssertTrue(app.staticTexts["O profissional recebe o valor integral"].exists)
    }

    func testArrastarMarcadorAjustaPonto() {
        let app = XCUIApplication()
        app.launchArguments += ["-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO", "-FRILA_CADASTRO_UI_TEST"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Cadastrar estabelecimento"].waitForExistence(timeout: 10))
        let marcador = app.images["marcador-mapa"]
        XCTAssertTrue(marcador.waitForExistence(timeout: 10))

        let pontoInicial = marcador.value as? String
        XCTAssertNotNil(pontoInicial)

        let coordenadaInicial = marcador.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let coordenadaFinal = coordenadaInicial.withOffset(CGVector(dx: 60, dy: -40))
        coordenadaInicial.press(forDuration: 0.2, thenDragTo: coordenadaFinal)

        let pontoFinal = marcador.value as? String
        XCTAssertNotNil(pontoFinal)
        XCTAssertNotEqual(pontoInicial, pontoFinal)
    }
}
