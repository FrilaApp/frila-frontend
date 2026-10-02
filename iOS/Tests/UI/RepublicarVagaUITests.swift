import XCTest

@MainActor
final class RepublicarVagaUITests: XCTestCase {
    func testRepublicarVagaEncerradaCaminhoFeliz() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-FRILA_ABRIR_MINHAS_VAGAS",
            "-FRILA_SCENARIO", "vaga-encerrada-contratante"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Minhas vagas"].waitForExistence(timeout: 10))

        // Na seção de encerradas, o botão de publicar de novo existe
        let botaoRepublicar = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "republicar-vaga-")).firstMatch
        XCTAssertTrue(botaoRepublicar.waitForExistence(timeout: 10))
        botaoRepublicar.tap()

        // Abre a tela de republicação com os dados copiados
        XCTAssertTrue(app.descendants(matching: .any)["tela-republicar-vaga"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Republicar vaga"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["cartao-dados-copiados-republicacao"].exists)

        let anexo = XCTAttachment(screenshot: app.screenshot())
        anexo.name = "republicar-vaga"
        anexo.lifetime = .keepAlways
        add(anexo)

        // Toca em confirmar republicação
        let botaoConfirmar = app.buttons["botao-confirmar-republicacao"]
        XCTAssertTrue(botaoConfirmar.waitForExistence(timeout: 5))
        botaoConfirmar.tap()

        // A folha fecha
        let telaRepublicar = app.descendants(matching: .any)["tela-republicar-vaga"]
        XCTAssertTrue(telaRepublicar.waitForNonExistence(timeout: 10))

        // A lista de Minhas vagas permanece visível com a nova vaga ativa (seção Em alerta, Hoje ou Próximas)
        XCTAssertTrue(app.staticTexts["Minhas vagas"].waitForExistence(timeout: 10))
        XCTAssertTrue(
            app.staticTexts["Em alerta"].waitForExistence(timeout: 5)
            || app.staticTexts["Hoje"].waitForExistence(timeout: 5)
            || app.staticTexts["Próximas"].waitForExistence(timeout: 5)
        )
    }
}
