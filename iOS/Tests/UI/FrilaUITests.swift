import XCTest

@MainActor
final class FrilaUITests: XCTestCase {
    func testCatalogoAbreEmPortugues() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_CATALOGO", "-FRILA_SCENARIO", "success", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Frila UI"].waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(app.buttons["Continuar"].exists)
    }

    func testCatalogoComTamanhoDeAcessibilidade() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_CATALOGO", "-FRILA_SCENARIO", "success", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Frila UI"].waitForExistence(timeout: Espera.aparecer))
        let botaoContinuar = app.buttons["Continuar"]
        XCTAssertTrue(botaoContinuar.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(botaoContinuar.isEnabled)
        XCTAssertTrue(app.buttons["Perto de mim"].waitForExistence(timeout: Espera.aparecer))
    }

    func testConflitoTipadoDoClienteChegaATela() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_CATALOGO", "-FRILA_SCENARIO", "vaga-preenchida"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Validação do cliente"].waitForExistence(timeout: Espera.aparecer))
        app.buttons["Simular vaga preenchida"].tap()
        XCTAssertTrue(app.staticTexts["Esta vaga acabou de ser preenchida. Volte para a lista e escolha outra vaga."].waitForExistence(timeout: Espera.aparecer))
    }

    func testEntradaMostraAClassificacaoIndicativaDe18Anos() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ENTRADA", "-FRILA_SCENARIO", "primeiro-acesso"]
        app.launch()

        XCTAssertTrue(app.textFields["entrada-email"].waitForExistence(timeout: Espera.aparecer))
        let classificacao = app.staticTexts["entrada-classificacao-indicativa"]
        XCTAssertTrue(classificacao.exists)
        XCTAssertEqual(classificacao.label, "Classificação indicativa: 18 anos")
    }

    func testSolicitacaoDeAcessoChegaAoClienteSemExporOEmailNaTelaDeResultado() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_CATALOGO", "-FRILA_SCENARIO", "success"]
        app.launch()

        let email = app.textFields["validacao-email"]
        XCTAssertTrue(email.waitForExistence(timeout: Espera.aparecer))
        email.tap()
        email.digitarEEsperar("teste@frila.app")
        app.buttons["Enviar código"].tap()

        XCTAssertTrue(app.staticTexts["Código enviado. Consulte a caixa de entrada do e-mail de teste."].waitForExistence(timeout: Espera.aparecer))
        XCTAssertFalse(app.staticTexts["teste@frila.app"].exists)
    }

    func testConfirmarCodigoAbreASessaoSemMostrarDadosDeAcesso() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_CATALOGO", "-FRILA_SCENARIO", "success"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Nenhuma sessão neste aparelho."].waitForExistence(timeout: Espera.aparecer))
        let email = app.textFields["validacao-email"]
        email.tap()
        email.digitarEEsperar("teste@frila.app")
        app.buttons["Enviar código"].tap()
        XCTAssertTrue(app.staticTexts["Código enviado. Consulte a caixa de entrada do e-mail de teste."].waitForExistence(timeout: Espera.aparecer))

        let codigo = app.textFields["validacao-codigo"]
        codigo.tap()
        codigo.typeText("123456")
        app.buttons["Confirmar código"].tap()

        XCTAssertTrue(app.staticTexts["Sessão ativa neste aparelho."].waitForExistence(timeout: Espera.aparecer))
        XCTAssertFalse(app.staticTexts["teste@frila.app"].exists)
        XCTAssertFalse(app.staticTexts["123456"].exists)
    }
}

/// Fluxo real do profissional (#104): o esquema Local abre na lista, sem argumento especial.
@MainActor
final class VagasUITests: XCTestCase {
    func testLocalAbreNaListaEODetalheTemOAvisoDaRN10SemTelefone() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
        let primeira = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-'")).firstMatch
        XCTAssertTrue(primeira.waitForExistence(timeout: 10))
        primeira.tap()

        XCTAssertTrue(app.descendants(matching: .any)["tela-detalhe-vaga"].waitForExistence(timeout: 10))
        let aviso = app.descendants(matching: .any)["aviso-rn10"]
        XCTAssertTrue(aviso.waitForExistence(timeout: 10))
        XCTAssertTrue(aviso.label.contains("seu telefone e WhatsApp ficam disponíveis"))
        // O detalhe não mostra telefone nem documento do estabelecimento.
        let comTelefone = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", ".*\\(?\\d{2}\\)? ?9? ?\\d{4}-?\\d{4}.*"))
        XCTAssertEqual(comTelefone.count, 0)
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'CNPJ' OR label CONTAINS[c] 'CPF'")).firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["detalhe-reputacao"].exists)
    }

    func testFiltroSemVagasMostraOEstadoVazio() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
        // O dublê só tem vaga de Garçom; filtrar por Bartender deixa a lista vazia.
        app.descendants(matching: .any)["filtro-funcao"].tap()
        let bartender = app.buttons["Bartender"]
        XCTAssertTrue(bartender.waitForExistence(timeout: Espera.aparecer))
        bartender.tap()
        XCTAssertTrue(app.descendants(matching: .any)["vagas-vazio"].waitForExistence(timeout: 10))
    }

    func testErroDaAPIMostraOEstadoDeErroComTentarNovamente() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "erro-na-lista"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["vagas-erro"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["vagas-tentar-de-novo"].exists)
    }

    func testSemRedeMostraOEstadoSemConexao() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "sem-rede"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["vagas-sem-conexao"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["vagas-tentar-de-novo"].exists)
    }

    func testListaComTamanhoDeAcessibilidadeMantemTituloEFiltros() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["filtro-funcao"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["filtro-data"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["filtro-distancia"].exists)
    }

    func testCatalogoSoAbreComPedidoExplicito() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.navigationBars["Frila UI"].exists)
        // Em Debug, o catálogo continua acessível pelo botão da barra.
        app.buttons["Catálogo"].tap()
        XCTAssertTrue(app.navigationBars["Frila UI"].waitForExistence(timeout: 10))
    }
}

/// Candidatura (#105) pela tela real: lista -> detalhe -> Candidatar-me -> resultado.
@MainActor
final class CandidaturaUITests: XCTestCase {
    private func abrirDetalheECandidatar(_ cenario: String, argumentos: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", cenario] + argumentos
        app.launch()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10), "a tela de vagas deve aparecer")
        let primeira = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-'")).firstMatch
        XCTAssertTrue(primeira.waitForExistence(timeout: Espera.aparecer), "a primeira vaga deve aparecer na lista após o carregamento inicial")

        if !primeira.isHittable {
            let tocavel = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "isHittable == true"),
                object: primeira
            )
            _ = XCTWaiter.wait(for: [tocavel], timeout: 5)
        }
        if !primeira.isHittable {
            app.swipeUp()
        }
        let tocavelFinal = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"),
            object: primeira
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [tocavelFinal], timeout: Espera.aparecer), .completed,
            "o primeiro cartão de vaga deve ficar tocável na lista"
        )

        primeira.tap()

        let detalhe = app.descendants(matching: .any)["tela-detalhe-vaga"]
        let detalheAbriu = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: detalhe
        )
        if XCTWaiter.wait(for: [detalheAbriu], timeout: 3) != .completed {
            XCTContext.runActivity(named: "Repetir toque no cartão da vaga") { _ in
                let anexo = XCTAttachment(string: "A tela de detalhe da vaga não abriu em até 3 s após o primeiro toque no cartão; acionando segundo toque.")
                anexo.name = "RepeticaoDoToqueNoCartaoDaVaga"
                anexo.lifetime = .keepAlways
                add(anexo)
            }
            if primeira.exists && primeira.isHittable {
                primeira.tap()
            }
            let detalheAbriuAposSegundoToque = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == true"),
                object: detalhe
            )
            // Depois do segundo toque, o mesmo prazo de antes da mudança: na CI carregada a
            // navegação pode levar mais de 3 s, e 3 s aqui acusariam defeito do app sem haver.
            XCTAssertEqual(
                XCTWaiter.wait(for: [detalheAbriuAposSegundoToque], timeout: 10), .completed,
                "Defeito do app: tela de detalhe da vaga não apareceu após o segundo toque no cartão"
            )
        }

        let candidatar = app.buttons["candidatar"]
        XCTAssertTrue(candidatar.waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any)["aviso-rn10"].waitForExistence(timeout: 10), "o aviso da RN10 vem antes de Candidatar-me")
        tocar(candidatar)
        return app
    }

    func testConfirmadaAbreMeuTurnoComOContato() {
        let app = abrirDetalheECandidatar("success")
        XCTAssertTrue(app.descendants(matching: .any)["resultado-confirmada"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["contato-do-turno"].exists)
        tocar(app.buttons["voltar-para-lista"])
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["1 posição aberta"].waitForExistence(timeout: 10), "a lista é atualizada após a confirmação")
    }

    func testVagaPreenchidaTemTelaPropriaEVoltaParaALista() {
        let app = abrirDetalheECandidatar("vaga-preenchida")
        XCTAssertTrue(app.descendants(matching: .any)["resultado-vaga-preenchida"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["resultado-vaga-encerrada"].exists)
        tocar(app.buttons["voltar-para-lista-navegacao"])
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
    }

    func testVagaEncerradaTemTelaPropriaDiferenteDaPreenchida() {
        let app = abrirDetalheECandidatar("vaga-encerrada")
        XCTAssertTrue(app.descendants(matching: .any)["resultado-vaga-encerrada"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["resultado-vaga-preenchida"].exists)
        tocar(app.buttons["voltar-para-lista"])
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
    }

    func testTurnoSobrepostoMostraOConflitoSemApontarTurno() {
        let app = abrirDetalheECandidatar("inelegivel")
        XCTAssertTrue(app.descendants(matching: .any)["resultado-turno-sobreposto"].waitForExistence(timeout: 15))
        let voltar = app.buttons["voltar-para-lista"]
        XCTAssertTrue(voltar.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["ajustar-minhas-funcoes"].exists)
        tocar(voltar)
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 15))
    }

    func testFuncaoIncompativelAbreFuncoesESalvarPermiteNovaCandidatura() {
        let app = abrirDetalheECandidatar("funcao-incompativel")
        XCTAssertTrue(app.descendants(matching: .any)["resultado-funcao-incompativel"].waitForExistence(timeout: 10))
        let ajustar = app.buttons["ajustar-minhas-funcoes"]
        XCTAssertTrue(ajustar.waitForExistence(timeout: Espera.aparecer))
        XCTAssertEqual(ajustar.label, "Ajustar minhas funções")
        XCTAssertTrue(app.buttons["voltar-para-lista"].exists)
        tocar(ajustar)
        XCTAssertTrue(app.descendants(matching: .any)["tela-perfil-profissional"].waitForExistence(timeout: 10))
        let funcao = app.buttons["pill-funcao-20000000-0000-0000-0000-000000000001"]
        tocar(funcao)
        let salvar = app.buttons["botao-salvar-perfil"]
        for _ in 0..<5 where !salvar.isHittable { app.swipeUp() }
        XCTAssertTrue(salvar.isHittable)
        tocar(salvar)

        XCTAssertTrue(app.descendants(matching: .any)["tela-detalhe-vaga"].waitForExistence(timeout: 10))
        let candidatar = app.buttons["candidatar"]
        if !candidatar.isHittable { app.swipeUp() }
        XCTAssertTrue(candidatar.isEnabled)
        XCTAssertFalse(app.descendants(matching: .any)["resultado-confirmada"].exists)
        tocar(candidatar)
        XCTAssertTrue(app.descendants(matching: .any)["resultado-confirmada"].waitForExistence(timeout: 10))
    }

    func testContaSuspensaNaCandidaturaAbreContestacaoEEnviaRelato() {
        let app = abrirDetalheECandidatar("inelegivel-suspenso")
        XCTAssertTrue(app.descendants(matching: .any)["resultado-conta-suspensa"].waitForExistence(timeout: 10))
        let contestar = app.buttons["contestar"]
        XCTAssertTrue(contestar.exists)
        XCTAssertTrue(contestar.isEnabled)
        tocar(contestar)
        XCTAssertTrue(app.descendants(matching: .any)["tela-conta-suspensa"].waitForExistence(timeout: Espera.aparecer))
        tocar(app.buttons["botao-contestar-suspensao"])
        let relato = app.descendants(matching: .any)["campo-relato-contestacao"].firstMatch
        XCTAssertTrue(relato.waitForExistence(timeout: Espera.aparecer))
        relato.tap()
        relato.typeText("Solicito a revisão da suspensão da minha conta")
        tocar(app.buttons["botao-enviar-contestacao"])
        XCTAssertTrue(app.descendants(matching: .any)["protocolo-contestacao"].waitForExistence(timeout: Espera.aparecer))
    }

    func testResultadoComTamanhoDeAcessibilidadeMantemOBotaoDeVolta() {
        let app = abrirDetalheECandidatar("vaga-preenchida", argumentos: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(app.descendants(matching: .any)["resultado-vaga-preenchida"].waitForExistence(timeout: 10))
        let voltar = app.buttons["voltar-para-lista"]
        tocar(voltar)
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
    }

    func testRotaPorVagaIDAbreODetalheSemCandidatar() {
        let app = XCUIApplication()
        // vaga.json do dublê.
        app.launchArguments = ["-FRILA_SCENARIO", "success", "-FRILA_VAGA_ID", "40000000-0000-0000-0000-000000000001"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["tela-detalhe-vaga"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["candidatar"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["resultado-confirmada"].exists, "a rota abre o detalhe, nunca aceita sozinha")
        tocar(app.buttons["candidatar"])
        XCTAssertTrue(app.descendants(matching: .any)["resultado-confirmada"].waitForExistence(timeout: 10))
    }
}

@MainActor
final class AutenticacaoUITests: XCTestCase {
    func testFluxoCompletoPrimeiroAcessoAteVagas() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ENTRADA", "-FRILA_SCENARIO", "primeiro-acesso", "-FRILA_BUSCA_PERFIL_UI_TEST"]
        AjudanteDeLancamentoUITests.preparar(app)
        app.launch()

        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.digitarEEsperar("novo@frila.app")
        tocar(app.buttons["entrada-receber-codigo"])

        let tfCodigo = app.textFields["Código de acesso"]
        XCTAssertTrue(tfCodigo.waitForExistence(timeout: 10))
        tfCodigo.tap()
        tfCodigo.typeText("123456")
        if app.buttons["codigo-entrar"].waitForExistence(timeout: 2) {
            app.buttons["codigo-entrar"].tap()
        }

        XCTAssertTrue(app.staticTexts["Como você quer usar o Frila?"].waitForExistence(timeout: 10))
        app.buttons["cadastro-perfil-profissional"].tap()
        let nome = app.textFields["cadastro-nome"]
        nome.tap()
        nome.typeText("Novo Usuário")

        let telefone = app.textFields["cadastro-telefone"]
        telefone.tap()
        telefone.digitarEEsperar("61988887777", esperado: "(61) 98888-7777")
        fecharTecladoSeVisivel(app: app)

        let nascimento = app.textFields["cadastro-nascimento"]
        rolarAte(nascimento, app: app)
        nascimento.tap()
        nascimento.digitarEEsperar("15/05/1995", esperado: "15/05/1995")
        fecharTecladoSeVisivel(app: app)

        let termos = app.buttons["cadastro-termos"]
        rolarAte(termos, app: app)
        termos.tap()

        let continuar = app.buttons["cadastro-continuar"]
        rolarAte(continuar, app: app)
        continuar.tap()

        preencherPerfil(app)
        tocar(app.buttons["botao-salvar-perfil"])
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-'")).firstMatch.waitForExistence(timeout: 10))
    }

    func testProfissionalSemPerfilPodeSairDaConta() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "sem-perfil-profissional"]
        app.launch()

        let sair = app.buttons["criacao-perfil-sair"]
        XCTAssertTrue(sair.waitForExistence(timeout: 10))
        guard sair.exists else { return }
        sair.tap()
        XCTAssertTrue(app.textFields["entrada-email"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["tela-perfil-profissional"].exists)
    }

    func testProfissionalSemPerfilCriaPerfilEAbreVagas() {
        let app = abrirCriacaoPerfil("sem-perfil-profissional")
        preencherPerfil(app)
        tocar(app.buttons["botao-salvar-perfil"])
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
        let primeira = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-'")).firstMatch
        XCTAssertTrue(primeira.waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["tela-perfil-profissional"].exists)
    }

    func testErroAoCriarPerfilPermiteRepetirEAbrirVagas() {
        let app = abrirCriacaoPerfil("erro-criacao-perfil-profissional")
        preencherPerfil(app)
        tocar(app.buttons["botao-salvar-perfil"])
        XCTAssertTrue(app.descendants(matching: .any)["aviso-erro-perfil"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["criacao-perfil-sair"].isHittable)
        let botaoSalvar = app.buttons["botao-salvar-perfil"]
        rolarAte(botaoSalvar, app: app)
        XCTAssertTrue(botaoSalvar.isEnabled)
        tocar(botaoSalvar)
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 15))
    }

    func testErroAoCriarPerfilPermiteSair() {
        let app = abrirCriacaoPerfil("erro-criacao-perfil-profissional")
        preencherPerfil(app)
        tocar(app.buttons["botao-salvar-perfil"])
        XCTAssertTrue(app.descendants(matching: .any)["aviso-erro-perfil"].waitForExistence(timeout: 10))
        tocar(app.buttons["criacao-perfil-sair"])
        XCTAssertTrue(app.textFields["entrada-email"].waitForExistence(timeout: 10))
    }

    private func abrirCriacaoPerfil(_ cenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", cenario, "-FRILA_BUSCA_PERFIL_UI_TEST"]
        app.launch()
        return app
    }

    private func preencherPerfil(_ app: XCUIApplication) {
        XCTAssertTrue(app.descendants(matching: .any)["tela-perfil-profissional"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["criacao-perfil-sair"].isHittable)
        let funcao = app.buttons["pill-funcao-20000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(funcao.waitForExistence(timeout: 10))
        funcao.tap()
        let ponto = app.textFields["campo-ponto-base"]
        ponto.tap()
        ponto.typeText("Guará II")
        app.buttons["botao-buscar-endereco"].tap()
        let sugestao = app.buttons["sugestao-endereco-0"]
        XCTAssertTrue(sugestao.waitForExistence(timeout: 10))
        sugestao.tap()
        fecharTecladoSeVisivel(app: app)
        rolarAte(app.buttons["botao-adicionar-janela"], app: app)
        app.buttons["botao-adicionar-janela"].tap()
        rolarAte(app.buttons["botao-salvar-perfil"], app: app)
    }

    private func fecharTecladoSeVisivel(app: XCUIApplication) {
        if app.keyboards.element.exists {
            let botoesTeclado = ["Buscar", "Search", "Done", "Concluído", "Retorno", "return"]
            for nome in botoesTeclado {
                let btn = app.keyboards.buttons[nome]
                if btn.exists {
                    btn.tap()
                    return
                }
            }
            let inicio = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
            let fim = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
            inicio.press(forDuration: 0.05, thenDragTo: fim)
        }
    }

    private func rolarAte(_ elemento: XCUIElement, app: XCUIApplication) {
        if elemento.isHittable && !app.keyboards.element.exists { return }
        for _ in 0..<6 {
            if elemento.isHittable && !app.keyboards.element.exists { return }
            let inicio = app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.60))
            let fim = app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.25))
            inicio.press(forDuration: 0.05, thenDragTo: fim)
        }
        if !elemento.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(elemento.isHittable)
    }

    func testSairDoAppParaBuscarOCodigoVoltaNaTelaDoCodigo() {
        let app = XCUIApplication()
        // Sem `-FRILA_ENTRADA`: a entrada vem da avaliação da sessão, como no app publicado.
        app.launchArguments = ["-FRILA_SEM_SESSAO"]
        app.launch()

        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.digitarEEsperar("existente@frila.app")
        tocar(app.buttons["entrada-receber-codigo"])
        let codigo = app.textFields["Código de acesso"]
        XCTAssertTrue(codigo.waitForExistence(timeout: 10))

        // Vai ao e-mail buscar o código e volta.
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        XCTAssertTrue(codigo.waitForExistence(timeout: 10), "a tela do código deve continuar aberta")
        XCTAssertFalse(app.textFields["entrada-email"].exists)
        codigo.tap()
        codigo.typeText("123456")
        if app.buttons["codigo-entrar"].waitForExistence(timeout: 2) {
            app.buttons["codigo-entrar"].tap()
        }
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
    }

    func testContaExistentePulaCadastroEAbreVagas() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ENTRADA", "-FRILA_SCENARIO", "success"]
        app.launch()

        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.digitarEEsperar("existente@frila.app")
        tocar(app.buttons["entrada-receber-codigo"])

        let tfCodigo = app.textFields["Código de acesso"]
        XCTAssertTrue(tfCodigo.waitForExistence(timeout: 10))
        tfCodigo.tap()
        tfCodigo.typeText("123456")
        if app.buttons["codigo-entrar"].waitForExistence(timeout: 2) {
            app.buttons["codigo-entrar"].tap()
        }

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
    }

    func testSairDoPerfilApagaSessaoEVoltaParaEntrada() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ENTRADA", "-FRILA_SCENARIO", "success"]
        app.launch()

        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.digitarEEsperar("existente@frila.app")
        tocar(app.buttons["entrada-receber-codigo"])
        let codigo = app.textFields["Código de acesso"]
        XCTAssertTrue(codigo.waitForExistence(timeout: 10))
        codigo.tap()
        codigo.typeText("123456")
        if app.buttons["codigo-entrar"].waitForExistence(timeout: 2) {
            app.buttons["codigo-entrar"].tap()
        }

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
        let botaoPerfil = app.buttons["abrir-meu-perfil"]
        XCTAssertTrue(botaoPerfil.waitForExistence(timeout: 10), "o botão para abrir o perfil deve aparecer na barra")
        botaoPerfil.tap()
        XCTAssertTrue(app.navigationBars["Meu perfil"].waitForExistence(timeout: 10))
        app.buttons["Sair"].tap()

        XCTAssertTrue(app.textFields["entrada-email"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.navigationBars["Meu perfil"].exists)
    }

    func testCodigoIncorretoExibeMensagemDeErro() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ENTRADA", "-FRILA_SCENARIO", "codigo-errado"]
        app.launch()

        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.digitarEEsperar("teste@frila.app")
        tocar(app.buttons["entrada-receber-codigo"])

        let tfCodigo = app.textFields["Código de acesso"]
        XCTAssertTrue(tfCodigo.waitForExistence(timeout: 10))
        tfCodigo.tap()
        tfCodigo.typeText("000000")
        tocar(app.buttons["codigo-entrar"])

        let aviso = app.descendants(matching: .any)["codigo-erro"]
        XCTAssertTrue(aviso.waitForExistence(timeout: Espera.aparecer))
        XCTAssertEqual(aviso.label, "Alerta: Código incorreto. Confira os números e tente novamente.")
    }

    func testMenorDeIdadeExibeRecusa() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ENTRADA", "-FRILA_SCENARIO", "primeiro-acesso"]
        app.launch()

        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.digitarEEsperar("jovem@frila.app")
        tocar(app.buttons["entrada-receber-codigo"])

        let tfCodigo = app.textFields["Código de acesso"]
        XCTAssertTrue(tfCodigo.waitForExistence(timeout: 10))
        tfCodigo.tap()
        tfCodigo.typeText("123456")
        if app.buttons["codigo-entrar"].waitForExistence(timeout: 2) {
            app.buttons["codigo-entrar"].tap()
        }

        XCTAssertTrue(app.staticTexts["Como você quer usar o Frila?"].waitForExistence(timeout: 10))
        let nome = app.textFields["cadastro-nome"]
        nome.tap()
        nome.typeText("Menor de Idade")

        let telefone = app.textFields["cadastro-telefone"]
        telefone.tap()
        telefone.digitarEEsperar("61988887777", esperado: "(61) 98888-7777")
        fecharTecladoSeVisivel(app: app)

        let nascimento = app.textFields["cadastro-nascimento"]
        rolarAte(nascimento, app: app)
        nascimento.tap()
        nascimento.digitarEEsperar("01/01/2015", esperado: "01/01/2015")

        let termos = app.buttons["cadastro-termos"]
        rolarAte(termos, app: app)
        termos.tap()

        XCTAssertTrue(app.staticTexts["cadastro-menor-idade-erro"].waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(app.staticTexts["O Frila é exclusivo para maiores de 18 anos."].exists)

        let continuar = app.buttons["cadastro-continuar"]
        rolarAte(continuar, app: app)
        XCTAssertFalse(continuar.isEnabled, "Botão Continuar deve estar bloqueado para menor de idade")
    }

    func testCadastroComDeclaredAgeRangeAbaixoDe18ExibeRecusa() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_ENTRADA",
            "-FRILA_SCENARIO", "primeiro-acesso",
            "-FRILA_DECLARED_AGE_RANGE", "abaixo-de-18"
        ]
        app.launch()

        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.digitarEEsperar("menor.declarado@frila.app")
        tocar(app.buttons["entrada-receber-codigo"])

        let tfCodigo = app.textFields["Código de acesso"]
        XCTAssertTrue(tfCodigo.waitForExistence(timeout: 10))
        tfCodigo.tap()
        tfCodigo.typeText("123456")
        if app.buttons["codigo-entrar"].waitForExistence(timeout: 2) {
            app.buttons["codigo-entrar"].tap()
        }

        XCTAssertTrue(app.staticTexts["Como você quer usar o Frila?"].waitForExistence(timeout: 10))
        let nome = app.textFields["cadastro-nome"]
        nome.tap()
        nome.typeText("Menor Pelo Sistema")

        let telefone = app.textFields["cadastro-telefone"]
        telefone.tap()
        telefone.digitarEEsperar("61988887777", esperado: "(61) 98888-7777")
        fecharTecladoSeVisivel(app: app)

        let nascimento = app.textFields["cadastro-nascimento"]
        rolarAte(nascimento, app: app)
        nascimento.tap()
        // Data de nascimento indica mais de 18 anos (passa na validação local da data)
        nascimento.digitarEEsperar("01/01/2000", esperado: "01/01/2000")
        fecharTecladoSeVisivel(app: app)

        let termos = app.buttons["cadastro-termos"]
        rolarAte(termos, app: app)
        termos.tap()

        let continuar = app.buttons["cadastro-continuar"]
        rolarAte(continuar, app: app)
        continuar.tap()

        // O sinal Declared Age Range diz que é menor de 18: recusa com a mensagem da RN20
        XCTAssertTrue(app.descendants(matching: .any)["cadastro-erro"].waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(app.staticTexts["O Frila é exclusivo para maiores de 18 anos."].exists)
    }

    func testCadastroBloqueiaMenorDeIdadeEValidaTermosAoTocarContinuar() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ENTRADA", "-FRILA_SCENARIO", "primeiro-acesso"]
        app.launch()

        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.digitarEEsperar("novo@frila.app")
        tocar(app.buttons["entrada-receber-codigo"])

        let tfCodigo = app.textFields["Código de acesso"]
        XCTAssertTrue(tfCodigo.waitForExistence(timeout: 10))
        tfCodigo.tap()
        tfCodigo.typeText("123456")
        if app.buttons["codigo-entrar"].waitForExistence(timeout: 2) {
            app.buttons["codigo-entrar"].tap()
        }

        XCTAssertTrue(app.staticTexts["Como você quer usar o Frila?"].waitForExistence(timeout: 10))
        let nome = app.textFields["cadastro-nome"]
        nome.tap()
        nome.typeText("Novo Usuário")

        let telefone = app.textFields["cadastro-telefone"]
        telefone.tap()
        telefone.digitarEEsperar("61988887777", esperado: "(61) 98888-7777")
        fecharTecladoSeVisivel(app: app)

        let nascimento = app.textFields["cadastro-nascimento"]
        rolarAte(nascimento, app: app)
        nascimento.tap()
        nascimento.digitarEEsperar("15/05/1995", esperado: "15/05/1995")
        fecharTecladoSeVisivel(app: app)

        let btnContinuar = app.buttons["cadastro-continuar"]
        rolarAte(btnContinuar, app: app)
        XCTAssertTrue(btnContinuar.isEnabled, "Botão deve estar habilitado para maior de idade")

        // Toca Continuar sem marcar termos: exibe erro destacando os termos
        btnContinuar.tap()
        XCTAssertTrue(app.descendants(matching: .any)["cadastro-erro"].waitForExistence(timeout: Espera.aparecer))

        // Marca termos e confere que continua habilitado
        let termos = app.buttons["cadastro-termos"]
        rolarAte(termos, app: app)
        termos.tap()
        rolarAte(btnContinuar, app: app)
        XCTAssertTrue(btnContinuar.isEnabled, "Botão deve continuar habilitado com os termos aceitos")
    }

    func testCapturasDeTelaCadastro() {
        let pastaCapturas = "/Users/cauecarneiro/Documents/Projetos/Apps/.workers/missoes/capturas/2026-10-17-ux-01-autenticacao"
        try? FileManager.default.createDirectory(atPath: pastaCapturas, withIntermediateDirectories: true)

        func salvar(_ app: XCUIApplication, nome: String) {
            let screenshot = app.screenshot()
            let anexo = XCTAttachment(screenshot: screenshot)
            anexo.name = nome
            anexo.lifetime = .keepAlways
            add(anexo)
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "\(pastaCapturas)/\(nome)"))
        }

        // 1. Tamanho padrão
        let appPadrao = XCUIApplication()
        appPadrao.launchArguments = ["-FRILA_ENTRADA", "-FRILA_SCENARIO", "primeiro-acesso"]
        AjudanteDeLancamentoUITests.preparar(appPadrao)
        appPadrao.launch()

        let email = appPadrao.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.digitarEEsperar("novo@frila.app")
        tocar(appPadrao.buttons["entrada-receber-codigo"])

        let tfCodigo = appPadrao.textFields["Código de acesso"]
        XCTAssertTrue(tfCodigo.waitForExistence(timeout: 10))
        tfCodigo.tap()
        tfCodigo.typeText("123456")
        if appPadrao.buttons["codigo-entrar"].waitForExistence(timeout: 2) {
            appPadrao.buttons["codigo-entrar"].tap()
        }

        XCTAssertTrue(appPadrao.staticTexts["Como você quer usar o Frila?"].waitForExistence(timeout: 10))
        let nome = appPadrao.textFields["cadastro-nome"]
        nome.tap()
        nome.typeText("Carlos Silva")

        let telefone = appPadrao.textFields["cadastro-telefone"]
        telefone.tap()
        telefone.digitarEEsperar("61988887777", esperado: "(61) 98888-7777")
        fecharTecladoSeVisivel(app: appPadrao)

        let nascimento = appPadrao.textFields["cadastro-nascimento"]
        rolarAte(nascimento, app: appPadrao)
        nascimento.tap()
        nascimento.digitarEEsperar("15/05/1995", esperado: "15/05/1995")
        fecharTecladoSeVisivel(app: appPadrao)

        let termos = appPadrao.buttons["cadastro-termos"]
        rolarAte(termos, app: appPadrao)
        termos.tap()

        salvar(appPadrao, nome: "01-cadastro-padrao.png")

        // 2. Maior tamanho de texto (AX5)
        let appAX5 = XCUIApplication()
        appAX5.launchArguments = [
            "-FRILA_ENTRADA",
            "-FRILA_SCENARIO", "primeiro-acesso",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        AjudanteDeLancamentoUITests.preparar(appAX5)
        appAX5.launch()

        let emailAX5 = appAX5.textFields["entrada-email"]
        XCTAssertTrue(emailAX5.waitForExistence(timeout: 10))
        emailAX5.tap()
        emailAX5.digitarEEsperar("novo@frila.app")
        tocar(appAX5.buttons["entrada-receber-codigo"])

        let tfCodigoAX5 = appAX5.textFields["Código de acesso"]
        XCTAssertTrue(tfCodigoAX5.waitForExistence(timeout: 10))
        tfCodigoAX5.tap()
        tfCodigoAX5.typeText("123456")
        if appAX5.buttons["codigo-entrar"].waitForExistence(timeout: 2) {
            appAX5.buttons["codigo-entrar"].tap()
        }

        XCTAssertTrue(appAX5.staticTexts["Como você quer usar o Frila?"].waitForExistence(timeout: 10))
        let nomeAX5 = appAX5.textFields["cadastro-nome"]
        nomeAX5.tap()
        nomeAX5.typeText("Carlos Silva")

        let telefoneAX5 = appAX5.textFields["cadastro-telefone"]
        telefoneAX5.tap()
        telefoneAX5.digitarEEsperar("61988887777", esperado: "(61) 98888-7777")
        fecharTecladoSeVisivel(app: appAX5)

        let nascimentoAX5 = appAX5.textFields["cadastro-nascimento"]
        rolarAte(nascimentoAX5, app: appAX5)
        nascimentoAX5.tap()
        nascimentoAX5.digitarEEsperar("15/05/1995", esperado: "15/05/1995")
        fecharTecladoSeVisivel(app: appAX5)

        salvar(appAX5, nome: "02-cadastro-ax5.png")

        // 3. Menor de 18 anos com erro inline (tamanho padrão)
        let appMenor = XCUIApplication()
        appMenor.launchArguments = ["-FRILA_ENTRADA", "-FRILA_SCENARIO", "primeiro-acesso"]
        AjudanteDeLancamentoUITests.preparar(appMenor)
        appMenor.launch()

        let emailMenor = appMenor.textFields["entrada-email"]
        XCTAssertTrue(emailMenor.waitForExistence(timeout: 10))
        emailMenor.tap()
        emailMenor.digitarEEsperar("jovem@frila.app")
        tocar(appMenor.buttons["entrada-receber-codigo"])

        let tfCodigoMenor = appMenor.textFields["Código de acesso"]
        XCTAssertTrue(tfCodigoMenor.waitForExistence(timeout: 10))
        tfCodigoMenor.tap()
        tfCodigoMenor.typeText("123456")
        if appMenor.buttons["codigo-entrar"].waitForExistence(timeout: 2) {
            appMenor.buttons["codigo-entrar"].tap()
        }

        XCTAssertTrue(appMenor.staticTexts["Como você quer usar o Frila?"].waitForExistence(timeout: 10))
        let nomeMenor = appMenor.textFields["cadastro-nome"]
        nomeMenor.tap()
        nomeMenor.typeText("Menor de Idade")

        let telefoneMenor = appMenor.textFields["cadastro-telefone"]
        telefoneMenor.tap()
        telefoneMenor.digitarEEsperar("61988887777", esperado: "(61) 98888-7777")
        fecharTecladoSeVisivel(app: appMenor)

        let nascimentoMenor = appMenor.textFields["cadastro-nascimento"]
        rolarAte(nascimentoMenor, app: appMenor)
        nascimentoMenor.tap()
        nascimentoMenor.digitarEEsperar("15102010", esperado: "15/10/2010")
        fecharTecladoSeVisivel(app: appMenor)

        let erroMenor = appMenor.descendants(matching: .any)["cadastro-menor-idade-erro"]
        XCTAssertTrue(erroMenor.waitForExistence(timeout: Espera.aparecer))
        let btnContinuarMenor = appMenor.buttons["cadastro-continuar"]
        rolarAte(btnContinuarMenor, app: appMenor)
        XCTAssertFalse(btnContinuarMenor.isEnabled)

        salvar(appMenor, nome: "03-cadastro-menor-idade.png")
    }
}

/// Validação de interface das telas de perfil (#54).
@MainActor
final class PerfilUITests: XCTestCase {
    /// O formulário de "Funções e horários" guarda o que carregou enquanto a tela está aberta: um
    /// redesenho de "Meu perfil" (aqui, a troca de aba) não pode trocá-lo por um formulário vazio.
    func testEdicaoDoPerfilMantemOQueCarregouQuandoATelaDeCimaRedesenha() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success"]
        app.launch()

        XCTAssertTrue(app.buttons["abrir-meu-perfil"].waitForExistence(timeout: 15))
        app.buttons["abrir-meu-perfil"].tap()
        let funcoesEHorarios = app.descendants(matching: .any)["perfil-funcoes-horarios"]
        XCTAssertTrue(funcoesEHorarios.waitForExistence(timeout: 10))
        funcoesEHorarios.tap()

        let funcao = app.buttons["pill-funcao-20000000-0000-0000-0000-000000000001"]
        let horario = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'remover-janela-'")).firstMatch
        XCTAssertTrue(funcao.waitForExistence(timeout: 10))
        XCTAssertTrue(horario.waitForExistence(timeout: Espera.aparecer))

        app.tabBars.buttons["Meus turnos"].tap()
        XCTAssertFalse(funcao.waitForExistence(timeout: 2))
        app.tabBars.buttons["Vagas no DF"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["tela-perfil-profissional"].waitForExistence(timeout: 10))
        XCTAssertTrue(funcao.waitForExistence(timeout: Espera.aparecer), "as funções carregadas continuam no formulário")
        XCTAssertTrue(horario.exists, "os horários carregados continuam no formulário")
    }

    func testMeuPerfilAbreAjudaComLinksDeTermosEPrivacidade() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))

        let botaoPerfil = app.buttons["abrir-meu-perfil"]
        XCTAssertTrue(botaoPerfil.waitForExistence(timeout: Espera.aparecer))
        botaoPerfil.tap()

        XCTAssertTrue(app.navigationBars["Meu perfil"].waitForExistence(timeout: Espera.aparecer))

        let botaoAjuda = app.buttons["perfil-ajuda"]
        if !botaoAjuda.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(botaoAjuda.waitForExistence(timeout: Espera.aparecer))
        botaoAjuda.tap()

        XCTAssertTrue(app.navigationBars["Ajuda"].waitForExistence(timeout: Espera.aparecer))

        let suporte = app.descendants(matching: .any)["perfil-suporte"]
        XCTAssertTrue(suporte.waitForExistence(timeout: Espera.aparecer), "perfil-suporte deve existir na tela de ajuda")

        let emailSuporte = app.descendants(matching: .any)["perfil-suporte-email"]
        XCTAssertTrue(emailSuporte.waitForExistence(timeout: Espera.aparecer), "perfil-suporte-email deve existir na tela de ajuda")
        XCTAssertTrue(emailSuporte.label.contains("suporte@frilabr.com"), "o endereço de suporte deve ser visível")

        let linkTermos = app.descendants(matching: .any)["perfil-termos"]
        let linkPrivacidade = app.descendants(matching: .any)["perfil-privacidade"]

        XCTAssertTrue(linkTermos.waitForExistence(timeout: Espera.aparecer), "perfil-termos deve existir na tela de ajuda")
        XCTAssertTrue(linkPrivacidade.waitForExistence(timeout: Espera.aparecer), "perfil-privacidade deve existir na tela de ajuda")
        XCTAssertTrue(linkTermos.isHittable)
        XCTAssertTrue(linkPrivacidade.isHittable)
        XCTAssertTrue(app.links["perfil-termos"].exists || linkTermos.elementType == .link || linkTermos.elementType == .button, "deve ser um link")
        XCTAssertTrue(app.links["perfil-privacidade"].exists || linkPrivacidade.elementType == .link || linkPrivacidade.elementType == .button, "deve ser um link")

        let botaoLicencas = app.descendants(matching: .any)["perfil-licencas"]
        XCTAssertTrue(botaoLicencas.waitForExistence(timeout: Espera.aparecer), "perfil-licencas deve existir na tela de ajuda")
    }

    func testPerfilEstabelecimentoAbreAjudaComLinksDeTermosEPrivacidade() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "contratante"]
        app.launch()

        let botaoPerfil = app.buttons["abrir-perfil-estabelecimento"]
        XCTAssertTrue(botaoPerfil.waitForExistence(timeout: 10), "botão de abrir perfil do estabelecimento deve existir")
        botaoPerfil.tap()

        XCTAssertTrue(app.navigationBars["Perfil do estabelecimento"].waitForExistence(timeout: Espera.aparecer))

        let botaoAjuda = app.buttons["perfil-ajuda"]
        if !botaoAjuda.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(botaoAjuda.waitForExistence(timeout: Espera.aparecer))
        botaoAjuda.tap()

        XCTAssertTrue(app.navigationBars["Ajuda"].waitForExistence(timeout: Espera.aparecer))

        let suporte = app.descendants(matching: .any)["perfil-suporte"]
        XCTAssertTrue(suporte.waitForExistence(timeout: Espera.aparecer), "perfil-suporte deve existir na tela de ajuda")

        let emailSuporte = app.descendants(matching: .any)["perfil-suporte-email"]
        XCTAssertTrue(emailSuporte.waitForExistence(timeout: Espera.aparecer), "perfil-suporte-email deve existir na tela de ajuda")
        XCTAssertTrue(emailSuporte.label.contains("suporte@frilabr.com"), "o endereço de suporte deve ser visível")

        let linkTermos = app.descendants(matching: .any)["perfil-termos"]
        let linkPrivacidade = app.descendants(matching: .any)["perfil-privacidade"]

        XCTAssertTrue(linkTermos.waitForExistence(timeout: Espera.aparecer), "perfil-termos deve existir na tela de ajuda")
        XCTAssertTrue(linkPrivacidade.waitForExistence(timeout: Espera.aparecer), "perfil-privacidade deve existir na tela de ajuda")
        XCTAssertTrue(linkTermos.isHittable)
        XCTAssertTrue(linkPrivacidade.isHittable)
        XCTAssertTrue(app.links["perfil-termos"].exists || linkTermos.elementType == .link || linkTermos.elementType == .button, "deve ser um link")
        XCTAssertTrue(app.links["perfil-privacidade"].exists || linkPrivacidade.elementType == .link || linkPrivacidade.elementType == .button, "deve ser um link")

        let botaoLicencas = app.descendants(matching: .any)["perfil-licencas"]
        XCTAssertTrue(botaoLicencas.waitForExistence(timeout: Espera.aparecer), "perfil-licencas deve existir na tela de ajuda")
    }

    func testMeuPerfilAjudaAbreLicencasDeTerceirosComPacoteConhecido() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))

        let botaoPerfil = app.buttons["abrir-meu-perfil"]
        XCTAssertTrue(botaoPerfil.waitForExistence(timeout: Espera.aparecer))
        botaoPerfil.tap()

        XCTAssertTrue(app.navigationBars["Meu perfil"].waitForExistence(timeout: Espera.aparecer))

        let botaoAjuda = app.buttons["perfil-ajuda"]
        if !botaoAjuda.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(botaoAjuda.waitForExistence(timeout: Espera.aparecer))
        botaoAjuda.tap()

        XCTAssertTrue(app.navigationBars["Ajuda"].waitForExistence(timeout: Espera.aparecer))

        let botaoLicencas = app.descendants(matching: .any)["perfil-licencas"]
        XCTAssertTrue(botaoLicencas.waitForExistence(timeout: Espera.aparecer), "perfil-licencas deve existir na tela de ajuda")
        XCTAssertTrue(botaoLicencas.isHittable)
        botaoLicencas.tap()

        XCTAssertTrue(app.navigationBars["Licenças de código aberto"].waitForExistence(timeout: Espera.aparecer))

        let pacote = app.descendants(matching: .any)["licenca-abseil-cpp-binary"]
        XCTAssertTrue(pacote.waitForExistence(timeout: Espera.aparecer), "a lista deve exibir pelo menos um pacote conhecido")
    }

    func testMeuPerfilAbreExplicacaoPorQueReceboVagasComTextoAprovado() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))

        let botaoPerfil = app.buttons["abrir-meu-perfil"]
        XCTAssertTrue(botaoPerfil.waitForExistence(timeout: Espera.aparecer))
        botaoPerfil.tap()

        XCTAssertTrue(app.navigationBars["Meu perfil"].waitForExistence(timeout: Espera.aparecer))

        var botaoPorQueRecebo = app.buttons["perfil-por-que-recebo"]
        if !botaoPorQueRecebo.exists && !botaoPorQueRecebo.waitForExistence(timeout: 2) {
            botaoPorQueRecebo = app.buttons["Por que recebo vagas"]
        }
        if !botaoPorQueRecebo.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(botaoPorQueRecebo.waitForExistence(timeout: Espera.aparecer))
        botaoPorQueRecebo.tap()

        XCTAssertTrue(app.navigationBars["Por que recebo vagas"].waitForExistence(timeout: Espera.aparecer))

        let textoExplicacao = app.descendants(matching: .any)["perfil-explicacao-vagas"]
        XCTAssertTrue(textoExplicacao.waitForExistence(timeout: Espera.aparecer), "o texto explicativo deve existir")
        let fraseEsperada = "Você recebe notificações de vagas da sua função, a até 15 km do seu ponto base, quando o turno inteiro cabe nos horários em que você marcou disponibilidade. Todas as vagas do DF aparecem na lista."
        XCTAssertEqual(textoExplicacao.label, fraseEsperada)

        let botaoFechar = app.buttons["fechar-explicacao-vagas"].exists ? app.buttons["fechar-explicacao-vagas"] : app.buttons["Fechar"]
        XCTAssertTrue(botaoFechar.waitForExistence(timeout: Espera.aparecer), "o botão fechar deve existir")
        botaoFechar.tap()

        XCTAssertTrue(app.navigationBars["Meu perfil"].waitForExistence(timeout: Espera.aparecer))
    }
}

extension XCUIElement {
    /// Digita e só devolve quando o campo mostra o texto inteiro.
    ///
    /// Com o teclado recém-aberto, `typeText` devolve antes de o teclado entregar todas as teclas
    /// ao campo. O toque seguinte chegava com o e-mail pela metade: a Entrada respondia
    /// "Informe um e-mail válido." e a tela do código nunca abria. Para campos com máscara onde
    /// a formatação intermediária varia durante a edição, informe `esperado` para validar
    /// contenção do texto ou equivalência dos dígitos numéricos.
    func digitarEEsperar(_ texto: String, esperado: String? = nil, timeout: TimeInterval = Espera.aparecer, file: StaticString = #filePath, line: UInt = #line) {
        let valorEsperado = esperado ?? (texto.hasSuffix("\n") ? String(texto.dropLast()) : texto)

        if let esperado, esperado != texto || !esperado.filter(\.isNumber).isEmpty {
            // Em campos mascarados (telefone, data, valor), digita em pedaços curtos
            // e aguarda o campo registrar cada pedaço antes de enviar o próximo, evitando que
            // a reescrita síncrona do UITextField pelo SwiftUI descarte teclas rápidas contínuas.
            let pedacos = Self.quebrarEmPedacos(texto)
            for pedaco in pedacos {
                let digitosAntes = ((value as? String) ?? "").filter(\.isNumber).count
                let novosDigitos = pedaco.filter(\.isNumber).count
                typeText(pedaco)
                if novosDigitos > 0 {
                    let predicadoPasso = NSPredicate { elemento, _ in
                        guard let elemento = elemento as? XCUIElement,
                              let atual = elemento.value as? String else { return false }
                        return atual.filter(\.isNumber).count >= digitosAntes + novosDigitos
                    }
                    let esperaPasso = XCTNSPredicateExpectation(predicate: predicadoPasso, object: self)
                    _ = XCTWaiter.wait(for: [esperaPasso], timeout: 2.0)
                }
            }
        } else {
            typeText(texto)
        }

        let predicado = NSPredicate { elemento, _ in
            guard let elemento = elemento as? XCUIElement, let atual = elemento.value as? String else { return false }
            if let esperado {
                return atual == esperado ||
                    atual.contains(esperado) ||
                    (!esperado.filter(\.isNumber).isEmpty && atual.filter(\.isNumber) == esperado.filter(\.isNumber))
            }
            return atual == valorEsperado
        }
        let espera = XCTNSPredicateExpectation(predicate: predicado, object: self)
        let resultado = XCTWaiter.wait(for: [espera], timeout: timeout)
        if resultado != .completed {
            XCTAssertEqual(
                value as? String, valorEsperado,
                "O campo deveria mostrar \"\(valorEsperado)\" depois da digitação", file: file, line: line
            )
        }
    }

    private static func quebrarEmPedacos(_ texto: String) -> [String] {
        let digitos = texto.filter(\.isNumber)
        // Telefone celular (11 dígitos): DDD (2), prefixo (5), sufixo (4)
        if digitos.count == 11 {
            let ddd = String(digitos.prefix(2))
            let meio = String(digitos.dropFirst(2).prefix(5))
            let fim = String(digitos.suffix(4))
            return [ddd, meio, fim]
        }
        // Telefone fixo (10 dígitos): DDD (2), prefixo (4), sufixo (4)
        if digitos.count == 10 {
            let ddd = String(digitos.prefix(2))
            let meio = String(digitos.dropFirst(2).prefix(4))
            let fim = String(digitos.suffix(4))
            return [ddd, meio, fim]
        }
        // Data civil (8 dígitos): dia (2), mês (2), ano (4)
        if digitos.count == 8 {
            let dia = String(digitos.prefix(2))
            let mes = String(digitos.dropFirst(2).prefix(2))
            let ano = String(digitos.suffix(4))
            return [dia, mes, ano]
        }
        // Se já vier com barras (ex.: partes separadas por barra)
        if texto.contains("/") {
            let partes = texto.split(separator: "/").map(String.init)
            if !partes.isEmpty { return partes }
        }
        // Padrão genérico: pedaços de até 3 caracteres
        var pedacos: [String] = []
        var resto = texto[...]
        while !resto.isEmpty {
            let pedaco = String(resto.prefix(3))
            pedacos.append(pedaco)
            resto = resto.dropFirst(3)
        }
        return pedacos.isEmpty ? [texto] : pedacos
    }
}

enum DirecaoRolagem: Equatable {
    case nenhuma
    case rolarParaCima    // swipeUp (conteúdo sobe para revelar o que está abaixo)
    case rolarParaBaixo   // swipeDown (conteúdo desce para revelar o que está acima)
}

/// Decide a direção de rolagem com base na posição do elemento em relação à área visível da tela.
/// Se o topo do elemento estiver acima da margem superior (`minY < margemSuperior`), ele precisa
/// descer para a área visível, portanto a rolagem deve ser para baixo (`swipeDown`).
/// Anteriormente, a verificação avaliava `!isHittable` junto de `maxY > ...`, fazendo com que elementos
/// que ficassem acima da tela rolassem para cima (`swipeUp`), afastando-se ainda mais da área visível.
func direcaoParaTrazerParaATela(
    quadro: CGRect,
    alturaJanela: CGFloat,
    margemSuperior: CGFloat = 120,
    margemInferior: CGFloat = 60,
    isHittable: Bool = true
) -> DirecaoRolagem {
    let visivel = isHittable
        && quadro.minY >= margemSuperior
        && quadro.maxY <= (alturaJanela - margemInferior)
    if visivel { return .nenhuma }

    if quadro.minY < margemSuperior {
        return .rolarParaBaixo
    } else if quadro.maxY > (alturaJanela - margemInferior) || !isHittable {
        return .rolarParaCima
    }
    return .nenhuma
}

final class TrazerParaATelaCalculoTests: XCTestCase {
    func testElementoAcimaDaAreaVisivelRolaParaBaixoMesmoNaoHittable() {
        // Elemento com topo acima da margem superior (ex: rolado para cima, minY = -50, isHittable = false)
        let quadro = CGRect(x: 20, y: -50, width: 200, height: 40)
        let direcao = direcaoParaTrazerParaATela(
            quadro: quadro,
            alturaJanela: 800,
            margemSuperior: 120,
            margemInferior: 60,
            isHittable: false
        )
        // Deve rolar para baixo (swipeDown) para trazer o elemento de volta à tela
        XCTAssertEqual(direcao, .rolarParaBaixo)
    }

    func testElementoAbaixoDaAreaVisivelRolaParaCima() {
        // Elemento com base abaixo da margem inferior (ex: minY = 750, maxY = 850, janela = 800)
        let quadro = CGRect(x: 20, y: 750, width: 200, height: 100)
        let direcao = direcaoParaTrazerParaATela(
            quadro: quadro,
            alturaJanela: 800,
            margemSuperior: 120,
            margemInferior: 60,
            isHittable: false
        )
        XCTAssertEqual(direcao, .rolarParaCima)
    }

    func testElementoVisivelEHittableNaoRola() {
        let quadro = CGRect(x: 20, y: 300, width: 200, height: 50)
        let direcao = direcaoParaTrazerParaATela(
            quadro: quadro,
            alturaJanela: 800,
            margemSuperior: 120,
            margemInferior: 60,
            isHittable: true
        )
        XCTAssertEqual(direcao, .nenhuma)
    }

    func testElementoDentroDosLimitesMasNaoHittableRolaParaCima() {
        // Fallback: se está geometricamente dentro mas não está hittable (ex: sob sobreposição)
        let quadro = CGRect(x: 20, y: 300, width: 200, height: 50)
        let direcao = direcaoParaTrazerParaATela(
            quadro: quadro,
            alturaJanela: 800,
            margemSuperior: 120,
            margemInferior: 60,
            isHittable: false
        )
        XCTAssertEqual(direcao, .rolarParaCima)
    }
}

