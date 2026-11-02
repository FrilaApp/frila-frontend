import XCTest

@MainActor
final class ContatoCopiavelUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func abrirConta() -> (XCUIApplication, XCUIElement) {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success", "-FRILA_ABA_CONTA"]
        app.launch()
        let valor = app.staticTexts["perfil-telefone-valor"]
        XCTAssertTrue(valor.waitForExistence(timeout: Espera.aparecer))
        return (app, valor)
    }

    private func direitaDaTela(_ app: XCUIApplication, naAlturaDe elemento: XCUIElement) -> XCUICoordinate {
        let janela = app.windows.firstMatch
        return janela.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: janela.frame.width - 24, dy: elemento.frame.midY))
    }

    func testToqueCopiaEMostraOTip() {
        let (app, valor) = abrirConta()
        XCTAssertFalse(app.staticTexts["perfil-telefone-copiado"].exists)
        valor.tap()
        XCTAssertTrue(app.staticTexts["perfil-telefone-copiado"].waitForExistence(timeout: 1))
    }

    func testSegurarEDeslizarNoMesmoGestoCopia() {
        let (app, valor) = abrirConta()
        valor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.7,
            thenDragTo: direitaDaTela(app, naAlturaDe: valor),
            withVelocity: XCUIGestureVelocity(rawValue: 80),
            thenHoldForDuration: 1.2
        )
        XCTAssertTrue(app.staticTexts["perfil-telefone-copiado"].waitForExistence(timeout: 10))
    }

    func testSegurarESoltarNaoCopia() {
        let (app, valor) = abrirConta()
        valor.press(forDuration: 0.7)
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertFalse(app.staticTexts["perfil-telefone-copiado"].exists)
    }

    func testRolarComecandoNoContatoNaoCopia() {
        let (app, valor) = abrirConta()
        let yAntes = app.staticTexts["perfil-email-valor"].frame.minY
        valor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.01, thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.05)))
        XCTAssertLessThan(app.staticTexts["perfil-email-valor"].frame.minY, yAntes, "A tela deve rolar")
        XCTAssertFalse(app.staticTexts["perfil-telefone-copiado"].exists)
    }
}
