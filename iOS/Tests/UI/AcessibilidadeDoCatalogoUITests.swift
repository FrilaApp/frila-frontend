import XCTest

/// Critérios 2 e 3 do #139, medidos no catálogo: Dynamic Type no maior tamanho de acessibilidade
/// (AX5) e alvo de 44 pt com rótulo em todo controle.
@MainActor
final class AcessibilidadeDoCatalogoUITests: XCTestCase {
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"
    private static var naCI: Bool {
        ProcessInfo.processInfo.environment["CI"] != nil
            || ProcessInfo.processInfo.environment["TEST_RUNNER_CI"] != nil
            || ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil
    }
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
        AjudanteDeLancamentoUITests.preparar(app)
        app.launch()
        XCTAssertTrue(app.navigationBars["Frila UI"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Continuar"].waitForExistence(timeout: 10))
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

        var anterior = CGRect.null
        for _ in 0..<3 {
            let atual = elemento.frame
            if atual == anterior { break }
            anterior = atual
            Thread.sleep(forTimeInterval: 0.05)
        }
    }

    /// Percorre o catálogo inteiro em AX5 e confere cada botão e campo que aparece na tela.
    func testTodoControleTemRotuloEAlvoMinimoEmAX5() {
        let app = abrirCatalogo(tamanho: Self.ax5)
        var conferidos = Set<String>()
        var problemas: [String] = []
        let fim = app.buttons["abrir-licencas"]

        let janela = app.windows.firstMatch.frame
        for _ in 0..<20 {
            let controles = app.buttons.allElementsBoundByIndex + app.textFields.allElementsBoundByIndex
            for controle in controles {
                guard controle.exists else { continue }
                let quadro = controle.frame
                guard janela.intersects(quadro) else { continue }
                let chave = "\(controle.elementType.rawValue)|\(controle.identifier)|\(controle.label)"
                guard !conferidos.contains(chave) else { continue }
                guard controle.isHittable else { continue }
                conferidos.insert(chave)
                if controle.label.trimmingCharacters(in: .whitespaces).isEmpty
                    && controle.placeholderValue?.isEmpty != false {
                    problemas.append("sem rótulo: \(controle.elementType) \(controle.identifier)")
                }
                if !AlvoMinimo.atende(quadro.height) || !AlvoMinimo.atende(quadro.width) {
                    problemas.append("alvo \(Int(quadro.width))×\(Int(quadro.height)) pt: \(controle.label)")
                }
            }
            if fim.exists && fim.isHittable { break }
            app.swipeUp()
        }

        XCTAssertTrue(fim.isHittable, "o percurso não alcançou o fim do catálogo")
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

    /// Pílula de filtro comunica seleção além da cor (#71): expõe valor de acessibilidade e traço (.isSelected).
    func testPilulaDeFiltroNaoDependeApenasDeCor() {
        let app = abrirCatalogo()
        let pilula = app.buttons["Perto de mim"]
        XCTAssertTrue(pilula.waitForExistence(timeout: 5))
        XCTAssertTrue(pilula.isSelected, "o catálogo abre com o filtro ligado")
        XCTAssertEqual(pilula.value as? String, "filtro ativo", "Pílula de filtro selecionada deve comunicar estado ativo")

        pilula.tap()

        let filtroDesmarcado = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND isSelected == false AND value != %@", "filtro ativo"),
            object: pilula
        )
        XCTAssertEqual(XCTWaiter.wait(for: [filtroDesmarcado], timeout: 5), .completed,
                       "O toque deve atualizar a seleção e o valor de acessibilidade da pílula")

        XCTAssertFalse(pilula.isSelected)
        XCTAssertNotEqual(pilula.value as? String, "filtro ativo", "Pílula desmarcada não deve ter valor ativo")
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
        AjudanteDeLancamentoUITests.preparar(app)
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
    /// Na CI a captura é desativada para evitar o timeout de screenshot da infra do runner,
    /// mantendo a conferência de navegação e layout até o fim do catálogo.
    func testCapturasDoCatalogoEmAX5() {
        let app = abrirCatalogo(tamanho: Self.ax5)
        let fim = app.buttons["abrir-licencas"]
        for indice in 0..<12 {
            if !Self.naCI {
                let opcoes = XCTExpectedFailure.Options()
                opcoes.isStrict = false
                XCTExpectFailure("Captura de tela sujeita a timeout no simulador", options: opcoes) {
                    let captura = XCTAttachment(screenshot: app.screenshot())
                    captura.name = String(format: "catalogo-ax5-%02d", indice)
                    captura.lifetime = .keepAlways
                    self.add(captura)
                }
            }
            if fim.exists && fim.isHittable { break }
            app.swipeUp()
        }
        if fim.exists && !fim.isHittable {
            trazerParaATela(fim, em: app, tentativas: 4)
        }
        XCTAssertTrue(fim.isHittable, "o percurso em AX5 não alcançou o fim do catálogo")
    }
}
