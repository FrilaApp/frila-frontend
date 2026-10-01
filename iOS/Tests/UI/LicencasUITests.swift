import XCTest

/// Critério 1 do #178, pela entrada provisória do catálogo: a lista abre e o detalhe mostra o
/// texto da licença do pacote.
@MainActor
final class LicencasUITests: XCTestCase {
    func testCatalogoAbreAListaEOTextoDaLicenca() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_CATALOGO", "-FRILA_SCENARIO", "success"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Frila UI"].waitForExistence(timeout: 10))

        let entrada = app.buttons["abrir-licencas"]
        for _ in 0..<12 where !entrada.isHittable { app.swipeUp() }
        XCTAssertTrue(entrada.isHittable, "a entrada das licenças não apareceu no catálogo")
        entrada.tap()

        XCTAssertTrue(app.navigationBars["Licenças de código aberto"].waitForExistence(timeout: 5))
        let pacote = app.buttons["licenca-abseil-cpp-binary"]
        XCTAssertTrue(pacote.waitForExistence(timeout: 5), "a lista não mostrou o primeiro pacote")
        XCTAssertTrue(pacote.label.contains("Apache-2.0"), "a linha não mostra o tipo da licença: \(pacote.label)")
        anexar(app, "licencas-lista")
        pacote.tap()

        XCTAssertTrue(app.navigationBars["abseil-cpp-binary"].waitForExistence(timeout: 5))
        let texto = app.staticTexts["texto-da-licenca"]
        XCTAssertTrue(texto.waitForExistence(timeout: 5))
        XCTAssertTrue(texto.label.contains("Apache License"), "o detalhe não mostra o texto da licença")
        anexar(app, "licencas-detalhe")
    }

    /// A interface é provisória: a captura fica no resultado do teste para quem for revisar.
    private func anexar(_ app: XCUIApplication, _ nome: String) {
        let anexo = XCTAttachment(screenshot: app.screenshot())
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)
    }
}
