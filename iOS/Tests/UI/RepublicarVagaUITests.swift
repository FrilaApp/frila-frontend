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
        XCTAssertTrue(app.descendants(matching: .any)["tela-republicar-vaga"].waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(app.staticTexts["Republicar vaga"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["cartao-dados-copiados-republicacao"].exists)

        let anexo = XCTAttachment(screenshot: app.screenshot())
        anexo.name = "republicar-vaga"
        anexo.lifetime = .keepAlways
        add(anexo)

        // Toca em confirmar republicação
        let botaoConfirmar = app.buttons["botao-confirmar-republicacao"]
        XCTAssertTrue(botaoConfirmar.waitForExistence(timeout: Espera.aparecer))
        botaoConfirmar.tap()

        // A folha fecha
        let telaRepublicar = app.descendants(matching: .any)["tela-republicar-vaga"]
        XCTAssertTrue(telaRepublicar.waitForNonExistence(timeout: 10))

        XCTAssertTrue(app.descendants(matching: .any)["aviso-sucesso-republicacao"].waitForExistence(timeout: Espera.aparecer))

        // A lista de Minhas vagas permanece visível com a nova vaga ativa (seção Em alerta, Hoje ou Próximas)
        XCTAssertTrue(app.staticTexts["Minhas vagas"].waitForExistence(timeout: 10))
        XCTAssertTrue(
            app.staticTexts["Precisa de atenção"].waitForExistence(timeout: 5)
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
        XCTAssertTrue(republicar.waitForExistence(timeout: Espera.aparecer))
        republicar.tap()
        let confirmar = app.buttons["botao-confirmar-republicacao"]
        XCTAssertTrue(confirmar.waitForExistence(timeout: Espera.aparecer))
        confirmar.tap()
        XCTAssertTrue(app.descendants(matching: .any)["tela-republicar-vaga"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["aviso-sucesso-republicacao"].waitForExistence(timeout: Espera.aparecer))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Precisa de atenção"].waitForExistence(timeout: 5)
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

        let larguraTela = app.windows.firstMatch.frame.width
        let elementos: [(String, XCUIElement)] = [
            ("cartao", app.descendants(matching: .any)["cartao-dados-copiados-republicacao"]),
            ("campo-inicio", app.descendants(matching: .any)["campo-inicio-republicacao"]),
            ("campo-fim", app.descendants(matching: .any)["campo-fim-republicacao"]),
            ("botao-confirmar", app.buttons["botao-confirmar-republicacao"]),
            ("botao-cancelar", app.buttons["botao-cancelar-republicacao"])
        ]

        for (nome, elemento) in elementos {
            XCTAssertTrue(elemento.waitForExistence(timeout: Espera.aparecer), "Elemento \(nome) deve existir")
            let frame = elemento.frame
            XCTAssertGreaterThanOrEqual(frame.minX, 0.0, "Elemento \(nome) minX=\(frame.minX) deve iniciar >= 0")
            XCTAssertLessThanOrEqual(frame.maxX, larguraTela, "Elemento \(nome) maxX=\(frame.maxX) deve caber na largura \(larguraTela)")
        }

        let dpInicio = app.descendants(matching: .any)["campo-inicio-republicacao"]
        XCTAssertTrue(dpInicio.waitForExistence(timeout: Espera.aparecer), "O campo Início deve existir")
        trazerParaATela(dpInicio, em: app)
        XCTAssertTrue(dpInicio.isHittable, "O campo Início deve ser tocável em AX5")

        let dpFim = app.descendants(matching: .any)["campo-fim-republicacao"]
        XCTAssertTrue(dpFim.waitForExistence(timeout: Espera.aparecer), "O campo Término deve existir")
        trazerParaATela(dpFim, em: app)
        XCTAssertTrue(dpFim.isHittable, "O campo Término deve ser tocável em AX5")

        let seletores = app.buttons.matching(NSPredicate(format: "label == 'Seletor de Data e Hora'")).allElementsBoundByIndex
        for seletor in seletores {
            if let valor = seletor.value as? String {
                XCTAssertFalse(valor.contains("…") || valor.contains("..."), "Valor do seletor '\(valor)' não deve estar truncado com reticências")
            }
        }
    }

    /// R8b, item 9b: em AX5, arrastar a tela de republicar pelo centro não muda início nem término (roda solta na rolagem gira
    /// com o dedo e a vaga seria republicada no horário errado). O seletor fica numa folha, fora da rolagem.
    func testEmAX5RolarPeloCentroNaoMudaInicioNemTermino() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-FRILA_ABRIR_MINHAS_VAGAS",
            "-FRILA_SCENARIO", "vaga-encerrada-contratante",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()
        let botaoRepublicar = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "republicar-vaga-")).firstMatch
        XCTAssertTrue(botaoRepublicar.waitForExistence(timeout: 10))
        botaoRepublicar.tap()
        XCTAssertTrue(app.descendants(matching: .any)["tela-republicar-vaga"].waitForExistence(timeout: 10))

        // O campo é um seletor de data na rolagem (antes do conserto) ou uma linha que abre a folha (depois): o que vale é o
        // identificador, buscado de novo a cada leitura.
        func campo(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
        XCTAssertTrue(campo("campo-inicio-republicacao").waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(campo("campo-fim-republicacao").waitForExistence(timeout: Espera.aparecer))
        func leitura() -> [String] {
            ["campo-inicio-republicacao", "campo-fim-republicacao"].map { id in
                let elemento = campo(id)
                return elemento.exists ? "\(elemento.label)|\(String(describing: elemento.value ?? ""))" : "ausente"
            } + app.pickerWheels.allElementsBoundByIndex.map { String(describing: $0.value ?? "") }
        }
        // Leva o início para o meio da janela arrastando pela margem (fora de qualquer controle) e arrasta por cima dele, como
        // quem rola a tela com o dedo passando pelo seletor: a roda, se houver, gira com o dedo.
        let janela = app.windows.firstMatch
        let margem = janela.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
        let altura = janela.frame.height
        for _ in 0..<12 {
            let meioDoCampo = campo("campo-inicio-republicacao").frame.midY
            if meioDoCampo > altura * 0.62 {
                margem.press(forDuration: 0.05, thenDragTo: janela.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.3)))
            } else if meioDoCampo < altura * 0.38 {
                margem.press(forDuration: 0.05, thenDragTo: janela.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.7)))
            } else {
                break
            }
        }
        let antes = leitura()
        let meio = campo("campo-inicio-republicacao").frame.midY / altura
        let de = janela.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: meio + 0.05))
        let ate = janela.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: meio - 0.05))
        de.press(forDuration: 0.05, thenDragTo: ate)

        XCTAssertEqual(app.pickerWheels.count, 0, "nenhuma roda solta na rolagem de republicar em AX5")
        XCTAssertEqual(leitura(), antes, "arrastar por cima do início não muda o início nem o término")
    }

    /// R8b, item 9b: a linha do início abre a folha com as rodas e "Fechar" volta à tela, sem rodas na rolagem.
    func testEmAX5ALinhaDoInicioAbreAFolhaComAsRodasEFechaVoltandoParaATela() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-FRILA_ABRIR_MINHAS_VAGAS",
            "-FRILA_SCENARIO", "vaga-encerrada-contratante",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()
        let botaoRepublicar = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "republicar-vaga-")).firstMatch
        XCTAssertTrue(botaoRepublicar.waitForExistence(timeout: 10))
        botaoRepublicar.tap()
        let linha = app.buttons["campo-inicio-republicacao"]
        XCTAssertTrue(linha.waitForExistence(timeout: 10), "o início é uma linha em AX5")
        XCTAssertEqual(app.pickerWheels.count, 0, "sem rodas soltas na rolagem")
        trazerParaATela(linha, em: app)
        linha.tap()
        XCTAssertTrue(app.descendants(matching: .any)["republicar-folha-de-horario"].waitForExistence(timeout: Espera.aparecer))
        XCTAssertGreaterThan(app.pickerWheels.count, 0, "a folha traz as rodas")
        app.buttons["republicar-fechar-horario"].tap()
        XCTAssertTrue(linha.waitForExistence(timeout: Espera.aparecer))
        XCTAssertEqual(app.pickerWheels.count, 0)
        XCTAssertFalse(String(describing: linha.value ?? "").isEmpty)
    }

    private func trazerParaATela(_ elemento: XCUIElement, em app: XCUIApplication, tentativas: Int = 8) {
        let janela = app.windows.firstMatch.frame
        for _ in 0..<tentativas {
            guard elemento.exists else {
                app.swipeUp()
                continue
            }
            if elemento.isHittable, elemento.frame.minY >= 100, elemento.frame.maxY <= janela.height - 60 { return }
            if elemento.frame.minY < 100 {
                app.swipeDown()
            } else {
                app.swipeUp()
            }
        }
    }
}

