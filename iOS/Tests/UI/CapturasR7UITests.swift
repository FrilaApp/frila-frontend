import XCTest

/// R7 do redesign (telas comuns aos dois lados), no tamanho padrão e em AX5: o que cada tela mostra e o alvo de toque
/// de cada botão que o redesenho trocou. `FRILA_CAPTURAS_DIR` (opcional) grava as imagens; sem ela, os anexos ficam só no
/// resultado do teste.
@MainActor
final class CapturasR7UITests: XCTestCase {
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"
    private let idDesconhecido = "99999999-0000-0000-0000-000000000001"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func iniciar(_ extra: [String], cenario: String = "success", cacheVazio: Bool = true, ax5: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", cenario, "-FRILA_MODO_CLARO", "-AppleLanguages", "(pt-BR)",
                               "-AppleLocale", "pt_BR", "-FRILA_SEM_ANIMACOES"] + (cacheVazio ? ["-FRILA_CACHE_VAZIO_UI_TEST"] : []) + extra
        if ax5 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", Self.ax5] }
        app.launch()
        return app
    }

    private func capturar(_ nome: String, ax5: Bool) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let captura = XCUIScreen.main.screenshot()
        let nomeFinal = "\(nome)-\(ax5 ? "ax5" : "padrao")"
        let anexo = XCTAttachment(screenshot: captura)
        anexo.name = nomeFinal
        anexo.lifetime = .keepAlways
        add(anexo)
        if let pasta = ProcessInfo.processInfo.environment["FRILA_CAPTURAS_DIR"], !pasta.isEmpty {
            try? FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
            try? captura.pngRepresentation.write(to: URL(fileURLWithPath: "\(pasta)/\(nomeFinal).png"))
        }
    }

    /// O botão existe e tem alvo de ao menos 44 pt.
    private func conferirBotao(_ botao: XCUIElement, _ nome: String) {
        XCTAssertTrue(botao.waitForExistence(timeout: Espera.aparecer), "\(nome) deve aparecer")
        XCTAssertGreaterThanOrEqual(botao.frame.height, 44, "\(nome): alvo de toque de ao menos 44 pt")
        XCTAssertGreaterThanOrEqual(botao.frame.width, 44, "\(nome): alvo de toque de ao menos 44 pt")
    }

    // MARK: - Parte 1: avisos, destinos do aviso e suporte

    private func explicacaoDosAvisos(contratante: Bool, ax5: Bool) {
        let app = iniciar(["-FRILA_PERMISSAO_PUSH", "nao-pedida"], cenario: contratante ? "painel-contratante" : "success", ax5: ax5)
        let explicar = app.buttons["explicar-notificacoes"]
        XCTAssertTrue(explicar.waitForExistence(timeout: 15), "o aviso fixo que reabre a explicação")
        explicar.tap()
        XCTAssertTrue(app.descendants(matching: .any)["explicacao-do-push"].waitForExistence(timeout: Espera.aparecer))
        conferirBotao(app.buttons["ativar-notificacoes"], "Ativar notificações")
        conferirBotao(app.buttons["notificacoes-agora-nao"], "Agora não")
        capturar(contratante ? "r7-avisos-explicacao-casa" : "r7-avisos-explicacao", ax5: ax5)
    }

    func testExplicacaoDosAvisosDoProfissionalNoTamanhoPadrao() { explicacaoDosAvisos(contratante: false, ax5: false) }
    func testExplicacaoDosAvisosDoProfissionalEmAX5() { explicacaoDosAvisos(contratante: false, ax5: true) }
    func testExplicacaoDosAvisosDaCasaNoTamanhoPadrao() { explicacaoDosAvisos(contratante: true, ax5: false) }

    private func faixaDeNotificacoes(estado: String, identificador: String, ax5: Bool) {
        let app = iniciar(["-FRILA_PERMISSAO_PUSH", estado], ax5: ax5)
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 15))
        conferirBotao(app.buttons[identificador], estado)
        capturar("r7-avisos-faixa-\(estado)", ax5: ax5)
    }

    func testFaixaComPermissaoNegadaNoTamanhoPadrao() { faixaDeNotificacoes(estado: "negada", identificador: "abrir-ajustes-de-notificacao", ax5: false) }
    func testFaixaComPermissaoNegadaEmAX5() { faixaDeNotificacoes(estado: "negada", identificador: "abrir-ajustes-de-notificacao", ax5: true) }
    func testFaixaSemPedirAindaNoTamanhoPadrao() { faixaDeNotificacoes(estado: "nao-pedida", identificador: "explicar-notificacoes", ax5: false) }

    private func vagaIndisponivel(ax5: Bool) {
        let app = iniciar(["-FRILA_PUSH", "vaga", "-FRILA_PUSH_ID", idDesconhecido], ax5: ax5)
        XCTAssertTrue(app.descendants(matching: .any)["vaga-indisponivel"].waitForExistence(timeout: 15))
        conferirBotao(app.buttons["voltar-para-lista"], "Voltar para a lista")
        capturar("r7-aviso-vaga-indisponivel", ax5: ax5)
    }

    func testVagaIndisponivelNoTamanhoPadrao() { vagaIndisponivel(ax5: false) }
    func testVagaIndisponivelEmAX5() { vagaIndisponivel(ax5: true) }

    private func turnoDoAvisoNaoEncontrado(ax5: Bool) {
        let app = iniciar(["-FRILA_PUSH", "lembrete_3h", "-FRILA_PUSH_ID", idDesconhecido], ax5: ax5)
        XCTAssertTrue(app.descendants(matching: .any)["turno-do-aviso-nao-encontrado"].waitForExistence(timeout: 15))
        conferirBotao(app.buttons["ver-meus-turnos"], "Ver meus turnos")
        capturar("r7-aviso-turno-nao-encontrado", ax5: ax5)
    }

    func testTurnoDoAvisoNaoEncontradoNoTamanhoPadrao() { turnoDoAvisoNaoEncontrado(ax5: false) }
    func testTurnoDoAvisoNaoEncontradoEmAX5() { turnoDoAvisoNaoEncontrado(ax5: true) }

    private func folhaDeSuporte(ax5: Bool) {
        let app = iniciar(["-FRILA_ABRIR_SUPORTE_TURNO"], ax5: ax5)
        XCTAssertTrue(app.descendants(matching: .any)["folha-suporte-turno"].waitForExistence(timeout: 10))
        conferirBotao(app.descendants(matching: .any)["botao-enviar-email-suporte"].firstMatch, "Abrir e-mail de suporte")
        capturar("r7-suporte-padrao", ax5: ax5)

        let risco = app.descendants(matching: .any)["opcao-motivo-risco_seguranca"]
        XCTAssertTrue(risco.waitForExistence(timeout: Espera.aparecer))
        risco.tap()
        conferirBotao(app.descendants(matching: .any)["botao-ligar-190"].firstMatch, "Ligar 190")
        conferirBotao(app.descendants(matching: .any)["botao-ligar-180"].firstMatch, "Ligar 180")
        capturar("r7-suporte-risco", ax5: ax5)
    }

    func testFolhaDeSuporteNoTamanhoPadrao() { folhaDeSuporte(ax5: false) }
    func testFolhaDeSuporteEmAX5() { folhaDeSuporte(ax5: true) }

    // MARK: - Parte 2: denúncia, bloqueio, perfil público, bloqueados, histórico, exportar, aparência e licenças

    private let vagaID = "40000000-0000-0000-0000-000000000001"

    private func rolarAteVer(_ elemento: XCUIElement, em app: XCUIApplication, tentativas: Int = 10) {
        for _ in 0..<tentativas where !(elemento.exists && elemento.isHittable) { app.swipeUp() }
    }

    /// Rola até o elemento ficar na metade de cima da tela: com o botão ancorado embaixo (e mais ainda em AX5), um
    /// elemento "tocável" no pé da tela pode estar atrás do grupo ancorado.
    private func rolarAteFicarAcima(_ elemento: XCUIElement, em app: XCUIApplication, tentativas: Int = 14) {
        let altura = app.windows.firstMatch.frame.height
        for _ in 0..<tentativas where !(elemento.exists && elemento.isHittable && elemento.frame.midY < altura * 0.55) { app.swipeUp() }
    }

    /// O perfil público da casa, aberto pelo detalhe da vaga.
    private func abrirPerfilDaCasa(ax5: Bool) -> XCUIApplication {
        let app = iniciar([], cacheVazio: false, ax5: ax5)
        let vaga = app.buttons["vaga-\(vagaID)"]
        XCTAssertTrue(vaga.waitForExistence(timeout: 15), "a vaga está na lista")
        vaga.tap()
        XCTAssertTrue(app.descendants(matching: .any)["tela-detalhe-vaga"].waitForExistence(timeout: Espera.aparecer))
        let abrir = app.descendants(matching: .any)["abrir-perfil-estabelecimento"].firstMatch
        rolarAteVer(abrir, em: app)
        abrir.tap()
        XCTAssertTrue(app.descendants(matching: .any)["perfil-publico-estabelecimento"].waitForExistence(timeout: Espera.aparecer))
        return app
    }

    private func perfilDaCasa(ax5: Bool) {
        let app = abrirPerfilDaCasa(ax5: ax5)
        capturar("r7-perfil-casa-topo", ax5: ax5)
        let denunciar = app.buttons["denunciar"]
        rolarAteVer(denunciar, em: app)
        conferirBotao(denunciar, "Denunciar")
        conferirBotao(app.buttons["bloquear"], "Bloquear")
        capturar("r7-perfil-casa-acoes", ax5: ax5)
    }

    func testPerfilDaCasaNoTamanhoPadrao() { perfilDaCasa(ax5: false) }
    func testPerfilDaCasaEmAX5() { perfilDaCasa(ax5: true) }

    /// O perfil público do profissional, visto pela casa, aberto pelos candidatos da vaga.
    private func perfilDoProfissional(ax5: Bool) {
        let app = iniciar(["-FRILA_ABRIR_MINHAS_VAGAS"], cenario: "selecao-com-candidatos", cacheVazio: false, ax5: ax5)
        let vaga = app.buttons["vaga-contratante-\(vagaID)"]
        XCTAssertTrue(vaga.waitForExistence(timeout: 15))
        vaga.tap()
        let detalhe = app.descendants(matching: .any)["detalhe-vaga-contratante"]
        if !detalhe.waitForExistence(timeout: 10), vaga.exists, vaga.isHittable { vaga.tap() }
        XCTAssertTrue(detalhe.waitForExistence(timeout: 10))
        let abrir = app.buttons["perfil-do-candidato-70000000-0000-0000-0000-000000000002"]
        rolarAteVer(abrir, em: app, tentativas: 12)
        abrir.tap()
        XCTAssertTrue(app.descendants(matching: .any)["perfil-publico-contratante"].waitForExistence(timeout: 10))
        capturar("r7-perfil-profissional-topo", ax5: ax5)
        let denunciar = app.buttons["denunciar"]
        rolarAteVer(denunciar, em: app)
        conferirBotao(denunciar, "Denunciar")
        conferirBotao(app.buttons["bloquear"], "Bloquear")
        capturar("r7-perfil-profissional-acoes", ax5: ax5)
    }

    func testPerfilDoProfissionalNoTamanhoPadrao() { perfilDoProfissional(ax5: false) }
    func testPerfilDoProfissionalEmAX5() { perfilDoProfissional(ax5: true) }

    private func folhaDeDenuncia(ax5: Bool) {
        let app = abrirPerfilDaCasa(ax5: ax5)
        let denunciar = app.buttons["denunciar"]
        rolarAteVer(denunciar, em: app)
        denunciar.tap()
        let enviar = app.buttons["enviar-denuncia"]
        XCTAssertTrue(enviar.waitForExistence(timeout: Espera.aparecer), "a folha de denúncia abre")
        XCTAssertFalse(enviar.isEnabled, "sem o relato, o envio fica em conferência")
        for motivo in ["Assédio", "Discriminação", "Risco à segurança", "Outro"] {
            conferirBotao(app.buttons[motivo], motivo)
        }
        capturar("r7-denuncia-formulario", ax5: ax5)

        let risco = app.buttons["Risco à segurança"]
        risco.tap()
        XCTAssertTrue(app.staticTexts["aviso-risco-imediato"].waitForExistence(timeout: Espera.aparecer))
        conferirBotao(app.buttons["atalho-emergencia-190"], "Ligar 190")
        conferirBotao(app.buttons["atalho-emergencia-180"], "Ligar 180")
        capturar("r7-denuncia-risco", ax5: ax5)
        guard !ax5 else { return }

        let relato = app.descendants(matching: .any)["relato-denuncia"].firstMatch
        rolarAteVer(relato, em: app)
        relato.tap()
        relato.typeText("Relato de risco ocorrido no estabelecimento.")
        tocarFechandoTeclado(enviar, em: app)
        XCTAssertTrue(app.descendants(matching: .any)["protocolo-denuncia"].waitForExistence(timeout: Espera.aparecer))
        conferirBotao(app.buttons["concluir-denuncia"], "Concluir")
        capturar("r7-denuncia-enviada", ax5: ax5)
    }

    func testFolhaDeDenunciaNoTamanhoPadrao() { folhaDeDenuncia(ax5: false) }
    func testFolhaDeDenunciaEmAX5() { folhaDeDenuncia(ax5: true) }

    /// Bloquear (o alerta), o perfil que fica indisponível, a lista de bloqueados e o desbloqueio.
    private func bloqueioEListaDeBloqueados(ax5: Bool) {
        let app = abrirPerfilDaCasa(ax5: ax5)
        let bloquear = app.buttons["bloquear"]
        rolarAteVer(bloquear, em: app)
        bloquear.tap()
        let confirmar = app.alerts.buttons["confirmar-bloqueio"].firstMatch
        XCTAssertTrue(confirmar.waitForExistence(timeout: Espera.aparecer), "o alerta de bloqueio abre")
        capturar("r7-bloquear-alerta", ax5: ax5)
        confirmar.tap()
        XCTAssertTrue(app.descendants(matching: .any)["perfil-indisponivel"].waitForExistence(timeout: Espera.aparecer))
        capturar("r7-perfil-indisponivel", ax5: ax5)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.descendants(matching: .any)["detalhe-nao-encontrada"].waitForExistence(timeout: Espera.aparecer))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let abaConta = app.tabBars.buttons["Conta"]
        XCTAssertTrue(abaConta.waitForExistence(timeout: Espera.aparecer))
        abaConta.tap()
        let linkBloqueios = app.buttons["perfil-bloqueios"]
        XCTAssertTrue(linkBloqueios.waitForExistence(timeout: Espera.aparecer))
        rolarAteVer(linkBloqueios, em: app)
        linkBloqueios.tap()
        XCTAssertTrue(app.descendants(matching: .any)["tela-bloqueios"].waitForExistence(timeout: Espera.aparecer))
        let desbloquear = app.buttons["desbloquear-30000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(desbloquear.waitForExistence(timeout: Espera.aparecer))
        conferirBotao(desbloquear, "Desbloquear")
        capturar("r7-bloqueados-lista", ax5: ax5)

        desbloquear.tap()
        let confirmarDesbloqueio = app.alerts.buttons["confirmar-desbloqueio"].firstMatch
        XCTAssertTrue(confirmarDesbloqueio.waitForExistence(timeout: Espera.aparecer))
        capturar("r7-desbloquear-alerta", ax5: ax5)
        confirmarDesbloqueio.tap()
        XCTAssertTrue(app.descendants(matching: .any)["bloqueios-vazio"].waitForExistence(timeout: Espera.aparecer))
        capturar("r7-bloqueados-vazio", ax5: ax5)
    }

    func testBloqueioEListaDeBloqueadosNoTamanhoPadrao() { bloqueioEListaDeBloqueados(ax5: false) }
    func testBloqueioEListaDeBloqueadosEmAX5() { bloqueioEListaDeBloqueados(ax5: true) }

    /// Abre a aba Conta e rola até a entrada.
    private func abrirPelaConta(_ app: XCUIApplication, entrada identificador: String) {
        let aba = app.tabBars.buttons["Conta"]
        XCTAssertTrue(aba.waitForExistence(timeout: 15))
        aba.tap()
        let entrada = app.buttons[identificador]
        XCTAssertTrue(entrada.waitForExistence(timeout: Espera.aparecer), "a entrada \(identificador) está na Conta")
        rolarAteVer(entrada, em: app, tentativas: 8)
        entrada.tap()
    }

    private func historicoDeTurnos(ax5: Bool) {
        let app = iniciar(["-FRILA_RELOGIO_AGORA", "2026-10-15T12:00:00Z"], cacheVazio: false, ax5: ax5)
        abrirPelaConta(app, entrada: "perfil-historico-turnos")
        let exportar = app.buttons["historico-exportar"]
        XCTAssertTrue(exportar.waitForExistence(timeout: Espera.aparecer))
        conferirBotao(exportar, "Exportar")
        conferirBotao(app.buttons["historico-este-mes"], "Este mês")
        capturar("r7-historico", ax5: ax5)

        let intervalo = app.buttons["historico-intervalo"]
        rolarAteFicarAcima(intervalo, em: app)
        intervalo.tap()
        XCTAssertTrue(app.descendants(matching: .any)["historico-de"].waitForExistence(timeout: Espera.aparecer))
        capturar("r7-historico-datas", ax5: ax5)
    }

    func testHistoricoDeTurnosNoTamanhoPadrao() { historicoDeTurnos(ax5: false) }
    func testHistoricoDeTurnosEmAX5() { historicoDeTurnos(ax5: true) }

    private func exportarMeusDados(ax5: Bool) {
        let app = iniciar([], cacheVazio: false, ax5: ax5)
        let aba = app.tabBars.buttons["Conta"]
        XCTAssertTrue(aba.waitForExistence(timeout: 15))
        aba.tap()
        let item = app.buttons["perfil-exportar-dados"]
        XCTAssertTrue(item.waitForExistence(timeout: Espera.aparecer))
        rolarAteVer(item, em: app, tentativas: 8)
        conferirBotao(item, "Exportar meus dados")
        XCTAssertTrue(app.staticTexts["perfil-exportar-dados-explicacao"].waitForExistence(timeout: Espera.aparecer))
        capturar("r7-exportar-dados", ax5: ax5)
    }

    func testExportarMeusDadosNoTamanhoPadrao() { exportarMeusDados(ax5: false) }
    func testExportarMeusDadosEmAX5() { exportarMeusDados(ax5: true) }

    private func aparencia(ax5: Bool) {
        let app = iniciar(["-FRILA_ABA_CONTA"], cacheVazio: false, ax5: ax5)
        let linha = app.buttons["perfil-aparencia"]
        XCTAssertTrue(linha.waitForExistence(timeout: 15))
        rolarAteVer(linha, em: app, tentativas: 8)
        linha.tap()
        let claro = app.buttons["aparencia-claro"]
        XCTAssertTrue(claro.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(claro.isSelected, "Claro é o padrão")
        conferirBotao(claro, "Claro")
        conferirBotao(app.buttons["aparencia-escuro"], "Escuro")
        capturar("r7-aparencia", ax5: ax5)
    }

    func testAparenciaNoTamanhoPadrao() { aparencia(ax5: false) }
    func testAparenciaEmAX5() { aparencia(ax5: true) }

    private func licencas(ax5: Bool) {
        let app = iniciar([], cacheVazio: false, ax5: ax5)
        let aba = app.tabBars.buttons["Conta"]
        XCTAssertTrue(aba.waitForExistence(timeout: 15))
        aba.tap()
        let ajuda = app.buttons["perfil-ajuda"]
        XCTAssertTrue(ajuda.waitForExistence(timeout: Espera.aparecer))
        rolarAteVer(ajuda, em: app, tentativas: 8)
        ajuda.tap()
        let entrada = app.descendants(matching: .any)["perfil-licencas"]
        XCTAssertTrue(entrada.waitForExistence(timeout: Espera.aparecer))
        rolarAteVer(entrada, em: app, tentativas: 12)
        entrada.tap()
        let pacote = app.buttons["licenca-abseil-cpp-binary"]
        XCTAssertTrue(pacote.waitForExistence(timeout: Espera.aparecer))
        conferirBotao(pacote, "primeiro pacote")
        capturar("r7-licencas-lista", ax5: ax5)
        pacote.tap()
        XCTAssertTrue(app.descendants(matching: .any)["tela-detalhe-da-licenca"].waitForExistence(timeout: Espera.aparecer))
        capturar("r7-licencas-detalhe", ax5: ax5)
    }

    func testLicencasNoTamanhoPadrao() { licencas(ax5: false) }
    func testLicencasEmAX5() { licencas(ax5: true) }
}
