import XCTest

/// Testes de interface para os achados de acessibilidade confirmados nas telas do contratante (#139).
/// Mede alvos mínimos de toque (44x44 pt), atributos de acessibilidade, hints e Dynamic Type XXXL.
@MainActor
final class AcessibilidadeDoContratanteUITests: XCTestCase {
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"

    // MARK: - 1. Cadastro do Estabelecimento: Alvos e Acessibilidade

    private func abrir(argumentos: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += argumentos
        AjudanteDeLancamentoUITests.preparar(app)
        app.launch()
        return app
    }

    func testCadastroEstabelecimentoAlvosERotulos() throws {
        let app = abrir(argumentos: ["-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO", "-FRILA_CADASTRO_UI_TEST"])

        XCTAssertTrue(app.staticTexts["Dados do negócio"].waitForExistence(timeout: 10))

        // 2.1 Botão de busca (lupa): alvo >= 44x44 pt
        let botaoBusca = app.buttons["buscar-endereco-botao"]
        XCTAssertTrue(botaoBusca.waitForExistence(timeout: Espera.aparecer))
        XCTAssertAlvoMinimo(botaoBusca.frame.width, "Botão de busca deve ter largura >= 44 pt")
        XCTAssertAlvoMinimo(botaoBusca.frame.height, "Botão de busca deve ter altura >= 44 pt")
        XCTAssertTrue(botaoBusca.isHittable)

        // 3.7 Marcador do mapa: label e alça >= 44x44 pt
        let marcador = app.descendants(matching: .any)["marcador-mapa"]
        XCTAssertTrue(marcador.waitForExistence(timeout: 10))
        XCTAssertEqual(marcador.label, "Ponto do estabelecimento")
        XCTAssertAlvoMinimo(marcador.frame.width)
        XCTAssertAlvoMinimo(marcador.frame.height)

        // Mapa do estabelecimento
        let mapa = app.descendants(matching: .any)["mapa-estabelecimento"]
        XCTAssertTrue(mapa.waitForExistence(timeout: 10))
        XCTAssertEqual(mapa.label, "Mapa do estabelecimento")
    }

    // MARK: - 2. Publicar Vaga no Tamanho Padrão: Alvos e Acessibilidade

    func testPublicarVagaAlvosNoTamanhoPadrao() {
        let app = abrir(argumentos: ["-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO", "-FRILA_CADASTRO_UI_TEST"])

        XCTAssertTrue(app.staticTexts["Dados do negócio"].waitForExistence(timeout: 10))
        tocar(app.buttons["continuar-cadastro"])
        XCTAssertTrue(esperarFormularioDePublicarVaga(app))

        // 3.10 Roleta de Função: rótulo acessível diz a categoria e a função (nunca "Função, Função")
        let pickerFuncao = app.descendants(matching: .any)["funcao-vaga-picker"]
        XCTAssertTrue(pickerFuncao.waitForExistence(timeout: Espera.aparecer))
        XCTAssertNotEqual(pickerFuncao.label, "Função, Função")
        XCTAssertTrue(pickerFuncao.label.lowercased().contains("função"), pickerFuncao.label)

        // 2.4 Régua de valor: tocável
        let regua = app.sliders["valor-vaga-campo"]
        XCTAssertTrue(regua.waitForExistence(timeout: Espera.aparecer))
        trazerParaATela(regua, em: app)
        XCTAssertTrue(regua.isHittable, "Régua de valor deve ser tocável")

        // 2.5 Botões do contador de vagas: alvo >= 44 pt (hitbox mínimo da origem)
        let mais = app.buttons["posicoes-vaga-mais"]
        XCTAssertTrue(mais.waitForExistence(timeout: Espera.aparecer))
        trazerParaATela(mais, em: app)
        XCTAssertAlvoMinimo(mais.frame.height, "Botão de adicionar vaga deve ter altura >= 44 pt")
        XCTAssertAlvoMinimo(mais.frame.width, "Botão de adicionar vaga deve ter largura >= 44 pt")

        // 2.3 Botões da barra fixa (Prévia e Publicar): altura >= 44 pt
        let previa = app.buttons["previa-vaga-botao"]
        XCTAssertTrue(previa.waitForExistence(timeout: Espera.aparecer))
        XCTAssertAlvoMinimo(previa.frame.height, "Botão Prévia deve ter altura >= 44 pt")
        let publicar = app.buttons["publicar-vaga-botao"]
        XCTAssertAlvoMinimo(publicar.frame.height, "Botão Publicar deve ter altura >= 44 pt")
        // O Estúdio não tem alerta de vaga vazia, "Mais opções" nem observações (relatório da Fase 1 do Hi-Fi).
    }

    // MARK: - 3. Publicar Vaga em Dynamic Type XXXL

    func testPublicarVagaEmDynamicTypeXXXLMantemControlesNaTela() throws {
        throw XCTSkip("Acessibilidade em AX5 adiada (decisão do Cauê, 21/10)")
        let app = abrir(argumentos: [
            "-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO",
            "-FRILA_CADASTRO_UI_TEST",
            "-UIPreferredContentSizeCategoryName",
            Self.ax5
        ])

        XCTAssertTrue(app.staticTexts["Dados do negócio"].waitForExistence(timeout: 10))
        tocar(app.buttons["continuar-cadastro"])
        XCTAssertTrue(esperarFormularioDePublicarVaga(app))

        let larguraTela = app.windows.firstMatch.frame.width

        // 1.3 Botões Sim/Não dentro da tela
        let botoesSim = app.descendants(matching: .button).allElementsBoundByIndex.filter { $0.label == "Sim" }
        XCTAssertEqual(botoesSim.count, 3)
        let botoesNao = app.descendants(matching: .button).allElementsBoundByIndex.filter { $0.label == "Não" }
        XCTAssertEqual(botoesNao.count, 3)

        for i in 0..<3 {
            let sim = botoesSim[i]
            let nao = botoesNao[i]

            trazerParaATela(sim, em: app)
            XCTAssertLessThanOrEqual(sim.frame.maxX, larguraTela, "Sim[\(i)] extrapolou a largura")
            XCTAssertTrue(sim.isHittable)

            trazerParaATela(nao, em: app)
            XCTAssertLessThanOrEqual(nao.frame.maxX, larguraTela, "Não[\(i)] extrapolou a largura")
            XCTAssertTrue(nao.isHittable)

            sim.tap()
        }

        XCTAssertTrue(app.images["icone-checkmark-sim"].exists)
        XCTAssertFalse(app.images["icone-checkmark-nao"].exists)

        // 1.1 e 1.2 Campos contidos na tela
        let campoValor = app.sliders["valor-vaga-campo"]
        if campoValor.exists {
            trazerParaATela(campoValor, em: app)
            XCTAssertLessThanOrEqual(campoValor.frame.maxX, larguraTela)
        }

        // Seletores de data Início e Fim tocáveis e contidos na tela em AX5
        let dpInicio = app.descendants(matching: .any)["datepicker-inicio"]
        XCTAssertTrue(dpInicio.waitForExistence(timeout: Espera.aparecer), "DatePicker Início deve existir")
        trazerParaATela(dpInicio, em: app)
        XCTAssertLessThanOrEqual(dpInicio.frame.maxX, larguraTela, "DatePicker Início extrapolou a largura")
        XCTAssertGreaterThanOrEqual(dpInicio.frame.minX, 0, "DatePicker Início fora à esquerda")
        XCTAssertTrue(dpInicio.isHittable, "DatePicker Início deve ser tocável em AX5")

        let dpFim = app.descendants(matching: .any)["datepicker-fim"]
        XCTAssertTrue(dpFim.waitForExistence(timeout: Espera.aparecer), "DatePicker Fim deve existir")
        trazerParaATela(dpFim, em: app)
        XCTAssertLessThanOrEqual(dpFim.frame.maxX, larguraTela, "DatePicker Fim extrapolou a largura")
        XCTAssertGreaterThanOrEqual(dpFim.frame.minX, 0, "DatePicker Fim fora à esquerda")
        XCTAssertTrue(dpFim.isHittable, "DatePicker Fim deve ser tocável em AX5")
    }

    // MARK: - 4. Perfil do Estabelecimento: Toolbar e Hints de Botões Desabilitados

    func testPerfilDoEstabelecimentoToolbarEHintsSemVazamento() {
        let app = abrir(argumentos: ["-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO", "-FRILA_CADASTRO_UI_TEST"])

        XCTAssertTrue(app.staticTexts["Dados do negócio"].waitForExistence(timeout: 10))
        tocar(app.buttons["continuar-cadastro"])
        XCTAssertTrue(esperarFormularioDePublicarVaga(app))

        // Toolbar: botão de Perfil do Estabelecimento deve abrir a folha do perfil
        let btnPerfil = app.buttons["Perfil do estabelecimento"]
        XCTAssertTrue(btnPerfil.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(btnPerfil.isHittable)
        tocar(btnPerfil)

        // 3.11 Botão Exportar dados não pode vazar referências a cartões (#219/#50)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '#219' OR label CONTAINS '#50'")).firstMatch.exists)
    }

    // MARK: - 5. Minhas Vagas: Títulos Acessíveis e Link Ligar (3.1 a 3.4)

    func testMinhasVagasAcessibilidadeTitulosELinkLigar() {
        let app = abrir(argumentos: [
            "-FRILA_ABRIR_MINHAS_VAGAS",
            "-FRILA_SCENARIO", "painel-contratante",
        ])

        // 3.2 NavigationTitle da lista
        let barraLista = app.navigationBars["Minhas vagas"]
        XCTAssertTrue(barraLista.waitForExistence(timeout: 10))
        XCTAssertTrue(barraLista.staticTexts["Minhas vagas"].exists)

        let vaga = app.buttons["vaga-contratante-40000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(vaga.waitForExistence(timeout: 10))
        vaga.tap()

        // 3.3 NavigationTitle do detalhe da vaga
        let barraDetalhe = app.navigationBars["Detalhe da vaga"]
        XCTAssertTrue(barraDetalhe.waitForExistence(timeout: 10))
        XCTAssertTrue(barraDetalhe.staticTexts["Detalhe da vaga"].exists)

        // 3.4 NavigationTitle do perfil público
        let perfil = app.buttons["perfil-publico-82000000-0000-0000-0000-000000000002"]
        XCTAssertTrue(perfil.waitForExistence(timeout: Espera.aparecer))
        perfil.tap()

        let barraPerfil = app.navigationBars["Perfil público"]
        XCTAssertTrue(barraPerfil.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(barraPerfil.staticTexts["Perfil público"].exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()

        // 3.1 Link Ligar com Label acessível e alvo de toque >= 44 pt
        let contato = app.buttons["ver-contato-82000000-0000-0000-0000-000000000002"]
        XCTAssertTrue(contato.waitForExistence(timeout: Espera.aparecer))
        trazerParaATela(contato, em: app)
        contato.tap()

        let linkLigar = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Ligar'")).firstMatch
        XCTAssertTrue(linkLigar.waitForExistence(timeout: Espera.aparecer))
        trazerParaATela(linkLigar, em: app)
        XCTAssertAlvoMinimo(linkLigar.frame.height, "Link Ligar deve ter altura mínima de 44 pt")
        XCTAssertTrue(linkLigar.isHittable)

        // Verifica que o WhatsApp também mantém alvo de toque
        let linkWhatsApp = app.buttons.matching(NSPredicate(format: "label CONTAINS 'WhatsApp'")).firstMatch
        XCTAssertTrue(linkWhatsApp.waitForExistence(timeout: Espera.aparecer))
        trazerParaATela(linkWhatsApp, em: app)
        XCTAssertAlvoMinimo(linkWhatsApp.frame.height, "Link WhatsApp deve ter altura mínima de 44 pt")
        XCTAssertTrue(linkWhatsApp.isHittable)
    }

    private func trazerParaATela(_ elemento: XCUIElement, em app: XCUIApplication, tentativas: Int = 12) {
        if elemento.isHittable { return }
        let janela = app.windows.firstMatch
        let quadroJanela = janela.frame
        let margemSuperior: CGFloat = 120
        let margemInferior: CGFloat = 60

        for _ in 0..<tentativas {
            guard elemento.exists else {
                app.swipeUp()
                continue
            }
            let quadro = elemento.frame
            let direcao = direcaoParaTrazerParaATela(
                quadro: quadro,
                alturaJanela: quadroJanela.height,
                margemSuperior: margemSuperior,
                margemInferior: margemInferior,
                isHittable: elemento.isHittable
            )
            switch direcao {
            case .nenhuma:
                return
            case .rolarParaBaixo:
                app.swipeDown()
            case .rolarParaCima:
                // Em AX5 os DatePickers usam .wheel (largura 320 pt), que intercepta toques verticais no centro
                // da tela (dx: 0.5) girando a roda em vez de rolar a ScrollView. Rolar pela margem direita (dx: 0.90)
                // evita o seletor em roda e atinge diretamente a ScrollView.
                let inicio = janela.coordinate(withNormalizedOffset: CGVector(dx: 0.90, dy: 0.85))
                let fim = janela.coordinate(withNormalizedOffset: CGVector(dx: 0.90, dy: 0.15))
                inicio.press(forDuration: 0.01, thenDragTo: fim)
            }
        }
    }

    // MARK: - 4. Avaliação do Profissional pelo Contratante (#22)

    func testAvaliacaoDoProfissionalPeloContratanteTamanhoPadrao() {
        let app = abrir(argumentos: [
            "-FRILA_ABRIR_MINHAS_VAGAS",
            "-FRILA_SCENARIO", "ciclo-contratante-turno-concluido"
        ])

        let minhasVagas = app.descendants(matching: .any)["minhas-vagas"]
        XCTAssertTrue(minhasVagas.waitForExistence(timeout: Espera.aparecer))

        let vaga = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-contratante-'")).firstMatch
        XCTAssertTrue(vaga.waitForExistence(timeout: 10))
        trazerParaATela(vaga, em: app)
        vaga.tap()

        XCTAssertTrue(app.descendants(matching: .any)["detalhe-vaga-contratante"].waitForExistence(timeout: 10))

        let acompanhar = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'acompanhar-turno-'")).firstMatch
        XCTAssertTrue(acompanhar.waitForExistence(timeout: 10))
        acompanhar.tap()

        XCTAssertTrue(app.descendants(matching: .any)["turno-do-contratante"].waitForExistence(timeout: 10))

        let cartaoAvaliacao = app.descendants(matching: .any)["cartao-avaliacao-turno"]
        trazerParaATela(cartaoAvaliacao, em: app)
        XCTAssertTrue(cartaoAvaliacao.waitForExistence(timeout: 10))

        salvarCaptura(app.screenshot(), nome: "01-entrada-turno-contratante-se.png")

        let botaoAvaliar = app.buttons["botao-abrir-avaliacao"]
        let botaoAlternativo = app.buttons["Avaliar turno"]
        let botaoEfetivo = botaoAvaliar.exists ? botaoAvaliar : botaoAlternativo
        XCTAssertTrue(botaoEfetivo.waitForExistence(timeout: 10))
        botaoEfetivo.tap()

        XCTAssertTrue(app.navigationBars["Avaliar turno"].waitForExistence(timeout: 10))
        let pergunta = app.staticTexts["pergunta-avaliacao"]
        XCTAssertTrue(pergunta.waitForExistence(timeout: 10))
        XCTAssertEqual(pergunta.label, "Chamaria este profissional de novo?")

        let sim = app.buttons["resposta-sim"]
        let nao = app.buttons["resposta-nao"]
        XCTAssertTrue(sim.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(nao.waitForExistence(timeout: Espera.aparecer))
        XCTAssertGreaterThanOrEqual(sim.frame.height, 44)
        XCTAssertGreaterThanOrEqual(nao.frame.height, 44)

        salvarCaptura(app.screenshot(), nome: "02-avaliacao-contratante-padrao-se.png")
    }

    func testAvaliacaoDoProfissionalPeloContratanteAX5() {
        let app = abrir(argumentos: [
            "-FRILA_ABRIR_MINHAS_VAGAS",
            "-FRILA_SCENARIO", "ciclo-contratante-turno-concluido",
            "-UIPreferredContentSizeCategoryName", Self.ax5
        ])

        let minhasVagas = app.descendants(matching: .any)["minhas-vagas"]
        XCTAssertTrue(minhasVagas.waitForExistence(timeout: Espera.aparecer))

        let vaga = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-contratante-'")).firstMatch
        XCTAssertTrue(vaga.waitForExistence(timeout: 10))
        trazerParaATela(vaga, em: app)
        vaga.tap()

        XCTAssertTrue(app.descendants(matching: .any)["detalhe-vaga-contratante"].waitForExistence(timeout: 10))

        let acompanhar = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'acompanhar-turno-'")).firstMatch
        XCTAssertTrue(acompanhar.waitForExistence(timeout: 10))
        acompanhar.tap()

        XCTAssertTrue(app.descendants(matching: .any)["turno-do-contratante"].waitForExistence(timeout: 10))

        let cartaoAvaliacao = app.descendants(matching: .any)["cartao-avaliacao-turno"]
        trazerParaATela(cartaoAvaliacao, em: app)
        XCTAssertTrue(cartaoAvaliacao.waitForExistence(timeout: 10))

        let botaoAvaliar = app.buttons["botao-abrir-avaliacao"]
        let botaoAlternativo = app.buttons["Avaliar turno"]
        let botaoEfetivo = botaoAvaliar.exists ? botaoAvaliar : botaoAlternativo
        XCTAssertTrue(botaoEfetivo.waitForExistence(timeout: 10))
        botaoEfetivo.tap()

        XCTAssertTrue(app.navigationBars["Avaliar turno"].waitForExistence(timeout: 10))
        let pergunta = app.staticTexts["pergunta-avaliacao"]
        XCTAssertTrue(pergunta.waitForExistence(timeout: 10))
        XCTAssertEqual(pergunta.label, "Chamaria este profissional de novo?")

        let sim = app.buttons["resposta-sim"]
        let nao = app.buttons["resposta-nao"]
        XCTAssertTrue(sim.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(nao.waitForExistence(timeout: Espera.aparecer))
        XCTAssertGreaterThanOrEqual(sim.frame.height, 44)
        XCTAssertGreaterThanOrEqual(nao.frame.height, 44)

        salvarCaptura(app.screenshot(), nome: "03-avaliacao-contratante-ax5-se.png")
    }

    private func salvarCaptura(_ screenshot: XCUIScreenshot, nome: String) {
        let anexo = XCTAttachment(screenshot: screenshot)
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)
        let caminho = "/Users/cauecarneiro/Documents/Projetos/Apps/.workers/thor/capturas/\(nome)"
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: caminho))
    }
}
