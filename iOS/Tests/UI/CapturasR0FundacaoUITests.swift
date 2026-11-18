import XCTest

/// R0 do redesign (fundação): os componentes novos do catálogo, no tamanho padrão e em AX5, depois da troca dos tokens
/// e dos componentes base para o sistema do Fabrício. Eles ficam no fim do catálogo, depois do ponto em que o
/// `AcessibilidadeDoCatalogoUITests` para; por isso rótulo e alvo de toque são conferidos aqui.
/// `FRILA_CAPTURAS_DIR` (opcional) grava as imagens; sem ela, os anexos ficam só no resultado do teste.
@MainActor
final class CapturasR0FundacaoUITests: XCTestCase {
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func abrirCatalogo(ax5: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_CATALOGO", "-FRILA_CATALOGO_FUNDACAO", "-FRILA_SCENARIO", "success", "-FRILA_MODO_CLARO",
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

    /// Percorre as seções da fundação, uma captura por tela, conferindo em cada uma que todo botão visível tem
    /// rótulo e alvo de ao menos 44 pt.
    private func percorrer(ax5: Bool, telas: Int) {
        let app = abrirCatalogo(ax5: ax5)
        let sufixo = ax5 ? "ax5" : "padrao"
        let janela = app.windows.firstMatch.frame
        var problemas: [String] = []
        for indice in 0..<telas {
            capturar(String(format: "r0-fundacao-%@-%02d", sufixo, indice))
            for botao in app.buttons.allElementsBoundByIndex where botao.exists && janela.contains(botao.frame) {
                if botao.label.trimmingCharacters(in: .whitespaces).isEmpty { problemas.append("sem rótulo: \(botao.identifier)") }
                if botao.frame.height < 44 || botao.frame.width < 44 {
                    problemas.append("alvo \(Int(botao.frame.width))×\(Int(botao.frame.height)) pt: \(botao.label)")
                }
            }
            app.swipeUp()
        }
        XCTAssertTrue(problemas.isEmpty, "controles da fundação fora da regra: \(Set(problemas).sorted())")
    }

    func testFundacaoNoTamanhoPadrao() {
        percorrer(ax5: false, telas: 3)
    }

    func testFundacaoEmAX5() {
        percorrer(ax5: true, telas: 6)
    }

    /// O botão primário em conferência (desligado) continua no lugar, com o rótulo, e não aceita toque.
    func testBotaoEmConferenciaFicaNoLugarEDesligado() {
        let app = abrirCatalogo(ax5: false)
        let receberCodigo = app.buttons["Receber código"]
        XCTAssertTrue(receberCodigo.waitForExistence(timeout: Espera.aparecer), "o botão em conferência aparece no catálogo")
        XCTAssertFalse(receberCodigo.isEnabled, "o botão em conferência não aceita toque")
        XCTAssertGreaterThanOrEqual(receberCodigo.frame.height, 48, "o botão tem ao menos 48 pt de altura")
        XCTAssertGreaterThanOrEqual(app.buttons["MARCAR PRESENÇA"].frame.height, 64, "o botão de presença tem ao menos 64 pt")
        XCTAssertGreaterThanOrEqual(app.buttons["Reenviar código"].frame.height, 48, "o link tem alvo de ao menos 48 pt")
    }
}
