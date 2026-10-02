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
        let janela = app.windows.firstMatch
        for _ in 0..<12 {
            let areaVisivel = janela.frame.insetBy(dx: 0, dy: entrada.frame.height)
            if entrada.isHittable && areaVisivel.contains(entrada.frame) { break }
            app.swipeUp()
        }
        XCTAssertTrue(entrada.isHittable, "a entrada das licenças não apareceu no catálogo")
        XCTAssertTrue(janela.frame.insetBy(dx: 0, dy: entrada.frame.height).contains(entrada.frame),
                      "o botão precisa estar inteiro dentro da área visível antes do toque")
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
