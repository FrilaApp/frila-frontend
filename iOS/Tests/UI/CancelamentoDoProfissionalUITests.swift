import XCTest

/// Cancelamento com motivo pelo profissional (#20), contra o dublê: o aviso muda com a antecedência,
/// cancelar sem motivo não é possível, e a lista mostra o turno cancelado sem reiniciar o app.
@MainActor
final class CancelamentoDoProfissionalUITests: XCTestCase {
    private let turnoID = "23000000-0000-0000-0000-000000000001"

    private func abrirTurno(cenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", cenario, "-FRILA_CACHE_VAZIO_UI_TEST"]
        AjudanteDeLancamentoUITests.preparar(app)
        app.launch()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 15))
        tocar(app.tabBars.buttons["Meus turnos"])
        let cartao = app.buttons["meu-turno-\(turnoID)"]
        XCTAssertTrue(cartao.waitForExistence(timeout: 10))
        XCTAssertFalse(cartao.label.contains("Turno cancelado"))
        tocar(cartao)
        XCTAssertTrue(app.navigationBars["Meu turno"].waitForExistence(timeout: 5))
        return app
    }

    private func abrirFolha(_ app: XCUIApplication) -> XCUIElement {
        tocar(app.buttons["cancelar-turno"])
        let folha = app.descendants(matching: .any)["folha-de-cancelamento"].firstMatch
        XCTAssertTrue(folha.waitForExistence(timeout: 5))
        return folha
    }

    func testAMenosDe24HorasAvisaFaltaEExigeMotivo() {
        let app = abrirTurno(cenario: "turno-confirmado-perto")
        _ = abrirFolha(app)

        let aviso = app.descendants(matching: .any)["aviso-do-cancelamento"].firstMatch
        XCTAssertTrue(aviso.waitForExistence(timeout: 5))
        XCTAssertTrue(aviso.label.contains("Faltam 10 h para o início."), aviso.label)
        XCTAssertTrue(aviso.label.contains("conta como falta na sua taxa de comparecimento"), aviso.label)

        // Critério 3: sem motivo, o botão não habilita.
        let confirmar = app.buttons["confirmar-cancelamento"]
        XCTAssertTrue(confirmar.waitForExistence(timeout: 5))
        XCTAssertFalse(confirmar.isEnabled)
        XCTAssertTrue(app.staticTexts["motivo-obrigatorio"].exists)

        tocar(app.buttons["motivo-saude"])
        XCTAssertTrue(confirmar.isEnabled)
        tocar(confirmar)

        let desfecho = app.descendants(matching: .any)["desfecho-do-cancelamento"].firstMatch
        XCTAssertTrue(desfecho.waitForExistence(timeout: 5))
        XCTAssertTrue(desfecho.label.contains("Turno cancelado. A vaga voltou a ser oferecida a outros profissionais."), desfecho.label)
        XCTAssertEqual(app.staticTexts["falta-do-cancelamento"].label, "Este cancelamento contou como falta.")
        tocar(app.buttons["fechar-cancelamento"])

        // A tela do turno vira "Turno cancelado" na hora, sem botão de cancelar nem ações do turno.
        XCTAssertTrue(app.staticTexts["estado-do-turno"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["estado-do-turno"].label, "Turno cancelado")
        let cancelamento = app.descendants(matching: .any)["cancelamento-do-turno"].firstMatch
        XCTAssertTrue(cancelamento.waitForExistence(timeout: 5))
        XCTAssertTrue(cancelamento.label.contains("Você cancelou este turno."))
        XCTAssertTrue(cancelamento.label.contains("Este cancelamento contou como falta."))
        XCTAssertFalse(app.buttons["cancelar-turno"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["contato-do-turno"].exists)

        // Critério 2: a lista mostra o cancelamento sem reiniciar o app.
        tocar(app.navigationBars["Meu turno"].buttons.firstMatch)
        let cartao = app.buttons["meu-turno-\(turnoID)"]
        XCTAssertTrue(cartao.waitForExistence(timeout: 10))
        let cancelado = NSPredicate(format: "label CONTAINS %@", "Turno cancelado")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: cancelado, object: cartao)], timeout: 10), .completed, cartao.label)
    }

    func testAMaisDe24HorasAvisaQueNaoAfetaATaxa() {
        let app = abrirTurno(cenario: "turno-confirmado-longe")
        let folha = abrirFolha(app)

        let aviso = app.descendants(matching: .any)["aviso-do-cancelamento"].firstMatch
        XCTAssertTrue(aviso.waitForExistence(timeout: 5))
        XCTAssertTrue(aviso.label.contains("Faltam 48 h para o início."), aviso.label)
        XCTAssertTrue(aviso.label.contains("não afeta sua taxa de comparecimento"), aviso.label)
        XCTAssertFalse(aviso.label.contains("conta como falta"), aviso.label)

        // "Outro motivo" exige o campo livre.
        let confirmar = app.buttons["confirmar-cancelamento"]
        tocar(app.buttons["motivo-outro"])
        XCTAssertFalse(confirmar.isEnabled)
        let detalhes = app.textFields["detalhes-do-cancelamento"]
        XCTAssertTrue(detalhes.waitForExistence(timeout: 5))
        // O campo fica abaixo da dobra da folha: rola até ele antes de tocar.
        if !detalhes.isHittable { folha.swipeUp() }
        tocar(detalhes)
        detalhes.typeText("Viagem marcada de última hora")
        XCTAssertTrue(confirmar.isEnabled)
        // Com o teclado aberto, o XCUITest não dá o botão como "hittable" embora ele esteja visível;
        // o toque direto rola até ele se preciso.
        confirmar.tap()

        let desfecho = app.descendants(matching: .any)["desfecho-do-cancelamento"].firstMatch
        XCTAssertTrue(desfecho.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["falta-do-cancelamento"].label, "Este cancelamento não contou como falta.")
        tocar(app.buttons["fechar-cancelamento"])
        XCTAssertEqual(app.staticTexts["estado-do-turno"].label, "Turno cancelado")
    }

    func testVoltarFechaAFolhaSemCancelar() {
        let app = abrirTurno(cenario: "turno-confirmado-longe")
        _ = abrirFolha(app)
        tocar(app.buttons["motivo-saude"])
        tocar(app.buttons["voltar-do-cancelamento"])
        XCTAssertTrue(app.buttons["cancelar-turno"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["estado-do-turno"].label, "Você está confirmado")
    }

    func testSemRedeEntraNaFilaEATelaAvisaQueSeraEnviado() {
        let app = abrirTurno(cenario: "cancelar-sem-rede")
        _ = abrirFolha(app)
        tocar(app.buttons["motivo-deslocamento"])
        tocar(app.buttons["confirmar-cancelamento"])

        let desfecho = app.descendants(matching: .any)["desfecho-do-cancelamento"].firstMatch
        XCTAssertTrue(desfecho.waitForExistence(timeout: 5))
        XCTAssertTrue(desfecho.label.contains("Sem conexão. O cancelamento será enviado quando a internet voltar."), desfecho.label)
        XCTAssertFalse(app.staticTexts["falta-do-cancelamento"].exists)
        tocar(app.buttons["fechar-cancelamento"])

        // Critério 5: a tela diz que o cancelamento será enviado e não oferece cancelar de novo.
        let naFila = app.descendants(matching: .any)["cancelamento-na-fila"].firstMatch
        XCTAssertTrue(naFila.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["cancelar-turno"].exists)
        XCTAssertEqual(app.staticTexts["estado-do-turno"].label, "Você está confirmado")
    }

    private func tocar(_ elemento: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(elemento.waitForExistence(timeout: 10), file: file, line: line)
        if !elemento.isHittable || !elemento.isEnabled {
            let habilitado = NSPredicate(format: "hittable == true AND enabled == true")
            let espera = XCTNSPredicateExpectation(predicate: habilitado, object: elemento)
            XCTAssertEqual(XCTWaiter.wait(for: [espera], timeout: 5), .completed, file: file, line: line)
        }
        elemento.tap()
    }
}
