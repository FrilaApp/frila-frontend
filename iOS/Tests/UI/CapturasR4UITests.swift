import XCTest

/// R4 do redesign (Profissional: perfil e chamadas, e as telas de Conta): uma captura por tela, no tamanho padrão e em AX5.
/// `FRILA_CAPTURAS_DIR` (opcional) grava as imagens; sem ela, os anexos ficam só no resultado do teste.
@MainActor
final class CapturasR4UITests: XCTestCase {
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func iniciar(cenario: String = "perfil-rico-habilitado", extra: [String] = [], ax5: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", cenario, "-FRILA_MODO_CLARO", "-AppleLanguages", "(pt-BR)",
                               "-AppleLocale", "pt_BR", "-FRILA_SEM_ANIMACOES"] + extra
        if ax5 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", Self.ax5] }
        app.launch()
        return app
    }

    private func capturar(_ nome: String, ax5: Bool) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let nomeFinal = "r4-\(nome)-\(ax5 ? "ax5" : "padrao")"
        let captura = XCUIScreen.main.screenshot()
        let anexo = XCTAttachment(screenshot: captura)
        anexo.name = nomeFinal
        anexo.lifetime = .keepAlways
        add(anexo)
        if let pasta = ProcessInfo.processInfo.environment["FRILA_CAPTURAS_DIR"], !pasta.isEmpty {
            try? FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
            try? captura.pngRepresentation.write(to: URL(fileURLWithPath: "\(pasta)/\(nomeFinal).png"))
        }
    }

    /// Rola até o elemento ficar tocável (a lista e o rodapé ancorado cobrem parte da tela) e toca.
    private func tocarRolando(_ elemento: XCUIElement, _ app: XCUIApplication) {
        XCTAssertTrue(elemento.waitForExistence(timeout: Espera.aparecer), "o elemento \(elemento.identifier) deve existir")
        for _ in 0..<12 where !elemento.isHittable { app.swipeUp() }
        XCTAssertTrue(elemento.isHittable, "o elemento \(elemento.identifier) deve estar tocável")
        elemento.tap()
    }

    /// Todo botão visível tem rótulo e alvo de ao menos 44 pt (fora a barra de abas e a de navegação, que são do sistema).
    private func conferirBotoes(_ app: XCUIApplication, tela: String) {
        let janela = app.windows.firstMatch.frame
        let barraDeAbas = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame : .zero
        let barraDeNavegacao = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame : .zero
        var problemas: [String] = []
        for botao in app.buttons.allElementsBoundByIndex where botao.exists && !botao.frame.isEmpty && janela.intersects(botao.frame) {
            if barraDeAbas.contains(botao.frame) || barraDeNavegacao.contains(botao.frame) { continue }
            if botao.label.trimmingCharacters(in: .whitespaces).isEmpty { problemas.append("sem rótulo: \(botao.identifier)") }
            if botao.frame.height < 44 { problemas.append("alvo \(Int(botao.frame.height)) pt: \(botao.identifier) \(botao.label)") }
        }
        XCTAssertTrue(problemas.isEmpty, "\(tela): controles fora da regra \(Set(problemas).sorted())")
    }

    private func abrirContaProfissional(_ app: XCUIApplication) {
        let conta = app.tabBars.buttons["Conta"]
        XCTAssertTrue(conta.waitForExistence(timeout: Espera.aparecer), "a aba Conta deve existir")
        conta.tap()
    }

    // MARK: - Parte 1: perfil do profissional, horários, apresentação e serviços

    private func perfilDoProfissional(ax5: Bool) {
        let app = iniciar(ax5: ax5)
        abrirContaProfissional(app)
        tocarRolando(app.buttons["perfil-funcoes-horarios"], app)
        XCTAssertTrue(app.descendants(matching: .any)["tela-perfil-profissional"].waitForExistence(timeout: Espera.aparecer))
        capturar("perfil-profissional-topo", ax5: ax5)
        conferirBotoes(app, tela: "perfil do profissional")
        app.swipeUp()
        capturar("perfil-profissional-meio", ax5: ax5)
        app.swipeUp()
        capturar("perfil-profissional-fim", ax5: ax5)
    }

    private func horariosDaSemana(ax5: Bool) {
        let app = iniciar(ax5: ax5)
        abrirContaProfissional(app)
        tocarRolando(app.buttons["perfil-funcoes-horarios"], app)
        let faixa = app.descendants(matching: .any)["faixa-semanal"]
        XCTAssertTrue(faixa.waitForExistence(timeout: Espera.aparecer), "a faixa semanal deve abrir")
        for _ in 0..<12 where !faixa.isHittable { app.swipeUp() }
        capturar("horarios-dias", ax5: ax5)
        let escolher = app.buttons["escolher-horario"]
        if escolher.waitForExistence(timeout: 3) {
            tocarRolando(escolher, app)
            XCTAssertTrue(app.buttons["horario-avancar"].waitForExistence(timeout: Espera.aparecer), "o editor de horário deve abrir")
            capturar("horarios-editor", ax5: ax5)
        }
    }

    private func apresentacaoERegioes(ax5: Bool) {
        let app = iniciar(ax5: ax5)
        abrirContaProfissional(app)
        tocarRolando(app.buttons["perfil-apresentacao-regioes"], app)
        XCTAssertTrue(app.navigationBars["Apresentação e regiões"].waitForExistence(timeout: Espera.aparecer))
        capturar("apresentacao-topo", ax5: ax5)
        conferirBotoes(app, tela: "apresentação e regiões")
        for indice in 1...3 {
            app.swipeUp()
            capturar("apresentacao-\(indice)", ax5: ax5)
        }
    }

    private func editarServicos(ax5: Bool) {
        let app = iniciar(ax5: ax5)
        abrirContaProfissional(app)
        tocarRolando(app.buttons["perfil-funcoes-horarios"], app)
        tocarRolando(app.buttons["editar-servicos"], app)
        XCTAssertTrue(app.buttons["salvar-servicos"].waitForExistence(timeout: Espera.aparecer), "o editor de serviços deve abrir")
        capturar("servicos-topo", ax5: ax5)
        conferirBotoes(app, tela: "editar serviços")
        app.swipeUp()
        capturar("servicos-meio", ax5: ax5)
    }

    func testPerfilDoProfissionalNoTamanhoPadrao() { perfilDoProfissional(ax5: false) }
    func testPerfilDoProfissionalEmAX5() { perfilDoProfissional(ax5: true) }
    func testHorariosDaSemanaNoTamanhoPadrao() { horariosDaSemana(ax5: false) }
    func testHorariosDaSemanaEmAX5() { horariosDaSemana(ax5: true) }
    func testApresentacaoERegioesNoTamanhoPadrao() { apresentacaoERegioes(ax5: false) }
    func testApresentacaoERegioesEmAX5() { apresentacaoERegioes(ax5: true) }
    func testEditarServicosNoTamanhoPadrao() { editarServicos(ax5: false) }
    func testEditarServicosEmAX5() { editarServicos(ax5: true) }
}
