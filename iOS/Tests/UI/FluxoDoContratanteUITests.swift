import XCTest

@MainActor
final class FluxoDoContratanteUITests: XCTestCase {
    func testContratanteComEstabelecimentoAbreMinhasVagasESai() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "contratante"]
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
        app.launch()

        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.digitarEEsperar("contratante@frila.app")
        app.buttons["entrada-receber-codigo"].tap()
        let codigo = app.textFields["Código de acesso"]
        XCTAssertTrue(codigo.waitForExistence(timeout: 10))
        codigo.tap()
        codigo.typeText("123456")
        app.buttons["codigo-entrar"].tap()

        let perfil = app.buttons["cadastro-perfil-contratante"]
        XCTAssertTrue(perfil.waitForExistence(timeout: 10))
        perfil.tap()
        let nome = app.textFields["cadastro-nome"]
        nome.tap()
        nome.typeText("Responsável do Café")
        let telefone = app.textFields["cadastro-telefone"]
        telefone.tap()
        telefone.typeText("61988887777")
        let nascimento = app.textFields["cadastro-nascimento"]
        nascimento.tap()
        nascimento.typeText("15/05/1995")
        app.buttons["cadastro-maior-de-idade"].tap()
        app.buttons["cadastro-termos"].tap()
        app.buttons["cadastro-continuar"].tap()

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
        app.launch()

        let email = app.textFields["entrada-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.digitarEEsperar("contratante@frila.app")
        app.buttons["entrada-receber-codigo"].tap()
        let codigo = app.textFields["Código de acesso"]
        XCTAssertTrue(codigo.waitForExistence(timeout: 10))
        codigo.tap()
        codigo.typeText("123456")
        app.buttons["codigo-entrar"].tap()

        let perfil = app.buttons["cadastro-perfil-contratante"]
        XCTAssertTrue(perfil.waitForExistence(timeout: 10))
        perfil.tap()
        let nome = app.textFields["cadastro-nome"]
        nome.tap()
        nome.typeText("Responsável do Café")
        let telefone = app.textFields["cadastro-telefone"]
        telefone.tap()
        telefone.typeText("61988887777")
        let nascimento = app.textFields["cadastro-nascimento"]
        nascimento.tap()
        nascimento.typeText("15/05/1995")
        app.buttons["cadastro-maior-de-idade"].tap()
        app.buttons["cadastro-termos"].tap()
        app.buttons["cadastro-continuar"].tap()

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
            let visivel = elemento.isHittable
                && quadro.minY >= margemSuperior
                && quadro.maxY <= (janela.height - margemInferior)
            if visivel { break }

            if quadro.maxY > (janela.height - margemInferior) || !elemento.isHittable {
                app.swipeUp(velocity: .slow)
            } else if quadro.minY < margemSuperior {
                app.swipeDown(velocity: .slow)
            }
        }
    }
}
