import XCTest

/// Check-in e check-out (#17) pela tela real, com o GPS simulado do esquema Local
/// (`-FRILA_LOCALIZACAO`): lista -> candidatura -> Meus turnos -> Meu turno -> presença.
@MainActor
final class PresencaUITests: XCTestCase {
    private func abrirMeuTurno(localizacao: String = "perto", cenario: String = "success", argumentos: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", cenario, "-FRILA_LOCALIZACAO", localizacao] + argumentos
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: Espera.aparecer)
        let primeira = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-'")).firstMatch
        tocar(primeira)
        XCTAssertTrue(app.descendants(matching: .any)["tela-detalhe-vaga"].waitForExistence(timeout: Espera.aparecer))
        let candidatar = app.buttons["candidatar"]
        tocar(candidatar)
        XCTAssertTrue(app.descendants(matching: .any)["resultado-confirmada"].waitForExistence(timeout: Espera.aparecer))
        tocar(app.buttons["voltar-para-lista"])
        let meusTurnos = app.buttons["abrir-meus-turnos"]
        tocar(meusTurnos)
        let turno = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'meu-turno-'")).firstMatch
        tocar(turno)
        XCTAssertTrue(app.descendants(matching: .any)["tela-meu-turno"].waitForExistence(timeout: Espera.aparecer))
        return app
    }

    /// Toca em "Fazer check-in" e passa pela explicação que antecede o pedido de permissão.
    private func fazerCheckinComPermissao(_ app: XCUIApplication) {
        let fazerCheckin = app.buttons["fazer-checkin"]
        tocar(fazerCheckin)
        XCTAssertTrue(app.descendants(matching: .any)["explicacao-localizacao"].waitForExistence(timeout: Espera.aparecer), "a explicação vem antes do pedido de permissão")
        tocar(app.buttons["permitir-localizacao"])
    }

    func testCheckinA150MetrosFicaVerificadoEOCheckoutRegistraASaida() {
        let app = abrirMeuTurno(localizacao: "perto")
        fazerCheckinComPermissao(app)

        let checkin = app.descendants(matching: .any)["checkin-situacao"]
        XCTAssertTrue(checkin.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(checkin.label.contains("Check-in verificado"), checkin.label)
        XCTAssertTrue(checkin.label.contains("150 m"), checkin.label)
        XCTAssertFalse(app.buttons["fazer-checkin"].exists)

        let fazerCheckout = app.buttons["fazer-checkout"]
        tocar(fazerCheckout)
        let checkout = app.descendants(matching: .any)["checkout-situacao"]
        XCTAssertTrue(checkout.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(checkout.label.contains("Check-out registrado"), checkout.label)
        XCTAssertTrue(checkout.label.contains("150 m"), checkout.label)
        XCTAssertFalse(app.buttons["fazer-checkout"].exists)
    }

    func testCheckoutA150MetrosRegistraASaidaComADistancia() {
        let app = abrirMeuTurno(localizacao: "perto")
        fazerCheckinComPermissao(app)

        let fazerCheckout = app.buttons["fazer-checkout"]
        tocar(fazerCheckout)

        let checkout = app.descendants(matching: .any)["checkout-situacao"]
        XCTAssertTrue(checkout.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(checkout.label.contains("Check-out registrado"), checkout.label)
        XCTAssertTrue(checkout.label.contains("150 m"), checkout.label)
        XCTAssertFalse(app.buttons["fazer-checkout"].exists)
    }

    func testCheckinA350MetrosOfereceOManualQueFicaAguardandoConfirmacao() {
        let app = abrirMeuTurno(localizacao: "longe", argumentos: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        fazerCheckinComPermissao(app)

        XCTAssertTrue(app.descendants(matching: .any)["sem-gps"].waitForExistence(timeout: Espera.aparecer))
        XCTAssertFalse(app.descendants(matching: .any)["checkin-situacao"].exists, "a 350 m nada é registrado sem a pessoa pedir")
        let manual = app.buttons["registro-manual"]
        XCTAssertTrue(app.buttons["tentar-gps"].exists)
        tocar(manual)

        let checkin = app.descendants(matching: .any)["checkin-situacao"]
        XCTAssertTrue(checkin.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(checkin.label.contains("Aguardando confirmação do contratante"), checkin.label)
    }

    func testPermissaoNegadaOfereceOManualEOsAjustes() {
        let app = abrirMeuTurno(localizacao: "negada")
        fazerCheckinComPermissao(app)

        XCTAssertTrue(app.descendants(matching: .any)["sem-gps"].waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(app.descendants(matching: .any)["abrir-ajustes"].waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(app.buttons["registro-manual"].exists)
        tocar(app.buttons["cancelar-presenca"])
        XCTAssertTrue(app.buttons["fazer-checkin"].waitForExistence(timeout: Espera.aparecer), "desistir devolve o botão de check-in")
    }

    func testBotaoEstouACaminhoApareceTocaEMostraAviso() {
        let app = abrirMeuTurno(cenario: "a-caminho")
        let botaoACaminho = app.buttons["botao-a-caminho"]
        XCTAssertTrue(botaoACaminho.waitForExistence(timeout: Espera.aparecer), "o botão Estou a caminho deve aparecer na janela permitida")
        tocar(botaoACaminho)

        let situacaoACaminho = app.descendants(matching: .any)["a-caminho-situacao"]
        XCTAssertTrue(situacaoACaminho.waitForExistence(timeout: Espera.aparecer), "o estado do aviso a caminho deve ser exibido após o toque")
        XCTAssertTrue(situacaoACaminho.label.contains("Você avisou que está a caminho"), situacaoACaminho.label)
        XCTAssertFalse(app.buttons["botao-a-caminho"].exists, "o botão Estou a caminho deve sumir após o envio")
    }
}
