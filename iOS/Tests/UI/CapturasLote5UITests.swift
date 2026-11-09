import XCTest

@MainActor
final class CapturasLote5UITests: XCTestCase {
    private let pastaProvas = "/Users/cauecarneiro/Documents/Projetos/Frila/orquestracao/retornos/B-L5-provas"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func iniciar(argumentos: [String], ax5: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_MODO_CLARO",
            "-AppleLanguages", "(pt-BR)",
            "-AppleLocale", "pt_BR",
            "-FRILA_SEM_ANIMACOES"
        ] + argumentos
        if ax5 {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityXXXL"
            ]
        }
        AjudanteDeLancamentoUITests.preparar(app)
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: Espera.aparecer)
        return app
    }

    private func capturar(_ screenshot: XCUIScreenshot, nome: String) {
        let anexo = XCTAttachment(screenshot: screenshot)
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)

        try? FileManager.default.createDirectory(atPath: pastaProvas, withIntermediateDirectories: true)
        let destino = URL(fileURLWithPath: "\(pastaProvas)/\(nome).png")
        try? screenshot.pngRepresentation.write(to: destino)
    }

    private func rolarAte(_ elemento: XCUIElement, em app: XCUIApplication, tentativas: Int = 10) {
        let altura = app.windows.firstMatch.frame.height
        for _ in 0..<tentativas {
            if elemento.exists, elemento.isHittable, elemento.frame.minY > 100, elemento.frame.maxY < altura - 40 { return }
            if elemento.exists, elemento.frame.minY <= 100 { app.swipeDown() } else { app.swipeUp() }
        }
    }

    // 3. RepublicarPosicoesRestantes (o botão)
    private func republicarPosicoesRestantes(ax5: Bool) {
        let app = iniciar(argumentos: ["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "selecao-encerrada-sem-escolha"], ax5: ax5)
        XCTAssertTrue(app.staticTexts["Minhas vagas"].waitForExistence(timeout: 15))
        let botao = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "republicar-urgencia-vaga-")).firstMatch
        XCTAssertTrue(botao.waitForExistence(timeout: 15))
        rolarAte(botao, em: app)
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        capturar(app.screenshot(), nome: "republicar-posicoes-restantes-\(ax5 ? "ax5" : "padrao")")
    }

    func testRepublicarPosicoesRestantesPadrao() { republicarPosicoesRestantes(ax5: false) }
    func testRepublicarPosicoesRestantesAX5() { republicarPosicoesRestantes(ax5: true) }
}
