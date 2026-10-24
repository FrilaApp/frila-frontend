import XCTest

/// Publicar vaga a partir de Minhas vagas: o contratante que já tem estabelecimento publica a
/// segunda vaga sem passar pelo cadastro. No dublê, pelo fluxo de produto.
@MainActor
final class PublicarVagaEmMinhasVagasUITests: XCTestCase {
    private func abrir(_ outros: [String] = [], cenario: String = "contratante") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", cenario, "-FRILA_CACHE_VAZIO_UI_TEST"] + outros
        app.launch()
        return app
    }

    private func vagas(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-contratante-'"))
    }

    /// Preenche o Estúdio e publica. A função vem do roteiro de teste (`-FRILA_CADASTRO_UI_TEST`,
    /// a primeira do catálogo: Garçom): a roleta acoplada da origem não é um `UIPickerView`, e o
    /// XCUITest não a gira. O responsável e o valor são trocados aqui, para provar o que o usuário
    /// digita e o que a fila restaura.
    private func preencherEPublicar(_ app: XCUIApplication) {
        XCTAssertTrue(esperarFormularioDePublicarVaga(app))
        // O endereço da casa vem preenchido: é o que a leitura do cadastro traz.
        XCTAssertEqual(app.textFields["endereco-vaga-campo"].value as? String, "CLS 405, Asa Sul, Brasília - DF")

        let funcao = app.descendants(matching: .any)["funcao-vaga-picker"]
        XCTAssertTrue(funcao.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(funcao.label.contains("Garçom"), funcao.label)

        let responsavel = app.textFields["responsavel-local-campo"]
        rolarAte(responsavel, em: app)
        substituirTexto(responsavel, por: "Marina")
        app.swipeUp(velocity: .slow)

        ajustarValorPorTurno(app, para: 180)
        let publicar = app.buttons["publicar-vaga-botao"]
        rolarAte(publicar, em: app)
        tocar(publicar)
    }

    func testContratanteComEstabelecimentoPublicaASegundaVagaEElaApareceNaLista() {
        let app = abrir(["-FRILA_CADASTRO_UI_TEST"])

        XCTAssertTrue(app.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 15))
        XCTAssertTrue(vagas(app).firstMatch.waitForExistence(timeout: 10))
        let antes = vagas(app).count
        let entrada = app.buttons["publicar-vaga-entrada"]
        XCTAssertTrue(entrada.isHittable, "a entrada fica à vista com a lista cheia, e não só na lista vazia")
        tocar(entrada)

        preencherEPublicar(app)
        concluirCelebracao(app)

        XCTAssertTrue(app.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 10))
        let depois = NSPredicate(format: "count == %d", antes + 1)
        expectation(for: depois, evaluatedWith: vagas(app))
        waitForExpectations(timeout: 10)
        XCTAssertTrue(app.buttons["publicar-vaga-entrada"].exists)
    }

    func testCancelarVoltaParaMinhasVagasSemPublicar() {
        let app = abrir()

        XCTAssertTrue(vagas(app).firstMatch.waitForExistence(timeout: 15))
        let antes = vagas(app).count
        tocar(app.buttons["publicar-vaga-entrada"])
        XCTAssertTrue(app.descendants(matching: .any)["publicar-vaga-formulario"].waitForExistence(timeout: 10))

        tocar(app.buttons["cancelar-publicacao"])

        XCTAssertTrue(vagas(app).firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(vagas(app).count, antes)
    }

    func testPublicarPorMinhasVagasMostraAExplicacaoDaNotificacao() {
        let app = abrir(["-FRILA_CADASTRO_UI_TEST", "-FRILA_PERMISSAO_PUSH", "nao-pedida"])

        XCTAssertTrue(app.buttons["publicar-vaga-entrada"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.descendants(matching: .any)["explicacao-do-push"].exists)
        tocar(app.buttons["publicar-vaga-entrada"])

        preencherEPublicar(app)
        concluirCelebracao(app)

        XCTAssertTrue(app.staticTexts["Ative as notificações"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Confirmação de quem vai trabalhar"].exists)
    }

    func testPublicarPorMinhasVagasOfereceModoSelecao() {
        // MS-RF01 (0.2.38): a opção Seleção só aparece com o início a mais de 24 horas. O início
        // de teste só é lido junto de `-FRILA_CADASTRO_UI_TEST` (veja `carregarFuncoes`).
        let app = abrir(["-FRILA_CADASTRO_UI_TEST", "-FRILA_PUBLICAR_INICIO_EM_HORAS", "30"])

        XCTAssertTrue(app.buttons["publicar-vaga-entrada"].waitForExistence(timeout: 15))
        app.buttons["publicar-vaga-entrada"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["publicar-vaga-formulario"].waitForExistence(timeout: 10))

        let modo = app.descendants(matching: .any)["modo-vaga-picker"]
        rolarAte(modo, em: app)
        XCTAssertTrue(modo.exists, "o formulário de publicação por Minhas vagas oferece o seletor de modo")
        XCTAssertTrue(modo.buttons["Urgência"].isSelected)
        XCTAssertTrue(modo.buttons["Seleção"].exists)

        let explicacao = app.staticTexts["modo-vaga-explicacao"]
        XCTAssertEqual(explicacao.label, "O primeiro profissional que aceitar é confirmado na hora.")

        modo.buttons["Seleção"].tap()
        XCTAssertTrue(modo.buttons["Seleção"].isSelected)
        XCTAssertTrue(explicacao.label.contains("O início precisa estar a mais de 24 horas"), explicacao.label)
    }

    func testPublicarPorMinhasVagasSemAntecedenciaNaoOfereceSelecao() {
        // MS-RF01 (0.2.38): com o início a 24 horas ou menos, o formulário só oferece Urgência.
        let app = abrir(["-FRILA_CADASTRO_UI_TEST", "-FRILA_PUBLICAR_INICIO_EM_HORAS", "6"])

        XCTAssertTrue(app.buttons["publicar-vaga-entrada"].waitForExistence(timeout: 15))
        app.buttons["publicar-vaga-entrada"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["publicar-vaga-formulario"].waitForExistence(timeout: 10))

        let modo = app.descendants(matching: .any)["modo-vaga-picker"]
        rolarAte(modo, em: app)
        XCTAssertTrue(modo.exists, "o seletor de modo continua na tela")
        XCTAssertTrue(modo.buttons["Urgência"].isSelected)
        XCTAssertFalse(modo.buttons["Seleção"].exists, "sem 24 horas de antecedência, Seleção não é oferecida")
    }

    func testErroAoLerEstabelecimentoMostraMensagemEVoltarReencontraLista() {
        let app = abrir(cenario: "erro-ao-ler-meu-estabelecimento")

        XCTAssertTrue(app.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 15))
        XCTAssertTrue(vagas(app).firstMatch.waitForExistence(timeout: 10))

        let entrada = app.buttons["publicar-vaga-entrada"]
        XCTAssertTrue(entrada.waitForExistence(timeout: Espera.aparecer))
        entrada.tap()

        let telaErro = app.descendants(matching: .any)["publicar-vaga-erro"]
        XCTAssertTrue(telaErro.waitForExistence(timeout: 10), "ao falhar a leitura de meu_estabelecimento, a tela de erro é exibida")
        XCTAssertTrue(app.staticTexts["Não foi possível concluir esta ação. Tente novamente."].exists)

        let voltar = app.buttons["voltar-para-minhas-vagas"]
        XCTAssertTrue(voltar.waitForExistence(timeout: Espera.aparecer))
        voltar.tap()

        XCTAssertTrue(app.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 10))
        XCTAssertTrue(vagas(app).firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["publicar-vaga-entrada"].exists)
    }

    func testPublicarSemRedeMostraAvisoVoltarEVagaContinuaPendente() {
        let app = abrir(["-FRILA_CADASTRO_UI_TEST"], cenario: "publicar-sem-rede")

        XCTAssertTrue(app.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 15))
        XCTAssertTrue(vagas(app).firstMatch.waitForExistence(timeout: 10))
        let antes = vagas(app).count

        let entrada = app.buttons["publicar-vaga-entrada"]
        XCTAssertTrue(entrada.waitForExistence(timeout: Espera.aparecer))
        entrada.tap()

        // 1. Antes de publicar, o botão de fechar é "Cancelar" e não há aviso de publicação contínua
        let botaoFechar = app.buttons["cancelar-publicacao"]
        XCTAssertTrue(botaoFechar.waitForExistence(timeout: Espera.aparecer))
        XCTAssertEqual(botaoFechar.label, "Cancelar")
        XCTAssertFalse(app.descendants(matching: .any)["aviso-publicacao-continua"].exists)

        // 2. Preenche e publica sem rede
        preencherEPublicar(app)

        // 3. Permanece no formulário: aviso informativo aparece e o botão vira "Voltar"
        let avisoContinua = app.descendants(matching: .any)["aviso-publicacao-continua"]
        XCTAssertTrue(avisoContinua.waitForExistence(timeout: Espera.aparecer), "o aviso informativo de que a publicação continua deve aparecer")
        XCTAssertTrue(app.staticTexts["A publicação continua e será concluída quando a conexão voltar."].exists)
        XCTAssertFalse(app.descendants(matching: .any)["aviso-erro-publicacao"].exists, "não deve exibir banner vermelho de erro sem rede")
        XCTAssertEqual(botaoFechar.label, "Voltar", "o botão de fechar passa a ser 'Voltar' quando a publicação ficou na fila")

        // 4. Toca em "Voltar" e volta para Minhas vagas
        botaoFechar.tap()

        XCTAssertTrue(app.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 10))
        XCTAssertTrue(vagas(app).firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(vagas(app).count, antes, "a vaga não foi criada no servidor, continua pendente na fila")

        // 5. Ao abrir o formulário novamente, a vaga continua pendente (restaurada da fila com os campos preenchidos)
        entrada.tap()
        XCTAssertTrue(app.descendants(matching: .any)["publicar-vaga-formulario"].waitForExistence(timeout: 10))
        XCTAssertTrue(avisoContinua.waitForExistence(timeout: Espera.aparecer), "a vaga pendente na fila reabre com o aviso de continuação")
        XCTAssertFalse(app.descendants(matching: .any)["aviso-erro-publicacao"].exists, "não deve exibir aviso vermelho ao reabrir pendência")
        XCTAssertEqual(botaoFechar.label, "Voltar")

        let botaoTentarNovamente = app.buttons["publicar-vaga-botao"]
        XCTAssertTrue(botaoTentarNovamente.waitForExistence(timeout: Espera.aparecer))
        XCTAssertEqual(botaoTentarNovamente.label, "Tentar novamente")

        let campoResponsavel = app.textFields["responsavel-local-campo"]
        XCTAssertTrue(campoResponsavel.exists)
        XCTAssertEqual(campoResponsavel.value as? String, "Marina")

        // A régua do Estúdio mostra o valor restaurado da fila.
        XCTAssertTrue(app.sliders["valor-vaga-campo"].exists)
        XCTAssertTrue(app.staticTexts["R$ 180"].exists)
    }

    func testPublicarVagaEmAX5SeletorDeDataETocavel() throws {
        throw XCTSkip("Acessibilidade em AX5 adiada (decisão do Cauê, 21/10)")
        let app = abrir(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])

        XCTAssertTrue(app.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 15))
        XCTAssertTrue(vagas(app).firstMatch.waitForExistence(timeout: 10))
        let entrada = app.buttons["publicar-vaga-entrada"]
        tocar(entrada)

        XCTAssertTrue(app.descendants(matching: .any)["publicar-vaga-formulario"].waitForExistence(timeout: 10))

        let campoValor = app.sliders["valor-vaga-campo"]
        let campoPosicoes = app.descendants(matching: .any)["posicoes-vaga-stepper"]
        rolarAte(campoValor, em: app)
        XCTAssertTrue(campoValor.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(campoPosicoes.waitForExistence(timeout: Espera.aparecer))
        XCTAssertGreaterThan(campoPosicoes.frame.width, 150, "Campo de posições deve ter largura útil em coluna no tamanho XXXL")

        let dpInicio = app.descendants(matching: .any)["datepicker-inicio"]
        rolarAte(dpInicio, em: app)
        XCTAssertTrue(dpInicio.waitForExistence(timeout: Espera.aparecer), "Campo Início deve existir")
        XCTAssertTrue(dpInicio.isHittable, "Campo Início deve ser tocável em AX5")

        let dpFim = app.descendants(matching: .any)["datepicker-fim"]
        rolarAte(dpFim, em: app)
        XCTAssertTrue(dpFim.waitForExistence(timeout: Espera.aparecer), "Campo Fim deve existir")
        XCTAssertTrue(dpFim.isHittable, "Campo Fim deve ser tocável em AX5")

        rolarAte(campoValor, em: app)
        salvarCaptura("03-publicar-vaga-xxxl")
    }

    func testCapturaPublicarVagaFimAcompanhaInicioPadrao() {
        let app = abrir(["-FRILA_CADASTRO_UI_TEST", "-FRILA_PUBLICAR_INICIO_EM_HORAS", "30"])

        XCTAssertTrue(app.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 15))
        XCTAssertTrue(vagas(app).firstMatch.waitForExistence(timeout: 10))
        tocar(app.buttons["publicar-vaga-entrada"])

        XCTAssertTrue(app.descendants(matching: .any)["publicar-vaga-formulario"].waitForExistence(timeout: 10))

        let dpInicio = app.descendants(matching: .any)["datepicker-inicio"]
        let dpFim = app.descendants(matching: .any)["datepicker-fim"]
        rolarAte(dpInicio, em: app)
        XCTAssertTrue(dpInicio.waitForExistence(timeout: 5))
        XCTAssertTrue(dpFim.waitForExistence(timeout: 5))

        salvarCaptura("06-publicar-vaga-fim-acompanha-inicio-padrao")
    }

    func testCapturasPublicarVagaUX02() {
        let app = abrir()

        XCTAssertTrue(app.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 15))
        XCTAssertTrue(vagas(app).firstMatch.waitForExistence(timeout: 10))
        salvarCaptura("01-minhas-vagas-vizinha-padrao")

        let entrada = app.buttons["publicar-vaga-entrada"]
        tocar(entrada)

        XCTAssertTrue(app.descendants(matching: .any)["publicar-vaga-formulario"].waitForExistence(timeout: 10))

        let valor = app.sliders["valor-vaga-campo"]
        rolarAte(valor, em: app)
        ajustarValorPorTurno(app, para: 150)

        // O contador de vagas do Estúdio: botões de menos e mais em volta do número.
        let mais = app.buttons["posicoes-vaga-mais"]
        rolarAte(mais, em: app)
        XCTAssertTrue(mais.waitForExistence(timeout: 5))
        XCTAssertEqual(mais.label, "Adicionar uma vaga")
        let contador = app.descendants(matching: .any)["posicoes-vaga-campo"]
        XCTAssertTrue(contador.label.hasPrefix("1"), contador.label)
        tocar(mais)
        XCTAssertTrue(contador.label.hasPrefix("2"), contador.label)

        let totalCalculado = app.staticTexts["total-vaga-calculado"]
        rolarAte(totalCalculado, em: app)
        XCTAssertTrue(totalCalculado.waitForExistence(timeout: 5))
        XCTAssertTrue(totalCalculado.label.contains("300"), totalCalculado.label)

        salvarCaptura("02-publicar-vaga-padrao")
    }

    /// O Estúdio não escreve avisos de validação por campo: com obrigatório faltando, Publicar
    /// não publica e leva à primeira etapa incompleta (aqui a função, que o cenário não preenche).
    func testPublicarComObrigatorioFaltandoNaoPublicaEVoltaAEtapaIncompleta() {
        let app = abrir()

        XCTAssertTrue(app.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 15))
        XCTAssertTrue(vagas(app).firstMatch.waitForExistence(timeout: 10))
        let antes = vagas(app).count
        tocar(app.buttons["publicar-vaga-entrada"])
        XCTAssertTrue(esperarFormularioDePublicarVaga(app))

        let botaoPublicar = app.buttons["publicar-vaga-botao"]
        rolarAte(botaoPublicar, em: app)
        tocar(botaoPublicar)

        XCTAssertFalse(app.buttons["celebracao-concluir"].waitForExistence(timeout: 3), "sem função a vaga não é publicada")
        XCTAssertTrue(app.descendants(matching: .any)["publicar-vaga-formulario"].exists)
        let etapa = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Publicar vaga, etapa 1 de 3")).firstMatch
        XCTAssertTrue(etapa.waitForExistence(timeout: 5), "a barra volta à etapa da vaga, a primeira incompleta")
        salvarCaptura("01-etapa-incompleta")

        tocar(app.buttons["cancelar-publicacao"])
        XCTAssertTrue(vagas(app).firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(vagas(app).count, antes)
    }

    private func salvarCaptura(_ nome: String) {
        let captura = XCUIScreen.main.screenshot()
        let anexo = XCTAttachment(screenshot: captura)
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)

        if let diretorio = ProcessInfo.processInfo.environment["FRILA_CAPTURAS_DIR"], !diretorio.isEmpty {
            let destino = URL(fileURLWithPath: diretorio).appendingPathComponent("\(nome).png")
            do {
                try FileManager.default.createDirectory(at: URL(fileURLWithPath: diretorio), withIntermediateDirectories: true)
                try captura.pngRepresentation.write(to: destino)
            } catch {
                XCTFail("Falha ao exportar captura para \(destino.path): \(error)")
            }
        }
    }

    private func rolarAte(_ elemento: XCUIElement, em app: XCUIApplication, tentativas: Int = 10) {
        let janela = app.windows.firstMatch.frame
        for _ in 0..<tentativas {
            guard elemento.exists else {
                app.swipeUp(velocity: .slow)
                continue
            }
            let quadro = elemento.frame
            if elemento.isHittable, quadro.minY >= 120, quadro.maxY <= janela.height - 60 { return }
            if quadro.minY < 120 {
                app.swipeDown(velocity: .slow)
            } else {
                app.swipeUp(velocity: .slow)
            }
        }
    }
}

