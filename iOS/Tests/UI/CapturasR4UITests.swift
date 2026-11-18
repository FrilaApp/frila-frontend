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
        XCTAssertTrue(app.descendants(matching: .any)["titulo-secao-ponto-base"].waitForExistence(timeout: Espera.aparecer), "o formulário deve carregar")
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
            // Se a linha estava junto do rodapé e o primeiro toque não pegou, toca de novo.
            if !app.buttons["horario-avancar"].waitForExistence(timeout: 3), escolher.exists, escolher.isHittable { escolher.tap() }
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

    // MARK: - Parte 2: Conta, contato e foto

    private func contaDoProfissional(ax5: Bool) {
        let app = iniciar(ax5: ax5)
        abrirContaProfissional(app)
        XCTAssertTrue(app.staticTexts["perfil-telefone-valor"].waitForExistence(timeout: Espera.aparecer), "o perfil deve carregar")
        capturar("conta-profissional-topo", ax5: ax5)
        conferirBotoes(app, tela: "conta do profissional")
        for indice in 1...3 {
            app.swipeUp()
            capturar("conta-profissional-\(indice)", ax5: ax5)
        }
    }

    private func edicaoDeContato(ax5: Bool) {
        let app = iniciar(ax5: ax5)
        abrirContaProfissional(app)
        let valor = app.staticTexts["perfil-telefone-valor"]
        XCTAssertTrue(valor.waitForExistence(timeout: Espera.aparecer), "o telefone deve aparecer")
        let janela = app.windows.firstMatch
        let direita = janela.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: janela.frame.width - 24, dy: valor.frame.midY))
        valor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.7, thenDragTo: direita, withVelocity: XCUIGestureVelocity(rawValue: 80), thenHoldForDuration: 0.6
        )
        if app.textFields["perfil-telefone-editar"].waitForExistence(timeout: 5) {
            capturar("contato-edicao", ax5: ax5)
        } else {
            XCTFail("a edição do contato deveria abrir pelo gesto de segurar e deslizar")
        }
    }

    private func fotoDePerfil(cenario: String, nome: String, ax5: Bool) {
        let app = iniciar(cenario: cenario, ax5: ax5)
        abrirContaProfissional(app)
        XCTAssertTrue(app.staticTexts["perfil-foto-estado"].waitForExistence(timeout: Espera.aparecer), "a seção da foto deve aparecer")
        capturar("foto-\(nome)", ax5: ax5)
        if nome == "sem-foto" {
            tocarRolando(app.buttons["perfil-foto-escolher"], app)
            // O alerta "Dicas para a foto" é do sistema.
            RunLoop.current.run(until: Date().addingTimeInterval(0.8))
            capturar("foto-dicas", ax5: ax5)
        }
    }

    private func ajuda(ax5: Bool) {
        let app = iniciar(ax5: ax5)
        abrirContaProfissional(app)
        tocarRolando(app.buttons["perfil-ajuda"], app)
        XCTAssertTrue(app.descendants(matching: .any)["perfil-suporte"].waitForExistence(timeout: Espera.aparecer), "a ajuda deve abrir")
        capturar("ajuda", ax5: ax5)
    }

    private func sairOuExcluir(ax5: Bool) {
        let app = iniciar(ax5: ax5)
        abrirContaProfissional(app)
        tocarRolando(app.buttons["perfil-sair-ou-excluir"], app)
        XCTAssertTrue(app.buttons["perfil-sair"].waitForExistence(timeout: Espera.aparecer), "a tela de sair ou excluir deve abrir")
        capturar("sair-ou-excluir", ax5: ax5)
        app.buttons["perfil-sair"].tap()
        XCTAssertTrue(app.buttons["botao-confirmar-saida-dialogo"].waitForExistence(timeout: Espera.aparecer), "a confirmação deve abrir")
        capturar("confirmacao-de-saida", ax5: ax5)
    }

    private func contaDoEstabelecimento(ax5: Bool) {
        let app = iniciar(cenario: "contratante", ax5: ax5)
        let conta = app.tabBars.buttons["Conta"]
        XCTAssertTrue(conta.waitForExistence(timeout: Espera.aparecer), "a aba Conta deve existir")
        conta.tap()
        XCTAssertTrue(app.buttons["estabelecimento-excluir-conta"].waitForExistence(timeout: Espera.aparecer), "o perfil do estabelecimento deve abrir")
        capturar("conta-estabelecimento-topo", ax5: ax5)
        conferirBotoes(app, tela: "conta do estabelecimento")
        app.swipeUp()
        capturar("conta-estabelecimento-fim", ax5: ax5)
    }

    func testContaDoProfissionalNoTamanhoPadrao() { contaDoProfissional(ax5: false) }
    func testContaDoProfissionalEmAX5() { contaDoProfissional(ax5: true) }
    func testEdicaoDeContatoNoTamanhoPadrao() { edicaoDeContato(ax5: false) }
    func testEdicaoDeContatoEmAX5() { edicaoDeContato(ax5: true) }
    func testFotoSemFotoNoTamanhoPadrao() { fotoDePerfil(cenario: "foto-sem-foto", nome: "sem-foto", ax5: false) }
    func testFotoSemFotoEmAX5() { fotoDePerfil(cenario: "foto-sem-foto", nome: "sem-foto", ax5: true) }
    func testFotoAprovadaNoTamanhoPadrao() { fotoDePerfil(cenario: "foto-aprovada", nome: "aprovada", ax5: false) }
    func testFotoAprovadaEmAX5() { fotoDePerfil(cenario: "foto-aprovada", nome: "aprovada", ax5: true) }
    func testFotoRecusadaNoTamanhoPadrao() { fotoDePerfil(cenario: "foto-recusada", nome: "recusada", ax5: false) }
    func testFotoRecusadaEmAX5() { fotoDePerfil(cenario: "foto-recusada", nome: "recusada", ax5: true) }
    func testAjudaNoTamanhoPadrao() { ajuda(ax5: false) }
    func testAjudaEmAX5() { ajuda(ax5: true) }
    func testSairOuExcluirNoTamanhoPadrao() { sairOuExcluir(ax5: false) }
    func testSairOuExcluirEmAX5() { sairOuExcluir(ax5: true) }
    func testContaDoEstabelecimentoNoTamanhoPadrao() { contaDoEstabelecimento(ax5: false) }
    func testContaDoEstabelecimentoEmAX5() { contaDoEstabelecimento(ax5: true) }

    // MARK: - Parte 3: por que recebo vagas, preferências de chamadas e chamada recebida

    private func porQueReceboVagas(ax5: Bool) {
        let app = iniciar(ax5: ax5)
        abrirContaProfissional(app)
        tocarRolando(app.buttons["perfil-por-que-recebo"], app)
        XCTAssertTrue(app.descendants(matching: .any)["tela-por-que-recebo"].waitForExistence(timeout: Espera.aparecer), "a folha deve abrir")
        capturar("por-que-recebo-topo", ax5: ax5)
        tocarRolando(app.buttons["botao-contestar-despacho"], app)
        XCTAssertTrue(app.buttons["botao-enviar-revisao"].waitForExistence(timeout: Espera.aparecer), "o formulário deve abrir")
        capturar("por-que-recebo-formulario", ax5: ax5)
    }

    private func preferenciasDeChamada(ax5: Bool) {
        let app = iniciar(cenario: "chamada-recebida", ax5: ax5)
        abrirContaProfissional(app)
        tocarRolando(app.buttons["perfil-preferencias-chamada"], app)
        XCTAssertTrue(app.switches["toggle-receber-chamadas"].waitForExistence(timeout: Espera.aparecer), "as preferências devem abrir")
        capturar("preferencias-topo", ax5: ax5)
        conferirBotoes(app, tela: "preferências de chamadas")
        for indice in 1...2 {
            app.swipeUp()
            capturar("preferencias-\(indice)", ax5: ax5)
        }
    }

    private func chamadaRecebida(ax5: Bool) {
        let app = iniciar(cenario: "chamada-recebida", extra: ["-FRILA_PUSH", "chamada_recebida",
                          "-FRILA_PUSH_CHAMADA_ID", "c2000000-0000-0000-0000-000000000001"], ax5: ax5)
        XCTAssertTrue(app.buttons["aceitar-chamada"].waitForExistence(timeout: 15), "a chamada recebida deve abrir")
        capturar("chamada-recebida-topo", ax5: ax5)
        conferirBotoes(app, tela: "chamada recebida")
        app.swipeUp()
        capturar("chamada-recebida-fim", ax5: ax5)
        app.buttons["recusar-chamada"].tap()
        XCTAssertTrue(app.buttons["confirmar-recusa-chamada"].waitForExistence(timeout: 5), "a folha de recusa deve abrir")
        capturar("chamada-recebida-recusa", ax5: ax5)
    }

    func testPorQueReceboVagasNoTamanhoPadrao() { porQueReceboVagas(ax5: false) }
    func testPorQueReceboVagasEmAX5() { porQueReceboVagas(ax5: true) }
    func testPreferenciasDeChamadaNoTamanhoPadrao() { preferenciasDeChamada(ax5: false) }
    func testPreferenciasDeChamadaEmAX5() { preferenciasDeChamada(ax5: true) }
    func testChamadaRecebidaNoTamanhoPadrao() { chamadaRecebida(ax5: false) }
    func testChamadaRecebidaEmAX5() { chamadaRecebida(ax5: true) }
}
