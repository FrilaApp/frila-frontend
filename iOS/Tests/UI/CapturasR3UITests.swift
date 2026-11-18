import XCTest

/// R3 do redesign (Profissional, Turnos): a lista de turnos, o Meu turno com a presença, o código da casa, o
/// check-out, a avaliação e a folha de cancelamento, no tamanho padrão e em AX5, com o dublê do app.
/// `FRILA_CAPTURAS_DIR` (opcional) grava as imagens; sem ela, os anexos ficam só no resultado do teste.
@MainActor
final class CapturasR3UITests: XCTestCase {
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func iniciar(cenario: String, localizacao: String? = nil, extras: [String] = [], ax5: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", cenario, "-FRILA_MODO_CLARO", "-AppleLanguages", "(pt-BR)",
                               "-AppleLocale", "pt_BR", "-FRILA_SEM_ANIMACOES", "-FRILA_CACHE_VAZIO_UI_TEST"] + extras
        if let localizacao { app.launchArguments += ["-FRILA_LOCALIZACAO", localizacao] }
        if ax5 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", Self.ax5] }
        app.launch()
        return app
    }

    private func capturar(_ nome: String) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let captura = XCUIScreen.main.screenshot()
        let anexo = XCTAttachment(screenshot: captura)
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)
        if let pasta = ProcessInfo.processInfo.environment["FRILA_CAPTURAS_DIR"], !pasta.isEmpty {
            try? FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
            try? captura.pngRepresentation.write(to: URL(fileURLWithPath: "\(pasta)/\(nome).png"))
        }
    }

    private func sufixo(_ ax5: Bool) -> String { ax5 ? "ax5" : "padrao" }

    private func abrirListaDeTurnos(_ app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: Espera.aparecer), "o feed abre")
        tocar(app.tabBars.buttons["Meus turnos"])
        XCTAssertTrue(app.descendants(matching: .any)["tela-meus-turnos"].waitForExistence(timeout: Espera.aparecer))
    }

    /// Da lista de turnos ao Meu turno do primeiro cartão.
    private func abrirMeuTurno(_ app: XCUIApplication) {
        abrirListaDeTurnos(app)
        let turno = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'meu-turno-'")).firstMatch
        tocar(turno)
        XCTAssertTrue(app.descendants(matching: .any)["tela-meu-turno"].waitForExistence(timeout: Espera.aparecer))
    }

    /// Candidata-se à primeira vaga do dublê, que vira um turno confirmado, e abre o Meu turno dele.
    private func abrirMeuTurnoPelaCandidatura(_ app: XCUIApplication) {
        let primeira = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-'")).firstMatch
        tocar(primeira)
        tocar(app.buttons["candidatar"])
        XCTAssertTrue(app.descendants(matching: .any)["resultado-confirmada"].waitForExistence(timeout: Espera.aparecer))
        tocar(app.buttons["voltar-para-lista"])
        tocar(app.tabBars.buttons["Meus turnos"])
        let turno = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'meu-turno-'")).firstMatch
        tocar(turno)
        XCTAssertTrue(app.descendants(matching: .any)["tela-meu-turno"].waitForExistence(timeout: Espera.aparecer))
    }

    // MARK: Lista de turnos

    private func listaDeTurnos(ax5: Bool) {
        let app = iniciar(cenario: "turno-confirmado-perto", ax5: ax5)
        abrirListaDeTurnos(app)
        XCTAssertTrue(app.buttons["meu-turno-23000000-0000-0000-0000-000000000001"].waitForExistence(timeout: Espera.aparecer))
        capturar("r3-lista-de-turnos-\(sufixo(ax5))")
    }

    func testListaDeTurnosNoTamanhoPadrao() { listaDeTurnos(ax5: false) }
    func testListaDeTurnosEmAX5() { listaDeTurnos(ax5: true) }

    // MARK: Meu turno, antes de sair e a caminho

    private func meuTurnoAntesDeSair(ax5: Bool) {
        let app = iniciar(cenario: "a-caminho", localizacao: "perto", ax5: ax5)
        abrirMeuTurnoPelaCandidatura(app)
        XCTAssertTrue(app.buttons["botao-a-caminho"].waitForExistence(timeout: Espera.aparecer))
        capturar("r3-meu-turno-antes-\(sufixo(ax5))-1")
        app.swipeUp()
        capturar("r3-meu-turno-antes-\(sufixo(ax5))-2")
        app.swipeUp()
        capturar("r3-meu-turno-antes-\(sufixo(ax5))-3")
    }

    func testMeuTurnoAntesDeSairNoTamanhoPadrao() { meuTurnoAntesDeSair(ax5: false) }
    func testMeuTurnoAntesDeSairEmAX5() { meuTurnoAntesDeSair(ax5: true) }

    private func meuTurnoACaminho(ax5: Bool) {
        let app = iniciar(cenario: "a-caminho", localizacao: "perto", ax5: ax5)
        abrirMeuTurnoPelaCandidatura(app)
        tocar(app.buttons["botao-a-caminho"])
        XCTAssertTrue(app.descendants(matching: .any)["a-caminho-situacao"].waitForExistence(timeout: Espera.aparecer))
        capturar("r3-meu-turno-a-caminho-\(sufixo(ax5))")
    }

    func testMeuTurnoACaminhoNoTamanhoPadrao() { meuTurnoACaminho(ax5: false) }
    func testMeuTurnoACaminhoEmAX5() { meuTurnoACaminho(ax5: true) }

    // MARK: Presença: o check-in e o check-out

    private func presenca(localizacao: String, esperar: String, nome: String, ax5: Bool, depoisDoPedido: (XCUIApplication) -> Void = { _ in }) {
        let app = iniciar(cenario: "success", localizacao: localizacao, ax5: ax5)
        abrirMeuTurnoPelaCandidatura(app)
        let fazerCheckin = app.buttons["fazer-checkin"]
        XCTAssertTrue(fazerCheckin.waitForExistence(timeout: Espera.aparecer))
        XCTAssertGreaterThanOrEqual(fazerCheckin.frame.height, 44, "o alvo do botão de presença")
        if nome == "inicio" {
            capturar("r3-presenca-inicio-\(sufixo(ax5))")
            return
        }
        tocar(fazerCheckin)
        XCTAssertTrue(app.descendants(matching: .any)["explicacao-localizacao"].waitForExistence(timeout: Espera.aparecer))
        if nome == "explicacao" {
            capturar("r3-presenca-explicacao-\(sufixo(ax5))")
            return
        }
        tocar(app.buttons["permitir-localizacao"])
        XCTAssertTrue(app.descendants(matching: .any)[esperar].waitForExistence(timeout: Espera.aparecer))
        depoisDoPedido(app)
        capturar("r3-presenca-\(nome)-\(sufixo(ax5))")
    }

    func testPresencaInicioNoTamanhoPadrao() { presenca(localizacao: "perto", esperar: "", nome: "inicio", ax5: false) }
    func testPresencaInicioEmAX5() { presenca(localizacao: "perto", esperar: "", nome: "inicio", ax5: true) }

    func testPresencaExplicacaoNoTamanhoPadrao() { presenca(localizacao: "perto", esperar: "", nome: "explicacao", ax5: false) }
    func testPresencaExplicacaoEmAX5() { presenca(localizacao: "perto", esperar: "", nome: "explicacao", ax5: true) }

    func testPresencaSemGPSNoTamanhoPadrao() { presenca(localizacao: "negada", esperar: "sem-gps", nome: "sem-gps", ax5: false) }
    func testPresencaSemGPSEmAX5() { presenca(localizacao: "negada", esperar: "sem-gps", nome: "sem-gps", ax5: true) }

    func testPresencaRegistradaNoTamanhoPadrao() { presenca(localizacao: "perto", esperar: "checkin-situacao", nome: "registrada", ax5: false) }
    func testPresencaRegistradaEmAX5() { presenca(localizacao: "perto", esperar: "checkin-situacao", nome: "registrada", ax5: true) }

    func testCheckoutRegistradoNoTamanhoPadrao() {
        presenca(localizacao: "perto", esperar: "checkin-situacao", nome: "checkout", ax5: false) { app in
            tocar(app.buttons["fazer-checkout"])
            XCTAssertTrue(app.descendants(matching: .any)["checkout-situacao"].waitForExistence(timeout: Espera.aparecer))
        }
    }

    func testCheckoutRegistradoEmAX5() {
        presenca(localizacao: "perto", esperar: "checkin-situacao", nome: "checkout", ax5: true) { app in
            tocar(app.buttons["fazer-checkout"])
            XCTAssertTrue(app.descendants(matching: .any)["checkout-situacao"].waitForExistence(timeout: Espera.aparecer))
        }
    }

    // MARK: Turno cancelado e avaliação no Meu turno

    private func turnoCancelado(ax5: Bool) {
        let app = iniciar(cenario: "turno-cancelado", ax5: ax5)
        abrirMeuTurno(app)
        XCTAssertTrue(app.staticTexts["estado-do-turno"].waitForExistence(timeout: Espera.aparecer))
        capturar("r3-meu-turno-cancelado-\(sufixo(ax5))")
    }

    func testTurnoCanceladoNoTamanhoPadrao() { turnoCancelado(ax5: false) }
    func testTurnoCanceladoEmAX5() { turnoCancelado(ax5: true) }

    private func cartaoDeAvaliacao(ax5: Bool) {
        let app = iniciar(cenario: "turno-encerrado", ax5: ax5)
        abrirMeuTurno(app)
        let cartao = app.descendants(matching: .any)["cartao-avaliacao-turno"]
        XCTAssertTrue(cartao.waitForExistence(timeout: Espera.aparecer))
        for _ in 0..<6 where !cartao.isHittable { app.swipeUp() }
        capturar("r3-meu-turno-avaliacao-\(sufixo(ax5))")
    }

    func testCartaoDeAvaliacaoNoTamanhoPadrao() { cartaoDeAvaliacao(ax5: false) }
    func testCartaoDeAvaliacaoEmAX5() { cartaoDeAvaliacao(ax5: true) }
}
