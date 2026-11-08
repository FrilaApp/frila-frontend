import XCTest

/// E2E do Prod, 08/11/2026 (vaga e415fe59): a vaga trabalhada termina `encerrada` com a posição cumprida,
/// e o detalhe dizia "Encerrada, ninguém aceitou". A variável `FRILA_CAPTURAS` (opcional) grava as capturas.
@MainActor
final class VagaEncerradaTrabalhadaUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func abrirDetalhe(ax5: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "ciclo-contratante-turno-concluido",
                               "-FRILA_MODO_CLARO", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR", "-FRILA_SEM_ANIMACOES"]
        if ax5 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        let vaga = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "vaga-contratante-")).firstMatch
        XCTAssertTrue(vaga.waitForExistence(timeout: 15))
        for _ in 0..<8 where !vaga.isHittable { app.swipeUp() }
        vaga.tap()
        return app
    }

    private func capturar(_ nome: String) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let captura = XCUIScreen.main.screenshot()
        let anexo = XCTAttachment(screenshot: captura)
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)
        if let pasta = ProcessInfo.processInfo.environment["FRILA_CAPTURAS"] {
            try? FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
            try? captura.pngRepresentation.write(to: URL(fileURLWithPath: "\(pasta)/\(nome).png"))
        }
    }

    private func conferir(ax5: Bool) {
        let app = abrirDetalhe(ax5: ax5)
        let titulo = app.staticTexts["Vaga encerrada"]
        XCTAssertTrue(titulo.waitForExistence(timeout: 10), "o detalhe da vaga trabalhada diz 'Vaga encerrada'")
        XCTAssertTrue(app.staticTexts["1 de 1 posição preenchida"].exists)
        XCTAssertFalse(app.staticTexts["Encerrada, ninguém aceitou"].exists)
        capturar("vaga-encerrada-trabalhada-\(ax5 ? "ax5" : "padrao")")
    }

    func testDetalheDaVagaTrabalhadaNoTamanhoPadrao() { conferir(ax5: false) }

    func testDetalheDaVagaTrabalhadaEmAX5() { conferir(ax5: true) }
}
