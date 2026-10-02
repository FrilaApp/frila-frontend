import XCTest

/// O turno do contratante (#19) no dublê: os cenários entram pela conta de contratante, como o app
/// entra, e o aviso de vaga vazia usa a mesma entrada que o push vai usar (#8).
@MainActor
final class TurnoDoContratanteUITests: XCTestCase {
    private let turnoID = "82000000-0000-0000-0000-000000000001"
    private let posicaoID = "82000000-0000-0000-0000-000000000002"
    private let vagaID = "40000000-0000-0000-0000-000000000001"

    private func abrir(_ argumentos: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = argumentos
        app.launch()
        return app
    }

    func testConfirmarPresencaTiraOTurnoDosPendentes() {
        let app = abrir(["-FRILA_SCENARIO", "checkin-manual-pendente"])

        let pendentes = app.descendants(matching: .any)["presencas-a-confirmar"]
        XCTAssertTrue(pendentes.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Confirme se a pessoa chegou. Sem a sua confirmação, o turno fica como não verificado."].exists)
        let confirmar = app.buttons["confirmar-presenca-\(turnoID)"]
        XCTAssertTrue(confirmar.exists)
        confirmar.tap()

        XCTAssertTrue(app.staticTexts["Presença confirmada."].waitForExistence(timeout: 5))
        XCTAssertFalse(pendentes.exists)
        XCTAssertFalse(confirmar.exists)
    }

    func testTurnoMostraAChegadaEConfirmaAPresenca() {
        let app = abrir(["-FRILA_SCENARIO", "checkin-manual-pendente"])

        let acompanhar = app.buttons["acompanhar-turno-\(turnoID)"]
        XCTAssertTrue(acompanhar.waitForExistence(timeout: 15))
        acompanhar.tap()

        XCTAssertTrue(app.staticTexts["Chegada"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Fez o check-in manual, sem confirmação pelo GPS."].exists)
        app.buttons["confirmar-presenca-\(turnoID)"].tap()
        XCTAssertTrue(app.staticTexts["Presença verificada."].waitForExistence(timeout: 5))
    }

    func testReabrirVagaPedeConfirmacaoEAvisaDaFalta() {
        let app = abrir(["-FRILA_SCENARIO", "atraso-no-turno"])

        let reabrir = app.buttons["reabrir-vaga-\(posicaoID)"]
        XCTAssertTrue(reabrir.waitForExistence(timeout: 15))
        reabrir.tap()

        let pergunta = app.alerts["Reabrir a vaga?"]
        XCTAssertTrue(pergunta.waitForExistence(timeout: 5))
        XCTAssertTrue(pergunta.staticTexts["Conta como falta para Ana Cunha, e a vaga volta a ser oferecida a outros profissionais."].exists)
        pergunta.buttons["Esperar"].tap()
        XCTAssertTrue(reabrir.waitForExistence(timeout: 5))

        reabrir.tap()
        XCTAssertTrue(pergunta.waitForExistence(timeout: 5))
        pergunta.buttons["Reabrir vaga"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["resultado-do-acompanhamento"].waitForExistence(timeout: 5))
        XCTAssertFalse(reabrir.exists)
    }

    func testAvisoDeVagaVaziaAbreAVagaCerta() {
        let app = abrir([
            "-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "alerta-vaga-vazia",
            "-FRILA_AVISO", "vaga_vazia", "-FRILA_AVISO_ID", vagaID,
        ])

        XCTAssertTrue(app.descendants(matching: .any)["detalhe-vaga-contratante"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Posição aberta"].firstMatch.exists)
        // Voltar leva à lista, onde a mesma vaga está na seção Em alerta, com o tempo que falta.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Em alerta"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["tempo-alerta-\(vagaID.uppercased())"].exists)
    }
}
