import XCTest

@MainActor
final class ExclusaoDeContaUITests: XCTestCase {
    func testExclusaoDeContaPeloPerfilProfissionalVoltaParaEntrada() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success"]
        app.launch()

        // 1. Abre a lista de vagas e navega para o perfil
        let botaoPerfil = app.buttons["abrir-meu-perfil"]
        XCTAssertTrue(botaoPerfil.waitForExistence(timeout: 10))
        botaoPerfil.tap()

        // 2. No perfil, aciona o item "Excluir conta"
        let botaoIrParaExclusao = app.buttons["perfil-excluir-conta"]
        XCTAssertTrue(botaoIrParaExclusao.waitForExistence(timeout: 5))
        botaoIrParaExclusao.tap()

        // 3. Verifica a tela de exclusão de conta e suas consequências
        let telaExclusao = app.descendants(matching: .any)["tela-exclusao-de-conta"]
        XCTAssertTrue(telaExclusao.waitForExistence(timeout: 5))

        let aviso = app.descendants(matching: .any)["aviso-consequencias-exclusao"]
        XCTAssertTrue(aviso.waitForExistence(timeout: 5))

        let capturaExclusao = XCTAttachment(screenshot: app.screenshot())
        capturaExclusao.name = "TelaExclusaoDeConta"
        capturaExclusao.lifetime = .keepAlways
        add(capturaExclusao)

        // 4. Marca a confirmação explícita das consequências
        let toggle = app.switches["toggle-confirmar-consequencias"]
        if toggle.waitForExistence(timeout: 5) {
            toggle.tap()
        } else {
            app.descendants(matching: .any)["toggle-confirmar-consequencias"].firstMatch.tap()
        }

        // 5. Aciona o botão de exclusão definitiva
        let botaoExcluir = app.buttons["botao-excluir-conta-definitivo"]
        XCTAssertTrue(botaoExcluir.waitForExistence(timeout: 5))
        botaoExcluir.tap()

        // 6. Confirma no diálogo de segurança
        let botaoConfirmar = app.buttons.matching(identifier: "botao-confirmar-exclusao-dialogo").firstMatch
        if botaoConfirmar.waitForExistence(timeout: 5) {
            botaoConfirmar.tap()
        } else {
            app.buttons["Sim, excluir minha conta"].firstMatch.tap()
        }

        // 7. A exclusão é concluída e o app volta para a tela de entrada
        let campoEmail = app.textFields["entrada-email"]
        XCTAssertTrue(campoEmail.waitForExistence(timeout: 10))

        let capturaEntrada = XCTAttachment(screenshot: app.screenshot())
        capturaEntrada.name = "VoltaParaEntrada"
        capturaEntrada.lifetime = .keepAlways
        add(capturaEntrada)
    }
}
