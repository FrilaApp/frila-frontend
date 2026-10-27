import XCTest

@MainActor
final class ExclusaoDeContaUITests: XCTestCase {
    func testExclusaoDeContaPeloPerfilProfissionalVoltaParaEntrada() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success"]
        app.launch()

        // 1. Abre a lista de vagas e navega para a aba Conta
        let abaConta = app.tabBars.buttons["Conta"]
        XCTAssertTrue(abaConta.waitForExistence(timeout: 10))
        abaConta.tap()

        // 2. No perfil, aciona o item "Excluir conta"
        let botaoIrParaExclusao = app.buttons["perfil-excluir-conta"]
        XCTAssertTrue(botaoIrParaExclusao.waitForExistence(timeout: Espera.aparecer))
        botaoIrParaExclusao.tap()

        // 3. Verifica a tela de exclusão de conta e suas consequências
        let telaExclusao = app.descendants(matching: .any)["tela-exclusao-de-conta"]
        XCTAssertTrue(telaExclusao.waitForExistence(timeout: Espera.aparecer))

        let aviso = app.descendants(matching: .any)["aviso-consequencias-exclusao"]
        XCTAssertTrue(aviso.waitForExistence(timeout: Espera.aparecer))

        let capturaExclusao = XCTAttachment(screenshot: app.screenshot())
        capturaExclusao.name = "TelaExclusaoDeConta"
        capturaExclusao.lifetime = .keepAlways
        add(capturaExclusao)

        // 4. Valida que o botão de exclusão definitiva permanece desabilitado antes do consentimento
        let botaoExcluir = app.buttons["botao-excluir-conta-definitivo"]
        XCTAssertTrue(botaoExcluir.waitForExistence(timeout: Espera.aparecer))
        XCTAssertFalse(botaoExcluir.isEnabled, "Botão de exclusão definitiva deve permanecer desabilitado antes de confirmar as consequências")

        // 5. Marca a confirmação explícita das consequências
        let toggle = app.switches["toggle-confirmar-consequencias"]
        if toggle.waitForExistence(timeout: 5) {
            toggle.tap()
        } else {
            app.descendants(matching: .any)["toggle-confirmar-consequencias"].firstMatch.tap()
        }

        // 6. Aciona o botão de exclusão definitiva após habilitado
        let botaoHabilitado = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: botaoExcluir
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [botaoHabilitado], timeout: Espera.aparecer), .completed,
            "Botão de exclusão definitiva deve ser habilitado após confirmar as consequências"
        )
        if !botaoExcluir.isHittable {
            app.swipeUp()
        }
        botaoExcluir.tap()

        // 7. Confirma no diálogo de segurança
        confirmarExclusaoNoDialogo(no: app)

        // 8. A exclusão é concluída e o app volta para a tela de entrada
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

        // 1. O app abre no fluxo do contratante e navega para a aba Conta
        let abaConta = app.tabBars.buttons["Conta"]
        XCTAssertTrue(abaConta.waitForExistence(timeout: 10), "Contratante existente deve ver a aba Conta")
        abaConta.tap()

        // 2. Na tela de perfil do estabelecimento, aciona "Excluir conta"
        let botaoExcluir = app.buttons["estabelecimento-excluir-conta"]
        XCTAssertTrue(botaoExcluir.waitForExistence(timeout: Espera.aparecer), "Botão de excluir conta do estabelecimento deve estar visível")
        botaoExcluir.tap()

        // 3. Chega à tela de exclusão de conta
        let telaExclusao = app.descendants(matching: .any)["tela-exclusao-de-conta"]
        XCTAssertTrue(telaExclusao.waitForExistence(timeout: Espera.aparecer), "Deve chegar à tela de exclusão de conta")
    }

    /// Cartão ABN4rvmT (Missão 6): Contratante com estabelecimento e sem turnos futuros
    /// acessa a exclusão no menu principal (sem submenu) e conclui a exclusão após consentimento.
    func testContratanteComEstabelecimentoExcluiContaEVoltaParaEntrada() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "contratante"]
        app.launch()

        // 1. Acesso direto à aba Conta a partir do fluxo principal
        let abaConta = app.tabBars.buttons["Conta"]
        XCTAssertTrue(abaConta.waitForExistence(timeout: 10), "Contratante existente deve ver a aba Conta")
        abaConta.tap()

        // 2. Botão de exclusão visível no menu principal (sem aninhamento em submenus)
        let botaoExcluir = app.buttons["estabelecimento-excluir-conta"]
        XCTAssertTrue(botaoExcluir.waitForExistence(timeout: Espera.aparecer), "Botão de excluir conta do estabelecimento deve estar no menu principal")
        botaoExcluir.tap()

        // 3. Tela de exclusão exibida com consequências e indicação de ausência de turnos futuros
        let telaExclusao = app.descendants(matching: .any)["tela-exclusao-de-conta"]
        XCTAssertTrue(telaExclusao.waitForExistence(timeout: Espera.aparecer), "Deve apresentar a tela de exclusão de conta")
        XCTAssertTrue(app.descendants(matching: .any)["aviso-consequencias-exclusao"].waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(app.staticTexts["texto-sem-turnos-futuros"].waitForExistence(timeout: Espera.aparecer))

        // 4. Botão de exclusão definitiva permanece desabilitado antes do consentimento
        let botaoConfirmarDefinitivo = app.buttons["botao-excluir-conta-definitivo"]
        XCTAssertTrue(botaoConfirmarDefinitivo.waitForExistence(timeout: Espera.aparecer))
        XCTAssertFalse(botaoConfirmarDefinitivo.isEnabled, "Botão definitivo deve estar desabilitado antes de alternar o toggle de consequências")

        // 5. Aciona o interruptor de consentimento das consequências
        let toggle = app.switches["toggle-confirmar-consequencias"]
        if toggle.waitForExistence(timeout: 5) {
            toggle.tap()
        } else {
            app.descendants(matching: .any)["toggle-confirmar-consequencias"].firstMatch.tap()
        }

        // 6. Botão é habilitado e acionado
        let habilitado = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: botaoConfirmarDefinitivo)
        XCTAssertEqual(XCTWaiter.wait(for: [habilitado], timeout: Espera.aparecer), .completed)
        if !botaoConfirmarDefinitivo.isHittable {
            app.swipeUp()
        }
        botaoConfirmarDefinitivo.tap()

        // 7. Confirmação no diálogo destrutivo nativo/segurança
        confirmarExclusaoNoDialogo(no: app)

        // 8. Sessão limpa e app redirecionado para a tela de entrada
        let campoEmail = app.textFields["entrada-email"]
        XCTAssertTrue(campoEmail.waitForExistence(timeout: 15), "Deve retornar à tela de entrada após exclusão do contratante")
    }

    /// Cartão ABN4rvmT (Missão 6): Contratante com turnos ativos vinculados visualiza as consequências,
    /// a listagem de turnos, e ao confirmar a exclusão tem a sessão limpa e volta para a entrada.
    func testContratanteComTurnosFuturosExcluiContaEVoltaParaEntrada() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "painel-contratante"]
        app.launch()

        // 1. Acesso direto à aba Conta a partir do painel
        let abaConta = app.tabBars.buttons["Conta"]
        XCTAssertTrue(abaConta.waitForExistence(timeout: 10), "Contratante existente deve ver a aba Conta")
        abaConta.tap()

        // 2. Botão de exclusão no menu principal
        let botaoExcluir = app.buttons["estabelecimento-excluir-conta"]
        XCTAssertTrue(botaoExcluir.waitForExistence(timeout: Espera.aparecer))
        botaoExcluir.tap()

        // 3. Tela de exclusão com vínculos de turnos futuros listados
        let telaExclusao = app.descendants(matching: .any)["tela-exclusao-de-conta"]
        XCTAssertTrue(telaExclusao.waitForExistence(timeout: Espera.aparecer))
        let itemTurno = app.descendants(matching: .any)["item-turno-futuro-82000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(itemTurno.waitForExistence(timeout: Espera.aparecer), "Turno futuro vinculado à conta deve ser exibido")

        // 4. Botão definitivo permanece desabilitado antes do consentimento
        let botaoConfirmarDefinitivo = app.buttons["botao-excluir-conta-definitivo"]
        XCTAssertTrue(botaoConfirmarDefinitivo.waitForExistence(timeout: Espera.aparecer))
        XCTAssertFalse(botaoConfirmarDefinitivo.isEnabled, "Botão definitivo deve estar desabilitado antes de alternar o toggle de consequências")

        // 5. Aciona o toggle de confirmação de consequências
        let toggle = app.switches["toggle-confirmar-consequencias"]
        if toggle.waitForExistence(timeout: 5) {
            toggle.tap()
        } else {
            app.descendants(matching: .any)["toggle-confirmar-consequencias"].firstMatch.tap()
        }

        // 6. Botão de exclusão definitivo habilitado
        let habilitado = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: botaoConfirmarDefinitivo)
        XCTAssertEqual(XCTWaiter.wait(for: [habilitado], timeout: Espera.aparecer), .completed)
        if !botaoConfirmarDefinitivo.isHittable {
            app.swipeUp()
        }
        botaoConfirmarDefinitivo.tap()

        // 7. Confirmação no diálogo
        confirmarExclusaoNoDialogo(no: app)

        // 8. Retorno à tela de entrada
        let campoEmail = app.textFields["entrada-email"]
        XCTAssertTrue(campoEmail.waitForExistence(timeout: 15), "Deve retornar à tela de entrada após exclusão do contratante com turnos")
    }

    func testContratanteComTurnosFuturosVisualizaVinculosEListaIncompletaNaExclusao() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "painel-contratante"]
        app.launch()

        // 1. O app abre no fluxo do contratante e navega para a aba Conta
        let abaConta = app.tabBars.buttons["Conta"]
        XCTAssertTrue(abaConta.waitForExistence(timeout: 10), "Contratante existente deve ver a aba Conta")
        abaConta.tap()

        // 2. Na tela de perfil do estabelecimento, aciona "Excluir conta"
        let botaoExcluir = app.buttons["estabelecimento-excluir-conta"]
        XCTAssertTrue(botaoExcluir.waitForExistence(timeout: Espera.aparecer), "Botão de excluir conta do estabelecimento deve estar visível")
        botaoExcluir.tap()

        // 3. Chega à tela de exclusão de conta
        let telaExclusao = app.descendants(matching: .any)["tela-exclusao-de-conta"]
        XCTAssertTrue(telaExclusao.waitForExistence(timeout: Espera.aparecer), "Deve chegar à tela de exclusão de conta")

        // 4. Verifica que o turno futuro confirmado do estabelecimento é listado como vínculo
        let itemTurno = app.descendants(matching: .any)["item-turno-futuro-82000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(itemTurno.waitForExistence(timeout: Espera.aparecer), "Turno futuro do contratante deve ser exibido")
        XCTAssertFalse(app.staticTexts["texto-sem-turnos-futuros"].exists)
        XCTAssertTrue(app.staticTexts["Turnos futuros vinculados à conta"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["aviso-lista-turnos-exclusao"].exists)
    }

    func testContratanteSemEstabelecimentoTemAcessoAExclusaoDeConta() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "contratante-sem-estabelecimento"]
        app.launch()

        // 1. Contratante sem estabelecimento acessa a aba Conta com Sair e Excluir conta
        let abaConta = app.tabBars.buttons["Conta"]
        XCTAssertTrue(abaConta.waitForExistence(timeout: 10), "Contratante sem estabelecimento deve ver a aba Conta")
        abaConta.tap()

        let botaoExcluirConta = app.buttons["estabelecimento-excluir-conta"]
        XCTAssertTrue(botaoExcluirConta.waitForExistence(timeout: 10), "Contratante sem estabelecimento deve ter acesso a Excluir conta")

        let botaoSair = app.buttons["estabelecimento-sair"]
        XCTAssertTrue(botaoSair.exists, "Botão Sair deve continuar visível")

        // 2. Aciona o botão de exclusão
        botaoExcluirConta.tap()

        // 3. Verifica que a tela de exclusão abre em folha
        let telaExclusao = app.descendants(matching: .any)["tela-exclusao-de-conta"]
        XCTAssertTrue(telaExclusao.waitForExistence(timeout: Espera.aparecer), "Tela de exclusão de conta deve ser apresentada")

        // 4. Confirma consequências e executa a exclusão
        let toggle = app.switches["toggle-confirmar-consequencias"]
        if toggle.waitForExistence(timeout: 5) {
            toggle.tap()
        } else {
            app.descendants(matching: .any)["toggle-confirmar-consequencias"].firstMatch.tap()
        }

        let botaoConfirmarDefinitivo = app.buttons["botao-excluir-conta-definitivo"]
        XCTAssertTrue(botaoConfirmarDefinitivo.waitForExistence(timeout: Espera.aparecer))
        let botaoHabilitado = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: botaoConfirmarDefinitivo
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [botaoHabilitado], timeout: Espera.aparecer), .completed,
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

        let abaConta = app.tabBars.buttons["Conta"]
        XCTAssertTrue(abaConta.waitForExistence(timeout: 10))
        abaConta.tap()

        let irParaExclusao = app.buttons["perfil-excluir-conta"]
        XCTAssertTrue(irParaExclusao.waitForExistence(timeout: Espera.aparecer))
        rolarAte(irParaExclusao, em: app)
        irParaExclusao.tap()
        XCTAssertTrue(app.descendants(matching: .any)["tela-exclusao-de-conta"].waitForExistence(timeout: Espera.aparecer))
        anexar(app, "ExclusaoEmAX5Topo")
        // Captura do item de consequência em AX5: o ícone vai acima do texto, sem invadi-lo.
        let consequencia = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Os turnos futuros'")).firstMatch
        let janela = app.windows.firstMatch.frame
        for _ in 0..<10 where !(consequencia.exists && consequencia.frame.minY > janela.minY && consequencia.frame.minY < janela.midY) {
            app.swipeUp()
        }
        anexar(app, "ExclusaoEmAX5Consequencias")

        // Em AX5 o elemento do Toggle é quase todo rótulo, e o toque no rótulo não alterna: vai no interruptor.
        let toggle = app.switches["toggle-confirmar-consequencias"]
        XCTAssertTrue(toggle.waitForExistence(timeout: Espera.aparecer))
        let interruptor = toggle.switches.firstMatch
        rolarAte(interruptor, em: app)
        anexar(app, "ExclusaoEmAX5Rolada")
        tocar(interruptor)

        let botaoExcluir = app.buttons["botao-excluir-conta-definitivo"]
        let habilitado = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: botaoExcluir)
        XCTAssertEqual(XCTWaiter.wait(for: [habilitado], timeout: Espera.aparecer), .completed)
        rolarAte(botaoExcluir, em: app)
        tocar(botaoExcluir)

        let cancelar = app.buttons["botao-cancelar-exclusao-dialogo"]
        let confirmar = app.buttons["botao-confirmar-exclusao-dialogo"]
        XCTAssertTrue(cancelar.waitForExistence(timeout: Espera.aparecer), "A confirmação deve ter o Cancelar")
        anexar(app, "ConfirmacaoDeExclusaoEmAX5")
        XCTAssertTrue(cancelar.isHittable, "Em AX5, o Cancelar fica tocável sem rolar")
        XCTAssertTrue(confirmar.isHittable, "Em AX5, o Confirmar fica tocável sem rolar")

        cancelar.tap()
        let fechou = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: cancelar)
        XCTAssertEqual(XCTWaiter.wait(for: [fechou], timeout: 5), .completed, "O Cancelar fecha a confirmação")
        XCTAssertTrue(app.descendants(matching: .any)["tela-exclusao-de-conta"].exists, "Cancelar não exclui: a tela continua")
        XCTAssertFalse(app.textFields["entrada-email"].exists, "Cancelar não volta para a entrada")
    }

    func testContratanteComTurnosCancelaExclusaoNoTamanhoPadrao() {
        conferirCancelamentoDoContratante(ax5: false)
    }

    func testContratanteComTurnosCancelaExclusaoEmAX5() {
        conferirCancelamentoDoContratante(ax5: true)
    }

    private func conferirCancelamentoDoContratante(ax5: Bool) {
        // Falha interrompe o fluxo antes de tocar qualquer controle da próxima etapa.
        continueAfterFailure = false
        let tamanho = ax5 ? "AX5" : "Padrao"
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "painel-contratante"]
        if ax5 {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()

        let abaConta = app.tabBars.buttons["Conta"]
        XCTAssertTrue(abaConta.waitForExistence(timeout: 10))
        abaConta.tap()
        let abrirExclusao = app.buttons["estabelecimento-excluir-conta"]
        XCTAssertTrue(abrirExclusao.waitForExistence(timeout: Espera.aparecer))
        rolarAte(abrirExclusao, em: app)
        conferirAlvo(abrirExclusao, em: app)
        anexar(app, "Contratante\(tamanho)Perfil")
        abrirExclusao.tap()

        let tela = app.descendants(matching: .any)["tela-exclusao-de-conta"]
        XCTAssertTrue(tela.waitForExistence(timeout: Espera.aparecer))
        let consequencias = app.descendants(matching: .any)["aviso-consequencias-exclusao"]
        XCTAssertTrue(consequencias.waitForExistence(timeout: Espera.aparecer))
        anexar(app, "Contratante\(tamanho)Consequencias")

        // O contêiner com children: .combine reúne o cartão em um único elemento acessível com o identifier do turno.
        let itemTurno = app.descendants(matching: .any)["item-turno-futuro-82000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(itemTurno.waitForExistence(timeout: Espera.aparecer), "Turno futuro do contratante deve ser exibido")
        XCTAssertTrue(itemTurno.label.contains("Garçom"), "Rótulo combinado do turno futuro deve conter a função Garçom")
        rolarAte(itemTurno, em: app)
        XCTAssertFalse(app.staticTexts["texto-sem-turnos-futuros"].exists)
        anexar(app, "Contratante\(tamanho)TurnoFuturo")

        let aviso = app.descendants(matching: .any)["aviso-lista-turnos-exclusao"]
        XCTAssertTrue(aviso.exists, "A lista parcial deve ser apresentada como incompleta")
        rolarAte(aviso, em: app)
        anexar(app, "Contratante\(tamanho)ListaIncompleta")

        let consentimento = app.switches["toggle-confirmar-consequencias"]
        let interruptor = consentimento.switches.firstMatch
        rolarAte(interruptor, em: app)
        conferirAlvo(consentimento, em: app)
        let excluir = app.buttons["botao-excluir-conta-definitivo"]
        XCTAssertTrue(excluir.exists)
        XCTAssertFalse(excluir.isEnabled, "Listar vínculos não substitui o consentimento explícito")
        anexar(app, "Contratante\(tamanho)SemConsentimento")
        tocar(interruptor)
        let habilitado = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: excluir)
        XCTAssertEqual(XCTWaiter.wait(for: [habilitado], timeout: Espera.aparecer), .completed)
        rolarAte(excluir, em: app)
        conferirAlvo(excluir, em: app)
        anexar(app, "Contratante\(tamanho)ComConsentimento")
        tocar(excluir)

        let cancelar = app.buttons["botao-cancelar-exclusao-dialogo"]
        let confirmar = app.buttons["botao-confirmar-exclusao-dialogo"]
        XCTAssertTrue(cancelar.waitForExistence(timeout: Espera.aparecer))
        let dialogoTocavel = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: cancelar)
        XCTAssertEqual(XCTWaiter.wait(for: [dialogoTocavel], timeout: Espera.aparecer), .completed)
        for botao in [cancelar, confirmar] {
            conferirAlvo(botao, em: app)
            XCTAssertGreaterThanOrEqual(botao.frame.minY, app.windows.firstMatch.frame.minY)
            XCTAssertLessThanOrEqual(botao.frame.maxY, app.windows.firstMatch.frame.maxY)
        }
        anexar(app, "Contratante\(tamanho)Confirmacao")
        cancelar.tap()

        let fechou = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: cancelar)
        XCTAssertEqual(XCTWaiter.wait(for: [fechou], timeout: Espera.aparecer), .completed)
        XCTAssertTrue(tela.exists, "Cancelar mantém a tela da conta")
        XCTAssertFalse(app.textFields["entrada-email"].exists, "Cancelar não encerra a sessão")
        XCTAssertTrue(excluir.isEnabled, "Cancelar a confirmação permite reconsiderar a ação")
        anexar(app, "Contratante\(tamanho)Cancelada")
    }

    private func conferirAlvo(_ elemento: XCUIElement, em app: XCUIApplication) {
        XCTAssertTrue(elemento.isHittable)
        XCTAssertAlvoMinimo(elemento.frame.width)
        XCTAssertAlvoMinimo(elemento.frame.height)
        XCTAssertGreaterThanOrEqual(elemento.frame.minX, app.windows.firstMatch.frame.minX)
        XCTAssertLessThanOrEqual(elemento.frame.maxX, app.windows.firstMatch.frame.maxX)
    }

    private func rolarAte(_ elemento: XCUIElement, em app: XCUIApplication) {
        for _ in 0..<10 where !elemento.isHittable { app.swipeUp() }
        XCTAssertTrue(elemento.isHittable, "\(elemento) não ficou tocável")
    }

    private func anexar(_ app: XCUIApplication, _ nome: String) {
        let anexo = XCTAttachment(screenshot: app.screenshot())
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)
    }

    private func confirmarExclusaoNoDialogo(no app: XCUIApplication) {
        let botaoConfirmar = app.buttons.matching(identifier: "botao-confirmar-exclusao-dialogo").firstMatch
        XCTAssertTrue(botaoConfirmar.waitForExistence(timeout: Espera.aparecer), "Diálogo de confirmação deve aparecer")

        let tocavel = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"),
            object: botaoConfirmar
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [tocavel], timeout: Espera.aparecer), .completed,
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

