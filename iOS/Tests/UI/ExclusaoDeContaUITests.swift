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

    func testContratanteComEstabelecimentoChegaAExclusaoDeConta() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "contratante"]
        app.launch()

        // 1. O app abre no fluxo do contratante e apresenta o botão de perfil do estabelecimento
        let botaoPerfil = app.buttons["abrir-perfil-estabelecimento"]
        XCTAssertTrue(botaoPerfil.waitForExistence(timeout: 10), "Contratante existente deve ver o botão de perfil")
        botaoPerfil.tap()

        // 2. Na tela de perfil do estabelecimento, aciona "Excluir conta"
        let botaoExcluir = app.buttons["estabelecimento-excluir-conta"]
        XCTAssertTrue(botaoExcluir.waitForExistence(timeout: 5), "Botão de excluir conta do estabelecimento deve estar visível")
        botaoExcluir.tap()

        // 3. Chega à tela de exclusão de conta
        let telaExclusao = app.descendants(matching: .any)["tela-exclusao-de-conta"]
        XCTAssertTrue(telaExclusao.waitForExistence(timeout: 5), "Deve chegar à tela de exclusão de conta")
    }

    func testContratanteComTurnosFuturosVisualizaTurnosCanceladosNaExclusao() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "painel-contratante"]
        app.launch()

        // 1. O app abre no fluxo do contratante e apresenta o botão de perfil do estabelecimento
        let botaoPerfil = app.buttons["abrir-perfil-estabelecimento"]
        XCTAssertTrue(botaoPerfil.waitForExistence(timeout: 10), "Contratante existente deve ver o botão de perfil")
        botaoPerfil.tap()

        // 2. Na tela de perfil do estabelecimento, aciona "Excluir conta"
        let botaoExcluir = app.buttons["estabelecimento-excluir-conta"]
        XCTAssertTrue(botaoExcluir.waitForExistence(timeout: 5), "Botão de excluir conta do estabelecimento deve estar visível")
        botaoExcluir.tap()

        // 3. Chega à tela de exclusão de conta
        let telaExclusao = app.descendants(matching: .any)["tela-exclusao-de-conta"]
        XCTAssertTrue(telaExclusao.waitForExistence(timeout: 5), "Deve chegar à tela de exclusão de conta")

        // 4. Verifica que o turno futuro confirmado do estabelecimento é listado para cancelamento
        let itemTurno = app.descendants(matching: .any)["item-turno-futuro-82000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(itemTurno.waitForExistence(timeout: 5), "Turno futuro do contratante deve ser exibido")
        XCTAssertFalse(app.staticTexts["texto-sem-turnos-futuros"].exists)
    }

    func testContratanteSemEstabelecimentoTemAcessoAExclusaoDeConta() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "contratante-sem-estabelecimento"]
        app.launch()

        // 1. Contratante sem estabelecimento vê o botão "Excluir conta" na barra superior junto com "Sair"
        let botaoExcluirConta = app.buttons["contratante-sem-estabelecimento-excluir-conta"]
        XCTAssertTrue(botaoExcluirConta.waitForExistence(timeout: 10), "Contratante sem estabelecimento deve ter acesso a Excluir conta")

        let botaoSair = app.buttons["sair-fluxo-contratante"]
        XCTAssertTrue(botaoSair.exists, "Botão Sair deve continuar visível")

        // 2. Aciona o botão de exclusão
        botaoExcluirConta.tap()

        // 3. Verifica que a tela de exclusão abre em folha
        let telaExclusao = app.descendants(matching: .any)["tela-exclusao-de-conta"]
        XCTAssertTrue(telaExclusao.waitForExistence(timeout: 5), "Tela de exclusão de conta deve ser apresentada")

        // 4. Confirma consequências e executa a exclusão
        let toggle = app.switches["toggle-confirmar-consequencias"]
        if toggle.waitForExistence(timeout: 5) {
            toggle.tap()
        } else {
            app.descendants(matching: .any)["toggle-confirmar-consequencias"].firstMatch.tap()
        }

        let botaoConfirmarDefinitivo = app.buttons["botao-excluir-conta-definitivo"]
        XCTAssertTrue(botaoConfirmarDefinitivo.waitForExistence(timeout: 5))
        botaoConfirmarDefinitivo.tap()

        let botaoConfirmarDialogo = app.buttons.matching(identifier: "botao-confirmar-exclusao-dialogo").firstMatch
        if botaoConfirmarDialogo.waitForExistence(timeout: 5) {
            botaoConfirmarDialogo.tap()
        } else {
            app.buttons["Sim, excluir minha conta"].firstMatch.tap()
        }

        // 5. App volta para a tela de entrada
        let campoEmail = app.textFields["entrada-email"]
        XCTAssertTrue(campoEmail.waitForExistence(timeout: 10), "Deve retornar à tela de entrada após exclusão")
    }
}

