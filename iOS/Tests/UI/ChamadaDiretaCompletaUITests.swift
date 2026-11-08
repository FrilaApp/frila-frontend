import XCTest

/// Lotes 2 e 3 da conferência visual da 1.1: a chamada direta de ponta a ponta no dublê (V1
/// Acompanhar chamadas, V2 chamada recebida, V3 Preferências, V5 Chamar de novo no turno cumprido) e
/// o turno não verificado nos dois lados (V4, parte iOS da B6).
@MainActor
final class ChamadaDiretaCompletaUITests: XCTestCase {
    /// Os identificadores dos cartões levam o UUID como o Swift o escreve, em maiúsculas.
    private let vagaComChamadaAberta = "C1000000-0000-0000-0000-000000000002"
    private let vagaComChamadaRecusada = "C1000000-0000-0000-0000-000000000003"
    private let chamadaRecebida = "c2000000-0000-0000-0000-000000000001"
    private let turnoDoProfissional = "22000000-0000-0000-0000-000000000001"
    private let turnoDaCasa = "82000000-0000-0000-0000-000000000001"
    private let profissionalDoTurno = "80000000-0000-0000-0000-000000000001"

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
        for _ in 0..<10 {
            if elemento.exists, elemento.isHittable, elemento.frame.minY > 100, elemento.frame.maxY < altura - 40 { return }
            if elemento.exists, elemento.frame.minY <= 100 { app.swipeDown() } else { app.swipeUp() }
        }
    }

    private func abrirAcompanhar(vaga: String, em app: XCUIApplication) {
        let cartao = app.buttons["vaga-contratante-\(vaga)"]
        XCTAssertTrue(cartao.waitForExistence(timeout: 15), "a vaga direta aparece em Minhas vagas")
        rolarAte(cartao, em: app)
        cartao.tap()
        let acompanhar = app.buttons["acompanhar-chamadas-\(vaga)"]
        XCTAssertTrue(acompanhar.waitForExistence(timeout: 10), "a vaga direta leva a Acompanhar chamadas")
        rolarAte(acompanhar, em: app)
        acompanhar.tap()
        XCTAssertTrue(app.navigationBars["Acompanhar chamadas"].waitForExistence(timeout: 10))
    }

    // MARK: V1

    func testAcompanharCancelaAChamadaAberta() {
        let app = abrir(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "chamadas-enviadas"])
        abrirAcompanhar(vaga: vagaComChamadaAberta, em: app)

        let cancelar = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH[c] 'cancelar-chamada-'")).firstMatch
        XCTAssertTrue(cancelar.waitForExistence(timeout: 10), "a chamada aberta pode ser cancelada")
        XCTAssertFalse(app.buttons["publicar-para-todos-chamada"].exists, "com chamada aberta, ainda não se publica para todos")
        cancelar.tap()
        let confirmar = app.alerts.firstMatch.buttons["Confirmar cancelamento"]
        XCTAssertTrue(confirmar.waitForExistence(timeout: 5), "cancelar pede confirmação")
        confirmar.tap()
        XCTAssertFalse(cancelar.waitForExistence(timeout: 3), "cancelada, a chamada não oferece cancelar de novo")
    }

    func testAcompanharPublicaParaTodosQuandoNinguemAceitou() {
        let app = abrir(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "chamadas-enviadas"])
        abrirAcompanhar(vaga: vagaComChamadaRecusada, em: app)

        let publicar = app.buttons["publicar-para-todos-chamada"]
        rolarAte(publicar, em: app)
        XCTAssertTrue(publicar.waitForExistence(timeout: 10), "com a chamada recusada, a casa publica para todos (RN35)")
        publicar.tap()
        let verVaga = app.buttons["ver-vaga-aberta"]
        rolarAte(verVaga, em: app)
        XCTAssertTrue(verVaga.waitForExistence(timeout: 10), "publicada, a tela leva à vaga nova")
        XCTAssertFalse(app.buttons["publicar-para-todos-chamada"].exists, "publicar para todos vale uma vez só")

        // O Acompanhar é uma rota da pilha de Minhas vagas: "Ver vaga aberta" troca o caminho pela vaga nova.
        verVaga.tap()
        let detalhe = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'funcao-vaga-detalhe-'")).firstMatch
        XCTAssertTrue(detalhe.waitForExistence(timeout: 10), "o toque leva ao detalhe da vaga aberta para todos")
        XCTAssertFalse(detalhe.identifier.hasSuffix(vagaComChamadaRecusada), "é a vaga nova, não a vaga direta")
        XCTAssertFalse(app.navigationBars["Acompanhar chamadas"].exists)
    }

    // MARK: V11

    /// Enviada a chamada, a folha mostra o resumo, até quando o profissional responde e o caminho para
    /// acompanhar, onde a chamada recém-enviada aparece aberta (CD-RF09).
    func testChamadaEnviadaMostraResumoPrazoEAcompanhar() {
        let app = abrir(["-FRILA_ABRIR_EQUIPE_CONFIANCA", "-FRILA_SCENARIO", "chamada-direta"])
        let chamar = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'chamar-de-novo-'")).firstMatch
        XCTAssertTrue(chamar.waitForExistence(timeout: 15))
        rolarAte(chamar, em: app)
        chamar.tap()

        let valor = app.textFields["total-chamada-centavos"]
        XCTAssertTrue(valor.waitForExistence(timeout: 10))
        rolarAte(valor, em: app)
        valor.tap()
        valor.typeText("180")
        let ok = app.buttons.matching(NSPredicate(format: "label ==[c] 'ok'")).firstMatch
        if ok.exists { ok.tap() }
        let total = app.switches["confirmar-total-chamada"]
        rolarAte(total, em: app)
        total.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let enviar = app.buttons["enviar-chamada"]
        rolarAte(enviar, em: app)
        XCTAssertTrue(enviar.isEnabled, "com valor e total confirmado, a chamada sai")
        enviar.tap()

        let prazo = app.staticTexts["prazo-chamada-enviada"]
        XCTAssertTrue(prazo.waitForExistence(timeout: 10), "enviada, a folha diz até quando o profissional responde")
        XCTAssertTrue(prazo.label.hasPrefix("O profissional tem até "), prazo.label)
        let valorNoResumo = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '180,00'")).firstMatch
        XCTAssertTrue(valorNoResumo.exists, "o resumo mostra o valor combinado")
        XCTAssertFalse(app.buttons["enviar-chamada"].exists, "enviada, o formulário não volta")

        let acompanhar = app.buttons["acompanhar-chamada-enviada"]
        rolarAte(acompanhar, em: app)
        XCTAssertTrue(acompanhar.waitForExistence(timeout: 5), "a folha leva a Acompanhar chamadas")
        acompanhar.tap()
        XCTAssertTrue(app.navigationBars["Acompanhar chamadas"].waitForExistence(timeout: 10))
        let cancelar = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH[c] 'cancelar-chamada-'")).firstMatch
        XCTAssertTrue(cancelar.waitForExistence(timeout: 10), "a chamada recém-enviada aparece aberta, com Cancelar")
    }

    // MARK: V2, V3 e CD-RF12

    func testChamadaRecebidaMostraDetalheAceitarRecusarDenunciarEBloquear() {
        let app = abrir(["-FRILA_SCENARIO", "chamada-recebida", "-FRILA_PUSH", "chamada_recebida",
                         "-FRILA_PUSH_CHAMADA_ID", chamadaRecebida])
        let aceitar = app.buttons["aceitar-chamada"]
        rolarAte(aceitar, em: app)
        XCTAssertTrue(aceitar.waitForExistence(timeout: 15), "o toque no push abre a chamada recebida")
        XCTAssertTrue(app.buttons["recusar-chamada"].exists)

        let denunciar = app.buttons["denunciar-chamada"]
        rolarAte(denunciar, em: app)
        XCTAssertTrue(denunciar.exists, "CD-RF12: denunciar a partir da chamada")
        XCTAssertTrue(app.buttons["bloquear-chamada"].exists, "CD-RF12: bloquear a partir da chamada")

        app.buttons["bloquear-chamada"].tap()
        // O botão do alerta aparece duas vezes na árvore, como em SegurancaUITests.
        let confirmar = app.alerts.buttons["confirmar-bloqueio-chamada"].firstMatch
        XCTAssertTrue(confirmar.waitForExistence(timeout: 5), "bloquear pede confirmação")
        confirmar.tap()
        XCTAssertFalse(app.buttons["bloquear-chamada"].isEnabled, "bloqueada, a casa não é bloqueada de novo")
        XCTAssertTrue(app.descendants(matching: .any)["etiqueta-bloqueio-chamada"].waitForExistence(timeout: 5),
                      "a tela diz que a casa foi bloqueada")
        XCTAssertFalse(app.buttons["aceitar-chamada"].exists, "bloqueada, a chamada não se aceita mais (o servidor a encerra)")
        XCTAssertFalse(app.buttons["recusar-chamada"].exists)
    }

    /// Recusar não tira o direito de denunciar ou bloquear quem chamou (CD-RF12, CD-S13).
    func testDepoisDeRecusarDenunciarEBloquearContinuam() {
        let app = abrir(["-FRILA_SCENARIO", "chamada-recebida", "-FRILA_PUSH", "chamada_recebida",
                         "-FRILA_PUSH_CHAMADA_ID", chamadaRecebida])
        let recusar = app.buttons["recusar-chamada"]
        rolarAte(recusar, em: app)
        XCTAssertTrue(recusar.waitForExistence(timeout: 15))
        recusar.tap()
        let confirmar = app.buttons["confirmar-recusa-chamada"]
        XCTAssertTrue(confirmar.waitForExistence(timeout: 5), "recusar abre a folha com o motivo opcional")
        confirmar.tap()

        XCTAssertFalse(app.buttons["aceitar-chamada"].waitForExistence(timeout: 3), "recusada, a chamada não se responde de novo")
        let denunciar = app.buttons["denunciar-chamada"]
        rolarAte(denunciar, em: app)
        XCTAssertTrue(denunciar.waitForExistence(timeout: 5), "depois de recusar, ainda dá para denunciar")
        XCTAssertTrue(app.buttons["bloquear-chamada"].exists, "e para bloquear")
    }

    func testPreferenciasDeChamadaAparecemComAChaveLigada() {
        let app = abrir(["-FRILA_SCENARIO", "chamada-recebida"])
        let conta = app.tabBars.buttons["Conta"]
        XCTAssertTrue(conta.waitForExistence(timeout: 15))
        conta.tap()
        let preferencias = app.buttons["perfil-preferencias-chamada"]
        rolarAte(preferencias, em: app)
        XCTAssertTrue(preferencias.waitForExistence(timeout: 10), "com a chamada direta ligada, a Conta leva às Preferências (CD-RF10)")
        preferencias.tap()
        XCTAssertTrue(app.switches["toggle-receber-chamadas"].waitForExistence(timeout: 10))
    }

    // MARK: V5

    /// CD-RF07: "Chamar de novo" vale no turno cumprido. Com o relógio do dublê três dias atrás, o
    /// turno da casa já terminou de verdade, e o botão aparece ao lado do selo da equipe.
    func testChamarDeNovoApareceNoTurnoCumprido() {
        let tresDiasAtras = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3 * 86_400))
        let app = abrir(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "chamada-direta", "-FRILA_RELOGIO_AGORA", tresDiasAtras,
                         "-FRILA_AVISO", "confirmacao", "-FRILA_AVISO_ID", turnoDaCasa])
        let chamar = app.buttons["chamar-de-novo-\(profissionalDoTurno)"]
        rolarAte(chamar, em: app)
        XCTAssertTrue(chamar.waitForExistence(timeout: 15), "no turno cumprido e verificado, a casa pode chamar de novo")
    }

    // MARK: V4 e B6

    func testMeuTurnoDoProfissionalMostraTurnoNaoVerificado() {
        let app = abrir(["-FRILA_SCENARIO", "turno-nao-verificado", "-FRILA_PUSH", "turno_nao_verificado",
                         "-FRILA_PUSH_ID", turnoDoProfissional])
        let estado = app.staticTexts["estado-do-turno"]
        XCTAssertTrue(estado.waitForExistence(timeout: 15), "o aviso abre o Meu turno")
        XCTAssertEqual(estado.label, "Turno não verificado")
        let aviso = app.descendants(matching: .any)["presenca-nao-verificada"]
        rolarAte(aviso, em: app)
        XCTAssertTrue(aviso.exists, "a presença diz que ficou não verificada")
        XCTAssertTrue(aviso.label.contains("Presença não verificada"), aviso.label)
        XCTAssertFalse(app.buttons["botao-ver-avaliacao"].exists, "sem presença verificada não há avaliação (RN07)")
    }

    func testTurnoDaCasaMostraPresencaNaoVerificada() {
        let app = abrir(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "turno-nao-verificado-contratante",
                         "-FRILA_AVISO", "turno_nao_verificado", "-FRILA_AVISO_ID", turnoDaCasa])
        let presenca = app.staticTexts["Presença não verificada."]
        rolarAte(presenca, em: app)
        XCTAssertTrue(presenca.waitForExistence(timeout: 15), "o aviso abre o turno, que diz que a presença não foi verificada")
    }
}
