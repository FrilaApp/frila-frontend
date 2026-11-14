import XCTest

/// As telas do check-in por código (F12b, etapa 3, contrato 0.2.68) com a chave ligada no dublê
/// (`checkin-por-codigo` e `checkin-por-codigo-casa`): a casa mostra o código e a contagem; o profissional
/// digita os 6 números, e o "chegue mais perto" segura o envio sem gastar tentativa.
/// Sem QR code na etapa 1 (apenas digitação manual dos 6 números).
@MainActor
final class CheckinPorCodigoUITests: XCTestCase {
    private let turnoDoProfissional = "24000000-0000-0000-0000-000000000001"
    private let turnoDaCasa = "82000000-0000-0000-0000-000000000001"
    private let codigoDaCasa = "482913"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func abrir(_ argumentos: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = argumentos
        AjudanteDeLancamentoUITests.preparar(app)
        app.launch()
        return app
    }

    private func rolarAte(_ elemento: XCUIElement, em app: XCUIApplication) {
        let altura = app.windows.firstMatch.frame.height
        for _ in 0..<12 {
            if elemento.exists, elemento.isHittable, elemento.frame.minY > 100, elemento.frame.maxY < altura - 40 { return }
            if elemento.exists, elemento.frame.minY <= 100 { app.swipeDown() } else { app.swipeUp() }
        }
    }

    // MARK: A casa

    private func abrirTurnoDaCasa(cenario: String, extras: [String] = []) -> XCUIApplication {
        abrir(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", cenario,
               "-FRILA_AVISO", "checkin_manual_pendente", "-FRILA_AVISO_ID", turnoDaCasa] + extras)
    }

    func testCasaVeOCodigoEContagemSemNavegarEMantemAConfirmacaoManual() {
        let app = abrirTurnoDaCasa(cenario: "checkin-por-codigo-casa")
        let codigo = app.descendants(matching: .any)["codigo-da-casa"]
        XCTAssertTrue(codigo.waitForExistence(timeout: 20), "ao abrir pelo aviso, o código já está visível")
        rolarAte(codigo, em: app)
        XCTAssertTrue(codigo.label.contains("4 8 2 9 1 3"), codigo.label)
        XCTAssertEqual(codigo.label, "Código de chegada: 4 8 2 9 1 3")
        let validade = app.staticTexts["validade-do-codigo-da-casa"]
        XCTAssertTrue(validade.waitForExistence(timeout: 5))
        XCTAssertTrue(validade.label.hasPrefix("Vale por mais "), validade.label)
        let confirmar = app.buttons["confirmar-presenca-\(turnoDaCasa)"]
        XCTAssertTrue(confirmar.exists, "a confirmação manual de hoje continua")
        XCTAssertEqual(confirmar.label, "Confirmar presença")
    }

    func testCasaComCheckinSemCodigoMostraOAvisoEMantemAConfirmacaoManual() {
        conferirAvisoSemCodigo(extras: [], nomeDaCaptura: "cartao-da-casa-sem-codigo-padrao")
    }

    func testCasaComCheckinSemCodigoMostraOAvisoEmAX5() {
        conferirAvisoSemCodigo(
            extras: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"],
            nomeDaCaptura: "cartao-da-casa-sem-codigo-ax5"
        )
    }

    private func conferirAvisoSemCodigo(extras: [String], nomeDaCaptura: String) {
        let app = abrirTurnoDaCasa(cenario: "checkin-por-codigo-casa-espera", extras: extras)
        let aviso = app.descendants(matching: .any)["codigo-da-casa-sem-codigo-para-o-checkin"]
        XCTAssertTrue(aviso.waitForExistence(timeout: 20), "aviso na tela da casa")
        rolarAte(aviso, em: app)
        let captura = XCTAttachment(screenshot: app.screenshot())
        captura.name = nomeDaCaptura
        captura.lifetime = .keepAlways
        add(captura)
        XCTAssertEqual(aviso.label, "O check-in foi feito longe do local ou há mais de 15 min. Confirme a presença pelo botão abaixo.")
        // Não há mais o botão "Verificar chegada": o 409 não muda com a espera.
        XCTAssertFalse(app.buttons["atualizar-chegada-casa"].exists)
        // A confirmação manual fica logo abaixo.
        let confirmar = app.buttons["confirmar-presenca-\(turnoDaCasa)"]
        XCTAssertTrue(confirmar.exists)
        XCTAssertEqual(confirmar.label, "Confirmar presença")
        XCTAssertTrue(confirmar.isEnabled)
    }

    func testSemAChaveACasaNaoVeOCodigoEOTurnoEOMesmoDeHoje() {
        let app = abrirTurnoDaCasa(cenario: "checkin-manual-pendente")
        let confirmar = app.buttons["confirmar-presenca-\(turnoDaCasa)"]
        XCTAssertTrue(confirmar.waitForExistence(timeout: 20), "o turno de hoje, com a confirmação manual")
        XCTAssertFalse(app.descendants(matching: .any)["cartao-codigo-da-casa"].exists, "sem a chave, nada do código aparece")
        XCTAssertFalse(app.descendants(matching: .any)["codigo-da-casa"].exists)
    }

    // MARK: O profissional

    private func abrirTurnoDoProfissional(localizacao: String) -> XCUIApplication {
        abrir(["-FRILA_SCENARIO", "checkin-por-codigo", "-FRILA_LOCALIZACAO", localizacao,
               "-FRILA_PUSH", "turno_nao_verificado", "-FRILA_PUSH_ID", turnoDoProfissional])
    }

    /// Faz o check-in com a permissão e, se o GPS não servir, o registro manual: deixa a presença pendente.
    private func fazerCheckinPendente(_ app: XCUIApplication, manual: Bool) {
        let fazerCheckin = app.buttons["fazer-checkin"]
        XCTAssertTrue(fazerCheckin.waitForExistence(timeout: 20), "o aviso abre o Meu turno")
        tocar(fazerCheckin)
        XCTAssertTrue(app.descendants(matching: .any)["explicacao-localizacao"].waitForExistence(timeout: Espera.aparecer))
        tocar(app.buttons["permitir-localizacao"])
        if manual { tocar(app.buttons["registro-manual"]) }
    }

    private func abrirALeituraDoCodigo(_ app: XCUIApplication) -> XCUIElement {
        let ler = app.buttons["ler-codigo-da-casa"]
        XCTAssertTrue(ler.waitForExistence(timeout: Espera.aparecer), "com o check-in pendente e a chave ligada, aparece a leitura do código")
        tocar(ler)
        let campo = app.textFields["campo-codigo-checkin"]
        XCTAssertTrue(campo.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(app.staticTexts["aviso-casa-confirma"].exists, "a casa também pode confirmar a chegada")
        return campo
    }

    func testGPSSimuladoPedeOCodigoEOCodigoCertoVerificaAPresenca() {
        let app = abrirTurnoDoProfissional(localizacao: "codigo-perto")
        fazerCheckinPendente(app, manual: false)
        let campo = abrirALeituraDoCodigo(app)
        let confirmar = app.buttons["confirmar-codigo-checkin"]
        XCTAssertFalse(confirmar.isEnabled, "com menos de 6 números o botão espera")
        campo.tap()
        campo.typeText(codigoDaCasa)
        tocarFechandoTeclado(confirmar, em: app)
        XCTAssertTrue(app.descendants(matching: .any)["entrada-do-codigo"].waitForNonExistence(timeout: Espera.aparecer), "validado, a folha fecha")
        let situacao = app.descendants(matching: .any)["checkin-situacao"]
        XCTAssertTrue(situacao.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(situacao.label.contains("Check-in verificado"), situacao.label)
        XCTAssertFalse(app.buttons["ler-codigo-da-casa"].exists, "verificada, não há mais o que ler")
    }

    func testCodigoErradoMostraOErroETresErradasBloqueiamPorUmTempo() {
        let app = abrirTurnoDoProfissional(localizacao: "codigo-perto")
        fazerCheckinPendente(app, manual: false)
        let campo = abrirALeituraDoCodigo(app)
        campo.tap()
        campo.typeText("000001")
        let confirmar = app.buttons["confirmar-codigo-checkin"]
        tocar(confirmar)
        XCTAssertTrue(app.descendants(matching: .any)["codigo-invalido"].waitForExistence(timeout: Espera.aparecer), "o erro do contrato, sem dizer o motivo")
        tocar(confirmar)
        XCTAssertTrue(app.descendants(matching: .any)["codigo-invalido"].waitForExistence(timeout: Espera.aparecer))
        tocar(confirmar)
        XCTAssertTrue(
            app.descendants(matching: .any)["codigo-bloqueado-temporario"].waitForExistence(timeout: Espera.aparecer),
            "na terceira errada, o bloqueio por um tempo e o caminho da casa"
        )
        XCTAssertTrue(app.staticTexts["aviso-casa-confirma"].exists)
    }

    func testAcimaDe100MetrosChegueMaisPertoSemGastarTentativa() {
        let app = abrirTurnoDoProfissional(localizacao: "longe")
        fazerCheckinPendente(app, manual: true)
        let campo = abrirALeituraDoCodigo(app)
        campo.tap()
        campo.typeText(codigoDaCasa)
        let confirmar = app.buttons["confirmar-codigo-checkin"]
        tocarFechandoTeclado(confirmar, em: app)
        let aviso = app.descendants(matching: .any)["chegue-mais-perto"]
        XCTAssertTrue(aviso.waitForExistence(timeout: Espera.aparecer), "a mais de 100 m, o aviso")
        XCTAssertTrue(aviso.label.contains("Chegue mais perto"), aviso.label)
        // Cinco toques seguidos: nenhum gastou tentativa (senão a terceira já bloquearia).
        for _ in 0..<4 { tocar(confirmar) }
        XCTAssertTrue(app.descendants(matching: .any)["chegue-mais-perto"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["codigo-bloqueado-temporario"].exists, "o código nem foi enviado")
        XCTAssertFalse(app.descendants(matching: .any)["codigo-invalido"].exists)
    }

    func testSemAChaveOProfissionalNaoVeALeituraDoCodigo() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success", "-FRILA_LOCALIZACAO", "longe"]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: Espera.aparecer)
        tocar(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-'")).firstMatch)
        tocar(app.buttons["candidatar"])
        XCTAssertTrue(app.descendants(matching: .any)["resultado-confirmada"].waitForExistence(timeout: Espera.aparecer))
        tocar(app.buttons["voltar-para-lista"])
        tocar(app.tabBars.buttons["Meus turnos"])
        tocar(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'meu-turno-'")).firstMatch)
        fazerCheckinPendente(app, manual: true)
        XCTAssertTrue(app.descendants(matching: .any)["checkin-situacao"].waitForExistence(timeout: Espera.aparecer))
        XCTAssertFalse(app.buttons["ler-codigo-da-casa"].exists, "sem a chave, a presença espera a confirmação da casa, como hoje")
    }
}
