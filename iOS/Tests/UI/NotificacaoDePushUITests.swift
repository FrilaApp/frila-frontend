import XCTest

/// O toque na notificação (#8) pelo caminho do sistema: a notificação aparece, a pessoa toca, e o
/// `AppDelegate` entrega o payload ao roteador único. O esquema Local não fala com o APNs, então
/// `-FRILA_PUSH_NOTIFICACAO_EM` agenda uma notificação local com o payload do push: daí em diante
/// o sistema e o app fazem o mesmo que fazem com o push de verdade.
@MainActor
final class NotificacaoDePushUITests: XCTestCase {
    /// `vaga.json` do dublê.
    private let vagaID = "40000000-0000-0000-0000-000000000001"
    /// `turnos.json` do dublê / cenário de turno confirmado.
    private let turnoID = "23000000-0000-0000-0000-000000000001"
    private let sistema = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUp() {
        continueAfterFailure = false
    }

    /// Abre o app com a permissão de verdade e a notificação agendada para dali a `segundos`.
    private func abrir(cenario: String = "success", push tipo: String = "vaga", id: String? = nil, notificacaoEm segundos: Int) -> XCUIApplication {
        let idUsado = id ?? (tipo == "vaga" ? vagaID : turnoID)
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_SCENARIO", cenario, "-FRILA_PERMISSAO_PUSH", "sistema",
            "-FRILA_PUSH", tipo, "-FRILA_PUSH_ID", idUsado, "-FRILA_PUSH_NOTIFICACAO_EM", "\(segundos)",
        ]
        app.launch()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 15))
        permitirNotificacoes(app)
        XCTAssertTrue(app.descendants(matching: .any)["push-simulado-agendado"].waitForExistence(timeout: 10), "a notificação deve ser agendada no sistema")
        return app
    }

    /// No simulador novo o sistema ainda não perguntou: a pessoa passa pela explicação e aceita o
    /// pedido. Depois disso a permissão fica concedida, e o aviso não aparece mais.
    private func permitirNotificacoes(_ app: XCUIApplication) {
        let explicar = app.buttons["explicar-notificacoes"]
        guard explicar.waitForExistence(timeout: 1) else { return }
        explicar.tap()
        XCTAssertTrue(app.buttons["ativar-notificacoes"].waitForExistence(timeout: 5), "o botão ativar notificações deve aparecer")
        app.buttons["ativar-notificacoes"].tap()
        let permitir = sistema.buttons.matching(NSPredicate(format: "label IN %@", ["Permitir", "Allow"])).firstMatch
        XCTAssertTrue(permitir.waitForExistence(timeout: 10), "o pedido do sistema vem depois da explicação")
        permitir.tap()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10), "a barra de navegação deve reaparecer após a permissão")
    }

    private func tocarNaNotificacao(tipo: String = "vaga") {
        let notificacao = sistema.staticTexts["Aviso simulado: \(tipo)"].firstMatch
        if !notificacao.waitForExistence(timeout: 15) {
            // Se o banner expirou para a central de notificações, arrasta da borda superior para baixo
            abrirCentralDeNotificacoes()
        }
        XCTAssertTrue(notificacao.waitForExistence(timeout: 15), "a notificação de \(tipo) aparece")
        notificacao.tap()
    }

    private func abrirCentralDeNotificacoes() {
        let topo = sistema.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.01))
        let meio = sistema.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        topo.press(forDuration: 0.1, thenDragTo: meio)
    }

    private func conferirDetalheDaVaga(_ app: XCUIApplication) {
        XCTAssertTrue(app.descendants(matching: .any)["tela-detalhe-vaga"].waitForExistence(timeout: 20), "o detalhe da vaga deve abrir após o toque na notificação")
        XCTAssertTrue(app.buttons["candidatar"].waitForExistence(timeout: 10), "o botão candidatar deve estar presente")
        XCTAssertFalse(app.descendants(matching: .any)["resultado-confirmada"].exists, "o toque abre o detalhe, nunca aceita sozinho")
    }

    func testToqueComOAppAbertoAbreODestino() {
        let app = abrir(notificacaoEm: 6)

        tocarNaNotificacao()
        conferirDetalheDaVaga(app)
    }

    func testToqueComOAppAbertoEmNotificacaoDeTurnoAbreMeuTurno() {
        let app = abrir(cenario: "turno-confirmado-perto", push: "confirmacao", id: turnoID, notificacaoEm: 6)

        tocarNaNotificacao(tipo: "confirmacao")
        XCTAssertTrue(app.descendants(matching: .any)["tela-meu-turno"].waitForExistence(timeout: 20), "o toque na notificação de turno abre Meu turno")
        let estadoTurno = app.descendants(matching: .any)["estado-do-turno"]
        XCTAssertTrue(estadoTurno.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Você está confirmado"].exists)
        XCTAssertTrue(app.buttons["botao-ajuda-turno"].waitForExistence(timeout: 5))
    }

    func testToqueComOAppEmSegundoPlanoAbreODestino() {
        let app = abrir(notificacaoEm: 14)

        XCUIDevice.shared.press(.home)
        tocarNaNotificacao()
        conferirDetalheDaVaga(app)
    }

    func testToqueComOAppFechadoAbreODestino() {
        let app = abrir(notificacaoEm: 6)

        // Aguarda a confirmação de que a notificação foi agendada no sistema antes de fechar o app.
        XCTAssertTrue(app.descendants(matching: .any)["push-simulado-agendado"].waitForExistence(timeout: 10), "a notificação deve ser agendada antes de fechar o app")
        app.terminate()
        tocarNaNotificacao()
        // O sistema abre o app sem argumento nenhum: quem leva ao destino é o toque.
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "o app deve abrir em resposta ao toque")
        conferirDetalheDaVaga(app)
    }
}
