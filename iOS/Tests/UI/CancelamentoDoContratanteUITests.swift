import XCTest

/// Cancelamento com motivo pelo contratante (#20), contra o dublê: a posição no painel do turno e a
/// vaga em Minhas vagas, com as listas atualizadas sem reiniciar o app.
@MainActor
final class CancelamentoDoContratanteUITests: XCTestCase {
    private let turnoID = "82000000-0000-0000-0000-000000000001"
    private let posicaoID = "82000000-0000-0000-0000-000000000002"
    private let vagaID = "40000000-0000-0000-0000-000000000001"

    private func abrir() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "painel-contratante", "-FRILA_CACHE_VAZIO_UI_TEST"]
        AjudanteDeLancamentoUITests.preparar(app)
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 15))
        return app
    }

    private func escolherMotivoEConfirmar(_ app: XCUIApplication, motivo: String) {
        let folha = app.descendants(matching: .any)["folha-de-cancelamento"].firstMatch
        XCTAssertTrue(folha.waitForExistence(timeout: Espera.aparecer))
        let aviso = app.descendants(matching: .any)["aviso-do-cancelamento"].firstMatch
        XCTAssertTrue(aviso.waitForExistence(timeout: Espera.aparecer))
        XCTAssertFalse(aviso.label.contains("falta na sua taxa"), aviso.label)
        let confirmar = app.buttons["confirmar-cancelamento"]
        XCTAssertTrue(confirmar.waitForExistence(timeout: Espera.aparecer))
        XCTAssertFalse(confirmar.isEnabled)
        tocar(app.buttons["motivo-\(motivo)"])
        XCTAssertTrue(confirmar.isEnabled)
        if !confirmar.isHittable { folha.swipeUp() }
        tocar(confirmar)
    }

    func testCancelarPosicaoNoPainelDoTurnoAtualizaAVaga() {
        let app = abrir()
        let cartao = app.buttons["vaga-contratante-\(vagaID)"]
        XCTAssertTrue(cartao.waitForExistence(timeout: 10))
        XCTAssertTrue(cartao.label.contains("1 de 2 confirmadas"), cartao.label)

        tocar(cartao)
        XCTAssertTrue(app.descendants(matching: .any)["detalhe-vaga-contratante"].waitForExistence(timeout: Espera.aparecer))
        let acompanhar = app.buttons["acompanhar-turno-\(turnoID)"]
        if !acompanhar.isHittable { app.swipeUp() }
        tocar(acompanhar)
        XCTAssertTrue(app.staticTexts["Chegada"].waitForExistence(timeout: Espera.aparecer))
        let cancelar = app.buttons["cancelar-posicao-\(posicaoID)"]
        if !cancelar.isHittable { app.swipeUp() }
        tocar(cancelar)

        let aviso = app.descendants(matching: .any)["aviso-do-cancelamento"].firstMatch
        XCTAssertTrue(aviso.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(aviso.label.hasPrefix("Faltam 2") && aviso.label.contains(" h para o início."), aviso.label)
        XCTAssertTrue(aviso.label.contains("Não conta como falta para o profissional."), aviso.label)
        escolherMotivoEConfirmar(app, motivo: "movimentoMenor")

        let desfecho = app.descendants(matching: .any)["desfecho-do-cancelamento"].firstMatch
        XCTAssertTrue(desfecho.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(desfecho.label.contains("Posição cancelada. Ela voltou a ser oferecida a outros profissionais."), desfecho.label)
        tocar(app.buttons["fechar-cancelamento"])

        // O turno passa a cancelado na tela, com a causa e sem o botão.
        XCTAssertTrue(app.staticTexts["posicao-cancelada-\(turnoID)"].waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(app.staticTexts["cancelamento-causa-\(turnoID)"].waitForExistence(timeout: Espera.aparecer))
        XCTAssertEqual(app.staticTexts["cancelamento-causa-\(turnoID)"].label, "Cancelado pelo estabelecimento.")
        XCTAssertEqual(app.staticTexts["cancelamento-falta-\(turnoID)"].label, "Não contou como falta.")
        XCTAssertFalse(app.buttons["cancelar-posicao-\(posicaoID)"].exists)

        // Critério 2: o detalhe e Minhas vagas mostram a vaga sem a confirmação, sem reiniciar o app.
        tocar(app.navigationBars.buttons.firstMatch)
        XCTAssertTrue(app.descendants(matching: .any)["detalhe-vaga-contratante"].waitForExistence(timeout: Espera.aparecer))
        XCTAssertFalse(app.buttons["cancelar-posicao-\(posicaoID)"].exists)
        tocar(app.navigationBars.buttons.firstMatch)
        XCTAssertTrue(cartao.waitForExistence(timeout: 10))
        let semConfirmadas = NSPredicate(format: "label CONTAINS %@", "0 de 3 confirmadas")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: semConfirmadas, object: cartao)], timeout: 10), .completed, cartao.label)
    }

    func testCancelarAVagaEmMinhasVagasMoveParaEncerradas() {
        let app = abrir()
        let cartao = app.buttons["vaga-contratante-\(vagaID)"]
        XCTAssertTrue(cartao.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Próximas"].exists)
        XCTAssertFalse(app.staticTexts["Encerradas"].exists)
        tocar(cartao)

        XCTAssertTrue(app.descendants(matching: .any)["detalhe-vaga-contratante"].waitForExistence(timeout: Espera.aparecer))
        tocar(app.buttons["cancelar-vaga-\(vagaID)"])
        let aviso = app.descendants(matching: .any)["aviso-do-cancelamento"].firstMatch
        XCTAssertTrue(aviso.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(aviso.label.contains("Todas as posições serão canceladas"), aviso.label)
        escolherMotivoEConfirmar(app, motivo: "mudancaDePlanos")

        let desfecho = app.descendants(matching: .any)["desfecho-do-cancelamento"].firstMatch
        XCTAssertTrue(desfecho.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(desfecho.label.contains("Vaga cancelada. Os profissionais confirmados foram avisados."), desfecho.label)
        tocar(app.buttons["fechar-cancelamento"])

        // O detalhe passa a oferecer republicar, e não mais cancelar.
        XCTAssertTrue(app.buttons["republicar-detalhe-vaga-\(vagaID)"].waitForExistence(timeout: Espera.aparecer))
        XCTAssertFalse(app.buttons["cancelar-vaga-\(vagaID)"].exists)
        XCTAssertFalse(app.buttons["cancelar-posicao-\(posicaoID)"].exists)

        // Critério 2: a lista move a vaga para Encerradas sem reiniciar o app.
        tocar(app.navigationBars.buttons.firstMatch)
        XCTAssertTrue(app.staticTexts["Encerradas"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Próximas"].exists)
        XCTAssertTrue(app.buttons["republicar-vaga-\(vagaID)"].waitForExistence(timeout: Espera.aparecer))
    }

    func testVoltarNaFolhaNaoCancelaNada() {
        let app = abrir()
        tocar(app.buttons["vaga-contratante-\(vagaID)"])
        tocar(app.buttons["cancelar-vaga-\(vagaID)"])
        tocar(app.buttons["motivo-movimentoMenor"])
        tocar(app.buttons["voltar-do-cancelamento"])
        XCTAssertTrue(app.buttons["cancelar-vaga-\(vagaID)"].waitForExistence(timeout: Espera.aparecer))
        XCTAssertFalse(app.buttons["republicar-detalhe-vaga-\(vagaID)"].exists)
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
