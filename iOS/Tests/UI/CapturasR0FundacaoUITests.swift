import XCTest

/// R0 do redesign (fundação): o catálogo de componentes, no tamanho padrão e em AX5, depois da troca dos tokens e
/// dos componentes base para o sistema do Fabrício. `FRILA_CAPTURAS_DIR` (opcional) grava as imagens; sem ela, os
/// anexos ficam só no resultado do teste.
@MainActor
final class CapturasR0FundacaoUITests: XCTestCase {
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func abrirCatalogo(ax5: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_CATALOGO", "-FRILA_SCENARIO", "success", "-FRILA_MODO_CLARO",
                               "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR", "-FRILA_SEM_ANIMACOES"]
        if ax5 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", Self.ax5] }
        app.launch()
        XCTAssertTrue(app.navigationBars["Frila UI"].waitForExistence(timeout: Espera.aparecer), "O catálogo deve abrir")
        return app
    }

    private func capturar(_ nome: String) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let captura = XCUIScreen.main.screenshot()
        let anexo = XCTAttachment(screenshot: captura)
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)
        if let pasta = ProcessInfo.processInfo.environment["FRILA_CAPTURAS_DIR"], !pasta.isEmpty {
            try? FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
            try? captura.pngRepresentation.write(to: URL(fileURLWithPath: "\(pasta)/\(nome).png"))
        }
    }

    /// Percorre o catálogo do topo até o cartão de vaga, uma captura por tela.
    private func percorrer(ax5: Bool, telas: Int) {
        let app = abrirCatalogo(ax5: ax5)
        let sufixo = ax5 ? "ax5" : "padrao"
        for indice in 0..<telas {
            capturar(String(format: "r0-catalogo-%@-%02d", sufixo, indice))
            app.swipeUp()
        }
    }

    func testCatalogoNoTamanhoPadrao() {
        percorrer(ax5: false, telas: 7)
    }

    func testCatalogoEmAX5() {
        percorrer(ax5: true, telas: 14)
    }

    /// O botão primário em conferência (desligado) continua no lugar, com o rótulo, e não aceita toque.
    func testBotaoEmConferenciaFicaNoLugarEDesligado() {
        let app = abrirCatalogo(ax5: false)
        let receberCodigo = app.buttons["Receber código"]
        for _ in 0..<6 where !receberCodigo.isHittable { app.swipeUp() }
        XCTAssertTrue(receberCodigo.exists, "o botão em conferência aparece no catálogo")
        XCTAssertFalse(receberCodigo.isEnabled, "o botão em conferência não aceita toque")
        XCTAssertGreaterThanOrEqual(receberCodigo.frame.height, 48, "o botão tem ao menos 48 pt de altura")
        XCTAssertGreaterThanOrEqual(app.buttons["MARCAR PRESENÇA"].frame.height, 64, "o botão de presença tem ao menos 64 pt")
        XCTAssertGreaterThanOrEqual(app.buttons["Reenviar código"].frame.height, 48, "o link tem alvo de ao menos 48 pt")
    }
}
