import XCTest

/// Testes de interface contra o servidor de hoje (sem os campos novos dos contratos 0.2.31 e 0.2.32),
/// no lado do profissional (cartões #22 e #10):
/// - Turnos sem `estado`, `avaliacao` e `cancelamento`
/// - Candidaturas sem `turno_id`
@MainActor
final class ServidorDeHojeUITests: XCTestCase {
    private let vagaID = "40000000-0000-0000-0000-000000000001"
    private let candidaturaID = "6F1C2A4E-2B7D-4C5E-9A1F-3D2E1C0B9A88"
    private let turnoConfirmadoID = "84000000-0000-0000-0000-000000000001"
    private let turnoEncerradoID = "22000000-0000-0000-0000-000000000001"

    override func setUp() {
        continueAfterFailure = false
    }

    private func abrir(extras: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "profissional-servidor-antigo"] + extras
        app.launch()
        return app
    }

    private func tocar(_ elemento: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(elemento.waitForExistence(timeout: 10), file: file, line: line)
        let habilitado = NSPredicate(format: "hittable == true AND enabled == true")
        let espera = XCTNSPredicateExpectation(predicate: habilitado, object: elemento)
        // 10 s, como a espera da existência e no TurnoContrato0231UITests: no runner lento da CI
        // a transição de telas pode demorar mais que os 5 s.
        XCTAssertEqual(XCTWaiter.wait(for: [espera], timeout: 10), .completed, file: file, line: line)
        elemento.tap()
    }

    // MARK: 1. Meus turnos e o detalhe do turno confirmado

    func testMeusTurnosEDetalheDoTurnoConfirmadoComAcoesDeSempre() {
        let app = abrir()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 15))

        let aba = app.tabBars.buttons["Meus turnos"]
        XCTAssertTrue(aba.waitForExistence(timeout: 10))
        tocar(aba)

        XCTAssertTrue(app.descendants(matching: .any)["tela-meus-turnos"].waitForExistence(timeout: 10))
        let cartao = app.buttons["meu-turno-\(turnoConfirmadoID)"]
        XCTAssertTrue(cartao.waitForExistence(timeout: 10))
        tocar(cartao)

        XCTAssertTrue(app.descendants(matching: .any)["tela-meu-turno"].waitForExistence(timeout: 10))
        let cabecalho = app.staticTexts["estado-do-turno"]
        XCTAssertTrue(cabecalho.waitForExistence(timeout: 10))
        XCTAssertEqual(cabecalho.label, "Você está confirmado")

        // Ações de sempre de um turno confirmado
        XCTAssertTrue(app.descendants(matching: .any)["contato-do-turno"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Abrir no WhatsApp"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Ver no Mapas"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Fazer check-in"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["cancelamento-do-turno"].exists)
        XCTAssertFalse(app.buttons["Avaliar turno"].exists)
    }

    // MARK: 2. Avaliar turno encerrado usando reserva do aparelho

    func testAvaliarTurnoEncerradoUsaReservaDoAparelho() {
        let app = abrir(extras: ["-FRILA_CACHE_VAZIO_UI_TEST"])
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 15))

        tocar(app.tabBars.buttons["Meus turnos"])
        let cartaoEncerrado = app.buttons["meu-turno-\(turnoEncerradoID)"]
        XCTAssertTrue(cartaoEncerrado.waitForExistence(timeout: 10))
        tocar(cartaoEncerrado)

        XCTAssertTrue(app.descendants(matching: .any)["tela-meu-turno"].waitForExistence(timeout: 10))

        let botaoAvaliar = app.buttons["Avaliar turno"]
        if !botaoAvaliar.isHittable { app.swipeUp() }
        XCTAssertTrue(botaoAvaliar.waitForExistence(timeout: 10))
        tocar(botaoAvaliar)

        XCTAssertTrue(app.navigationBars["Avaliar turno"].waitForExistence(timeout: 10))
        let sim = app.buttons["resposta-sim"]
        XCTAssertTrue(sim.waitForExistence(timeout: 10))
        tocar(sim)

        let enviar = app.buttons["botao-enviar-avaliacao"]
        XCTAssertTrue(enviar.waitForExistence(timeout: 10))
        tocar(enviar)

        let confirmacao = app.descendants(matching: .any)["aviso-sucesso-avaliacao"]
        XCTAssertTrue(confirmacao.waitForExistence(timeout: 10))

        // Voltar para "Meu turno"
        tocar(app.navigationBars["Avaliar turno"].buttons.firstMatch)
        XCTAssertTrue(app.descendants(matching: .any)["tela-meu-turno"].waitForExistence(timeout: 10))
        let statusAvaliacao = app.staticTexts["Turno avaliado · Resposta: Sim"]
        if !statusAvaliacao.isHittable { app.swipeUp() }
        XCTAssertTrue(statusAvaliacao.waitForExistence(timeout: 10))

        // Voltar para "Meus turnos"
        tocar(app.navigationBars["Meu turno"].buttons.firstMatch)
        XCTAssertTrue(app.descendants(matching: .any)["tela-meus-turnos"].waitForExistence(timeout: 10))

        // Reabrir o mesmo turno encerrado: sem o campo avaliacao no servidor antigo, usa a reserva local
        let reabrirCartao = app.buttons["meu-turno-\(turnoEncerradoID)"]
        XCTAssertTrue(reabrirCartao.waitForExistence(timeout: 10))
        tocar(reabrirCartao)

        XCTAssertTrue(app.descendants(matching: .any)["tela-meu-turno"].waitForExistence(timeout: 10))
        let statusReaberto = app.staticTexts["Turno avaliado · Resposta: Sim"]
        if !statusReaberto.isHittable { app.swipeUp() }
        XCTAssertTrue(statusReaberto.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Avaliar turno"].exists)
        XCTAssertTrue(app.buttons["Ver avaliação"].exists)
    }

    // MARK: 3. Candidaturas: aceita diz "Confirmada" e toque vai para Meus turnos

    func testCandidaturaAceitaSemTurnoIDApareceConfirmadaETocaVaiParaMeusTurnos() {
        let app = abrir()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 15))

        let aba = app.tabBars.buttons["Candidaturas"]
        XCTAssertTrue(aba.waitForExistence(timeout: 10))
        tocar(aba)

        let cartao = app.buttons["candidatura-\(candidaturaID)"]
        XCTAssertTrue(cartao.waitForExistence(timeout: 10))
        XCTAssertTrue(cartao.label.contains("Confirmada: o turno está em Meus turnos"), cartao.label)

        tocar(cartao)
        // Sem turno_id no servidor de hoje, o toque na candidatura aceita vai para Meus turnos
        XCTAssertTrue(app.descendants(matching: .any)["tela-meus-turnos"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Meus turnos"].isSelected)
    }

    // MARK: 4. Aviso de push de uma vaga abre o turno certo sem estado

    func testPushDeVagaPreenchidaAbreOTurnoCertoSemEstado() {
        let app = abrir(extras: ["-FRILA_PUSH", "vaga", "-FRILA_PUSH_ID", vagaID])

        // A vaga está preenchida e o profissional já tem um turno confirmado nela.
        // Mesmo sem o campo 'estado' no turno (servidor de hoje), o roteador de push
        // encontra o turno (pois nil != .cancelada) e abre diretamente a tela do turno.
        XCTAssertTrue(app.descendants(matching: .any)["tela-meu-turno"].waitForExistence(timeout: 15))
        let cabecalho = app.staticTexts["estado-do-turno"]
        XCTAssertTrue(cabecalho.waitForExistence(timeout: 10))
        XCTAssertEqual(cabecalho.label, "Você está confirmado")
        XCTAssertTrue(app.descendants(matching: .any)["contato-do-turno"].waitForExistence(timeout: 10))
    }
}
