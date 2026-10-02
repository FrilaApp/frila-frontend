import XCTest

@MainActor
final class FrilaUITests: XCTestCase {
    func testCatalogoAbreEmPortugues() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_CATALOGO", "-FRILA_SCENARIO", "success", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Frila UI"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Continuar"].exists)
    }

    func testCatalogoComTamanhoDeAcessibilidade() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_CATALOGO", "-FRILA_SCENARIO", "success", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Frila UI"].waitForExistence(timeout: 5))
    }

    func testConflitoTipadoDoClienteChegaATela() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_CATALOGO", "-FRILA_SCENARIO", "vaga-preenchida"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Validação do cliente"].waitForExistence(timeout: 5))
        app.buttons["Simular vaga preenchida"].tap()
        XCTAssertTrue(app.staticTexts["Esta vaga acabou de ser preenchida. Escolha outra oportunidade."].waitForExistence(timeout: 5))
    }

    func testSolicitacaoDeAcessoChegaAoClienteSemExporOEmailNaTelaDeResultado() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_CATALOGO", "-FRILA_SCENARIO", "success"]
        app.launch()

        let email = app.textFields["validacao-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        email.digitarEEsperar("teste@frila.app")
        app.buttons["Enviar código"].tap()

        XCTAssertTrue(app.staticTexts["Código enviado. Consulte a caixa de entrada do e-mail de teste."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["teste@frila.app"].exists)
    }

    func testConfirmarCodigoAbreASessaoSemMostrarDadosDeAcesso() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_CATALOGO", "-FRILA_SCENARIO", "success"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Nenhuma sessão neste aparelho."].waitForExistence(timeout: 5))
        let email = app.textFields["validacao-email"]
        email.tap()
        email.digitarEEsperar("teste@frila.app")
        app.buttons["Enviar código"].tap()
        XCTAssertTrue(app.staticTexts["Código enviado. Consulte a caixa de entrada do e-mail de teste."].waitForExistence(timeout: 5))

        let codigo = app.textFields["validacao-codigo"]
        codigo.tap()
        codigo.typeText("123456")
        app.buttons["Confirmar código"].tap()

        XCTAssertTrue(app.staticTexts["Sessão ativa neste aparelho."].waitForExistence(timeout: 5))
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
        XCTAssertTrue(aviso.label.contains("seu telefone e WhatsApp serão mostrados"))
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
        XCTAssertTrue(bartender.waitForExistence(timeout: 5))
        bartender.tap()
        XCTAssertTrue(app.descendants(matching: .any)["vagas-vazio"].waitForExistence(timeout: 10))
    }

    func testErroDaAPIMostraOEstadoDeErroComTentarNovamente() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "erro-na-lista"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["vagas-erro"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Tentar novamente"].exists)
    }

    func testSemRedeMostraOEstadoSemConexao() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "sem-rede"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["vagas-sem-conexao"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Tentar novamente"].exists)
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
        let primeira = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-'")).firstMatch
        XCTAssertTrue(primeira.waitForExistence(timeout: 25), "a primeira vaga deve aparecer na lista após o carregamento inicial")
        primeira.tap()
        XCTAssertTrue(app.descendants(matching: .any)["tela-detalhe-vaga"].waitForExistence(timeout: 10), "a tela de detalhe da vaga deve aparecer após o toque no cartão")
        let candidatar = app.buttons["candidatar"]
        XCTAssertTrue(candidatar.waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any)["aviso-rn10"].waitForExistence(timeout: 10), "o aviso da RN10 vem antes de Candidatar-me")
        candidatar.tap()
        return app
    }

    func testConfirmadaAbreMeuTurnoComOContato() {
        let app = abrirDetalheECandidatar("success")
        XCTAssertTrue(app.descendants(matching: .any)["resultado-confirmada"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["contato-do-turno"].exists)
        app.buttons["voltar-para-lista"].tap()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["1 vaga aberta"].waitForExistence(timeout: 10), "a lista é atualizada após a confirmação")
    }

    func testVagaPreenchidaTemTelaPropriaEVoltaParaALista() {
        let app = abrirDetalheECandidatar("vaga-preenchida")
        XCTAssertTrue(app.descendants(matching: .any)["resultado-vaga-preenchida"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["resultado-vaga-encerrada"].exists)
        app.buttons["voltar-para-lista-navegacao"].tap()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
    }

    func testVagaEncerradaTemTelaPropriaDiferenteDaPreenchida() {
        let app = abrirDetalheECandidatar("vaga-encerrada")
        XCTAssertTrue(app.descendants(matching: .any)["resultado-vaga-encerrada"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["resultado-vaga-preenchida"].exists)
        app.buttons["voltar-para-lista"].tap()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
    }

    func testTurnoSobrepostoMostraOConflitoSemApontarTurno() {
        let app = abrirDetalheECandidatar("inelegivel")
        XCTAssertTrue(app.descendants(matching: .any)["resultado-turno-sobreposto"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["ver-meu-turno"].exists, "sem link para um turno específico")
        app.buttons["voltar-para-lista"].tap()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 15))
    }

    func testContaSuspensaMostraOMotivoEContestarDesabilitado() {
        let app = abrirDetalheECandidatar("inelegivel-suspenso")
        XCTAssertTrue(app.descendants(matching: .any)["resultado-conta-suspensa"].waitForExistence(timeout: 10))
        let contestar = app.buttons["contestar"]
        XCTAssertTrue(contestar.exists)
        XCTAssertFalse(contestar.isEnabled)
    }

    func testResultadoComTamanhoDeAcessibilidadeMantemOBotaoDeVolta() {
        let app = abrirDetalheECandidatar("vaga-preenchida", argumentos: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(app.descendants(matching: .any)["resultado-vaga-preenchida"].waitForExistence(timeout: 10))
        let voltar = app.buttons["voltar-para-lista"]
        XCTAssertTrue(voltar.waitForExistence(timeout: 5))
        voltar.tap()
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
        app.buttons["candidatar"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["resultado-confirmada"].waitForExistence(timeout: 10))
    }
}

@MainActor
final class AutenticacaoUITests: XCTestCase {
    func testFluxoCompletoPrimeiroAcessoAteVagas() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ENTRADA", "-FRILA_SCENARIO", "primeiro-acesso", "-FRILA_BUSCA_PERFIL_UI_TEST"]
        app.launch()

        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.digitarEEsperar("novo@frila.app")
        app.buttons["entrada-receber-codigo"].tap()

        let tfCodigo = app.textFields["Código de acesso"]
        XCTAssertTrue(tfCodigo.waitForExistence(timeout: 10))
        tfCodigo.tap()
        tfCodigo.typeText("123456")
        app.buttons["codigo-entrar"].tap()

        XCTAssertTrue(app.staticTexts["Como você vai usar o Frila?"].waitForExistence(timeout: 10))
        app.buttons["cadastro-perfil-profissional"].tap()
        let nome = app.textFields["cadastro-nome"]
        nome.tap()
        nome.typeText("Novo Usuário")

        let telefone = app.textFields["cadastro-telefone"]
        telefone.tap()
        telefone.typeText("61988887777")

        let nascimento = app.textFields["cadastro-nascimento"]
        nascimento.tap()
        nascimento.typeText("15/05/1995")

        app.buttons["cadastro-maior-de-idade"].tap()
        app.buttons["cadastro-termos"].tap()

        app.buttons["cadastro-continuar"].tap()

        preencherPerfil(app)
        app.buttons["botao-salvar-perfil"].tap()
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
        app.buttons["botao-salvar-perfil"].tap()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
    }

    func testErroAoCriarPerfilPermiteRepetirEAbrirVagas() {
        let app = abrirCriacaoPerfil("erro-criacao-perfil-profissional")
        preencherPerfil(app)
        app.buttons["botao-salvar-perfil"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["aviso-erro-perfil"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["criacao-perfil-sair"].isHittable)
        XCTAssertTrue(app.buttons["botao-salvar-perfil"].isEnabled)
        app.buttons["botao-salvar-perfil"].tap()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
    }

    func testErroAoCriarPerfilPermiteSair() {
        let app = abrirCriacaoPerfil("erro-criacao-perfil-profissional")
        preencherPerfil(app)
        app.buttons["botao-salvar-perfil"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["aviso-erro-perfil"].waitForExistence(timeout: 10))
        app.buttons["criacao-perfil-sair"].tap()
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
        rolarAte(app.buttons["botao-adicionar-janela"], app: app)
        app.buttons["botao-adicionar-janela"].tap()
        rolarAte(app.buttons["botao-salvar-perfil"], app: app)
    }

    private func rolarAte(_ elemento: XCUIElement, app: XCUIApplication) {
        for _ in 0..<6 {
            if elemento.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(elemento.isHittable)
    }

    func testContaExistentePulaCadastroEAbreVagas() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ENTRADA", "-FRILA_SCENARIO", "success"]
        app.launch()

        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.digitarEEsperar("existente@frila.app")
        app.buttons["entrada-receber-codigo"].tap()

        let tfCodigo = app.textFields["Código de acesso"]
        XCTAssertTrue(tfCodigo.waitForExistence(timeout: 10))
        tfCodigo.tap()
        tfCodigo.typeText("123456")
        app.buttons["codigo-entrar"].tap()

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
        app.buttons["entrada-receber-codigo"].tap()
        let codigo = app.textFields["Código de acesso"]
        XCTAssertTrue(codigo.waitForExistence(timeout: 10))
        codigo.tap()
        codigo.typeText("123456")
        app.buttons["codigo-entrar"].tap()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
        app.buttons["abrir-meu-perfil"].tap()
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
        app.buttons["entrada-receber-codigo"].tap()

        let tfCodigo = app.textFields["Código de acesso"]
        XCTAssertTrue(tfCodigo.waitForExistence(timeout: 10))
        tfCodigo.tap()
        tfCodigo.typeText("000000")
        app.buttons["codigo-entrar"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["codigo-erro"].waitForExistence(timeout: 5))
    }

    func testMenorDeIdadeExibeRecusa() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ENTRADA", "-FRILA_SCENARIO", "primeiro-acesso"]
        app.launch()

        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.digitarEEsperar("jovem@frila.app")
        app.buttons["entrada-receber-codigo"].tap()

        let tfCodigo = app.textFields["Código de acesso"]
        XCTAssertTrue(tfCodigo.waitForExistence(timeout: 10))
        tfCodigo.tap()
        tfCodigo.typeText("123456")
        app.buttons["codigo-entrar"].tap()

        XCTAssertTrue(app.staticTexts["Como você vai usar o Frila?"].waitForExistence(timeout: 10))
        let nome = app.textFields["cadastro-nome"]
        nome.tap()
        nome.typeText("Menor de Idade")

        let telefone = app.textFields["cadastro-telefone"]
        telefone.tap()
        telefone.typeText("61988887777")

        let nascimento = app.textFields["cadastro-nascimento"]
        nascimento.tap()
        nascimento.typeText("01/01/2015")

        app.buttons["cadastro-maior-de-idade"].tap()
        app.buttons["cadastro-termos"].tap()

        app.buttons["cadastro-continuar"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["cadastro-erro"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["O Frila é exclusivo para maiores de 18 anos."].exists)
    }

    func testCadastroDesabilitaBotaoSemMaioridadeOuSemTermos() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ENTRADA", "-FRILA_SCENARIO", "primeiro-acesso"]
        app.launch()

        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.digitarEEsperar("novo@frila.app")
        app.buttons["entrada-receber-codigo"].tap()

        let tfCodigo = app.textFields["Código de acesso"]
        XCTAssertTrue(tfCodigo.waitForExistence(timeout: 10))
        tfCodigo.tap()
        tfCodigo.typeText("123456")
        app.buttons["codigo-entrar"].tap()

        XCTAssertTrue(app.staticTexts["Como você vai usar o Frila?"].waitForExistence(timeout: 10))
        let nome = app.textFields["cadastro-nome"]
        nome.tap()
        nome.typeText("Novo Usuário")

        let telefone = app.textFields["cadastro-telefone"]
        telefone.tap()
        telefone.typeText("61988887777")

        let nascimento = app.textFields["cadastro-nascimento"]
        nascimento.tap()
        nascimento.typeText("15/05/1995")

        let btnContinuar = app.buttons["cadastro-continuar"]
        XCTAssertFalse(btnContinuar.isEnabled, "Botão deve estar desabilitado sem maioridade e sem termos")

        // Marca apenas maioridade
        app.buttons["cadastro-maior-de-idade"].tap()
        XCTAssertFalse(btnContinuar.isEnabled, "Botão deve continuar desabilitado sem aceite dos termos")

        // Desmarca maioridade e marca apenas termos
        app.buttons["cadastro-maior-de-idade"].tap()
        app.buttons["cadastro-termos"].tap()
        XCTAssertFalse(btnContinuar.isEnabled, "Botão deve continuar desabilitado sem confirmação de maioridade")

        // Marca ambos
        app.buttons["cadastro-maior-de-idade"].tap()
        XCTAssertTrue(btnContinuar.isEnabled, "Botão deve habilitar com formulário completo, maioridade e termos")
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
        XCTAssertTrue(horario.waitForExistence(timeout: 5))

        app.tabBars.buttons["Meus turnos"].tap()
        XCTAssertFalse(funcao.waitForExistence(timeout: 2))
        app.tabBars.buttons["Vagas no DF"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["tela-perfil-profissional"].waitForExistence(timeout: 10))
        XCTAssertTrue(funcao.waitForExistence(timeout: 5), "as funções carregadas continuam no formulário")
        XCTAssertTrue(horario.exists, "os horários carregados continuam no formulário")
    }

    func testMeuPerfilAbreAjudaComLinksDeTermosEPrivacidade() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))

        let botaoPerfil = app.buttons["abrir-meu-perfil"]
        XCTAssertTrue(botaoPerfil.waitForExistence(timeout: 5))
        botaoPerfil.tap()

        XCTAssertTrue(app.navigationBars["Meu perfil"].waitForExistence(timeout: 5))

        let botaoAjuda = app.buttons["perfil-ajuda"]
        if !botaoAjuda.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(botaoAjuda.waitForExistence(timeout: 5))
        botaoAjuda.tap()

        XCTAssertTrue(app.navigationBars["Ajuda"].waitForExistence(timeout: 5))

        let linkTermos = app.descendants(matching: .any)["perfil-termos"]
        let linkPrivacidade = app.descendants(matching: .any)["perfil-privacidade"]

        XCTAssertTrue(linkTermos.waitForExistence(timeout: 5), "perfil-termos deve existir na tela de ajuda")
        XCTAssertTrue(linkPrivacidade.waitForExistence(timeout: 5), "perfil-privacidade deve existir na tela de ajuda")
        XCTAssertTrue(linkTermos.isHittable)
        XCTAssertTrue(linkPrivacidade.isHittable)
        XCTAssertTrue(app.links["perfil-termos"].exists || linkTermos.elementType == .link || linkTermos.elementType == .button, "deve ser um link")
        XCTAssertTrue(app.links["perfil-privacidade"].exists || linkPrivacidade.elementType == .link || linkPrivacidade.elementType == .button, "deve ser um link")

        let botaoLicencas = app.descendants(matching: .any)["perfil-licencas"]
        XCTAssertTrue(botaoLicencas.waitForExistence(timeout: 5), "perfil-licencas deve existir na tela de ajuda")
    }

    func testMeuPerfilAjudaAbreLicencasDeTerceirosComPacoteConhecido() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))

        let botaoPerfil = app.buttons["abrir-meu-perfil"]
        XCTAssertTrue(botaoPerfil.waitForExistence(timeout: 5))
        botaoPerfil.tap()

        XCTAssertTrue(app.navigationBars["Meu perfil"].waitForExistence(timeout: 5))

        let botaoAjuda = app.buttons["perfil-ajuda"]
        if !botaoAjuda.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(botaoAjuda.waitForExistence(timeout: 5))
        botaoAjuda.tap()

        XCTAssertTrue(app.navigationBars["Ajuda"].waitForExistence(timeout: 5))

        let botaoLicencas = app.descendants(matching: .any)["perfil-licencas"]
        XCTAssertTrue(botaoLicencas.waitForExistence(timeout: 5), "perfil-licencas deve existir na tela de ajuda")
        XCTAssertTrue(botaoLicencas.isHittable)
        botaoLicencas.tap()

        XCTAssertTrue(app.navigationBars["Licenças de código aberto"].waitForExistence(timeout: 5))

        let pacote = app.descendants(matching: .any)["licenca-abseil-cpp-binary"]
        XCTAssertTrue(pacote.waitForExistence(timeout: 5), "a lista deve exibir pelo menos um pacote conhecido")
    }
}

extension XCUIElement {
    /// Digita e só devolve quando o campo mostra o texto inteiro.
    ///
    /// Com o teclado recém-aberto, `typeText` devolve antes de o teclado entregar todas as teclas
    /// ao campo. O toque seguinte chegava com o e-mail pela metade: a Entrada respondia
    /// "Informe um e-mail válido." e a tela do código nunca abria.
    func digitarEEsperar(_ texto: String, file: StaticString = #filePath, line: UInt = #line) {
        typeText(texto)
        let completo = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", texto), object: self)
        XCTAssertEqual(
            XCTWaiter.wait(for: [completo], timeout: 10), .completed,
            "O campo deveria mostrar \"\(texto)\" depois da digitação", file: file, line: line
        )
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

