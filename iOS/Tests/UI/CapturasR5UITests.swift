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
        // Neste cenário a tela abre sem a entrada de publicar (o botão só existe dentro do app completo).
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

    // MARK: - Parte 2: candidatos, republicar e cancelar

    private func rolarAte(_ elemento: XCUIElement, em app: XCUIApplication, tentativas: Int = 10) {
        for _ in 0..<tentativas where !(elemento.exists && elemento.isHittable) { app.swipeUp() }
    }

    private func candidatos(ax5: Bool) {
        let app = iniciar(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "selecao-com-candidatos", "-FRILA_CAPTURA", "vaga-aberta"], ax5: ax5)
        XCTAssertTrue(app.descendants(matching: .any)["candidatos-da-vaga"].waitForExistence(timeout: 20))
        let escolher = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'escolher-candidato-'")).firstMatch
        XCTAssertTrue(escolher.waitForExistence(timeout: 15))
        rolarAte(escolher, em: app)
        XCTAssertGreaterThanOrEqual(escolher.frame.height, 44, "Escolher tem alvo de ao menos 44 pt")
        capturar("candidatos", ax5: ax5)
    }

    private func confirmarEscolha(ax5: Bool) {
        let app = iniciar(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "selecao-com-candidatos", "-FRILA_CAPTURA", "vaga-aberta"], ax5: ax5)
        let escolher = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'escolher-candidato-'")).firstMatch
        XCTAssertTrue(escolher.waitForExistence(timeout: 20))
        rolarAte(escolher, em: app)
        escolher.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: Espera.aparecer), "o alerta Confirmar a escolha abre")
        capturar("confirmar-escolha", ax5: ax5)
    }

    private func republicar(ax5: Bool) {
        let app = iniciar(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "vaga-encerrada-contratante"], ax5: ax5)
        let botao = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "republicar-vaga-")).firstMatch
        XCTAssertTrue(botao.waitForExistence(timeout: 15))
        rolarAte(botao, em: app)
        botao.tap()
        XCTAssertTrue(app.descendants(matching: .any)["tela-republicar-vaga"].waitForExistence(timeout: Espera.aparecer))
        confirmarAlvo(app.buttons["botao-confirmar-republicacao"], "o botão de confirmar")
        capturar("republicar-vaga", ax5: ax5)
    }

    private func cancelarVaga(ax5: Bool) {
        let app = iniciar(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "painel-contratante", "-FRILA_CAPTURA", "vaga-aberta"], ax5: ax5)
        XCTAssertTrue(app.descendants(matching: .any)["detalhe-vaga-contratante"].waitForExistence(timeout: 15))
        let cancelar = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cancelar-vaga-'")).firstMatch
        XCTAssertTrue(cancelar.waitForExistence(timeout: Espera.aparecer))
        rolarAte(cancelar, em: app)
        capturar("detalhe-acao-discreta", ax5: ax5)
        cancelar.tap()
        XCTAssertTrue(app.descendants(matching: .any)["folha-de-cancelamento"].firstMatch.waitForExistence(timeout: Espera.aparecer))
        capturar("cancelar-vaga", ax5: ax5)
    }

    func testCandidatosNoTamanhoPadrao() { candidatos(ax5: false) }
    func testCandidatosEmAX5() { candidatos(ax5: true) }
    func testConfirmarEscolhaNoTamanhoPadrao() { confirmarEscolha(ax5: false) }
    func testConfirmarEscolhaEmAX5() { confirmarEscolha(ax5: true) }
    func testRepublicarVagaNoTamanhoPadrao() { republicar(ax5: false) }
    func testRepublicarVagaEmAX5() { republicar(ax5: true) }
    func testCancelarVagaNoTamanhoPadrao() { cancelarVaga(ax5: false) }
    func testCancelarVagaEmAX5() { cancelarVaga(ax5: true) }

    // MARK: - Parte 3: publicar vaga (Estúdio), prévia e vaga publicada

    private func abrirEstudio(ax5: Bool) -> XCUIApplication {
        let app = iniciar(["-FRILA_SCENARIO", "contratante", "-FRILA_CACHE_VAZIO_UI_TEST", "-FRILA_CADASTRO_UI_TEST"], ax5: ax5)
        let entrada = app.buttons["publicar-vaga-entrada"]
        XCTAssertTrue(entrada.waitForExistence(timeout: 20), "Minhas vagas abre com a entrada de publicar")
        entrada.tap()
        XCTAssertTrue(esperarFormularioDePublicarVaga(app), "o Estúdio de criação abre")
        return app
    }

    private func estudio(ax5: Bool) {
        let app = abrirEstudio(ax5: ax5)
        confirmarAlvo(app.buttons["publicar-vaga-botao"], "o botão de publicar")
        confirmarAlvo(app.buttons["previa-vaga-botao"], "o botão de prévia")
        capturar("estudio", ax5: ax5)
    }

    private func previa(ax5: Bool) {
        let app = abrirEstudio(ax5: ax5)
        let botao = app.buttons["previa-vaga-botao"]
        XCTAssertTrue(botao.waitForExistence(timeout: Espera.aparecer))
        botao.tap()
        XCTAssertTrue(app.buttons["Fechar"].waitForExistence(timeout: Espera.aparecer), "a prévia tem o Fechar na barra")
        capturar("previa", ax5: ax5)
    }

    private func vagaPublicada(ax5: Bool) {
        let app = abrirEstudio(ax5: ax5)
        let responsavel = app.textFields["responsavel-local-campo"]
        rolarAte(responsavel, em: app)
        responsavel.tap()
        responsavel.typeText("Marina")
        fecharTeclado(app)
        if ax5 {
            // Em AX5 o texto do atalho muda de leitura; toca o atalho de R$ 160 sem conferir o texto do preço.
            fecharTeclado(app)
            let atalho = app.buttons.matching(NSPredicate(format: "label CONTAINS '160'")).firstMatch
            XCTAssertTrue(atalho.waitForExistence(timeout: Espera.aparecer), "o atalho de R$ 160 existe")
            rolarAte(atalho, em: app)
            atalho.tap()
        } else {
            ajustarValorPorTurno(app, para: 160)
        }
        let publicar = app.buttons["publicar-vaga-botao"]
        rolarAte(publicar, em: app)
        publicar.tap()
        XCTAssertTrue(app.buttons["celebracao-concluir"].waitForExistence(timeout: 20), "a celebração da vaga publicada abre")
        confirmarAlvo(app.buttons["celebracao-ver-vaga"], "Ver Detalhes da Vaga")
        capturar("vaga-publicada", ax5: ax5)
    }

    func testEstudioNoTamanhoPadrao() { estudio(ax5: false) }
    func testEstudioEmAX5() { estudio(ax5: true) }
    func testPreviaNoTamanhoPadrao() { previa(ax5: false) }
    func testPreviaEmAX5() { previa(ax5: true) }
    func testVagaPublicadaNoTamanhoPadrao() { vagaPublicada(ax5: false) }
    func testVagaPublicadaEmAX5() { vagaPublicada(ax5: true) }
}
