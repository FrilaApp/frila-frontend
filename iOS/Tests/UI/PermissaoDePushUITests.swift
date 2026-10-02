import XCTest

/// A permissão de notificação (#8) no dublê: o esquema Local simula a permissão do sistema, e
/// `-FRILA_PERMISSAO_PUSH` escolhe o estado em que o app abre.
@MainActor
final class PermissaoDePushUITests: XCTestCase {
    private func abrir(_ argumentos: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = argumentos
        app.launch()
        return app
    }

    func testPermissaoNegadaMostraOAvisoFixoEmVagasComOCaminhoParaOsAjustes() {
        let app = abrir(["-FRILA_SCENARIO", "success", "-FRILA_PERMISSAO_PUSH", "negada"])

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["As notificações estão desativadas. Você não recebe o aviso de vaga nova nem os lembretes dos seus turnos."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["abrir-ajustes-de-notificacao"].isHittable)
        XCTAssertFalse(app.buttons["explicar-notificacoes"].exists)
    }

    func testPermissaoNegadaMostraOAvisoFixoEmMinhasVagas() {
        let app = abrir(["-FRILA_SCENARIO", "checkin-manual-pendente", "-FRILA_PERMISSAO_PUSH", "negada"])

        XCTAssertTrue(app.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["As notificações estão desativadas. Você não recebe o aviso de quem aceitou a vaga, de check-in nem de atraso."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["abrir-ajustes-de-notificacao"].isHittable)
    }

    func testPermissaoConcedidaNaoMostraAvisoNenhum() {
        let app = abrir(["-FRILA_SCENARIO", "success", "-FRILA_PERMISSAO_PUSH", "concedida"])

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["abrir-ajustes-de-notificacao"].exists)
        XCTAssertFalse(app.buttons["explicar-notificacoes"].exists)
    }

    func testExplicacaoVemAntesDoPedidoEAtivarTiraOAviso() {
        let app = abrir(["-FRILA_SCENARIO", "success", "-FRILA_PERMISSAO_PUSH", "nao-pedida"])

        let explicar = app.buttons["explicar-notificacoes"]
        XCTAssertTrue(explicar.waitForExistence(timeout: 15))
        XCTAssertFalse(app.descendants(matching: .any)["explicacao-do-push"].exists, "a explicação não aparece sozinha na abertura")
        explicar.tap()

        XCTAssertTrue(app.staticTexts["Ative as notificações"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Vaga nova na sua função e na sua região"].exists)
        app.buttons["ativar-notificacoes"].tap()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 5))
        XCTAssertFalse(explicar.waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["abrir-ajustes-de-notificacao"].exists)
    }

    func testAgoraNaoFechaAExplicacaoEMantemOAviso() {
        let app = abrir(["-FRILA_SCENARIO", "success", "-FRILA_PERMISSAO_PUSH", "nao-pedida"])

        let explicar = app.buttons["explicar-notificacoes"]
        XCTAssertTrue(explicar.waitForExistence(timeout: 15))
        explicar.tap()
        XCTAssertTrue(app.buttons["notificacoes-agora-nao"].waitForExistence(timeout: 5))
        app.buttons["notificacoes-agora-nao"].tap()

        XCTAssertTrue(explicar.waitForExistence(timeout: 5))
        XCTAssertTrue(explicar.isHittable)

        // O aviso fixo reabre a explicação na mesma sessão:
        explicar.tap()
        XCTAssertTrue(app.buttons["notificacoes-agora-nao"].waitForExistence(timeout: 5))
        app.buttons["notificacoes-agora-nao"].tap()
        XCTAssertTrue(explicar.waitForExistence(timeout: 5))
    }

    func testRecusarOPedidoDoSistemaLevaAoAvisoDosAjustes() {
        let app = abrir(["-FRILA_SCENARIO", "success", "-FRILA_PERMISSAO_PUSH", "nao-pedida", "-FRILA_PERMISSAO_PUSH_RESPOSTA", "negada"])

        let explicar = app.buttons["explicar-notificacoes"]
        XCTAssertTrue(explicar.waitForExistence(timeout: 15))
        explicar.tap()
        XCTAssertTrue(app.buttons["ativar-notificacoes"].waitForExistence(timeout: 5))
        app.buttons["ativar-notificacoes"].tap()

        XCTAssertTrue(app.buttons["abrir-ajustes-de-notificacao"].waitForExistence(timeout: 5))
        XCTAssertFalse(explicar.exists)
    }

    func testSalvarFuncoesEHorariosMostraAExplicacaoAoProfissional() {
        let app = abrir(["-FRILA_SCENARIO", "success", "-FRILA_PERMISSAO_PUSH", "nao-pedida"])

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 15))
        app.buttons["abrir-meu-perfil"].tap()
        let funcoesEHorarios = app.descendants(matching: .any)["perfil-funcoes-horarios"]
        XCTAssertTrue(funcoesEHorarios.waitForExistence(timeout: 10))
        funcoesEHorarios.tap()
        let salvar = app.buttons["botao-salvar-perfil"]
        XCTAssertTrue(salvar.waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["explicacao-do-push"].exists)
        salvar.tap()

        XCTAssertTrue(app.staticTexts["Ative as notificações"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["ativar-notificacoes"].exists)
    }

    func testPublicarAPrimeiraVagaMostraAExplicacaoAoContratante() {
        // A conta de contratante ainda sem estabelecimento chega à publicação pelo cadastro, que
        // `-FRILA_CADASTRO_UI_TEST` já traz preenchido. O mesmo argumento preenche a função, o
        // valor e o responsável da vaga: aqui só falta publicar.
        let app = abrir(["-FRILA_SCENARIO", "contratante-sem-estabelecimento", "-FRILA_CADASTRO_UI_TEST", "-FRILA_PERMISSAO_PUSH", "nao-pedida"])

        XCTAssertTrue(app.buttons["continuar-cadastro"].waitForExistence(timeout: 15))
        app.buttons["continuar-cadastro"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["publicar-vaga-formulario"].waitForExistence(timeout: 10))

        let publicar = app.buttons["publicar-vaga-botao"]
        XCTAssertTrue(publicar.waitForExistence(timeout: 10))
        app.swipeUp()
        XCTAssertFalse(app.descendants(matching: .any)["explicacao-do-push"].exists)
        publicar.tap()

        XCTAssertTrue(app.staticTexts["Ative as notificações"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Confirmação de quem vai trabalhar"].exists)
    }
}
