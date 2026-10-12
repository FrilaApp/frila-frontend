import XCTest

/// US18 (#124): denominadores e ausência de histórico no perfil público, usando o dublê local.
@MainActor
final class ReputacaoDosPerfisPublicosUITests: XCTestCase {
    func testPerfisComESemHistoricoNoTamanhoPadrao() {
        conferirPerfis(tamanho: "padrao", argumentos: [])
    }

    func testPerfisComESemHistoricoEmAX5() {
        conferirPerfis(tamanho: "ax5", argumentos: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
    }

    private func conferirPerfis(tamanho: String, argumentos: [String]) {
        continueAfterFailure = false
        let app = AjudanteDeLancamentoUITests.abrir(argumentos: [
            "-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "selecao-com-candidatos",
            "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR"
        ] + argumentos)
        defer { app.terminate() }

        let vaga = app.buttons["vaga-contratante-40000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(vaga.waitForExistence(timeout: 15))
        conferirBotao(vaga, em: app)
        vaga.tap()
        let detalhe = app.descendants(matching: .any)["detalhe-vaga-contratante"]
        if !detalhe.waitForExistence(timeout: 10), vaga.exists, vaga.isHittable { vaga.tap() }
        XCTAssertTrue(detalhe.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["candidatos-da-vaga"].waitForExistence(timeout: 10))

        let perfis = [
            (id: "70000000-0000-0000-0000-000000000002", nome: "Bruno Tavares", slug: "bruno",
             recomendacao: "10 de 12 chamariam de novo", comparecimento: "Compareceu a 18 de 20 turnos"),
            (id: "70000000-0000-0000-0000-000000000003", nome: "Carla Menezes", slug: "carla",
             recomendacao: "Sem histórico", comparecimento: "Ainda não há turnos considerados.")
        ]
        for perfil in perfis {
            let abrir = app.buttons["perfil-do-candidato-\(perfil.id)"]
            rolarAte(abrir, em: app)
            conferirBotao(abrir, em: app)
            XCTAssertEqual(abrir.label, "Ver perfil público de \(perfil.nome)")
            capturar(app, nome: "\(tamanho)-candidatos-\(perfil.slug)")
            abrir.tap()
            XCTAssertTrue(app.descendants(matching: .any)["perfil-publico-contratante"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.staticTexts[perfil.nome].waitForExistence(timeout: 10))

            let recomendacao = app.staticTexts[perfil.recomendacao]
            let comparecimento = app.staticTexts[perfil.comparecimento]
            XCTAssertTrue(recomendacao.waitForExistence(timeout: 5))
            XCTAssertTrue(comparecimento.waitForExistence(timeout: 5))
            rolarAte(recomendacao, em: app)
            conferirLimitesHorizontais(recomendacao, em: app)
            XCTAssertEqual(recomendacao.label, perfil.recomendacao)
            rolarAte(comparecimento, em: app)
            conferirLimitesHorizontais(comparecimento, em: app)
            XCTAssertEqual(comparecimento.label, perfil.comparecimento)
            if perfil.slug == "carla" {
                XCTAssertFalse(app.staticTexts["10 de 12 chamariam de novo"].exists)
                XCTAssertFalse(app.staticTexts["Compareceu a 18 de 20 turnos"].exists)
                XCTAssertFalse(app.staticTexts["0 de 0 chamariam de novo"].exists)
                XCTAssertFalse(app.staticTexts["Compareceu a 0 de 0 turnos"].exists)
            }
            capturar(app, nome: "\(tamanho)-perfil-\(perfil.slug)")

            let voltar = app.navigationBars.buttons.element(boundBy: 0)
            conferirBotao(voltar, em: app)
            voltar.tap()
            XCTAssertTrue(app.descendants(matching: .any)["candidatos-da-vaga"].waitForExistence(timeout: 5))
        }
    }

    private func rolarAte(_ elemento: XCUIElement, em app: XCUIApplication) {
        let janela = app.windows.firstMatch.frame
        for _ in 0..<12 {
            if elemento.exists, elemento.isHittable {
                let quadro = elemento.frame
                if quadro.minY >= janela.minY + 100, quadro.maxY <= janela.maxY - 40 { return }
                if quadro.minY < janela.minY + 100 { app.swipeDown(); continue }
            }
            app.swipeUp()
        }
        XCTFail("Elemento não ficou inteiramente visível: \(elemento.identifier)")
    }

    private func conferirBotao(_ botao: XCUIElement, em app: XCUIApplication) {
        XCTAssertTrue(botao.exists)
        XCTAssertTrue(botao.isHittable, botao.label)
        XCTAssertAlvoMinimo(botao.frame.width, botao.label)
        XCTAssertAlvoMinimo(botao.frame.height, botao.label)
        conferirLimitesHorizontais(botao, em: app)
    }

    private func conferirLimitesHorizontais(_ elemento: XCUIElement, em app: XCUIApplication) {
        let janela = app.windows.firstMatch.frame
        XCTAssertGreaterThan(elemento.frame.width, 0)
        XCTAssertGreaterThanOrEqual(elemento.frame.minX, janela.minX - AlvoMinimo.tolerancia, elemento.label)
        XCTAssertLessThanOrEqual(elemento.frame.maxX, janela.maxX + AlvoMinimo.tolerancia, elemento.label)
    }

    private func capturar(_ app: XCUIApplication, nome: String) {
        let captura = XCTAttachment(screenshot: app.screenshot())
        captura.name = nome
        captura.lifetime = .keepAlways
        add(captura)
    }
}
