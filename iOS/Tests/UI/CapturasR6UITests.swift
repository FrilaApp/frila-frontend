import XCTest

/// R6 (redesign, a casa: turno e busca): uma captura de cada tela do lote, no tamanho padrão e em AX5.
/// `FRILA_CAPTURAS_DIR` (opcional) grava as imagens; sem ela, os anexos ficam só no resultado do teste.
/// Cada teste confere só que a tela abriu (o elemento principal existe); o que cada tela faz já tem teste próprio
/// (`TurnoDoContratanteUITests`, `CheckinPorCodigoUITests`, `BuscaDeProfissionaisUITests`, `ChamadaDiretaCompletaUITests`,
/// `EquipeDeConfiancaUITests`).
@MainActor
final class CapturasR6UITests: XCTestCase {
    private let turnoDaCasa = "82000000-0000-0000-0000-000000000001"
    private let posicaoDaCasa = "82000000-0000-0000-0000-000000000002"
    private let vagaComChamadaAberta = "C1000000-0000-0000-0000-000000000002"
    private let vagaComChamadaRecusada = "C1000000-0000-0000-0000-000000000003"
    private let profissionalDoTurno = "80000000-0000-0000-0000-000000000001"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: Apoio

    private func abrir(_ argumentos: [String], ax5: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = argumentos + ["-FRILA_MODO_CLARO", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR"]
        if ax5 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        AjudanteDeLancamentoUITests.preparar(app)
        app.launch()
        return app
    }

    private func sufixo(_ ax5: Bool) -> String { ax5 ? "ax5" : "padrao" }

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

    /// Rola até o elemento ficar à vista (sem exigir que ele exista: a captura sai do jeito que a tela estiver).
    private func rolarAte(_ elemento: XCUIElement, em app: XCUIApplication) {
        let altura = app.windows.firstMatch.frame.height
        for _ in 0..<14 {
            if elemento.exists, elemento.isHittable, elemento.frame.minY > 100, elemento.frame.maxY < altura - 120 { return }
            if elemento.exists, elemento.frame.minY <= 100 { app.swipeDown() } else { app.swipeUp() }
        }
    }

    private func qualquer(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    // MARK: Turno da casa (parte 1)

    private func turnoComCodigo(ax5: Bool) {
        let app = abrir(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "checkin-por-codigo-casa",
                         "-FRILA_AVISO", "checkin_manual_pendente", "-FRILA_AVISO_ID", turnoDaCasa], ax5: ax5)
        let codigo = qualquer(app, "codigo-da-casa")
        XCTAssertTrue(codigo.waitForExistence(timeout: 25), "o código de chegada aparece no turno da casa")
        capturar("r6-turno-chegada-manual-\(sufixo(ax5))")
        rolarAte(codigo, em: app)
        capturar("r6-codigo-de-chegada-\(sufixo(ax5))")
    }

    private func turnoVerificado(ax5: Bool) {
        let app = abrir(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "checkin-confirmado",
                         "-FRILA_AVISO", "checkin", "-FRILA_AVISO_ID", turnoDaCasa], ax5: ax5)
        XCTAssertTrue(qualquer(app, "turno-do-contratante").waitForExistence(timeout: 25))
        XCTAssertTrue(app.staticTexts["Presença verificada."].waitForExistence(timeout: 10))
        capturar("r6-turno-verificado-\(sufixo(ax5))")
        for _ in 0..<6 { app.swipeUp() }
        capturar("r6-turno-acoes-no-fim-\(sufixo(ax5))")
    }

    private func turnoEmAtraso(ax5: Bool) {
        let app = abrir(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "atraso-no-turno",
                         "-FRILA_AVISO", "atraso_15min", "-FRILA_AVISO_ID", turnoDaCasa], ax5: ax5)
        XCTAssertTrue(qualquer(app, "turno-do-contratante").waitForExistence(timeout: 25))
        capturar("r6-turno-em-atraso-\(sufixo(ax5))")
    }

    private func turnoCancelado(ax5: Bool) {
        let app = abrir(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "posicao-cancelada-com-motivo",
                         "-FRILA_AVISO", "checkin", "-FRILA_AVISO_ID", turnoDaCasa], ax5: ax5)
        XCTAssertTrue(app.staticTexts["Esta posição foi cancelada."].waitForExistence(timeout: 25))
        capturar("r6-turno-cancelado-\(sufixo(ax5))")
    }

    private func presencasAConfirmar(ax5: Bool) {
        let app = abrir(["-FRILA_SCENARIO", "checkin-manual-pendente"], ax5: ax5)
        XCTAssertTrue(qualquer(app, "presencas-a-confirmar").waitForExistence(timeout: 25))
        capturar("r6-presencas-a-confirmar-\(sufixo(ax5))")
    }

    private func avaliarProfissional(ax5: Bool) {
        let app = abrir(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "ciclo-contratante-turno-concluido"], ax5: ax5)
        let vaga = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-contratante-'")).firstMatch
        XCTAssertTrue(vaga.waitForExistence(timeout: 25))
        rolarAte(vaga, em: app)
        vaga.tap()
        let acompanhar = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'acompanhar-turno-'")).firstMatch
        XCTAssertTrue(acompanhar.waitForExistence(timeout: 15))
        rolarAte(acompanhar, em: app)
        acompanhar.tap()
        let cartao = qualquer(app, "cartao-avaliacao-turno")
        XCTAssertTrue(qualquer(app, "turno-do-contratante").waitForExistence(timeout: 15))
        rolarAte(cartao, em: app)
        capturar("r6-avaliar-cartao-no-turno-\(sufixo(ax5))")
        let abrirAvaliacao = app.buttons["botao-abrir-avaliacao"]
        if abrirAvaliacao.waitForExistence(timeout: 5) {
            rolarAte(abrirAvaliacao, em: app)
            abrirAvaliacao.tap()
            if app.navigationBars["Avaliar turno"].waitForExistence(timeout: 10) {
                capturar("r6-avaliar-profissional-\(sufixo(ax5))")
            }
        }
    }

    // MARK: Equipe e chamar de novo (partes 1 e 2)

    private func equipeEChamada(ax5: Bool) {
        let app = abrir(["-FRILA_ABRIR_EQUIPE_CONFIANCA", "-FRILA_SCENARIO", "chamada-direta"], ax5: ax5)
        let chamar = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'chamar-de-novo-'")).firstMatch
        XCTAssertTrue(chamar.waitForExistence(timeout: 25), "a equipe mostra Chamar de novo")
        capturar("r6-equipe-de-confianca-\(sufixo(ax5))")
        rolarAte(chamar, em: app)
        chamar.tap()

        let valor = app.textFields["total-chamada-centavos"]
        XCTAssertTrue(valor.waitForExistence(timeout: 15), "a folha Chamar profissional abre")
        capturar("r6-chamar-profissional-\(sufixo(ax5))")
        rolarAte(valor, em: app)
        valor.tap()
        valor.typeText("180")
        let ok = app.buttons.matching(NSPredicate(format: "label ==[c] 'ok'")).firstMatch
        if ok.exists { ok.tap() }
        let total = app.switches["confirmar-total-chamada"]
        rolarAte(total, em: app)
        total.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        capturar("r6-chamar-profissional-pronta-\(sufixo(ax5))")
        let enviar = app.buttons["enviar-chamada"]
        guard enviar.waitForExistence(timeout: 5), enviar.isEnabled else { return }
        enviar.tap()

        XCTAssertTrue(app.staticTexts["prazo-chamada-enviada"].waitForExistence(timeout: 15), "enviada, a folha mostra o prazo")
        capturar("r6-chamada-enviada-\(sufixo(ax5))")
        let acompanhar = app.buttons["acompanhar-chamada-enviada"]
        rolarAte(acompanhar, em: app)
        if acompanhar.waitForExistence(timeout: 5) {
            acompanhar.tap()
            if app.navigationBars["Acompanhar chamadas"].waitForExistence(timeout: 10) {
                capturar("r6-acompanhar-chamadas-do-resumo-\(sufixo(ax5))")
            }
        }
    }

    private func chamarDeNovoPreenchido(ax5: Bool) {
        let tresDiasAtras = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3 * 86_400))
        let app = abrir(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "chamada-direta", "-FRILA_RELOGIO_AGORA", tresDiasAtras,
                         "-FRILA_AVISO", "confirmacao", "-FRILA_AVISO_ID", turnoDaCasa], ax5: ax5)
        let chamar = app.buttons["chamar-de-novo-\(profissionalDoTurno)"]
        rolarAte(chamar, em: app)
        XCTAssertTrue(chamar.waitForExistence(timeout: 25), "no turno cumprido e verificado, a casa pode chamar de novo")
        capturar("r6-turno-com-chamar-de-novo-\(sufixo(ax5))")
        chamar.tap()
        XCTAssertTrue(app.staticTexts["aviso-preenchido-vaga-anterior"].waitForExistence(timeout: 15))
        capturar("r6-chamar-de-novo-preenchido-\(sufixo(ax5))")
    }

    // MARK: Acompanhar chamadas (parte 2)

    private func acompanharChamadas(vaga: String, nome: String, ax5: Bool) {
        let app = abrir(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "chamadas-enviadas"], ax5: ax5)
        let cartao = app.buttons["vaga-contratante-\(vaga)"]
        XCTAssertTrue(cartao.waitForExistence(timeout: 25), "a vaga direta aparece em Minhas vagas")
        rolarAte(cartao, em: app)
        cartao.tap()
        let acompanhar = app.buttons["acompanhar-chamadas-\(vaga)"]
        XCTAssertTrue(acompanhar.waitForExistence(timeout: 15))
        rolarAte(acompanhar, em: app)
        acompanhar.tap()
        XCTAssertTrue(app.navigationBars["Acompanhar chamadas"].waitForExistence(timeout: 15))
        capturar("\(nome)-\(sufixo(ax5))")
    }

    // MARK: Busca (parte 2)

    private func abrirABusca(_ app: XCUIApplication) {
        let entrada = app.buttons["encontrar-profissional"]
        XCTAssertTrue(entrada.waitForExistence(timeout: 25), "Minhas vagas oferece Encontrar profissional")
        entrada.tap()
        XCTAssertTrue(app.navigationBars["Encontrar profissional"].waitForExistence(timeout: 15))
    }

    private func buscar(_ app: XCUIApplication) {
        let botao = app.buttons["buscar-profissionais"]
        XCTAssertTrue(botao.waitForExistence(timeout: 15))
        let habilitado = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: botao)
        wait(for: [habilitado], timeout: 20)
        rolarAte(botao, em: app)
        botao.tap()
    }

    private func busca(ax5: Bool) {
        let app = abrir(["-FRILA_SCENARIO", "busca-de-profissionais"], ax5: ax5)
        abrirABusca(app)
        capturar("r6-busca-filtros-\(sufixo(ax5))")
        buscar(app)
        let primeira = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'selecionar-profissional-'")).firstMatch
        XCTAssertTrue(primeira.waitForExistence(timeout: 20), "a busca traz profissionais")
        rolarAte(primeira, em: app)
        capturar("r6-busca-resultados-\(sufixo(ax5))")
        primeira.tap()
        capturar("r6-busca-selecao-\(sufixo(ax5))")
        let chamar = app.buttons["chamar-selecionados"]
        // Em AX5 o botão está no fim da lista rolável: rola até ele antes de tocar.
        for _ in 0..<30 where !(chamar.exists && chamar.isHittable) { app.swipeUp() }
        XCTAssertTrue(chamar.waitForExistence(timeout: 5) && chamar.isEnabled, "com uma pessoa escolhida, dá para chamar")
        chamar.tap()
        XCTAssertTrue(app.textFields["busca-valor-total"].waitForExistence(timeout: 10), "a folha de chamada abre")
        capturar("r6-busca-folha-chamar-\(sufixo(ax5))")
    }

    private func buscaSemResultado(ax5: Bool) {
        let app = abrir(["-FRILA_SCENARIO", "busca-de-profissionais"], ax5: ax5)
        abrirABusca(app)
        // Outro serviço: ninguém oferece, a busca fica vazia e oferece "Publicar para todos".
        let servico = app.buttons["busca-servico"]
        XCTAssertTrue(servico.waitForExistence(timeout: 15))
        rolarAte(servico, em: app)
        servico.tap()
        let outro = app.collectionViews.buttons["Bartender"]
        XCTAssertTrue(outro.waitForExistence(timeout: 10), "o seletor de serviço lista o catálogo")
        outro.tap()
        buscar(app)
        let vazia = qualquer(app, "busca-vazia")
        XCTAssertTrue(vazia.waitForExistence(timeout: 20), "sem ninguém, a busca fica vazia")
        rolarAte(vazia, em: app)
        capturar("r6-busca-vazia-\(sufixo(ax5))")
    }

    private func buscaComAceiteDosTermos(ax5: Bool) {
        let app = abrir(["-FRILA_SCENARIO", "busca-com-termos-pendentes"], ax5: ax5)
        abrirABusca(app)
        buscar(app)
        let aceitar = app.buttons["aceite-termos-aceitar"]
        XCTAssertTrue(aceitar.waitForExistence(timeout: 20), "sem os Termos, a busca pede o aceite")
        rolarAte(aceitar, em: app)
        capturar("r6-busca-aceite-dos-termos-\(sufixo(ax5))")
    }

    // MARK: Os testes (padrão e AX5)

    func testTurnoComCodigoPadrao() { turnoComCodigo(ax5: false) }
    func testTurnoComCodigoAX5() { turnoComCodigo(ax5: true) }
    func testTurnoVerificadoPadrao() { turnoVerificado(ax5: false) }
    func testTurnoVerificadoAX5() { turnoVerificado(ax5: true) }
    func testTurnoEmAtrasoPadrao() { turnoEmAtraso(ax5: false) }
    func testTurnoEmAtrasoAX5() { turnoEmAtraso(ax5: true) }
    func testTurnoCanceladoPadrao() { turnoCancelado(ax5: false) }
    func testTurnoCanceladoAX5() { turnoCancelado(ax5: true) }
    func testPresencasAConfirmarPadrao() { presencasAConfirmar(ax5: false) }
    func testPresencasAConfirmarAX5() { presencasAConfirmar(ax5: true) }
    func testAvaliarProfissionalPadrao() { avaliarProfissional(ax5: false) }
    func testAvaliarProfissionalAX5() { avaliarProfissional(ax5: true) }
    func testEquipeEChamadaPadrao() { equipeEChamada(ax5: false) }
    func testEquipeEChamadaAX5() { equipeEChamada(ax5: true) }
    func testChamarDeNovoPreenchidoPadrao() { chamarDeNovoPreenchido(ax5: false) }
    func testChamarDeNovoPreenchidoAX5() { chamarDeNovoPreenchido(ax5: true) }
    func testAcompanharChamadasAbertaPadrao() {
        acompanharChamadas(vaga: vagaComChamadaAberta, nome: "r6-acompanhar-chamadas-aberta", ax5: false)
    }
    func testAcompanharChamadasAbertaAX5() {
        acompanharChamadas(vaga: vagaComChamadaAberta, nome: "r6-acompanhar-chamadas-aberta", ax5: true)
    }
    func testAcompanharChamadasRecusadaPadrao() {
        acompanharChamadas(vaga: vagaComChamadaRecusada, nome: "r6-acompanhar-chamadas-recusada", ax5: false)
    }
    func testAcompanharChamadasRecusadaAX5() {
        acompanharChamadas(vaga: vagaComChamadaRecusada, nome: "r6-acompanhar-chamadas-recusada", ax5: true)
    }
    func testBuscaPadrao() { busca(ax5: false) }
    func testBuscaAX5() { busca(ax5: true) }
    func testBuscaSemResultadoPadrao() { buscaSemResultado(ax5: false) }
    func testBuscaSemResultadoAX5() { buscaSemResultado(ax5: true) }
    func testBuscaComAceiteDosTermosPadrao() { buscaComAceiteDosTermos(ax5: false) }
    func testBuscaComAceiteDosTermosAX5() { buscaComAceiteDosTermos(ax5: true) }
}
