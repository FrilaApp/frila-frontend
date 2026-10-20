import XCTest

@MainActor
final class FluxoDoContratanteUITests: XCTestCase {
    func testContratanteComEstabelecimentoAbreMinhasVagasESai() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "contratante"]
        AjudanteDeLancamentoUITests.preparar(app)
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 10))
        let captura = XCTAttachment(screenshot: app.screenshot())
        captura.lifetime = .keepAlways
        add(captura)
        let sair = app.buttons["sair-fluxo-contratante"]
        XCTAssertTrue(sair.isHittable)
        sair.tap()
        XCTAssertTrue(app.textFields["entrada-email"].waitForExistence(timeout: 10))
    }

    func testPrimeiroAcessoDoContratanteAbreCadastroComResponsavelDaConta() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ENTRADA", "-FRILA_SCENARIO", "primeiro-acesso"]
        AjudanteDeLancamentoUITests.preparar(app)
        app.launch()

        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.digitarEEsperar("contratante@frila.app")
        tocar(app.buttons["entrada-receber-codigo"])
        let codigo = app.textFields["Código de acesso"]
        XCTAssertTrue(codigo.waitForExistence(timeout: 10))
        codigo.tap()
        codigo.typeText("123456")
        if app.buttons["codigo-entrar"].waitForExistence(timeout: 2) {
            app.buttons["codigo-entrar"].tap()
        }

        let perfil = app.buttons["cadastro-perfil-contratante"]
        XCTAssertTrue(perfil.waitForExistence(timeout: 10))
        perfil.tap()
        let nome = app.textFields["cadastro-nome"]
        nome.tap()
        nome.digitarEEsperar("Responsável do Café")
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

        XCTAssertTrue(app.buttons["continuar-cadastro"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Responsável do Café"].exists)
        XCTAssertTrue(app.staticTexts["+5561988887777"].exists)
        let captura = XCTAttachment(screenshot: app.screenshot())
        captura.lifetime = .keepAlways
        add(captura)
        let sair = app.buttons["sair-fluxo-contratante"]
        XCTAssertTrue(sair.isHittable)
        sair.tap()
        XCTAssertTrue(app.textFields["entrada-email"].waitForExistence(timeout: 10))
    }

    func testPrimeiroAcessoDoContratantePublicaPrimeiraVagaETerminaEmMinhasVagas() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_ENTRADA",
            "-FRILA_SCENARIO", "primeiro-acesso",
            "-FRILA_CADASTRO_UI_TEST"
        ]
        AjudanteDeLancamentoUITests.preparar(app)
        app.launch()

        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.digitarEEsperar("contratante@frila.app")
        tocar(app.buttons["entrada-receber-codigo"])
        let codigo = app.textFields["Código de acesso"]
        XCTAssertTrue(codigo.waitForExistence(timeout: 10))
        codigo.tap()
        codigo.typeText("123456")
        if app.buttons["codigo-entrar"].waitForExistence(timeout: 2) {
            app.buttons["codigo-entrar"].tap()
        }

        let perfil = app.buttons["cadastro-perfil-contratante"]
        XCTAssertTrue(perfil.waitForExistence(timeout: 10))
        perfil.tap()
        let nome = app.textFields["cadastro-nome"]
        nome.tap()
        nome.digitarEEsperar("Responsável do Café")
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

        // 1. Tela de Cadastro do Estabelecimento
        let continuarCadastro = app.buttons["continuar-cadastro"]
        XCTAssertTrue(continuarCadastro.waitForExistence(timeout: 10))
        continuarCadastro.tap()

        // 2. Tela de Publicar Vaga
        XCTAssertTrue(app.staticTexts["Publicar vaga"].waitForExistence(timeout: 10))
        let botaoPublicar = app.buttons["publicar-vaga-botao"]
        XCTAssertTrue(botaoPublicar.waitForExistence(timeout: 10))
        trazerParaATela(botaoPublicar, em: app)
        botaoPublicar.tap()

        // 3. Termina em Minhas vagas de verdade, com a vaga publicada
        XCTAssertTrue(app.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["A lista Minhas vagas estará disponível em breve"].exists)
    }

    func testPrimeiroAcessoComFilaNulaSalvaEstabelecimentoEAbreMinhasVagas() {
        conferirPrimeiroAcessoComFilaNula(categoria: "UICTContentSizeCategoryL", captura: "normal")
    }

    func testPrimeiroAcessoComFilaNulaSalvaEstabelecimentoEAbreMinhasVagasEmAX5() {
        conferirPrimeiroAcessoComFilaNula(categoria: "UICTContentSizeCategoryAccessibilityXXXL", captura: "AX5")
    }

    private func conferirPrimeiroAcessoComFilaNula(categoria: String, captura: String) {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_ENTRADA", "-FRILA_SCENARIO", "primeiro-acesso",
            "-FRILA_CADASTRO_UI_TEST", "-FRILA_SEM_FILA_UI_TEST",
            "-UIPreferredContentSizeCategoryName", categoria
        ]
        AjudanteDeLancamentoUITests.preparar(app)
        app.launch()

        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.digitarEEsperar("contratante@frila.app")
        tocar(app.buttons["entrada-receber-codigo"])
        let codigo = app.textFields["Código de acesso"]
        XCTAssertTrue(codigo.waitForExistence(timeout: 10))
        codigo.tap()
        codigo.typeText("123456")
        if app.buttons["codigo-entrar"].waitForExistence(timeout: 2) {
            app.buttons["codigo-entrar"].tap()
        }

        let perfil = app.buttons["cadastro-perfil-contratante"]
        XCTAssertTrue(perfil.waitForExistence(timeout: 10))
        trazerParaATela(perfil, em: app)
        perfil.tap()
        let nome = app.textFields["cadastro-nome"]
        trazerParaATela(nome, em: app)
        nome.tap()
        nome.digitarEEsperar("Responsável do Café")
        fecharTecladoSeVisivel(app: app)
        let telefone = app.textFields["cadastro-telefone"]
        trazerParaATela(telefone, em: app)
        telefone.tap()
        telefone.digitarEEsperar("61988887777", esperado: "(61) 98888-7777")
        fecharTecladoSeVisivel(app: app)

        let nascimento = app.textFields["cadastro-nascimento"]
        trazerParaATela(nascimento, em: app)
        nascimento.tap()
        nascimento.digitarEEsperar("15/05/1995", esperado: "15/05/1995")
        fecharTecladoSeVisivel(app: app)

        let termos = app.buttons["cadastro-termos"]
        trazerParaATela(termos, em: app)
        termos.tap()

        let continuar = app.buttons["cadastro-continuar"]
        trazerParaATela(continuar, em: app)
        continuar.tap()

        let continuarCadastro = app.buttons["continuar-cadastro"]
        XCTAssertTrue(continuarCadastro.waitForExistence(timeout: 10))
        let responsavel = app.staticTexts["Responsável do Café"]
        trazerParaATela(responsavel, em: app)
        XCTAssertTrue(responsavel.exists)
        XCTAssertTrue(app.staticTexts["+5561988887777"].exists)
        XCTAssertFalse(app.staticTexts["Algo deu errado"].exists)
        anexarCaptura(app, nome: "fila-nula-\(captura)-responsavel")

        trazerParaATela(continuarCadastro, em: app)
        XCTAssertTrue(continuarCadastro.isEnabled)
        anexarCaptura(app, nome: "fila-nula-\(captura)-salvar-estabelecimento")
        continuarCadastro.tap()

        // Prova comportamental da fila nula: com fila, salvar abre Publicar vaga e não
        // chega a Minhas vagas sem publicar (coberto pelo teste existente acima).
        XCTAssertTrue(app.descendants(matching: .any)["minhas-vagas"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.descendants(matching: .any)["publicar-vaga-formulario"].exists)
        XCTAssertFalse(app.buttons["publicar-vaga-entrada"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["estado-vazio-minhas-vagas"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Algo deu errado"].exists)
        anexarCaptura(app, nome: "fila-nula-\(captura)-minhas-vagas")

        let perfilEstabelecimento = app.buttons["abrir-perfil-estabelecimento"]
        XCTAssertTrue(perfilEstabelecimento.isHittable)
        perfilEstabelecimento.tap()
        XCTAssertTrue(app.staticTexts["Café de teste"].waitForExistence(timeout: 10))
        anexarCaptura(app, nome: "fila-nula-\(captura)-perfil-estabelecimento")
    }

    private func anexarCaptura(_ app: XCUIApplication, nome: String) {
        let anexo = XCTAttachment(screenshot: app.screenshot())
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)
    }

    private func trazerParaATela(_ elemento: XCUIElement, em app: XCUIApplication, tentativas: Int = 8) {
        let janela = app.windows.firstMatch.frame
        let margemSuperior: CGFloat = 120
        let margemInferior: CGFloat = 60

        for _ in 0..<tentativas {
            guard elemento.exists else {
                app.swipeUp(velocity: .slow)
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
                app.swipeDown(velocity: .slow)
            case .rolarParaCima:
                app.swipeUp(velocity: .slow)
            }
            if direcao == .nenhuma { break }
        }
    }

    private func fecharTecladoSeVisivel(app: XCUIApplication) {
        if app.keyboards.element.exists {
            let inicio = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
            let fim = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
            inicio.press(forDuration: 0.05, thenDragTo: fim)
        }
    }

    private func rolarAte(_ elemento: XCUIElement, app: XCUIApplication) {
        if elemento.isHittable && !app.keyboards.element.exists { return }
        for _ in 0..<6 {
            if elemento.isHittable && !app.keyboards.element.exists { return }
            let inicio = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.60))
            let fim = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
            inicio.press(forDuration: 0.05, thenDragTo: fim)
        }
        if !elemento.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(elemento.isHittable)
    }
}
