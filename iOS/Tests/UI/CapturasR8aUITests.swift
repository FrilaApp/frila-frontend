import XCTest

/// R8a: as provas dos consertos de texto grande e de sistema nas telas de R1 e R5: o fundo sob o relógio com a tela
/// rolada (cadastro, conta suspensa, cadastro da casa), o Colar do código e o título do diálogo de exclusão em AX5.
/// `FRILA_CAPTURAS_DIR` (opcional) grava as imagens; sem ela, os anexos ficam só no resultado do teste.
@MainActor
final class CapturasR8aUITests: XCTestCase {
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func iniciar(_ extra: [String], ax5: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = extra + ["-FRILA_MODO_CLARO", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR",
                                       "-FRILA_SEM_ANIMACOES"]
        if ax5 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", Self.ax5] }
        app.launch()
        return app
    }

    private func capturar(_ nome: String, _ ax5: Bool) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let captura = XCUIScreen.main.screenshot()
        let arquivo = "r8a-\(nome)-\(ax5 ? "ax5" : "padrao")"
        let anexo = XCTAttachment(screenshot: captura)
        anexo.name = arquivo
        anexo.lifetime = .keepAlways
        add(anexo)
        if let pasta = ProcessInfo.processInfo.environment["FRILA_CAPTURAS_DIR"], !pasta.isEmpty {
            try? FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
            try? captura.pngRepresentation.write(to: URL(fileURLWithPath: "\(pasta)/\(arquivo).png"))
        }
    }

    /// Arrasta pelo meio da tela: o `swipeUp()` do XCTest começa no pé, onde o rodapé fixo não rola.
    private func rolar(_ app: XCUIApplication, vezes: Int = 1) {
        for _ in 0..<vezes {
            let inicio = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
            let fim = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
            inicio.press(forDuration: 0.05, thenDragTo: fim)
        }
    }

    private func entrar(_ app: XCUIApplication) {
        abrirCriarContaPelaEntrada(app)
        let campo = app.textFields["entrada-email"]
        XCTAssertTrue(campo.waitForExistence(timeout: Espera.aparecer), "a entrada deve abrir")
        if campo.frame.minY > app.windows.firstMatch.frame.height * 0.6 { app.swipeUp() }
        campo.tap()
        campo.digitarEEsperar("novo@frila.app")
        tocarFechandoTeclado(app.buttons["entrada-receber-codigo"], em: app)
        XCTAssertTrue(app.textFields["Código de acesso"].waitForExistence(timeout: Espera.aparecer), "a tela do código deve abrir")
    }

    private func codigo(ax5: Bool) {
        let app = iniciar(["-FRILA_ENTRADA", "-FRILA_SCENARIO", "primeiro-acesso"], ax5: ax5)
        entrar(app)
        let colar = app.buttons["Colar código"]
        XCTAssertTrue(colar.waitForExistence(timeout: Espera.aparecer))
        XCTAssertGreaterThanOrEqual(colar.frame.height, 44, "o Colar tem alvo de ao menos 44 pt")
        XCTAssertLessThanOrEqual(colar.frame.maxX, app.windows.firstMatch.frame.width, "o Colar cabe na largura da tela")
        // O Colar fica abaixo das caixas: em AX5 uma rolagem o traz para a tela.
        if ax5 { rolar(app) }
        capturar("codigo-colar", ax5)
    }

    private func cadastroRolado(ax5: Bool) {
        let app = iniciar(["-FRILA_ENTRADA", "-FRILA_SCENARIO", "primeiro-acesso"], ax5: ax5)
        entrar(app)
        app.textFields["Código de acesso"].tap()
        app.textFields["Código de acesso"].typeText("123456")
        definirSenhaObrigatoria(app)
        XCTAssertTrue(app.staticTexts["Como você quer usar o Frila?"].waitForExistence(timeout: Espera.aparecer), "o cadastro deve abrir")
        rolar(app, vezes: 2)
        capturar("cadastro-rolado", ax5)
    }

    private func contaSuspensaRolada(ax5: Bool) {
        let app = iniciar(["-FRILA_SCENARIO", "conta-suspensa"], ax5: ax5)
        XCTAssertTrue(app.descendants(matching: .any)["tela-conta-suspensa"].waitForExistence(timeout: Espera.aparecer))
        rolar(app, vezes: 2)
        capturar("conta-suspensa-rolada", ax5)
    }

    private func cadastroDaCasaRolado(ax5: Bool) {
        let app = iniciar(["-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO", "-FRILA_CADASTRO_UI_TEST"], ax5: ax5)
        XCTAssertTrue(app.staticTexts["Dados do negócio"].waitForExistence(timeout: 10))
        rolar(app, vezes: 2)
        capturar("cadastro-da-casa-rolado", ax5)
    }

    private func dialogoDaExclusao(ax5: Bool) {
        let app = iniciar(["-FRILA_SCENARIO", "success"], ax5: ax5)
        let conta = app.tabBars.buttons["Conta"]
        XCTAssertTrue(conta.waitForExistence(timeout: Espera.aparecer))
        conta.tap()
        let caminho = app.buttons["perfil-sair-ou-excluir"]
        XCTAssertTrue(caminho.waitForExistence(timeout: Espera.aparecer))
        for _ in 0..<8 where !caminho.isHittable { app.swipeUp() }
        caminho.tap()
        let irParaExclusao = app.buttons["perfil-excluir-conta"]
        XCTAssertTrue(irParaExclusao.waitForExistence(timeout: Espera.aparecer))
        irParaExclusao.tap()
        XCTAssertTrue(app.descendants(matching: .any)["tela-exclusao-de-conta"].waitForExistence(timeout: Espera.aparecer))
        let toggle = app.switches["toggle-confirmar-consequencias"]
        for _ in 0..<10 where !toggle.isHittable { app.swipeUp() }
        let interruptor = toggle.switches.firstMatch
        if interruptor.exists { interruptor.tap() } else { toggle.tap() }
        let excluir = app.buttons["botao-excluir-conta-definitivo"]
        for _ in 0..<10 where !excluir.isHittable { app.swipeUp() }
        excluir.tap()
        XCTAssertTrue(app.buttons["botao-cancelar-exclusao-dialogo"].waitForExistence(timeout: Espera.aparecer))
        capturar("exclusao-dialogo", ax5)
    }

    func testCodigoNoTamanhoPadrao() { codigo(ax5: false) }
    func testCodigoEmAX5() { codigo(ax5: true) }
    func testCadastroRoladoNoTamanhoPadrao() { cadastroRolado(ax5: false) }
    func testCadastroRoladoEmAX5() { cadastroRolado(ax5: true) }
    func testContaSuspensaRoladaNoTamanhoPadrao() { contaSuspensaRolada(ax5: false) }
    func testContaSuspensaRoladaEmAX5() { contaSuspensaRolada(ax5: true) }
    func testCadastroDaCasaRoladoNoTamanhoPadrao() { cadastroDaCasaRolado(ax5: false) }
    func testCadastroDaCasaRoladoEmAX5() { cadastroDaCasaRolado(ax5: true) }
    func testDialogoDaExclusaoNoTamanhoPadrao() { dialogoDaExclusao(ax5: false) }
    func testDialogoDaExclusaoEmAX5() { dialogoDaExclusao(ax5: true) }
}
