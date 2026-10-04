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
        let botaoHabilitado = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: botaoExcluir
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [botaoHabilitado], timeout: 5), .completed,
            "Botão de exclusão definitiva deve ser habilitado após confirmar as consequências"
        )
        if !botaoExcluir.isHittable {
            app.swipeUp()
        }
        botaoExcluir.tap()

        // 6. Confirma no diálogo de segurança
        confirmarExclusaoNoDialogo(no: app)

        // 7. A exclusão é concluída e o app volta para a tela de entrada
        let campoEmail = app.textFields["entrada-email"]
        XCTAssertTrue(campoEmail.waitForExistence(timeout: 15))

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

    func testContratanteComTurnosFuturosVisualizaVinculosEListaIncompletaNaExclusao() {
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

        // 4. Verifica que o turno futuro confirmado do estabelecimento é listado como vínculo
        let itemTurno = app.descendants(matching: .any)["item-turno-futuro-82000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(itemTurno.waitForExistence(timeout: 5), "Turno futuro do contratante deve ser exibido")
        XCTAssertFalse(app.staticTexts["texto-sem-turnos-futuros"].exists)
        XCTAssertTrue(app.staticTexts["Turnos futuros vinculados à conta"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["aviso-lista-turnos-exclusao"].exists)
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
        let botaoHabilitado = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: botaoConfirmarDefinitivo
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [botaoHabilitado], timeout: 5), .completed,
            "Botão de exclusão definitiva deve ser habilitado após confirmar as consequências"
        )
        if !botaoConfirmarDefinitivo.isHittable {
            app.swipeUp()
        }
        botaoConfirmarDefinitivo.tap()

        confirmarExclusaoNoDialogo(no: app)

        // 5. App volta para a tela de entrada
        let campoEmail = app.textFields["entrada-email"]
        XCTAssertTrue(campoEmail.waitForExistence(timeout: 15), "Deve retornar à tela de entrada após exclusão")
    }

    /// Em AX5 o `confirmationDialog` do sistema empurrava o Cancelar para fora da tela, numa ação
    /// irreversível (QA de 04/10, achado 1). A confirmação tem de mostrar os dois botões sem rolar.
    func testConfirmacaoEmAX5MostraCancelarTocavelECancelarNaoExclui() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()

        let botaoPerfil = app.buttons["abrir-meu-perfil"]
        XCTAssertTrue(botaoPerfil.waitForExistence(timeout: 10))
        botaoPerfil.tap()

        let irParaExclusao = app.buttons["perfil-excluir-conta"]
        XCTAssertTrue(irParaExclusao.waitForExistence(timeout: 5))
        rolarAte(irParaExclusao, em: app)
        irParaExclusao.tap()
        XCTAssertTrue(app.descendants(matching: .any)["tela-exclusao-de-conta"].waitForExistence(timeout: 5))

        let toggle = app.switches["toggle-confirmar-consequencias"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        rolarAte(toggle, em: app)
        toggle.tap()

        let botaoExcluir = app.buttons["botao-excluir-conta-definitivo"]
        let habilitado = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: botaoExcluir)
        XCTAssertEqual(XCTWaiter.wait(for: [habilitado], timeout: 5), .completed)
        rolarAte(botaoExcluir, em: app)
        botaoExcluir.tap()

        let cancelar = app.buttons["botao-cancelar-exclusao-dialogo"]
        let confirmar = app.buttons["botao-confirmar-exclusao-dialogo"]
        XCTAssertTrue(cancelar.waitForExistence(timeout: 5), "A confirmação deve ter o Cancelar")
        let anexo = XCTAttachment(screenshot: app.screenshot())
        anexo.name = "ConfirmacaoDeExclusaoEmAX5"
        anexo.lifetime = .keepAlways
        add(anexo)
        XCTAssertTrue(cancelar.isHittable, "Em AX5, o Cancelar fica tocável sem rolar")
        XCTAssertTrue(confirmar.isHittable, "Em AX5, o Confirmar fica tocável sem rolar")

        cancelar.tap()
        let fechou = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: cancelar)
        XCTAssertEqual(XCTWaiter.wait(for: [fechou], timeout: 5), .completed, "O Cancelar fecha a confirmação")
        XCTAssertTrue(app.descendants(matching: .any)["tela-exclusao-de-conta"].exists, "Cancelar não exclui: a tela continua")
        XCTAssertFalse(app.textFields["entrada-email"].exists, "Cancelar não volta para a entrada")
    }

    private func rolarAte(_ elemento: XCUIElement, em app: XCUIApplication) {
        for _ in 0..<10 where !elemento.isHittable { app.swipeUp() }
        XCTAssertTrue(elemento.isHittable, "\(elemento) não ficou tocável")
    }

    private func confirmarExclusaoNoDialogo(no app: XCUIApplication) {
        let botaoConfirmar = app.buttons.matching(identifier: "botao-confirmar-exclusao-dialogo").firstMatch
        XCTAssertTrue(botaoConfirmar.waitForExistence(timeout: 5), "Diálogo de confirmação deve aparecer")

        let tocavel = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"),
            object: botaoConfirmar
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [tocavel], timeout: 5), .completed,
            "Botão de confirmação de exclusão deve ficar tocável no diálogo"
        )

        botaoConfirmar.tap()

        let sumiu = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: botaoConfirmar
        )
        if XCTWaiter.wait(for: [sumiu], timeout: 3) != .completed {
            XCTContext.runActivity(named: "Repetir toque no botão de confirmação de exclusão") { _ in
                let anexo = XCTAttachment(string: "O diálogo de confirmação não sumiu em até 3 s após o primeiro toque; acionando segundo toque.")
                anexo.name = "RepeticaoDoToqueDeConfirmacaoDeExclusao"
                anexo.lifetime = .keepAlways
                add(anexo)
            }
            if botaoConfirmar.exists && botaoConfirmar.isHittable {
                botaoConfirmar.tap()
            }
            let sumiuAposSegundoToque = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"),
                object: botaoConfirmar
            )
            XCTAssertEqual(
                XCTWaiter.wait(for: [sumiuAposSegundoToque], timeout: 3), .completed,
                "Defeito do app: diálogo de confirmação de exclusão não fechou após o segundo toque"
            )
        }
    }
}

