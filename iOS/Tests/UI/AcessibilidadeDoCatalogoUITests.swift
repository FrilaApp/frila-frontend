import XCTest

/// Critérios 2 e 3 do #139, medidos no catálogo: Dynamic Type no maior tamanho de acessibilidade
/// (AX5) e alvo de 44 pt com rótulo em todo controle.
@MainActor
final class AcessibilidadeDoCatalogoUITests: XCTestCase {
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"
    private var appAtual: XCUIApplication?

    override func tearDown() {
        if let appAtual, let testRun, testRun.failureCount > 0 {
            let anexo = XCTAttachment(screenshot: appAtual.screenshot())
            anexo.name = "falha-\(name)"
            anexo.lifetime = .keepAlways
            add(anexo)
        }
        appAtual = nil
        super.tearDown()
    }

    private func abrirCatalogo(tamanho: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        appAtual = app
        app.launchArguments = ["-FRILA_ABRIR_CATALOGO", "-FRILA_SCENARIO", "success"]
        if let tamanho { app.launchArguments += ["-UIPreferredContentSizeCategoryName", tamanho] }
        app.launch()
        XCTAssertTrue(app.navigationBars["Frila UI"].waitForExistence(timeout: 10))
        return app
    }

    /// Rola até o elemento ficar totalmente visível na área segura e espera a rolagem parar.
    /// Um elemento na borda inferior pode ter `isHittable == true` pelo XCTest mesmo estando
    /// cortado pela tela ou sob a área do indicador de início (home indicator), onde toques
    /// com deslocamento caem fora da área útil.
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

        var anterior = CGRect.null
        for _ in 0..<10 {
            let atual = elemento.frame
            if atual == anterior { break }
            anterior = atual
            Thread.sleep(forTimeInterval: 0.3)
        }
    }

    /// Percorre o catálogo inteiro em AX5 e confere cada botão e campo que aparece na tela.
    func testTodoControleTemRotuloEAlvoMinimoEmAX5() {
        let app = abrirCatalogo(tamanho: Self.ax5)
        var conferidos = Set<String>()
        var problemas: [String] = []

        for _ in 0..<40 {
            let controles = app.buttons.allElementsBoundByIndex + app.textFields.allElementsBoundByIndex
            for controle in controles where controle.exists && controle.isHittable {
                let chave = "\(controle.elementType.rawValue)|\(controle.identifier)|\(controle.label)"
                guard conferidos.insert(chave).inserted else { continue }
                let quadro = controle.frame
                if controle.label.trimmingCharacters(in: .whitespaces).isEmpty
                    && controle.placeholderValue?.isEmpty != false {
                    problemas.append("sem rótulo: \(controle.elementType) \(controle.identifier)")
                }
                if quadro.height < 44 || quadro.width < 44 {
                    problemas.append("alvo \(Int(quadro.width))×\(Int(quadro.height)) pt: \(controle.label)")
                }
            }
            let antes = app.screenshot().pngRepresentation
            app.swipeUp()
            if app.screenshot().pngRepresentation == antes { break }
        }

        XCTAssertGreaterThan(conferidos.count, 8, "o percurso não encontrou os controles do catálogo")
        XCTAssertTrue(problemas.isEmpty, problemas.joined(separator: "\n"))
    }

    /// O alvo de 44 pt só vale se a borda também responde: um frame transparente sem
    /// `contentShape` mede 44 pt e não recebe o toque fora do texto.
    func testToqueNaBordaDaPilulaAlternaOFiltro() {
        let app = abrirCatalogo()
        let pilula = app.buttons["Perto de mim"]
        XCTAssertTrue(pilula.waitForExistence(timeout: 5))
        XCTAssertTrue(pilula.isSelected, "o catálogo abre com o filtro ligado")

        pilula.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()

        XCTAssertFalse(pilula.isSelected, "o toque na borda de cima da pílula não chegou ao botão")
    }

    func testToqueNaBordaDoSimSeleciona() {
        let app = abrirCatalogo()
        let sim = app.buttons["Sim"]
        trazerParaATela(sim, em: app, tentativas: 6)
        XCTAssertTrue(sim.isHittable)
        XCTAssertFalse(sim.isSelected)

        sim.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.1)).tap()

        XCTAssertTrue(sim.isSelected, "o toque no canto do Sim não chegou ao botão")
    }

    /// Botão de largura total com o texto no meio: a lateral fica longe do texto.
    func testToqueNaLateralDoBotaoSecundarioDispara() {
        let app = XCUIApplication()
        appAtual = app
        app.launchArguments = ["-FRILA_ABRIR_CATALOGO", "-FRILA_SCENARIO", "vaga-preenchida"]
        app.launch()
        let botao = app.buttons["Simular vaga preenchida"]
        XCTAssertTrue(botao.waitForExistence(timeout: 10))
        trazerParaATela(botao, em: app)
        XCTAssertTrue(botao.isHittable)

        botao.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.5)).tap()

        let apareceu = app.staticTexts["Esta vaga acabou de ser preenchida. Escolha outra oportunidade."].waitForExistence(timeout: 5)
        if !apareceu {
            let captura = XCTAttachment(screenshot: app.screenshot())
            captura.name = "falha-toque-lateral"
            captura.lifetime = .keepAlways
            add(captura)
        }
        XCTAssertTrue(apareceu, "o toque na lateral do botão não chegou à ação")
    }

    /// Capturas do catálogo em AX5, anexadas ao resultado, para conferir texto cortado.
    func testCapturasDoCatalogoEmAX5() {
        let app = abrirCatalogo(tamanho: Self.ax5)
        for indice in 0..<12 {
            let captura = XCTAttachment(screenshot: app.screenshot())
            captura.name = String(format: "catalogo-ax5-%02d", indice)
            captura.lifetime = .keepAlways
            add(captura)
            let antes = app.screenshot().pngRepresentation
            app.swipeUp()
            if app.screenshot().pngRepresentation == antes { break }
        }
    }
}
