import XCTest

/// O modo seleção do lado de quem contrata (#10), no dublê: a casa vê os candidatos com perfil e
/// reputação, escolhe com confirmação e vê quem ficou com a posição. Os candidatos e a vaga são os
/// de `candidatos.json` e de `vaga.json`.
@MainActor
final class ModoSelecaoDoContratanteUITests: XCTestCase {
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"
    private let vagaID = "40000000-0000-0000-0000-000000000001"
    private let ana = "70000000-0000-0000-0000-000000000001"
    private let bruno = "70000000-0000-0000-0000-000000000002"
    private let carla = "70000000-0000-0000-0000-000000000003"

    private func abrir(_ argumentos: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = argumentos
        app.launch()
        return app
    }

    /// Abre Minhas vagas no cenário e entra no detalhe da vaga de seleção.
    private func abrirVaga(cenario: String, extras: [String] = []) -> XCUIApplication {
        let app = abrir(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", cenario] + extras)
        let vaga = app.buttons["vaga-contratante-\(vagaID)"]
        XCTAssertTrue(vaga.waitForExistence(timeout: 15))
        abrirDetalhe(de: vaga, em: app)
        return app
    }

    /// Toca no cartão e espera o detalhe abrir. Com a máquina sob carga, o toque pode cair no meio
    /// de uma atualização da lista e se perder: se o detalhe não abriu, toca de novo, uma vez.
    private func abrirDetalhe(de cartao: XCUIElement, em app: XCUIApplication) {
        let detalhe = app.descendants(matching: .any)["detalhe-vaga-contratante"]
        cartao.tap()
        if !detalhe.waitForExistence(timeout: 10), cartao.exists, cartao.isHittable { cartao.tap() }
        XCTAssertTrue(detalhe.waitForExistence(timeout: 10), "o detalhe da vaga não abriu")
    }

    /// Rola até o elemento ficar longe da barra de navegação e da borda de baixo, para o toque não
    /// cair fora dele. Sobe ou desce, conforme o lado em que ele está.
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

    // MARK: Critério 1

    func testEscolherUmCandidatoConfirmaSoEleELiberaOsOutros() {
        let app = abrir(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "selecao-com-candidatos"])

        // A lista de Minhas vagas já diz que a vaga é de seleção e quantos esperam a escolha.
        let cartao = app.buttons["vaga-contratante-\(vagaID)"]
        XCTAssertTrue(cartao.waitForExistence(timeout: 15))
        XCTAssertTrue(cartao.label.contains("Modo seleção"), cartao.label)
        XCTAssertTrue(cartao.label.contains("4 candidatos aguardando sua escolha"), cartao.label)
        XCTAssertTrue(cartao.label.contains("0 de 1 confirmadas"), cartao.label)
        abrirDetalhe(de: cartao, em: app)

        // Quatro candidatos, cada um com a reputação e o denominador; sem histórico diz que não há.
        XCTAssertTrue(app.descendants(matching: .any)["candidatos-da-vaga"].waitForExistence(timeout: 10))
        let dadosDoBruno = app.descendants(matching: .any)["dados-do-candidato-\(bruno)"]
        XCTAssertTrue(dadosDoBruno.waitForExistence(timeout: 10))
        XCTAssertTrue(dadosDoBruno.label.contains("Bruno Tavares"), dadosDoBruno.label)
        XCTAssertTrue(dadosDoBruno.label.contains("10 de 12 chamariam de novo"), dadosDoBruno.label)
        XCTAssertTrue(dadosDoBruno.label.contains("Compareceu a 18 de 20 turnos"), dadosDoBruno.label)
        XCTAssertTrue(app.descendants(matching: .any)["dados-do-candidato-\(ana)"].label.contains("7 de 7 chamariam de novo"))
        let dadosDaCarla = app.descendants(matching: .any)["dados-do-candidato-\(carla)"]
        rolarAte(dadosDaCarla, em: app)
        XCTAssertTrue(dadosDaCarla.label.contains("Sem histórico"), dadosDaCarla.label)

        // O perfil público do candidato abre a partir da lista.
        let perfil = app.buttons["perfil-do-candidato-\(bruno)"]
        rolarAte(perfil, em: app)
        XCTAssertEqual(perfil.label, "Ver perfil público de Bruno Tavares")
        perfil.tap()
        XCTAssertTrue(app.descendants(matching: .any)["perfil-publico-contratante"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["10 de 12 chamariam de novo"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Escolher pergunta antes; cancelar não escolhe ninguém.
        let escolher = app.buttons["escolher-candidato-\(bruno)"]
        XCTAssertTrue(escolher.waitForExistence(timeout: 5))
        rolarAte(escolher, em: app)
        XCTAssertEqual(escolher.label, "Escolher Bruno Tavares")
        escolher.tap()
        let pergunta = app.alerts["Confirmar a escolha?"]
        XCTAssertTrue(pergunta.waitForExistence(timeout: 5))
        let aviso = pergunta.staticTexts.element(boundBy: 1).label
        XCTAssertTrue(aviso.contains("Bruno Tavares será confirmado nesta vaga"), aviso)
        XCTAssertTrue(aviso.contains("É a última posição: os outros candidatos serão avisados"), aviso)
        pergunta.buttons["cancelar-escolha-botao"].firstMatch.tap()
        XCTAssertTrue(escolher.waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["resultado-da-escolha"].exists)

        escolher.tap()
        XCTAssertTrue(pergunta.waitForExistence(timeout: 5))
        pergunta.buttons["confirmar-escolha-botao"].firstMatch.tap()

        // Só ele foi confirmado: a lista de candidatos some, e a posição mostra quem ficou.
        let resultado = app.descendants(matching: .any)["resultado-da-escolha"]
        XCTAssertTrue(resultado.waitForExistence(timeout: 10))
        XCTAssertTrue(resultado.label.contains("Bruno Tavares foi confirmado, e a vaga está preenchida"), resultado.label)
        XCTAssertTrue(resultado.label.contains("Os outros candidatos foram avisados"), resultado.label)
        XCTAssertTrue(app.descendants(matching: .any)["selecao-concluida"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["escolher-candidato-\(bruno)"].exists)
        XCTAssertFalse(app.buttons["escolher-candidato-\(ana)"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["dados-do-candidato-\(carla)"].exists)
        XCTAssertTrue(app.staticTexts["1 de 1 confirmadas"].exists)
        XCTAssertTrue(app.staticTexts["Bruno Tavares"].exists)
        XCTAssertTrue(app.buttons["Ver contato liberado"].exists)

        // De volta à lista, o cartão mostra o confirmado e que a seleção terminou.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(cartao.waitForExistence(timeout: 5))
        XCTAssertTrue(cartao.label.contains("1 de 1 confirmadas"), cartao.label)
        XCTAssertTrue(cartao.label.contains("Bruno Tavares"), cartao.label)
        XCTAssertTrue(cartao.label.contains("seleção concluída"), cartao.label)
    }

    // MARK: Critério 4

    func testEscolhaQuePerdeACorridaExplicaERecarrega() {
        let app = abrirVaga(cenario: "escolha-perde-corrida")

        let escolher = app.buttons["escolher-candidato-\(ana)"]
        XCTAssertTrue(escolher.waitForExistence(timeout: 10))
        rolarAte(escolher, em: app)
        escolher.tap()
        let pergunta = app.alerts["Confirmar a escolha?"]
        XCTAssertTrue(pergunta.waitForExistence(timeout: 5))
        pergunta.buttons["confirmar-escolha-botao"].firstMatch.tap()

        // Outro membro da casa chegou antes: a tela explica e já mostra quem ficou com a posição.
        let falha = app.descendants(matching: .any)["falha-da-escolha"]
        XCTAssertTrue(falha.waitForExistence(timeout: 10))
        XCTAssertEqual(falha.label, "Outra pessoa da sua equipe preencheu a última posição antes. Atualizamos a lista.")
        XCTAssertFalse(app.descendants(matching: .any)["resultado-da-escolha"].exists)
        XCTAssertFalse(app.buttons["escolher-candidato-\(ana)"].exists)
        XCTAssertFalse(app.buttons["escolher-candidato-\(carla)"].exists)
        XCTAssertTrue(app.staticTexts["1 de 1 confirmadas"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Bruno Tavares"].exists)
        XCTAssertFalse(app.staticTexts["Ana Cunha"].exists)
    }

    // MARK: Critério 2, do lado da casa

    func testSelecaoQueFechouSemEscolhaAbrePeloAvisoEDizOQueAconteceu() {
        // O aviso `selecao_encerrada` (tipo 18) leva a casa à vaga, como os outros avisos de vaga.
        let app = abrir([
            "-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "selecao-encerrada-sem-escolha",
            "-FRILA_AVISO", "selecao_encerrada", "-FRILA_AVISO_ID", vagaID,
        ])

        XCTAssertTrue(app.descendants(matching: .any)["detalhe-vaga-contratante"].waitForExistence(timeout: 15))
        let fechada = app.descendants(matching: .any)["selecao-fechada-sem-escolha"]
        XCTAssertTrue(fechada.waitForExistence(timeout: 10))
        XCTAssertEqual(fechada.label, "A seleção fechou 24 horas antes do início sem nenhuma escolha. Os candidatos foram avisados e liberados.")
        XCTAssertFalse(app.buttons["escolher-candidato-\(ana)"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["dados-do-candidato-\(ana)"].exists)
        XCTAssertTrue(app.staticTexts["0 de 1 confirmadas"].exists)
        XCTAssertTrue(app.staticTexts["Posição fechada sem escolha"].exists)
        // A vaga fechada pode ser publicada de novo, com outra data.
        XCTAssertTrue(app.buttons["republicar-detalhe-vaga-\(vagaID)"].exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let cartao = app.buttons["vaga-contratante-\(vagaID)"]
        XCTAssertTrue(cartao.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Encerradas"].exists)
        XCTAssertTrue(cartao.label.contains("fechou sem escolha"), cartao.label)
    }

    // MARK: Critério 3

    func testPublicarEmSelecaoComMenosDe24HorasERecusadoNoCampoDoInicio() {
        let app = abrir(["-FRILA_SCENARIO", "contratante-sem-estabelecimento", "-FRILA_CADASTRO_UI_TEST"])
        let continuar = app.buttons["continuar-cadastro"]
        XCTAssertTrue(continuar.waitForExistence(timeout: 15))
        continuar.tap()
        XCTAssertTrue(app.staticTexts["Publicar vaga"].waitForExistence(timeout: 10))

        // O formulário abre em urgência, com a explicação do modo; o início padrão é daqui a 3 horas.
        let modo = app.segmentedControls["modo-vaga-picker"]
        rolarAte(modo, em: app)
        XCTAssertTrue(modo.exists)
        XCTAssertTrue(modo.buttons["Urgência"].isSelected)
        let explicacao = app.staticTexts["modo-vaga-explicacao"]
        XCTAssertEqual(explicacao.label, "O primeiro profissional que aceitar é confirmado na hora.")
        modo.buttons["Seleção"].tap()
        XCTAssertTrue(modo.buttons["Seleção"].isSelected)
        XCTAssertTrue(explicacao.label.contains("O início precisa estar a mais de 24 horas"), explicacao.label)

        let publicar = app.buttons["publicar-vaga-botao"]
        rolarAte(publicar, em: app)
        publicar.tap()

        // Recusada no aparelho, com a regra no campo do início, e a pessoa continua no formulário.
        let erro = app.staticTexts["erro-publicacao-inicio"]
        for _ in 0..<8 where !erro.exists { app.swipeDown(velocity: .slow) }
        XCTAssertTrue(erro.waitForExistence(timeout: 5))
        XCTAssertEqual(erro.label, "Vagas no modo seleção exigem pelo menos 24 horas de antecedência.")
        XCTAssertFalse(app.descendants(matching: .any)["minhas-vagas"].exists)

        // A mesma vaga em urgência é publicada, e o fluxo termina em Minhas vagas.
        rolarAte(modo, em: app)
        modo.buttons["Urgência"].tap()
        rolarAte(publicar, em: app)
        publicar.tap()
        XCTAssertTrue(app.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 15))
    }

    // MARK: Acessibilidade

    func testCandidatosNoMaiorTamanhoDeLetraTemRotuloEAlvoMinimo() {
        let app = abrirVaga(cenario: "selecao-com-candidatos", extras: ["-UIPreferredContentSizeCategoryName", Self.ax5])
        let largura = app.windows.firstMatch.frame.width

        for (id, nome) in [(ana, "Ana Cunha"), (bruno, "Bruno Tavares")] {
            let dados = app.descendants(matching: .any)["dados-do-candidato-\(id)"]
            rolarAte(dados, em: app)
            XCTAssertTrue(dados.exists)
            XCTAssertTrue(dados.label.contains(nome), dados.label)
            XCTAssertLessThanOrEqual(dados.frame.maxX, largura, "os dados de \(nome) passaram da largura da tela")

            let perfil = app.buttons["perfil-do-candidato-\(id)"]
            rolarAte(perfil, em: app)
            XCTAssertTrue(perfil.isHittable)
            XCTAssertEqual(perfil.label, "Ver perfil público de \(nome)")
            XCTAssertAlvoMinimo(perfil.frame.height)

            let escolher = app.buttons["escolher-candidato-\(id)"]
            rolarAte(escolher, em: app)
            XCTAssertTrue(escolher.isHittable)
            XCTAssertEqual(escolher.label, "Escolher \(nome)")
            XCTAssertAlvoMinimo(escolher.frame.height)
            XCTAssertAlvoMinimo(escolher.frame.width)
            XCTAssertLessThanOrEqual(escolher.frame.maxX, largura)
        }

        // O alerta de confirmação cabe e responde no tamanho grande.
        let escolher = app.buttons["escolher-candidato-\(bruno)"]
        escolher.tap()
        let pergunta = app.alerts["Confirmar a escolha?"]
        XCTAssertTrue(pergunta.waitForExistence(timeout: 5))
        XCTAssertTrue(pergunta.buttons["confirmar-escolha-botao"].firstMatch.isHittable)
        pergunta.buttons["cancelar-escolha-botao"].firstMatch.tap()
        XCTAssertTrue(escolher.waitForExistence(timeout: 5))
    }
}
