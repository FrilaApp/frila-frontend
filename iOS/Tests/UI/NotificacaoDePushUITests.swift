import XCTest

/// O toque na notificação (#8) pelo caminho do sistema: a notificação aparece, a pessoa toca, e o
/// `AppDelegate` entrega o payload ao roteador único. O esquema Local não fala com o APNs, então
/// `-FRILA_PUSH_NOTIFICACAO_EM` agenda uma notificação local com o payload do push: daí em diante
/// o sistema e o app fazem o mesmo que fazem com o push de verdade.
@MainActor
final class NotificacaoDePushUITests: XCTestCase {
    /// `vaga.json` do dublê.
    private let vagaID = "40000000-0000-0000-0000-000000000001"
    private let sistema = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUp() {
        continueAfterFailure = false
    }

    /// Abre o app com a permissão de verdade e a notificação agendada para dali a `segundos`.
    private func abrir(notificacaoEm segundos: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_SCENARIO", "success", "-FRILA_PERMISSAO_PUSH", "sistema",
            "-FRILA_PUSH", "vaga", "-FRILA_PUSH_ID", vagaID, "-FRILA_PUSH_NOTIFICACAO_EM", "\(segundos)",
        ]
        app.launch()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 15))
        permitirNotificacoes(app)
        return app
    }

    /// No simulador novo o sistema ainda não perguntou: a pessoa passa pela explicação e aceita o
    /// pedido. Depois disso a permissão fica concedida, e o aviso não aparece mais.
    private func permitirNotificacoes(_ app: XCUIApplication) {
        let explicar = app.buttons["explicar-notificacoes"]
        guard explicar.waitForExistence(timeout: 3) else { return }
        explicar.tap()
        XCTAssertTrue(app.buttons["ativar-notificacoes"].waitForExistence(timeout: 5))
        app.buttons["ativar-notificacoes"].tap()
        let permitir = sistema.buttons.matching(NSPredicate(format: "label IN %@", ["Permitir", "Allow"])).firstMatch
        XCTAssertTrue(permitir.waitForExistence(timeout: 10), "o pedido do sistema vem depois da explicação")
        permitir.tap()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
    }

    private func tocarNaNotificacao() {
        let notificacao = sistema.staticTexts["Aviso simulado: vaga"].firstMatch
        XCTAssertTrue(notificacao.waitForExistence(timeout: 30), "a notificação aparece")
        notificacao.tap()
    }

    private func conferirDetalheDaVaga(_ app: XCUIApplication) {
        XCTAssertTrue(app.descendants(matching: .any)["tela-detalhe-vaga"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["candidatar"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["resultado-confirmada"].exists, "o toque abre o detalhe, nunca aceita sozinho")
    }

    func testToqueComOAppAbertoAbreODestino() {
        let app = abrir(notificacaoEm: 6)

        tocarNaNotificacao()
        conferirDetalheDaVaga(app)
    }

    func testToqueComOAppEmSegundoPlanoAbreODestino() {
        let app = abrir(notificacaoEm: 9)

        XCUIDevice.shared.press(.home)
        tocarNaNotificacao()
        conferirDetalheDaVaga(app)
    }

    func testToqueComOAppFechadoAbreODestino() {
        let app = abrir(notificacaoEm: 15)

        // Dá tempo de o aparelho ser registrado para a conta e a notificação ser agendada.
        sleep(2)
        app.terminate()
        tocarNaNotificacao()
        // O sistema abre o app sem argumento nenhum: quem leva ao destino é o toque.
        conferirDetalheDaVaga(app)
    }
}
