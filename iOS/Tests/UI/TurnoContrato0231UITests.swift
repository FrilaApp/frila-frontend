import XCTest

@MainActor
final class TurnoContrato0231UITests: XCTestCase {
    private let turnoID = "22000000-0000-0000-0000-000000000001"

    private func abrirTurno(_ app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
        tocar(app.tabBars.buttons["Meus turnos"])
        let cartao = app.buttons["meu-turno-\(turnoID)"]
        XCTAssertTrue(cartao.waitForExistence(timeout: 10))
        tocar(cartao)
        XCTAssertTrue(app.navigationBars["Meu turno"].waitForExistence(timeout: 5))
    }

    func testCheckinRecusadoSaiDaFilaEMostraAvisoNoTurnoCancelado() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "turno-cancelado", "-FRILA_CACHE_VAZIO_UI_TEST", "-FRILA_CHECKIN_CANCELADO_NA_FILA_UI_TEST"]
        app.launch()
        abrirTurno(app)
        let aviso = app.descendants(matching: .any)["aviso-acao-recusada-checkin"].firstMatch
        XCTAssertTrue(aviso.waitForExistence(timeout: 10))
        XCTAssertTrue(aviso.label.contains("O check-in guardado neste aparelho não foi registrado. Esse envio não será repetido."))
        XCTAssertFalse(app.descendants(matching: .any)["presenca-do-turno"].exists)
        XCTAssertFalse(app.buttons["fazer-checkin"].exists)
        tocar(app.navigationBars["Meu turno"].buttons.firstMatch)
        tocar(app.buttons["meu-turno-\(turnoID)"])
        XCTAssertTrue(aviso.waitForExistence(timeout: 10), "a recusa permanece registrada ao reabrir")
    }

    private func iniciarApp(cenario: String, extras: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", cenario, "-FRILA_CACHE_VAZIO_UI_TEST"] + extras
        AjudanteDeLancamentoUITests.preparar(app)
        app.launch()
        return app
    }

    func testCanceladoApareceNaListaENoDetalheSemAcoes() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "turno-cancelado"]
        app.launchArguments.append("-FRILA_CACHE_VAZIO_UI_TEST")
        app.launch()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
        tocar(app.tabBars.buttons["Meus turnos"])
        let cartao = app.buttons["meu-turno-\(turnoID)"]
        XCTAssertTrue(cartao.waitForExistence(timeout: 10))
        XCTAssertTrue(cartao.label.contains("Turno cancelado"))
        tocar(cartao)
        XCTAssertTrue(app.staticTexts["estado-do-turno"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["estado-do-turno"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["estado-do-turno"].label, "Turno cancelado")
        let cancelamento = app.descendants(matching: .any)["cancelamento-do-turno"].firstMatch
        XCTAssertTrue(cancelamento.waitForExistence(timeout: 5))
        XCTAssertTrue(cancelamento.label.contains("Você cancelou este turno."))
        XCTAssertTrue(cancelamento.label.contains("Este cancelamento não contou como falta."))
        for id in ["presenca-do-turno", "contato-do-turno", "cartao-avaliacao-turno"] {
            XCTAssertFalse(app.descendants(matching: .any)[id].exists)
        }
        for id in ["botao-whatsapp", "Avaliar turno", "Ver avaliação"] {
            XCTAssertFalse(app.buttons[id].exists)
        }
    }

    func testCancelamentoComFaltaMostraCausaEConsequencia() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "turno-cancelado-com-falta"]
        app.launchArguments.append("-FRILA_CACHE_VAZIO_UI_TEST")
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
        app.launchArguments.append("-FRILA_CACHE_VAZIO_UI_TEST")
        app.launch()
        abrirTurno(app)
        XCTAssertTrue(app.staticTexts["estado-do-turno"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["estado-do-turno"].label, "Turno cancelado")
        XCTAssertFalse(app.descendants(matching: .any)["cancelamento-do-turno"].exists)
        XCTAssertFalse(app.buttons["Avaliar turno"].exists)
    }

    func testOutraCausaTemTextoNeutro() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "turno-cancelado-outro"]
        app.launchArguments.append("-FRILA_CACHE_VAZIO_UI_TEST")
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
        app.launchArguments.append("-FRILA_CACHE_VAZIO_UI_TEST")
        app.launch()
        abrirTurno(app)
        conferirAvaliacaoNegativa(app)
    }

    func testRespostaContinuaDepoisDeSairEEntrarNaConta() {
        let app = iniciarApp(cenario: "turno-encerrado")
        abrirTurno(app)
        let avaliar = app.buttons["Avaliar turno"]
        if !avaliar.isHittable { app.swipeUp() }
        XCTAssertTrue(avaliar.waitForExistence(timeout: 5))
        tocar(avaliar)
        XCTAssertTrue(app.buttons["resposta-nao"].waitForExistence(timeout: 5))
        tocar(app.buttons["resposta-nao"])
        tocar(app.buttons["botao-enviar-avaliacao"])
        XCTAssertTrue(app.descendants(matching: .any)["aviso-sucesso-avaliacao"].waitForExistence(timeout: 5))
        tocar(app.navigationBars["Avaliar turno"].buttons.firstMatch)
        tocar(app.navigationBars["Meu turno"].buttons.firstMatch)
        tocar(app.tabBars.buttons["Vagas no DF"])
        tocar(app.buttons["abrir-meu-perfil"])
        let sair = app.buttons["Sair"]
        if !sair.isHittable { app.swipeUp() }
        XCTAssertTrue(sair.waitForExistence(timeout: 5))
        tocar(sair)
        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        tocar(email)
        email.digitarEEsperar("teste@frila.app")
        tocar(app.buttons["entrada-receber-codigo"])
        let codigo = app.textFields["Código de acesso"]
        XCTAssertTrue(codigo.waitForExistence(timeout: 10))
        tocar(codigo)
        codigo.digitarEEsperar("123456")
        tocar(app.buttons["codigo-entrar"])
        abrirTurno(app)
        conferirAvaliacaoNegativa(app)
    }

    func testAvaliarVoltarAListaEAbrirDeNovoPreservaResposta() {
        conferirReabertura(cenario: "turno-encerrado", offline: false)
    }

    func testAvaliarSemRedeVoltarAListaEAbrirDeNovoMantemVotoNaFila() {
        conferirReabertura(cenario: "avaliacao-sem-rede", offline: true)
    }

    func testAvaliacaoAbertaPeloAvisoUsaRespostaDoServidor() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "turno-avaliado", "-FRILA_AVALIACAO_TURNO_ID", turnoID]
        app.launchArguments.append("-FRILA_CACHE_VAZIO_UI_TEST")
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["aviso-ja-avaliado"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["resposta-nao"].isSelected)
        XCTAssertFalse(app.buttons["resposta-sim"].isEnabled)
        XCTAssertFalse(app.buttons["botao-enviar-avaliacao"].exists)
    }

    private func conferirReabertura(cenario: String, offline: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", cenario]
        app.launchArguments.append("-FRILA_CACHE_VAZIO_UI_TEST")
        app.launch()
        abrirTurno(app)
        let avaliar = app.buttons["Avaliar turno"]
        if !avaliar.isHittable { app.swipeUp() }
        tocar(avaliar)
        let navBar = app.navigationBars["Avaliar turno"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 10))
        XCTAssertTrue(navBar.buttons.firstMatch.waitForExistence(timeout: 10))
        let botaoNao = app.buttons["resposta-nao"]
        tocar(botaoNao)
        let botaoEnviar = app.buttons["botao-enviar-avaliacao"]
        XCTAssertTrue(botaoEnviar.waitForExistence(timeout: 10))
        let habilitado = NSPredicate(format: "enabled == true")
        if !botaoEnviar.isEnabled {
            let espera = XCTNSPredicateExpectation(predicate: habilitado, object: botaoEnviar)
            if XCTWaiter.wait(for: [espera], timeout: 3) != .completed {
                botaoNao.tap()
                let segundaEspera = XCTNSPredicateExpectation(predicate: habilitado, object: botaoEnviar)
                _ = XCTWaiter.wait(for: [segundaEspera], timeout: 5)
            }
        }
        XCTAssertTrue(botaoEnviar.isEnabled)
        tocar(botaoEnviar)

        let confirmacao = app.descendants(matching: .any)["aviso-sucesso-avaliacao"]
        XCTAssertTrue(confirmacao.waitForExistence(timeout: 10))
        if offline {
            XCTAssertTrue(confirmacao.label.contains("Será enviada quando a internet voltar."))
        }
        tocar(app.navigationBars["Avaliar turno"].buttons.firstMatch)
        XCTAssertTrue(app.staticTexts["Turno avaliado · Resposta: Não"].waitForExistence(timeout: 10))
        tocar(app.navigationBars["Meu turno"].buttons.firstMatch)
        XCTAssertTrue(app.navigationBars["Meus turnos"].waitForExistence(timeout: 10))
        let cartao = app.buttons["meu-turno-\(turnoID)"]
        XCTAssertTrue(cartao.waitForExistence(timeout: 10))
        tocar(cartao)
        conferirAvaliacaoNegativa(app)
    }

    private func tocar(_ elemento: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(elemento.waitForExistence(timeout: 10), file: file, line: line)
        if !elemento.isHittable || !elemento.isEnabled {
            let habilitado = NSPredicate(format: "hittable == true AND enabled == true")
            let espera = XCTNSPredicateExpectation(predicate: habilitado, object: elemento)
            _ = XCTWaiter.wait(for: [espera], timeout: 5)
        }
        elemento.tap()
    }

    private func conferirAvaliacaoNegativa(_ app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Meu turno"].waitForExistence(timeout: 10))
        let status = app.staticTexts["Turno avaliado · Resposta: Não"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        if !status.isHittable { app.swipeUp() }
        XCTAssertTrue(status.isHittable)
        XCTAssertTrue(status.label.contains("Não"))
        XCTAssertFalse(app.buttons["Avaliar turno"].exists)
        let verAvaliacao = app.buttons["Ver avaliação"]
        if !verAvaliacao.isHittable { app.swipeUp() }
        tocar(verAvaliacao)
        XCTAssertTrue(app.navigationBars["Avaliar turno"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["resposta-nao"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["resposta-nao"].isSelected)
        XCTAssertFalse(app.buttons["resposta-nao"].isEnabled)
        XCTAssertFalse(app.buttons["resposta-sim"].isEnabled)
        XCTAssertFalse(app.buttons["botao-enviar-avaliacao"].exists)
    }
}
