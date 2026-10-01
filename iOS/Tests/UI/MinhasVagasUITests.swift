import XCTest

@MainActor
final class MinhasVagasUITests: XCTestCase {
    func testPainelVazioExplicaComoPublicarPrimeiraVaga() {
        let app = XCUIApplication()
        app.launchArguments += ["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "painel-vazio"]
        app.launch()

        let estadoVazio = app.descendants(matching: .any)["estado-vazio-minhas-vagas"]
        XCTAssertTrue(estadoVazio.waitForExistence(timeout: 10))
        XCTAssertTrue(estadoVazio.label.contains("Suas vagas aparecem aqui"))
        XCTAssertTrue(estadoVazio.label.contains("Publique sua primeira vaga"))
    }

    func testVagaConfirmadaAbrePerfilPublicoEContatoLiberado() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-FRILA_ABRIR_MINHAS_VAGAS",
            "-FRILA_SCENARIO", "painel-contratante",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Minhas vagas"].waitForExistence(timeout: 10))
        let vaga = app.buttons["vaga-contratante-40000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(vaga.waitForExistence(timeout: 10))
        XCTAssertTrue(vaga.label.contains("Ana Cunha"))
        vaga.tap()

        let perfil = app.buttons["perfil-publico-82000000-0000-0000-0000-000000000002"]
        XCTAssertTrue(perfil.waitForExistence(timeout: 5))
        perfil.tap()
        XCTAssertTrue(app.staticTexts["Ana Cunha"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["7 de 7 chamariam de novo"].exists)
        XCTAssertTrue(app.staticTexts["Comparecimento: 100%"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let contato = app.buttons["ver-contato-82000000-0000-0000-0000-000000000002"]
        XCTAssertTrue(contato.waitForExistence(timeout: 5))
        contato.tap()
        XCTAssertTrue(app.descendants(matching: .any)["contato-liberado-82000000-0000-0000-0000-000000000001"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "+5561999990000")).firstMatch.exists)
    }
}
