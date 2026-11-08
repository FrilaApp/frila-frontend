import XCTest

/// Check-in e check-out (#17) pela tela real, com o GPS simulado do esquema Local
/// (`-FRILA_LOCALIZACAO`): lista -> candidatura -> Meus turnos -> Meu turno -> presença.
@MainActor
final class PresencaUITests: XCTestCase {
    private func abrirMeuTurno(localizacao: String = "perto", cenario: String = "success", argumentos: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", cenario, "-FRILA_LOCALIZACAO", localizacao] + argumentos
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: Espera.aparecer)
        let primeira = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-'")).firstMatch
        tocar(primeira)
        XCTAssertTrue(app.descendants(matching: .any)["tela-detalhe-vaga"].waitForExistence(timeout: Espera.aparecer))
        let candidatar = app.buttons["candidatar"]
        tocar(candidatar)
        XCTAssertTrue(app.descendants(matching: .any)["resultado-confirmada"].waitForExistence(timeout: Espera.aparecer))
        tocar(app.buttons["voltar-para-lista"])
        let meusTurnos = app.tabBars.buttons["Meus turnos"]
        tocar(meusTurnos)
        let turno = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'meu-turno-'")).firstMatch
        tocar(turno)
        XCTAssertTrue(app.descendants(matching: .any)["tela-meu-turno"].waitForExistence(timeout: Espera.aparecer))
        return app
    }

    /// Toca em "Fazer check-in" e passa pela explicação que antecede o pedido de permissão.
    private func fazerCheckinComPermissao(_ app: XCUIApplication) {
        let fazerCheckin = app.buttons["fazer-checkin"]
        tocar(fazerCheckin)
        XCTAssertTrue(app.descendants(matching: .any)["explicacao-localizacao"].waitForExistence(timeout: Espera.aparecer), "a explicação vem antes do pedido de permissão")
        tocar(app.buttons["permitir-localizacao"])
    }

    func testCheckinA150MetrosFicaVerificadoEOCheckoutRegistraASaida() {
        let app = abrirMeuTurno(localizacao: "perto")
        fazerCheckinComPermissao(app)

        let checkin = app.descendants(matching: .any)["checkin-situacao"]
        XCTAssertTrue(checkin.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(checkin.label.contains("Check-in verificado"), checkin.label)
        XCTAssertTrue(checkin.label.contains("150 m"), checkin.label)
        XCTAssertFalse(app.buttons["fazer-checkin"].exists)

        let fazerCheckout = app.buttons["fazer-checkout"]
        tocar(fazerCheckout)
        let checkout = app.descendants(matching: .any)["checkout-situacao"]
        XCTAssertTrue(checkout.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(checkout.label.contains("Check-out registrado"), checkout.label)
        XCTAssertTrue(checkout.label.contains("150 m"), checkout.label)
        XCTAssertFalse(app.buttons["fazer-checkout"].exists)
    }

    /// RN07: com presença verificada e check-out feito antes do fim previsto, a tela diz quando a
    /// avaliação libera e não mostra o cartão. O relógio do dublê é o do aparelho: a vaga do cenário
    /// `success` termina no futuro, então este é o caso "antes do fim". O caso "depois do fim" está em
    /// `AvaliacaoUITests.testTurnoEncerradoMostraOCartaoENaoOAvisoDeEspera`.
    func testCheckoutAntesDoFimAvisaQuandoAAvaliacaoLiberaESemCartao() {
        let app = abrirMeuTurno(localizacao: "perto")
        fazerCheckinComPermissao(app)
        tocar(app.buttons["fazer-checkout"])
        let checkout = app.descendants(matching: .any)["checkout-situacao"]
        XCTAssertTrue(checkout.waitForExistence(timeout: Espera.aparecer))

        let aviso = app.descendants(matching: .any)["aviso-avaliacao-libera"]
        XCTAssertTrue(aviso.waitForExistence(timeout: Espera.aparecer), "antes do fim, o aviso de espera ocupa o lugar do cartão")
        XCTAssertTrue(aviso.label.contains("A avaliação libera às "), aviso.label)
        XCTAssertFalse(app.descendants(matching: .any)["cartao-avaliacao-turno"].exists)
        XCTAssertFalse(app.buttons["Avaliar turno"].exists)
    }

    func testCheckoutA150MetrosRegistraASaidaComADistancia() {
        let app = abrirMeuTurno(localizacao: "perto")
        fazerCheckinComPermissao(app)

        let fazerCheckout = app.buttons["fazer-checkout"]
        tocar(fazerCheckout)

        let checkout = app.descendants(matching: .any)["checkout-situacao"]
        XCTAssertTrue(checkout.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(checkout.label.contains("Check-out registrado"), checkout.label)
        XCTAssertTrue(checkout.label.contains("150 m"), checkout.label)
        XCTAssertFalse(app.buttons["fazer-checkout"].exists)
    }

    func testCheckinA350MetrosOfereceOManualQueFicaAguardandoConfirmacao() {
        let app = abrirMeuTurno(localizacao: "longe", argumentos: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        fazerCheckinComPermissao(app)

        XCTAssertTrue(app.descendants(matching: .any)["sem-gps"].waitForExistence(timeout: Espera.aparecer))
        XCTAssertFalse(app.descendants(matching: .any)["checkin-situacao"].exists, "a 350 m nada é registrado sem a pessoa pedir")
        let manual = app.buttons["registro-manual"]
        XCTAssertTrue(app.buttons["tentar-gps"].exists)
        tocar(manual)

        let checkin = app.descendants(matching: .any)["checkin-situacao"]
        XCTAssertTrue(checkin.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(checkin.label.contains("Aguardando confirmação do contratante"), checkin.label)
    }

    func testPermissaoNegadaOfereceOManualEOsAjustes() {
        let app = abrirMeuTurno(localizacao: "negada")
        fazerCheckinComPermissao(app)

        XCTAssertTrue(app.descendants(matching: .any)["sem-gps"].waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(app.descendants(matching: .any)["abrir-ajustes"].waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(app.buttons["registro-manual"].exists)
        tocar(app.buttons["cancelar-presenca"])
        XCTAssertTrue(app.buttons["fazer-checkin"].waitForExistence(timeout: Espera.aparecer), "desistir devolve o botão de check-in")
    }

    /// A11: quem só concedeu a localização aproximada é avisado de que a precisa mede os 200 m.
    func testLocalizacaoAproximadaPedeAPrecisaEAvisaAntesDoProximoToque() {
        let app = abrirMeuTurno(localizacao: "aproximada")
        XCTAssertFalse(app.descendants(matching: .any)["aviso-precisao-desligada"].exists, "sem permissão decidida, não há o que avisar")
        fazerCheckinComPermissao(app)

        XCTAssertTrue(app.descendants(matching: .any)["sem-gps"].waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(app.descendants(matching: .any)["abrir-ajustes"].exists)
        XCTAssertTrue(app.buttons["registro-manual"].exists)
        tocar(app.buttons["cancelar-presenca"])

        XCTAssertTrue(app.buttons["fazer-checkin"].waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(app.descendants(matching: .any)["aviso-precisao-desligada"].waitForExistence(timeout: Espera.aparecer), "com a aproximada, o aviso vem antes do toque")
        XCTAssertTrue(app.descendants(matching: .any)["abrir-ajustes"].exists)
    }

    func testBotaoEstouACaminhoApareceTocaEMostraAviso() {
        let app = abrirMeuTurno(cenario: "a-caminho")
        let botaoACaminho = app.buttons["botao-a-caminho"]
        XCTAssertTrue(botaoACaminho.waitForExistence(timeout: Espera.aparecer), "o botão Estou a caminho deve aparecer na janela permitida")
        salvarCaptura(app.screenshot(), nome: "a-caminho-padrao.png")
        tocar(botaoACaminho)

        let situacaoACaminho = app.descendants(matching: .any)["a-caminho-situacao"]
        XCTAssertTrue(situacaoACaminho.waitForExistence(timeout: Espera.aparecer), "o estado do aviso a caminho deve ser exibido após o toque")
        XCTAssertTrue(situacaoACaminho.label.contains("Você avisou que está a caminho"), situacaoACaminho.label)
        XCTAssertFalse(app.buttons["botao-a-caminho"].exists, "o botão Estou a caminho deve sumir após o envio")
        salvarCaptura(app.screenshot(), nome: "a-caminho-enviado-padrao.png")
    }

    /// LOJA-M2: Quando o turno começa a mais de 60 min, o check-in não fica disponível e
    /// a tela exibe o aviso informativo de abertura antecipada.
    func testTurnoComMaisDe60MinutosNaoOfereceCheckinEMostraAviso() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "turno-confirmado-perto", "-FRILA_LOCALIZACAO", "perto", "-FRILA_CACHE_VAZIO_UI_TEST"]
        AjudanteDeLancamentoUITests.preparar(app)
        app.launch()
        let meusTurnos = app.tabBars.buttons["Meus turnos"]
        XCTAssertTrue(meusTurnos.waitForExistence(timeout: Espera.aparecer))
        tocar(meusTurnos)
        let turno = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'meu-turno-'")).firstMatch
        XCTAssertTrue(turno.waitForExistence(timeout: Espera.aparecer))
        tocar(turno)
        XCTAssertTrue(app.descendants(matching: .any)["tela-meu-turno"].waitForExistence(timeout: Espera.aparecer))

        XCTAssertFalse(app.buttons["fazer-checkin"].exists, "botão de check-in não deve aparecer antes de 60 min do turno")
        let aviso = app.descendants(matching: .any)["aviso-checkin-antecipado"]
        XCTAssertTrue(aviso.waitForExistence(timeout: Espera.aparecer), "aviso de check-in abre 1 hora antes deve ser exibido")
    }

    func testBotaoEstouACaminhoEmAX5() {
        let app = abrirMeuTurno(cenario: "a-caminho", argumentos: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let botaoACaminho = app.buttons["botao-a-caminho"]
        XCTAssertTrue(botaoACaminho.waitForExistence(timeout: Espera.aparecer), "o botão Estou a caminho deve aparecer na janela permitida em AX5")
        salvarCaptura(app.screenshot(), nome: "a-caminho-ax5.png")
        tocar(botaoACaminho)

        let situacaoACaminho = app.descendants(matching: .any)["a-caminho-situacao"]
        XCTAssertTrue(situacaoACaminho.waitForExistence(timeout: Espera.aparecer), "o estado do aviso a caminho deve ser exibido após o toque em AX5")
        salvarCaptura(app.screenshot(), nome: "a-caminho-enviado-ax5.png")
    }

    private func salvarCaptura(_ screenshot: XCUIScreenshot, nome: String) {
        let anexo = XCTAttachment(screenshot: screenshot)
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)

        let pasta = "/Users/cauecarneiro/Documents/Projetos/Apps/.workers/missoes/capturas/2026-10-16-a-caminho"
        try? FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "\(pasta)/\(nome)"))
    }
}
