import XCTest

/// R5 do redesign (casa: vagas): uma captura por tela, no tamanho padrão e em AX5, com as telas no sistema do Fabrício.
/// Cada captura também confere o que a tela promete (o botão primário existe e tem alvo de ao menos 44 pt, o
/// nome da tela existe). `FRILA_CAPTURAS_DIR` (opcional) grava as imagens; sem ela, os anexos ficam só no resultado.
@MainActor
final class CapturasR5UITests: XCTestCase {
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func iniciar(_ argumentos: [String], ax5: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = argumentos + ["-FRILA_MODO_CLARO", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR",
                                            "-FRILA_SEM_ANIMACOES"]
        if ax5 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", Self.ax5] }
        app.launch()
        return app
    }

    private func capturar(_ nome: String, ax5: Bool) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let captura = XCUIScreen.main.screenshot()
        let anexo = XCTAttachment(screenshot: captura)
        let completo = "r5-\(nome)-\(ax5 ? "ax5" : "padrao")"
        anexo.name = completo
        anexo.lifetime = .keepAlways
        add(anexo)
        if let pasta = ProcessInfo.processInfo.environment["FRILA_CAPTURAS_DIR"], !pasta.isEmpty {
            try? FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
            try? captura.pngRepresentation.write(to: URL(fileURLWithPath: "\(pasta)/\(completo).png"))
        }
    }

    private func confirmarAlvo(_ elemento: XCUIElement, _ nome: String) {
        XCTAssertTrue(elemento.waitForExistence(timeout: Espera.aparecer), "\(nome) deve existir")
        XCTAssertGreaterThanOrEqual(elemento.frame.height, 44, "\(nome) tem alvo de ao menos 44 pt")
    }

    // MARK: - Parte 1: cadastro do estabelecimento e Minhas vagas

    private func cadastro(ax5: Bool) {
        let app = iniciar(["-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO", "-FRILA_CADASTRO_UI_TEST"], ax5: ax5)
        XCTAssertTrue(app.staticTexts["Dados do negócio"].waitForExistence(timeout: 10))
        confirmarAlvo(app.buttons["continuar-cadastro"], "o botão de salvar")
        capturar("cadastro", ax5: ax5)
    }

    private func cadastroComErro(ax5: Bool) {
        let app = iniciar(["-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO", "-FRILA_CADASTRO_UI_TEST", "-FRILA_CAPTURA", "erro-nome"], ax5: ax5)
        XCTAssertTrue(app.staticTexts["Dados do negócio"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["erro-campo-nome"].waitForExistence(timeout: Espera.aparecer), "o erro aparece junto do campo")
        capturar("cadastro-erro", ax5: ax5)
    }

    private func minhasVagas(ax5: Bool) {
        let app = iniciar(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "painel-contratante"], ax5: ax5)
        XCTAssertTrue(app.staticTexts["Minhas vagas"].waitForExistence(timeout: 10), "o nome da tela existe")
        XCTAssertTrue(app.buttons["vaga-contratante-40000000-0000-0000-0000-000000000001"].waitForExistence(timeout: 10))
        capturar("minhas-vagas", ax5: ax5)
    }

    private func minhasVagasVazio(ax5: Bool) {
        let app = iniciar(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "painel-vazio"], ax5: ax5)
        XCTAssertTrue(app.descendants(matching: .any)["estado-vazio-minhas-vagas"].waitForExistence(timeout: 10))
        confirmarAlvo(app.buttons["publicar-vaga-entrada"], "o botão de publicar")
        capturar("minhas-vagas-vazio", ax5: ax5)
    }

    private func detalheDaVaga(ax5: Bool) {
        let app = iniciar(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "painel-contratante", "-FRILA_CAPTURA", "vaga-aberta"], ax5: ax5)
        XCTAssertTrue(app.descendants(matching: .any)["detalhe-vaga-contratante"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.navigationBars["Detalhe da vaga"].waitForExistence(timeout: Espera.aparecer))
        capturar("detalhe-da-vaga", ax5: ax5)
    }

    func testCadastroNoTamanhoPadrao() { cadastro(ax5: false) }
    func testCadastroEmAX5() { cadastro(ax5: true) }
    func testCadastroComErroNoTamanhoPadrao() { cadastroComErro(ax5: false) }
    func testCadastroComErroEmAX5() { cadastroComErro(ax5: true) }
    func testMinhasVagasNoTamanhoPadrao() { minhasVagas(ax5: false) }
    func testMinhasVagasEmAX5() { minhasVagas(ax5: true) }
    func testMinhasVagasVazioNoTamanhoPadrao() { minhasVagasVazio(ax5: false) }
    func testMinhasVagasVazioEmAX5() { minhasVagasVazio(ax5: true) }
    func testDetalheDaVagaNoTamanhoPadrao() { detalheDaVaga(ax5: false) }
    func testDetalheDaVagaEmAX5() { detalheDaVaga(ax5: true) }
}
