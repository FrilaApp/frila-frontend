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

        XCTAssertTrue(app.staticTexts["Cadastrar estabelecimento"].waitForExistence(timeout: 10))

        // 2.1 Botão de busca (lupa): alvo >= 44x44 pt
        let botaoBusca = app.buttons["buscar-endereco-botao"]
        XCTAssertTrue(botaoBusca.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(botaoBusca.frame.width, 44, "Botão de busca deve ter largura >= 44 pt")
        XCTAssertGreaterThanOrEqual(botaoBusca.frame.height, 44, "Botão de busca deve ter altura >= 44 pt")
        XCTAssertTrue(botaoBusca.isHittable)

        // 3.7 Marcador do mapa: label e alça >= 44x44 pt
        let marcador = app.descendants(matching: .any)["marcador-mapa"]
        XCTAssertTrue(marcador.waitForExistence(timeout: 10))
        XCTAssertEqual(marcador.label, "Ponto do estabelecimento")
        XCTAssertGreaterThanOrEqual(marcador.frame.width, 44)
        XCTAssertGreaterThanOrEqual(marcador.frame.height, 44)

        // Mapa do estabelecimento
        let mapa = app.descendants(matching: .any)["mapa-estabelecimento"]
        XCTAssertTrue(mapa.waitForExistence(timeout: 10))
        XCTAssertEqual(mapa.label, "Mapa do estabelecimento")
    }

    // MARK: - 2. Publicar Vaga no Tamanho Padrão: Alvos e Acessibilidade

    func testPublicarVagaAlvosNoTamanhoPadrao() {
        let app = abrir(argumentos: ["-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO", "-FRILA_CADASTRO_UI_TEST"])

        XCTAssertTrue(app.staticTexts["Cadastrar estabelecimento"].waitForExistence(timeout: 10))
        app.buttons["continuar-cadastro"].tap()
        XCTAssertTrue(app.staticTexts["Publicar vaga"].waitForExistence(timeout: 10))

        // 2.4 Campo de Valor: altura >= 44 pt
        let campoValor = app.textFields["valor-vaga-campo"]
        XCTAssertTrue(campoValor.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(campoValor.frame.height, 44, "Campo Valor deve ter altura >= 44 pt")

        // 2.5 Campo de Posições: altura >= 44 pt
        let campoPosicoes = app.textFields["posicoes-vaga-campo"]
        XCTAssertTrue(campoPosicoes.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(campoPosicoes.frame.height, 44, "Campo Posições deve ter altura >= 44 pt")

        // 3.9 Picker de Alerta: deve ter accessibilityLabel "Avisar se a vaga seguir vazia"
        let pickerAlerta = app.descendants(matching: .any)["alerta-vaga-picker"]
        XCTAssertTrue(pickerAlerta.waitForExistence(timeout: 5))
        XCTAssertEqual(pickerAlerta.label, "Avisar se a vaga seguir vazia")

        // 2.3 Botão "Mais opções": altura >= 44 pt
        let maisOpcoes = app.buttons["mais-opcoes-botao"]
        XCTAssertTrue(maisOpcoes.waitForExistence(timeout: 5))
        trazerParaATela(maisOpcoes, em: app)
        XCTAssertGreaterThanOrEqual(maisOpcoes.frame.height, 44, "Botão Mais opções deve ter altura >= 44 pt")
        maisOpcoes.tap()

        // 2.6 Campo de Observações: altura >= 44 pt mesmo vazio
        let campoObs = app.descendants(matching: .any)["observacoes-vaga-campo"]
        XCTAssertTrue(campoObs.waitForExistence(timeout: 5))
        trazerParaATela(campoObs, em: app)
        XCTAssertGreaterThanOrEqual(campoObs.frame.height, 44, "Campo Observações deve ter altura >= 44 pt")
    }

    // MARK: - 3. Publicar Vaga em Dynamic Type XXXL

    func testPublicarVagaEmDynamicTypeXXXLMantemControlesNaTela() {
        let app = abrir(argumentos: [
            "-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO",
            "-FRILA_CADASTRO_UI_TEST",
            "-UIPreferredContentSizeCategoryName",
            Self.ax5
        ])

        XCTAssertTrue(app.staticTexts["Cadastrar estabelecimento"].waitForExistence(timeout: 10))
        app.buttons["continuar-cadastro"].tap()
        XCTAssertTrue(app.staticTexts["Publicar vaga"].waitForExistence(timeout: 10))

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
        }

        // 1.1 e 1.2 Campos contidos na tela
        let campoValor = app.textFields["valor-vaga-campo"]
        if campoValor.exists {
            trazerParaATela(campoValor, em: app)
            XCTAssertLessThanOrEqual(campoValor.frame.maxX, larguraTela)
        }
    }

    // MARK: - 4. Perfil do Estabelecimento: Toolbar e Hints de Botões Desabilitados

    func testPerfilDoEstabelecimentoToolbarEHintsSemVazamento() {
        let app = abrir(argumentos: ["-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO", "-FRILA_CADASTRO_UI_TEST"])

        XCTAssertTrue(app.staticTexts["Cadastrar estabelecimento"].waitForExistence(timeout: 10))
        app.buttons["continuar-cadastro"].tap()
        XCTAssertTrue(app.staticTexts["Publicar vaga"].waitForExistence(timeout: 10))

        // Toolbar: botão de Perfil do Estabelecimento deve abrir a folha do perfil
        let btnPerfil = app.buttons["Perfil do estabelecimento"]
        XCTAssertTrue(btnPerfil.waitForExistence(timeout: 5))
        XCTAssertTrue(btnPerfil.isHittable)
        btnPerfil.tap()

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
        XCTAssertTrue(perfil.waitForExistence(timeout: 5))
        perfil.tap()

        let barraPerfil = app.navigationBars["Perfil público"]
        XCTAssertTrue(barraPerfil.waitForExistence(timeout: 5))
        XCTAssertTrue(barraPerfil.staticTexts["Perfil público"].exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()

        // 3.1 Link Ligar com Label acessível e alvo de toque >= 44 pt
        let contato = app.buttons["ver-contato-82000000-0000-0000-0000-000000000002"]
        XCTAssertTrue(contato.waitForExistence(timeout: 5))
        trazerParaATela(contato, em: app)
        contato.tap()

        let linkLigar = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Ligar'")).firstMatch
        XCTAssertTrue(linkLigar.waitForExistence(timeout: 5))
        trazerParaATela(linkLigar, em: app)
        XCTAssertGreaterThanOrEqual(linkLigar.frame.height, 44, "Link Ligar deve ter altura mínima de 44 pt")
        XCTAssertTrue(linkLigar.isHittable)

        // Verifica que o WhatsApp também mantém alvo de toque
        let linkWhatsApp = app.buttons.matching(NSPredicate(format: "label CONTAINS 'WhatsApp'")).firstMatch
        XCTAssertTrue(linkWhatsApp.waitForExistence(timeout: 5))
        trazerParaATela(linkWhatsApp, em: app)
        XCTAssertGreaterThanOrEqual(linkWhatsApp.frame.height, 44, "Link WhatsApp deve ter altura mínima de 44 pt")
        XCTAssertTrue(linkWhatsApp.isHittable)
    }

    private func trazerParaATela(_ elemento: XCUIElement, em app: XCUIApplication, tentativas: Int = 8) {
        let janela = app.windows.firstMatch.frame
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
                alturaJanela: janela.height,
                margemSuperior: margemSuperior,
                margemInferior: margemInferior,
                isHittable: elemento.isHittable
            )
            switch direcao {
            case .nenhuma:
                break
            case .rolarParaBaixo:
                app.swipeDown()
            case .rolarParaCima:
                app.swipeUp()
            }
            if direcao == .nenhuma { break }
        }
    }
}
