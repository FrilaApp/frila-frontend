import XCTest

/// Check-in e check-out (#17) pela tela real, com o GPS simulado do esquema Local
/// (`-FRILA_LOCALIZACAO`): lista -> candidatura -> Meus turnos -> Meu turno -> presença.
@MainActor
final class PresencaUITests: XCTestCase {
    private func abrirMeuTurno(localizacao: String, argumentos: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success", "-FRILA_LOCALIZACAO", localizacao] + argumentos
        app.launch()
        let primeira = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-'")).firstMatch
        XCTAssertTrue(primeira.waitForExistence(timeout: 10))
        if !primeira.isHittable {
            let tocavel = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "isHittable == true"),
                object: primeira
            )
            _ = XCTWaiter.wait(for: [tocavel], timeout: 5)
        }
        primeira.tap()
        XCTAssertTrue(app.descendants(matching: .any)["tela-detalhe-vaga"].waitForExistence(timeout: 10))
        let candidatar = app.buttons["candidatar"]
        XCTAssertTrue(candidatar.waitForExistence(timeout: 10))
        candidatar.tap()
        XCTAssertTrue(app.descendants(matching: .any)["resultado-confirmada"].waitForExistence(timeout: 10))
        app.buttons["voltar-para-lista"].tap()
        let meusTurnos = app.buttons["abrir-meus-turnos"]
        XCTAssertTrue(meusTurnos.waitForExistence(timeout: 10))
        meusTurnos.tap()
        let turno = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'meu-turno-'")).firstMatch
        XCTAssertTrue(turno.waitForExistence(timeout: 10))
        turno.tap()
        XCTAssertTrue(app.descendants(matching: .any)["tela-meu-turno"].waitForExistence(timeout: 10))
        return app
    }

    /// Toca em "Fazer check-in" e passa pela explicação que antecede o pedido de permissão.
    private func fazerCheckinComPermissao(_ app: XCUIApplication) {
        let fazerCheckin = app.buttons["fazer-checkin"]
        XCTAssertTrue(fazerCheckin.waitForExistence(timeout: 10))
        fazerCheckin.tap()
        XCTAssertTrue(app.descendants(matching: .any)["explicacao-localizacao"].waitForExistence(timeout: Espera.aparecer), "a explicação vem antes do pedido de permissão")
        app.buttons["permitir-localizacao"].tap()
    }

    func testCheckinA150MetrosFicaVerificadoEOCheckoutRegistraASaida() {
        let app = abrirMeuTurno(localizacao: "perto")
        fazerCheckinComPermissao(app)

        let checkin = app.descendants(matching: .any)["checkin-situacao"]
        XCTAssertTrue(checkin.waitForExistence(timeout: 10))
        XCTAssertTrue(checkin.label.contains("Check-in verificado"), checkin.label)
        XCTAssertTrue(checkin.label.contains("150 m"), checkin.label)
        XCTAssertFalse(app.buttons["fazer-checkin"].exists)

        let fazerCheckout = app.buttons["fazer-checkout"]
        XCTAssertTrue(fazerCheckout.waitForExistence(timeout: Espera.aparecer))
        fazerCheckout.tap()
        let checkout = app.descendants(matching: .any)["checkout-situacao"]
        XCTAssertTrue(checkout.waitForExistence(timeout: 10))
        XCTAssertTrue(checkout.label.contains("Check-out registrado"), checkout.label)
        XCTAssertTrue(checkout.label.contains("150 m"), checkout.label)
        XCTAssertFalse(app.buttons["fazer-checkout"].exists)
    }

    func testCheckoutA150MetrosRegistraASaidaComADistancia() {
        let app = abrirMeuTurno(localizacao: "perto")
        fazerCheckinComPermissao(app)

        let fazerCheckout = app.buttons["fazer-checkout"]
        XCTAssertTrue(fazerCheckout.waitForExistence(timeout: Espera.aparecer))
        fazerCheckout.tap()

        let checkout = app.descendants(matching: .any)["checkout-situacao"]
        XCTAssertTrue(checkout.waitForExistence(timeout: 10))
        XCTAssertTrue(checkout.label.contains("Check-out registrado"), checkout.label)
        XCTAssertTrue(checkout.label.contains("150 m"), checkout.label)
        XCTAssertFalse(app.buttons["fazer-checkout"].exists)
    }

    func testCheckinA350MetrosOfereceOManualQueFicaAguardandoConfirmacao() {
        let app = abrirMeuTurno(localizacao: "longe", argumentos: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        fazerCheckinComPermissao(app)

        XCTAssertTrue(app.descendants(matching: .any)["sem-gps"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["checkin-situacao"].exists, "a 350 m nada é registrado sem a pessoa pedir")
        let manual = app.buttons["registro-manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(app.buttons["tentar-gps"].exists)
        manual.tap()

        let checkin = app.descendants(matching: .any)["checkin-situacao"]
        XCTAssertTrue(checkin.waitForExistence(timeout: 10))
        XCTAssertTrue(checkin.label.contains("Aguardando confirmação do contratante"), checkin.label)
    }

    func testPermissaoNegadaOfereceOManualEOsAjustes() {
        let app = abrirMeuTurno(localizacao: "negada")
        fazerCheckinComPermissao(app)

        XCTAssertTrue(app.descendants(matching: .any)["sem-gps"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["abrir-ajustes"].waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(app.buttons["registro-manual"].exists)
        app.buttons["cancelar-presenca"].tap()
        XCTAssertTrue(app.buttons["fazer-checkin"].waitForExistence(timeout: Espera.aparecer), "desistir devolve o botão de check-in")
    }
}
