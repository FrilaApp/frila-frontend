import XCTest

/// R2 do redesign (Profissional, Vagas): feed, filtros, detalhe da vaga (urgência e seleção), resultados da candidatura,
/// Candidaturas e seleção de funções, no tamanho padrão e em AX5.
/// `FRILA_CAPTURAS_DIR` (opcional) grava as imagens; sem ela, os anexos ficam só no resultado do teste.
@MainActor
final class CapturasR2UITests: XCTestCase {
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"
    private let vagaID = "40000000-0000-0000-0000-000000000001"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: Ajudantes

    private func iniciar(_ cenario: String, extra: [String] = [], ax5: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", cenario, "-FRILA_MODO_CLARO", "-AppleLanguages", "(pt-BR)",
                               "-AppleLocale", "pt_BR", "-FRILA_SEM_ANIMACOES"] + extra
        if ax5 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", Self.ax5] }
        app.launch()
        return app
    }

    private func capturar(_ nome: String, ax5: Bool) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let captura = XCUIScreen.main.screenshot()
        let nomeCompleto = "r2-\(nome)-\(ax5 ? "ax5" : "padrao")"
        let anexo = XCTAttachment(screenshot: captura)
        anexo.name = nomeCompleto
        anexo.lifetime = .keepAlways
        add(anexo)
        if let pasta = ProcessInfo.processInfo.environment["FRILA_CAPTURAS_DIR"], !pasta.isEmpty {
            try? FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
            try? captura.pngRepresentation.write(to: URL(fileURLWithPath: "\(pasta)/\(nomeCompleto).png"))
        }
    }

    private func elemento(_ id: String, em app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    /// Cada roteiro roda no tamanho padrão e em AX5, com o app novo.
    private func nosDoisTamanhos(cenario: String, extra: [String] = [], _ roteiro: (XCUIApplication, Bool) -> Void) {
        for ax5 in [false, true] {
            let app = iniciar(cenario, extra: extra, ax5: ax5)
            roteiro(app, ax5)
            app.terminate()
        }
    }

    // MARK: Parte 1: feed e filtros

    func testFeedDeVagas() {
        nosDoisTamanhos(cenario: "success") { app, ax5 in
            XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: Espera.aparecer), "O feed deve abrir")
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-'")).firstMatch
                .waitForExistence(timeout: Espera.aparecer))
            capturar("feed", ax5: ax5)
        }
    }

    func testFiltroAberto() {
        nosDoisTamanhos(cenario: "success") { app, ax5 in
            XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: Espera.aparecer))
            tocar(elemento("filtro-funcao", em: app))
            XCTAssertTrue(elemento("folha-filtro", em: app).waitForExistence(timeout: Espera.aparecer))
            capturar("filtro-aberto", ax5: ax5)
        }
    }

    func testFeedVazioComFiltro() {
        nosDoisTamanhos(cenario: "success") { app, ax5 in
            XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: Espera.aparecer))
            tocar(elemento("filtro-funcao", em: app))
            tocar(app.buttons["Bartender"])
            XCTAssertTrue(elemento("vagas-vazio", em: app).waitForExistence(timeout: Espera.aparecer))
            capturar("feed-vazio-com-filtro", ax5: ax5)
        }
    }

    func testFeedSemConexao() {
        nosDoisTamanhos(cenario: "sem-rede") { app, ax5 in
            XCTAssertTrue(elemento("vagas-sem-conexao", em: app).waitForExistence(timeout: Espera.aparecer))
            capturar("feed-sem-conexao", ax5: ax5)
        }
    }

    func testFeedComErro() {
        nosDoisTamanhos(cenario: "erro-na-lista") { app, ax5 in
            XCTAssertTrue(elemento("vagas-erro", em: app).waitForExistence(timeout: Espera.aparecer))
            capturar("feed-erro", ax5: ax5)
        }
    }

    // MARK: Parte 2: detalhe da vaga

    private func abrirDetalhe(_ cenario: String, ax5: Bool) -> XCUIApplication {
        let app = iniciar(cenario, extra: ["-FRILA_VAGA_ID", vagaID, "-FRILA_HORARIO_VAGA", "amanha-23h30"], ax5: ax5)
        XCTAssertTrue(elemento("tela-detalhe-vaga", em: app).waitForExistence(timeout: Espera.aparecer), "O detalhe deve abrir")
        XCTAssertTrue(app.buttons["candidatar"].waitForExistence(timeout: Espera.aparecer))
        return app
    }

    func testDetalheDeUrgencia() {
        for ax5 in [false, true] {
            let app = abrirDetalhe("success", ax5: ax5)
            capturar("detalhe-urgencia-topo", ax5: ax5)
            for _ in 0..<4 { app.swipeUp(velocity: .fast) }
            capturar("detalhe-urgencia-fim", ax5: ax5)
            app.terminate()
        }
    }

    func testDetalheDeSelecao() {
        for ax5 in [false, true] {
            let app = abrirDetalhe("vaga-em-selecao", ax5: ax5)
            capturar("detalhe-selecao-topo", ax5: ax5)
            for _ in 0..<4 { app.swipeUp(velocity: .fast) }
            capturar("detalhe-selecao-fim", ax5: ax5)
            app.terminate()
        }
    }

    func testDetalheComCandidaturaEnviada() {
        nosDoisTamanhos(cenario: "candidatura-pendente") { app, ax5 in
            let aba = app.tabBars.buttons["Candidaturas"]
            XCTAssertTrue(aba.waitForExistence(timeout: 15))
            aba.tap()
            let cartao = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'candidatura-'")).firstMatch
            tocar(cartao)
            XCTAssertTrue(elemento("candidatura-enviada", em: app).waitForExistence(timeout: Espera.aparecer))
            capturar("detalhe-candidatura-enviada", ax5: ax5)
        }
    }

    // MARK: Parte 2: resultados da candidatura

    private func resultado(_ cenario: String, marca: String, nome: String) {
        for ax5 in [false, true] {
            let app = abrirDetalhe(cenario, ax5: ax5)
            tocar(app.buttons["candidatar"])
            XCTAssertTrue(elemento(marca, em: app).waitForExistence(timeout: Espera.aparecer), "O resultado \(marca) deve abrir")
            capturar(nome, ax5: ax5)
            app.terminate()
        }
    }

    func testResultadoTurnoConfirmado() { resultado("success", marca: "resultado-confirmada", nome: "resultado-turno-confirmado") }
    func testResultadoCandidaturaEnviada() { resultado("vaga-em-selecao", marca: "candidatura-enviada", nome: "resultado-candidatura-enviada") }
    func testResultadoVagaPreenchida() { resultado("vaga-preenchida", marca: "resultado-vaga-preenchida", nome: "resultado-vaga-preenchida") }
    func testResultadoVagaEncerrada() { resultado("vaga-encerrada", marca: "resultado-vaga-encerrada", nome: "resultado-vaga-encerrada") }
    func testResultadoHorarioCoincidente() { resultado("inelegivel", marca: "resultado-turno-sobreposto", nome: "resultado-horario-coincidente") }
    func testResultadoFuncaoDiferente() { resultado("funcao-incompativel", marca: "resultado-funcao-incompativel", nome: "resultado-funcao-diferente") }
    func testResultadoContaSuspensa() { resultado("inelegivel-suspenso", marca: "resultado-conta-suspensa", nome: "resultado-conta-suspensa") }

    // MARK: Parte 2: Candidaturas e seleção de funções

    private func abrirCandidaturas(_ cenario: String, nome: String) {
        nosDoisTamanhos(cenario: cenario) { app, ax5 in
            let aba = app.tabBars.buttons["Candidaturas"]
            XCTAssertTrue(aba.waitForExistence(timeout: 15))
            aba.tap()
            XCTAssertTrue(elemento("tela-minhas-candidaturas", em: app).waitForExistence(timeout: Espera.aparecer))
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'candidatura-'")).firstMatch
                .waitForExistence(timeout: Espera.aparecer))
            capturar(nome, ax5: ax5)
        }
    }

    func testCandidaturasAguardando() { abrirCandidaturas("candidatura-pendente", nome: "candidaturas-aguardando") }
    func testCandidaturasConfirmada() { abrirCandidaturas("candidatura-escolhida", nome: "candidaturas-confirmada") }

    func testSelecaoDeFuncoes() {
        nosDoisTamanhos(cenario: "sem-perfil-profissional") { app, ax5 in
            XCTAssertTrue(elemento("tela-perfil-profissional", em: app).waitForExistence(timeout: Espera.aparecer))
            capturar("funcoes-fechada", ax5: ax5)
            tocar(app.buttons["botao-expandir-funcoes"])
            XCTAssertTrue(app.textFields["campo-busca-funcao"].waitForExistence(timeout: Espera.aparecer))
            capturar("funcoes-aberta", ax5: ax5)
        }
    }
}
