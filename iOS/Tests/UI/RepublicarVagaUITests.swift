import XCTest

@MainActor
final class RepublicarVagaUITests: XCTestCase {
    func testRepublicarVagaEncerradaCaminhoFeliz() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-FRILA_ABRIR_MINHAS_VAGAS",
            "-FRILA_SCENARIO", "vaga-encerrada-contratante"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Minhas vagas"].waitForExistence(timeout: 10))

        // Na seção de encerradas, o botão de publicar de novo existe
        let botaoRepublicar = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "republicar-vaga-")).firstMatch
        XCTAssertTrue(botaoRepublicar.waitForExistence(timeout: 10))
        botaoRepublicar.tap()

        // Abre a tela de republicação com os dados copiados
        XCTAssertTrue(app.descendants(matching: .any)["tela-republicar-vaga"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Republicar vaga"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["cartao-dados-copiados-republicacao"].exists)

        let anexo = XCTAttachment(screenshot: app.screenshot())
        anexo.name = "republicar-vaga"
        anexo.lifetime = .keepAlways
        add(anexo)

        // Toca em confirmar republicação
        let botaoConfirmar = app.buttons["botao-confirmar-republicacao"]
        XCTAssertTrue(botaoConfirmar.waitForExistence(timeout: 5))
        botaoConfirmar.tap()

        // A folha fecha
        let telaRepublicar = app.descendants(matching: .any)["tela-republicar-vaga"]
        XCTAssertTrue(telaRepublicar.waitForNonExistence(timeout: 10))

        XCTAssertTrue(app.descendants(matching: .any)["aviso-sucesso-republicacao"].waitForExistence(timeout: 5))

        // A lista de Minhas vagas permanece visível com a nova vaga ativa (seção Em alerta, Hoje ou Próximas)
        XCTAssertTrue(app.staticTexts["Minhas vagas"].waitForExistence(timeout: 10))
        XCTAssertTrue(
            app.staticTexts["Em alerta"].waitForExistence(timeout: 5)
            || app.staticTexts["Hoje"].waitForExistence(timeout: 5)
            || app.staticTexts["Próximas"].waitForExistence(timeout: 5)
        )
    }

    func testRepublicarPeloDetalheMostraConfirmacaoEAtualizaLista() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "vaga-encerrada-contratante"]
        app.launch()
        let vaga = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "vaga-contratante-")).firstMatch
        XCTAssertTrue(vaga.waitForExistence(timeout: 10))
        vaga.tap()
        let republicar = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "republicar-detalhe-vaga-")).firstMatch
        XCTAssertTrue(republicar.waitForExistence(timeout: 5))
        republicar.tap()
        let confirmar = app.buttons["botao-confirmar-republicacao"]
        XCTAssertTrue(confirmar.waitForExistence(timeout: 5))
        confirmar.tap()
        XCTAssertTrue(app.descendants(matching: .any)["tela-republicar-vaga"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["aviso-sucesso-republicacao"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Em alerta"].waitForExistence(timeout: 5)
                      || app.staticTexts["Hoje"].waitForExistence(timeout: 5)
                      || app.staticTexts["Próximas"].waitForExistence(timeout: 5))
    }

    func testRepublicarVagaCabeNaLarguraNoMaiorDynamicTypeSE() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_ABRIR_MINHAS_VAGAS",
            "-FRILA_SCENARIO", "vaga-encerrada-contratante",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()

        let botaoRepublicar = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "republicar-vaga-")).firstMatch
        XCTAssertTrue(botaoRepublicar.waitForExistence(timeout: 10))
        botaoRepublicar.tap()

        let telaRepublicar = app.descendants(matching: .any)["tela-republicar-vaga"]
        XCTAssertTrue(telaRepublicar.waitForExistence(timeout: 10))

        let larguraTela: CGFloat = 375.0
        let elementos: [(String, XCUIElement)] = [
            ("cartao", app.descendants(matching: .any)["cartao-dados-copiados-republicacao"]),
            ("campo-inicio", app.descendants(matching: .any)["campo-inicio-republicacao"]),
            ("campo-fim", app.descendants(matching: .any)["campo-fim-republicacao"]),
            ("botao-confirmar", app.buttons["botao-confirmar-republicacao"]),
            ("botao-cancelar", app.buttons["botao-cancelar-republicacao"])
        ]

        for (nome, elemento) in elementos {
            XCTAssertTrue(elemento.waitForExistence(timeout: 5), "Elemento \(nome) deve existir")
            let frame = elemento.frame
            XCTAssertGreaterThanOrEqual(frame.minX, 0.0, "Elemento \(nome) minX=\(frame.minX) deve iniciar >= 0")
            XCTAssertLessThanOrEqual(frame.maxX, larguraTela, "Elemento \(nome) maxX=\(frame.maxX) deve caber na largura \(larguraTela)")
        }

        let seletores = app.buttons.matching(NSPredicate(format: "label == 'Seletor de Data e Hora'")).allElementsBoundByIndex
        for seletor in seletores {
            if let valor = seletor.value as? String {
                XCTAssertFalse(valor.contains("…") || valor.contains("..."), "Valor do seletor '\(valor)' não deve estar truncado com reticências")
            }
        }
    }
}

