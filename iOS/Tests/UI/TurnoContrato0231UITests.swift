import XCTest

@MainActor
final class TurnoContrato0231UITests: XCTestCase {
    private let turnoID = "22000000-0000-0000-0000-000000000001"

    private func abrirTurno(_ app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Meus turnos"].tap()
        let cartao = app.buttons["meu-turno-\(turnoID)"]
        XCTAssertTrue(cartao.waitForExistence(timeout: 10))
        cartao.tap()
        XCTAssertTrue(app.navigationBars["Meu turno"].waitForExistence(timeout: 5))
    }

    func testCanceladoApareceNaListaENoDetalheSemAcoes() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "turno-cancelado"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Meus turnos"].tap()
        let cartao = app.buttons["meu-turno-\(turnoID)"]
        XCTAssertTrue(cartao.waitForExistence(timeout: 10))
        XCTAssertTrue(cartao.label.contains("Turno cancelado"))
        cartao.tap()
        XCTAssertTrue(app.staticTexts["estado-do-turno"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["estado-do-turno"].label, "Turno cancelado")
        let cancelamento = app.descendants(matching: .any)["cancelamento-do-turno"].firstMatch
        XCTAssertTrue(cancelamento.exists)
        XCTAssertTrue(cancelamento.label.contains("Você cancelou este turno."))
        XCTAssertTrue(cancelamento.label.contains("Este cancelamento não contou como falta."))
        for id in ["presenca-do-turno", "contato-do-turno", "cartao-avaliacao-turno"] {
            XCTAssertFalse(app.descendants(matching: .any)[id].exists)
        }
        for id in ["avisar-a-caminho", "fazer-checkin", "fazer-checkout", "botao-whatsapp", "Avaliar turno", "Ver avaliação"] {
            XCTAssertFalse(app.buttons[id].exists)
        }
    }

    func testCancelamentoComFaltaMostraCausaEConsequencia() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "turno-cancelado-com-falta"]
        app.launch()
        abrirTurno(app)
        let cancelamento = app.descendants(matching: .any)["cancelamento-do-turno"].firstMatch
        XCTAssertTrue(cancelamento.waitForExistence(timeout: 5))
        XCTAssertTrue(cancelamento.label.contains("O estabelecimento reabriu a posição por atraso."))
        XCTAssertTrue(cancelamento.label.contains("Este cancelamento contou como falta."))
        XCTAssertFalse(app.buttons["Avaliar turno"].exists)
    }

    func testCancelamentoAnteriorMostraSoCancelado() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "turno-cancelado-sem-detalhes"]
        app.launch()
        abrirTurno(app)
        XCTAssertEqual(app.staticTexts["estado-do-turno"].label, "Turno cancelado")
        XCTAssertFalse(app.descendants(matching: .any)["cancelamento-do-turno"].exists)
        XCTAssertFalse(app.buttons["Avaliar turno"].exists)
    }

    func testOutraCausaTemTextoNeutro() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "turno-cancelado-outro"]
        app.launch()
        abrirTurno(app)
        let cancelamento = app.descendants(matching: .any)["cancelamento-do-turno"].firstMatch
        XCTAssertTrue(cancelamento.waitForExistence(timeout: 5))
        XCTAssertTrue(cancelamento.label.contains("Cancelamento registrado."))
        XCTAssertTrue(cancelamento.label.contains("Este cancelamento não contou como falta."))
    }

    func testAvaliacaoDoServidorMostraRespostaSemOferecerNovoEnvio() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "turno-avaliado"]
        app.launch()
        abrirTurno(app)
        conferirAvaliacaoNegativa(app)
    }

    func testRespostaContinuaDepoisDeSairEEntrarNaConta() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "turno-encerrado"]
        app.launch()
        abrirTurno(app)
        let avaliar = app.buttons["Avaliar turno"]
        if !avaliar.isHittable { app.swipeUp() }
        XCTAssertTrue(avaliar.waitForExistence(timeout: 5))
        avaliar.tap()
        XCTAssertTrue(app.buttons["resposta-nao"].waitForExistence(timeout: 5))
        app.buttons["resposta-nao"].tap()
        app.buttons["botao-enviar-avaliacao"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["aviso-sucesso-avaliacao"].waitForExistence(timeout: 5))
        app.navigationBars["Avaliar turno"].buttons.firstMatch.tap()
        app.navigationBars["Meu turno"].buttons.firstMatch.tap()
        app.tabBars.buttons["Vagas no DF"].tap()
        app.buttons["abrir-meu-perfil"].tap()
        let sair = app.buttons["Sair"]
        if !sair.isHittable { app.swipeUp() }
        XCTAssertTrue(sair.waitForExistence(timeout: 5))
        sair.tap()
        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.digitarEEsperar("teste@frila.app")
        app.buttons["entrada-receber-codigo"].tap()
        let codigo = app.textFields["Código de acesso"]
        XCTAssertTrue(codigo.waitForExistence(timeout: 10))
        codigo.tap()
        codigo.digitarEEsperar("123456")
        app.buttons["codigo-entrar"].tap()
        abrirTurno(app)
        conferirAvaliacaoNegativa(app)
    }

    private func conferirAvaliacaoNegativa(_ app: XCUIApplication) {
        let status = app.staticTexts["Turno avaliado · Resposta: Não"]
        if !status.isHittable { app.swipeUp() }
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertTrue(status.label.contains("Não"))
        XCTAssertFalse(app.buttons["Avaliar turno"].exists)
        app.buttons["Ver avaliação"].tap()
        XCTAssertTrue(app.buttons["resposta-nao"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["resposta-nao"].isSelected)
        XCTAssertFalse(app.buttons["resposta-nao"].isEnabled)
        XCTAssertFalse(app.buttons["resposta-sim"].isEnabled)
        XCTAssertFalse(app.buttons["botao-enviar-avaliacao"].exists)
    }
}
