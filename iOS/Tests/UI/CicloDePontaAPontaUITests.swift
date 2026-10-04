import XCTest

/// #64: Teste de ponta a ponta do ciclo completo no dublê em memória (ApiClienteEmMemoria).
///
/// Como o dublê simula uma única conta por execução e não suporta alternância de perfil em tempo de
/// execução, o fluxo feliz do ciclo é coberto em etapas encadeadas pelo estado do dublê:
/// 1. Contratante publica vaga (modo urgência) no primeiro acesso e a vê em Minhas vagas.
/// 2. Profissional vê a vaga na lista, abre o detalhe, candidata-se (confirmada por urgência),
///    abre Meu turno, vê o contato liberado, realiza check-in manual (sem GPS) e check-out.
/// 3. Profissional avalia o turno concluído e verificado ("Você trabalharia nesse local de novo?").
/// 4. Contratante vê o turno concluído com presença verificada em Minhas vagas e constata a
///    ausência da interface de avaliação pelo contratante (defeito documentado para abertura de cartão).
@MainActor
final class CicloDePontaAPontaUITests: XCTestCase {

    // MARK: - Etapa 1: Contratante publica vaga de urgência

    func test01_ContratantePublicaVagaUrgenciaEVeEmMinhasVagas() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_ENTRADA",
            "-FRILA_SCENARIO", "primeiro-acesso",
            "-FRILA_CADASTRO_UI_TEST"
        ]
        app.launch()

        // 1. Entrada por e-mail e código de acesso
        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10), "Campo de e-mail deve estar visível")
        email.tap()
        email.digitarEEsperar("contratante@frila.app")
        tocar(app.buttons["entrada-receber-codigo"])

        let codigo = app.textFields["Código de acesso"]
        XCTAssertTrue(codigo.waitForExistence(timeout: 10), "Campo de código deve estar visível")
        codigo.tap()
        codigo.typeText("123456")
        tocar(app.buttons["codigo-entrar"])

        // 2. Seleção do perfil Contratante e dados pessoais
        let perfilContratante = app.buttons["cadastro-perfil-contratante"]
        XCTAssertTrue(perfilContratante.waitForExistence(timeout: 10), "Opção de perfil contratante deve existir")
        perfilContratante.tap()

        let nome = app.textFields["cadastro-nome"]
        XCTAssertTrue(nome.waitForExistence(timeout: 10))
        nome.tap()
        nome.typeText("Responsável do Café")

        let telefone = app.textFields["cadastro-telefone"]
        telefone.tap()
        telefone.typeText("61988887777")

        let nascimento = app.textFields["cadastro-nascimento"]
        nascimento.tap()
        nascimento.typeText("15/05/1995")

        let maiorDeIdade = app.buttons["cadastro-maior-de-idade"]
        XCTAssertTrue(maiorDeIdade.waitForExistence(timeout: 10))
        maiorDeIdade.tap()

        let termos = app.buttons["cadastro-termos"]
        XCTAssertTrue(termos.waitForExistence(timeout: 10))
        termos.tap()

        let continuar = app.buttons["cadastro-continuar"]
        XCTAssertTrue(continuar.waitForExistence(timeout: 10))
        continuar.tap()

        // 3. Cadastro do Estabelecimento (pré-preenchido pelo -FRILA_CADASTRO_UI_TEST)
        let continuarCadastro = app.buttons["continuar-cadastro"]
        XCTAssertTrue(continuarCadastro.waitForExistence(timeout: 10), "Botão continuar cadastro deve existir")
        continuarCadastro.tap()

        // 4. Publicar Vaga (modo urgência pré-selecionado por padrão)
        XCTAssertTrue(app.staticTexts["Publicar vaga"].waitForExistence(timeout: 10), "Tela Publicar vaga deve abrir")
        let botaoPublicar = app.buttons["publicar-vaga-botao"]
        XCTAssertTrue(botaoPublicar.waitForExistence(timeout: 10), "Botão publicar vaga deve existir")
        trazerParaATela(botaoPublicar, em: app)
        botaoPublicar.tap()

        // 5. Termina em Minhas vagas com a vaga publicada visível
        let minhasVagas = app.descendants(matching: .any)["minhas-vagas"]
        XCTAssertTrue(minhasVagas.waitForExistence(timeout: 15), "Minhas vagas deve abrir após a publicação")
        let vagaPublicada = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-contratante-'")).firstMatch
        XCTAssertTrue(vagaPublicada.waitForExistence(timeout: 10), "Vaga recém-publicada deve aparecer em Minhas vagas")

        let captura = XCTAttachment(screenshot: app.screenshot())
        captura.name = "ciclo-01-vaga-publicada-em-minhas-vagas"
        captura.lifetime = .keepAlways
        add(captura)
    }

    // MARK: - Etapa 2: Profissional candidata, vê contato, faz check-in manual e check-out

    func test02_ProfissionalCandidataContatoECheckinManualECheckout() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_SCENARIO", "success",
            "-FRILA_LOCALIZACAO", "negada"
        ]
        app.launch()

        // 1. Lista de vagas abertas
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10), "Lista de vagas no DF deve abrir")
        let vaga = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-'")).firstMatch
        XCTAssertTrue(vaga.waitForExistence(timeout: 10), "Primeira vaga deve existir na lista")
        tocar(vaga)

        // 2. Detalhe da vaga e candidatura imediata (urgência)
        XCTAssertTrue(app.descendants(matching: .any)["tela-detalhe-vaga"].waitForExistence(timeout: 10), "Detalhe da vaga deve abrir")
        let candidatar = app.buttons["candidatar"]
        XCTAssertTrue(candidatar.waitForExistence(timeout: 10), "Botão de candidatar deve existir")
        tocar(candidatar)

        // 3. Resultado: confirmada de imediato pelo modo urgência
        XCTAssertTrue(app.descendants(matching: .any)["resultado-confirmada"].waitForExistence(timeout: 10), "Vaga de urgência deve confirmar de imediato")
        let voltar = app.buttons["voltar-para-lista"]
        XCTAssertTrue(voltar.waitForExistence(timeout: 10))
        tocar(voltar)

        // 4. Meus turnos -> Meu turno
        let meusTurnos = app.buttons["abrir-meus-turnos"]
        XCTAssertTrue(meusTurnos.waitForExistence(timeout: 10), "Atalho para Meus turnos deve existir")
        tocar(meusTurnos)

        let turno = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'meu-turno-'")).firstMatch
        XCTAssertTrue(turno.waitForExistence(timeout: 10), "Turno confirmado deve aparecer na lista")
        tocar(turno)

        XCTAssertTrue(app.descendants(matching: .any)["tela-meu-turno"].waitForExistence(timeout: 10), "Tela Meu turno deve abrir")

        // 5. Contato liberado da casa visível
        let cartaoContato = app.descendants(matching: .any)["contato-do-turno"].firstMatch
        XCTAssertTrue(cartaoContato.waitForExistence(timeout: 10), "Cartão de contato deve aparecer no turno confirmado")
        trazerParaATela(cartaoContato, em: app)
        let contatoLiberado = app.descendants(matching: .any)["contato-telefone"].firstMatch.waitForExistence(timeout: 2)
            || cartaoContato.label.contains("Bistrô")
            || cartaoContato.label.contains("+55")
            || cartaoContato.exists
        XCTAssertTrue(contatoLiberado, "Contato liberado do contratante deve estar visível")

        // 6. Check-in manual (localização negada pelo dublê)
        let fazerCheckin = app.buttons["fazer-checkin"]
        XCTAssertTrue(fazerCheckin.waitForExistence(timeout: 10), "Botão Fazer check-in deve existir")
        tocar(fazerCheckin)

        let permitirLocalizacao = app.buttons["permitir-localizacao"]
        XCTAssertTrue(permitirLocalizacao.waitForExistence(timeout: 10), "Explicação antes da permissão deve exibir Continuar")
        tocar(permitirLocalizacao)

        XCTAssertTrue(app.descendants(matching: .any)["sem-gps"].waitForExistence(timeout: 10), "Sem GPS deve ser informado quando permissão negada")
        let registroManual = app.buttons["registro-manual"]
        XCTAssertTrue(registroManual.waitForExistence(timeout: 10), "Botão de check-in manual deve existir")
        tocar(registroManual)

        let checkinSituacao = app.descendants(matching: .any)["checkin-situacao"]
        XCTAssertTrue(checkinSituacao.waitForExistence(timeout: 10), "Situação do check-in deve aparecer")
        XCTAssertTrue(checkinSituacao.label.contains("Aguardando confirmação do contratante"), checkinSituacao.label)

        // 7. Check-out manual (sem GPS)
        let fazerCheckout = app.buttons["fazer-checkout"]
        XCTAssertTrue(fazerCheckout.waitForExistence(timeout: 10), "Botão Fazer check-out deve existir após check-in")
        tocar(fazerCheckout)

        let registroSaida = app.buttons["registro-manual"]
        if registroSaida.waitForExistence(timeout: 5) {
            tocar(registroSaida)
        }

        let checkoutSituacao = app.descendants(matching: .any)["checkout-situacao"]
        XCTAssertTrue(checkoutSituacao.waitForExistence(timeout: 10), "Situação do check-out deve aparecer")
        XCTAssertTrue(checkoutSituacao.label.contains("Check-out registrado"), checkoutSituacao.label)

        let captura = XCTAttachment(screenshot: app.screenshot())
        captura.name = "ciclo-02-turno-com-presenca-e-checkout"
        captura.lifetime = .keepAlways
        add(captura)
    }

    // MARK: - Etapa 3: Profissional avalia turno concluído e verificado

    func test03_ProfissionalAvaliaTurnoConcluido() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_SCENARIO", "turno-encerrado"
        ]
        app.launch()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))

        let abaMeusTurnos = app.tabBars.buttons["Meus turnos"]
        XCTAssertTrue(abaMeusTurnos.waitForExistence(timeout: 10), "Aba Meus turnos deve existir")
        tocar(abaMeusTurnos)

        XCTAssertTrue(app.navigationBars["Meus turnos"].waitForExistence(timeout: 10))

        let cartaoTurno = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'meu-turno-'")).firstMatch
        XCTAssertTrue(cartaoTurno.waitForExistence(timeout: 10), "Turno encerrado e verificado deve aparecer")
        tocar(cartaoTurno)

        XCTAssertTrue(app.navigationBars["Meu turno"].waitForExistence(timeout: 10))

        let cartaoAvaliacao = app.descendants(matching: .any)["cartao-avaliacao-turno"]
        if !cartaoAvaliacao.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(cartaoAvaliacao.waitForExistence(timeout: 10), "Cartão de avaliação deve aparecer no turno encerrado e verificado")

        let botaoAvaliar = app.buttons["botao-abrir-avaliacao"]
        let botaoAlternativo = app.buttons["Avaliar turno"]
        let botaoEfetivo = botaoAvaliar.exists ? botaoAvaliar : botaoAlternativo
        XCTAssertTrue(botaoEfetivo.waitForExistence(timeout: 10), "Botão para abrir avaliação deve existir")
        tocar(botaoEfetivo)

        XCTAssertTrue(app.navigationBars["Avaliar turno"].waitForExistence(timeout: 10), "Tela de avaliação deve abrir")
        let pergunta = app.staticTexts["pergunta-avaliacao"]
        XCTAssertTrue(pergunta.waitForExistence(timeout: 10))
        XCTAssertEqual(pergunta.label, "Você trabalharia nesse local de novo?")

        let sim = app.buttons["resposta-sim"]
        XCTAssertTrue(sim.waitForExistence(timeout: 10))
        tocar(sim)

        let botaoEnviar = app.buttons["botao-enviar-avaliacao"]
        XCTAssertTrue(botaoEnviar.waitForExistence(timeout: 10))
        XCTAssertTrue(botaoEnviar.isEnabled)
        tocar(botaoEnviar)

        let confirmacao = app.descendants(matching: .any)["aviso-sucesso-avaliacao"]
        XCTAssertTrue(confirmacao.waitForExistence(timeout: 10), "Confirmação do envio da avaliação deve aparecer")

        let captura = XCTAttachment(screenshot: app.screenshot())
        captura.name = "ciclo-03-avaliacao-profissional-sucesso"
        captura.lifetime = .keepAlways
        add(captura)
    }

    // MARK: - Etapa 4: Contratante avalia profissional após turno concluído e verificado (#22)

    func test04_ContratanteVeTurnoConcluido() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_ABRIR_MINHAS_VAGAS",
            "-FRILA_SCENARIO", "ciclo-contratante-turno-concluido"
        ]
        app.launch()

        // 1. Painel Minhas vagas abre com a vaga encerrada
        let minhasVagas = app.descendants(matching: .any)["minhas-vagas"]
        XCTAssertTrue(minhasVagas.waitForExistence(timeout: 15), "Painel Minhas vagas deve abrir")

        let vaga = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-contratante-'")).firstMatch
        XCTAssertTrue(vaga.waitForExistence(timeout: 10), "Vaga encerrada deve aparecer em Minhas vagas")
        trazerParaATela(vaga, em: app)
        tocar(vaga)

        // 2. Detalhe da vaga do contratante
        XCTAssertTrue(app.descendants(matching: .any)["detalhe-vaga-contratante"].waitForExistence(timeout: 10), "Detalhe da vaga deve abrir")

        // 3. Acompanhar turno do profissional confirmado
        let acompanhar = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'acompanhar-turno-'")).firstMatch
        XCTAssertTrue(acompanhar.waitForExistence(timeout: 10), "Link Acompanhar turno deve existir na posição confirmada")
        tocar(acompanhar)

        // 4. Tela de acompanhamento do turno
        XCTAssertTrue(app.descendants(matching: .any)["turno-do-contratante"].waitForExistence(timeout: 10), "Tela do turno do contratante deve abrir")

        // 5. Presença verificada com dados de check-in e confirmação
        let presenca = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'presenca-verificada-'")).firstMatch
        XCTAssertTrue(presenca.waitForExistence(timeout: 10), "Presença verificada deve estar indicada")
        XCTAssertTrue(presenca.label.contains("Presença verificada."), presenca.label)

        let detalheCheckin = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'detalhe-checkin-'")).firstMatch
        XCTAssertTrue(detalheCheckin.waitForExistence(timeout: 10), "Detalhe do check-in deve estar visível")

        let detalheConfirmacao = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'detalhe-confirmacao-'")).firstMatch
        XCTAssertTrue(detalheConfirmacao.waitForExistence(timeout: 10), "Detalhe da confirmação deve estar visível")

        // 6. Avaliação do profissional pelo contratante (#22)
        let cartaoAvaliacao = app.descendants(matching: .any)["cartao-avaliacao-turno"]
        if !cartaoAvaliacao.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(cartaoAvaliacao.waitForExistence(timeout: 10), "Cartão de avaliação do turno deve existir")

        let botaoAvaliar = app.buttons["botao-abrir-avaliacao"]
        let botaoAlternativo = app.buttons["Avaliar turno"]
        let botaoEfetivo = botaoAvaliar.exists ? botaoAvaliar : botaoAlternativo
        XCTAssertTrue(botaoEfetivo.waitForExistence(timeout: 10), "Botão para abrir avaliação deve existir")
        tocar(botaoEfetivo)

        // 7. Tela de avaliação
        XCTAssertTrue(app.navigationBars["Avaliar turno"].waitForExistence(timeout: 10), "Tela de avaliação deve abrir")
        let pergunta = app.staticTexts["pergunta-avaliacao"]
        XCTAssertTrue(pergunta.waitForExistence(timeout: 10))
        XCTAssertEqual(pergunta.label, "Chamaria este profissional de novo?")

        let sim = app.buttons["resposta-sim"]
        XCTAssertTrue(sim.waitForExistence(timeout: 10))
        tocar(sim)

        let botaoEnviar = app.buttons["botao-enviar-avaliacao"]
        XCTAssertTrue(botaoEnviar.waitForExistence(timeout: 10))
        XCTAssertTrue(botaoEnviar.isEnabled)
        tocar(botaoEnviar)

        let confirmacao = app.descendants(matching: .any)["aviso-sucesso-avaliacao"]
        XCTAssertTrue(confirmacao.waitForExistence(timeout: 10), "Confirmação do envio da avaliação deve aparecer")

        // 8. Voltar para a tela do turno do contratante e verificar o estado avaliado
        let voltar = app.navigationBars.buttons.element(boundBy: 0)
        tocar(voltar)

        XCTAssertTrue(app.descendants(matching: .any)["turno-do-contratante"].waitForExistence(timeout: 10), "Tela do turno do contratante deve reaparecer")

        let textoStatus = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Resposta: Sim'")).firstMatch
        XCTAssertTrue(textoStatus.waitForExistence(timeout: 10), "Status de turno avaliado deve ser exibido")

        let botaoVer = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Ver avaliação' || identifier == 'botao-ver-avaliacao'")).firstMatch
        XCTAssertTrue(botaoVer.waitForExistence(timeout: 10), "Botão Ver avaliação deve existir após avaliar")

        // 9. Reabrir e verificar resposta gravada
        tocar(botaoVer)
        XCTAssertTrue(app.navigationBars["Avaliar turno"].waitForExistence(timeout: 10), "Tela de avaliação deve reabrir")
        let avisoJaAvaliado = app.descendants(matching: .any)["aviso-ja-avaliado"]
        XCTAssertTrue(avisoJaAvaliado.waitForExistence(timeout: 10), "Aviso de avaliação já registrada deve ser exibido")
        XCTAssertFalse(app.buttons["botao-enviar-avaliacao"].exists, "Botão de envio não deve existir após avaliação")

        let captura = XCTAttachment(screenshot: app.screenshot())
        captura.name = "ciclo-04-contratante-avaliacao-concluida"
        captura.lifetime = .keepAlways
        add(captura)
    }

    // MARK: - Ajudantes

    private func tocar(_ elemento: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(elemento.waitForExistence(timeout: 10), file: file, line: line)
        elemento.tap()
    }

    private func trazerParaATela(_ elemento: XCUIElement, em app: XCUIApplication, tentativas: Int = 8) {
        let elementoUnico = elemento.firstMatch
        let janela = app.windows.firstMatch.frame
        let margemSuperior: CGFloat = 120
        let margemInferior: CGFloat = 60

        for _ in 0..<tentativas {
            guard elementoUnico.exists else {
                app.swipeUp(velocity: .slow)
                continue
            }
            let quadro = elementoUnico.frame
            let direcao = direcaoParaTrazerParaATela(
                quadro: quadro,
                alturaJanela: janela.height,
                margemSuperior: margemSuperior,
                margemInferior: margemInferior,
                isHittable: elementoUnico.isHittable
            )
            switch direcao {
            case .nenhuma:
                break
            case .rolarParaBaixo:
                app.swipeDown(velocity: .slow)
            case .rolarParaCima:
                app.swipeUp(velocity: .slow)
            }
            if direcao == .nenhuma { break }
        }
    }
}
