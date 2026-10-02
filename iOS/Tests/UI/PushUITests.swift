import XCTest

/// O destino do toque num push (#8) no dublê, pelo caminho inteiro: o aparelho ganha um token
/// simulado, a conta que entrou o registra, e `-FRILA_PUSH` entrega o payload ao roteador único.
@MainActor
final class PushUITests: XCTestCase {
    /// `vaga.json` do dublê.
    private let vagaID = "40000000-0000-0000-0000-000000000001"
    /// O turno dos cenários do contratante.
    private let turnoDaCasa = "82000000-0000-0000-0000-000000000001"
    private let idDesconhecido = "99999999-0000-0000-0000-000000000001"

    private func abrir(_ cenario: String, push tipo: String, id: String? = nil, outros: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", cenario, "-FRILA_PUSH", tipo] + (id.map { ["-FRILA_PUSH_ID", $0] } ?? []) + outros
        app.launch()
        return app
    }

    func testPushDeVagaAbreODetalheSemCandidatar() {
        let app = abrir("success", push: "vaga", id: vagaID)

        XCTAssertTrue(app.descendants(matching: .any)["tela-detalhe-vaga"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["candidatar"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["resultado-confirmada"].exists, "o toque abre o detalhe, nunca aceita sozinho")
    }

    func testPushDeVagaIndisponivelAbreATelaPropriaEVoltaParaALista() {
        let app = abrir("success", push: "vaga", id: idDesconhecido)

        XCTAssertTrue(app.descendants(matching: .any)["vaga-indisponivel"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Essa vaga não está mais aberta"].exists)
        XCTAssertFalse(app.buttons["candidatar"].exists)

        app.buttons["voltar-para-lista"].tap()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
    }

    func testPushEntregueAntesDeOAparelhoSerDaContaNaoAbreNada() {
        let app = abrir("success", push: "vaga", id: vagaID, outros: ["-FRILA_PUSH_DE_ANTES"])

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.descendants(matching: .any)["tela-detalhe-vaga"].waitForExistence(timeout: 3), "push de outra conta não abre destino")
    }

    func testPushDeTurnoQueNaoEDaContaNaoMostraTurnoELevaAosMeusTurnos() {
        let app = abrir("success", push: "lembrete_3h", id: idDesconhecido)

        XCTAssertTrue(app.descendants(matching: .any)["turno-do-aviso-nao-encontrado"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.descendants(matching: .any)["tela-meu-turno"].exists)

        app.buttons["ver-meus-turnos"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["tela-meus-turnos"].waitForExistence(timeout: 10))
    }

    func testPushDaCasaAbreOTurnoParaQuemContrata() {
        let app = abrir("checkin-manual-pendente", push: "checkin_manual_pendente", id: turnoDaCasa)

        XCTAssertTrue(app.descendants(matching: .any)["turno-do-contratante"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Chegada"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Confirmar presença"].exists, "o toque abre o turno, e quem confirma é a pessoa")
    }

    func testPushDeOutroPerfilNaoAbreNada() {
        // Aviso de quem trabalha chegando a uma conta de contratante: fica em Minhas vagas.
        let app = abrir("checkin-manual-pendente", push: "vaga", id: vagaID)

        XCTAssertTrue(app.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.descendants(matching: .any)["tela-detalhe-vaga"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["detalhe-vaga-contratante"].exists)
    }
}
