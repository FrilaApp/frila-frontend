import XCTest

/// Critério 1 do #178, pela entrada provisória do catálogo: a lista abre e o detalhe mostra o
/// texto da licença do pacote.
@MainActor
final class LicencasUITests: XCTestCase {
    func testCatalogoAbreAListaEOTextoDaLicenca() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_CATALOGO", "-FRILA_SCENARIO", "success"]
        AjudanteDeLancamentoUITests.preparar(app)
        app.launch()
        XCTAssertTrue(app.navigationBars["Frila UI"].waitForExistence(timeout: 10))

        let entrada = app.buttons["abrir-licencas"]
        let janela = app.windows.firstMatch
        for _ in 0..<12 {
            if entrada.exists && entrada.isHittable {
                let areaVisivel = janela.frame.insetBy(dx: 0, dy: entrada.frame.height)
                if areaVisivel.contains(entrada.frame) { break }
            }
            app.swipeUp()
        }
        XCTAssertTrue(entrada.isHittable, "a entrada das licenças não apareceu no catálogo")
        XCTAssertTrue(janela.frame.insetBy(dx: 0, dy: entrada.frame.height).contains(entrada.frame),
                      "o botão precisa estar inteiro dentro da área visível antes do toque")
        entrada.tap()

        XCTAssertTrue(app.navigationBars["Licenças de código aberto"].waitForExistence(timeout: Espera.aparecer))
        let pacote = app.buttons["licenca-abseil-cpp-binary"]
        XCTAssertTrue(pacote.waitForExistence(timeout: Espera.aparecer), "a lista não mostrou o primeiro pacote")
        XCTAssertTrue(pacote.label.contains("Apache-2.0"), "a linha não mostra o tipo da licença: \(pacote.label)")
        anexar(app, "licencas-lista")
        pacote.tap()

        XCTAssertTrue(app.navigationBars["abseil-cpp-binary"].waitForExistence(timeout: Espera.aparecer))
        let texto = app.staticTexts["texto-da-licenca"]
        XCTAssertTrue(texto.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(texto.label.contains("Apache License"), "o detalhe não mostra o texto da licença")
        anexar(app, "licencas-detalhe")
    }

    func testMeuPerfilAjudaAbreLicencasEmAlturaInteira() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success"]
        AjudanteDeLancamentoUITests.preparar(app)
        app.launch()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))

        let botaoPerfil = app.buttons["abrir-meu-perfil"]
        XCTAssertTrue(botaoPerfil.waitForExistence(timeout: Espera.aparecer))
        botaoPerfil.tap()

        XCTAssertTrue(app.navigationBars["Meu perfil"].waitForExistence(timeout: Espera.aparecer))

        let botaoAjuda = app.buttons["perfil-ajuda"]
        if !botaoAjuda.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(botaoAjuda.waitForExistence(timeout: Espera.aparecer))
        botaoAjuda.tap()

        XCTAssertTrue(app.navigationBars["Ajuda"].waitForExistence(timeout: Espera.aparecer))

        let botaoLicencas = app.descendants(matching: .any)["perfil-licencas"]
        XCTAssertTrue(botaoLicencas.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(botaoLicencas.isHittable)
        botaoLicencas.tap()

        XCTAssertTrue(app.navigationBars["Licenças de código aberto"].waitForExistence(timeout: Espera.aparecer))

        let navBar = app.navigationBars["Licenças de código aberto"]
        let janela = app.windows.firstMatch
        // Em .large (altura inteira), o topo da barra de navegação fica próximo ao topo da tela (y < janela.frame.height * 0.25).
        // Em .medium (meia tela), a barra ficaria perto da metade (y >= janela.frame.height * 0.4).
        XCTAssertLessThan(navBar.frame.minY, janela.frame.height * 0.25, "A folha de licenças deve abrir em altura inteira (.large)")

        let pacote = app.descendants(matching: .any)["licenca-abseil-cpp-binary"]
        XCTAssertTrue(pacote.waitForExistence(timeout: Espera.aparecer))
        anexar(app, "licencas-folha-altura-inteira")
    }

    /// A interface é provisória: a captura fica no resultado do teste para quem for revisar.
    private func anexar(_ app: XCUIApplication, _ nome: String) {
        let anexo = XCTAttachment(screenshot: app.screenshot())
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)
    }
}
