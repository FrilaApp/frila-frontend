import XCTest

@MainActor
final class SegurancaUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private func abrirVaga() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR"]
        app.launch()
        let vaga = app.buttons["vaga-40000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(vaga.waitForExistence(timeout: 10))
        vaga.tap()
        XCTAssertTrue(app.descendants(matching: .any)["tela-detalhe-vaga"].waitForExistence(timeout: 5))
        return app
    }

    private func trazerParaATela(_ elemento: XCUIElement, em app: XCUIApplication, tentativas: Int = 8) {
        let janela = app.windows.firstMatch.frame
        let margemSuperior: CGFloat = 120
        let margemInferior: CGFloat = 60

        for _ in 0..<tentativas {
            guard elemento.exists else {
                app.swipeUp(velocity: .slow)
                continue
            }
            let quadro = elemento.frame
            let direcao = direcaoParaTrazerParaATela(
                quadro: quadro,
                alturaJanela: janela.height,
                margemSuperior: margemSuperior,
                margemInferior: margemInferior,
                isHittable: elemento.isHittable
            )
            switch direcao {
            case .nenhuma:
                break
            case .rolarParaBaixo:
                app.swipeDown(velocity: .slow)
            case .rolarParaCima:
                app.swipeUp(velocity: .slow)
            }
            if direcao == .nenhuma { break }
        }
        XCTAssertTrue(elemento.exists)
    }

    private func conferirAcoes(
        _ app: XCUIApplication,
        idDenunciar: String = "denunciar",
        idBloquear: String = "bloquear",
        nomeEsperado: String? = nil
    ) {
        for (id, rotulo) in [(idDenunciar, "Denunciar"), (idBloquear, "Bloquear")] {
            let botao = app.buttons[id]
            trazerParaATela(botao, em: app)
            if let nomeEsperado {
                XCTAssertEqual(botao.label, "\(rotulo) \(nomeEsperado)")
            } else {
                XCTAssertTrue(botao.label.hasPrefix(rotulo))
            }
            XCTAssertTrue(botao.isEnabled)
            XCTAssertGreaterThanOrEqual(botao.frame.height, 44 - 0.1)
        }
    }

    func testDenunciaNoDetalheMostraEmergenciaProtocoloEPrazo() {
        let app = abrirVaga()
        conferirAcoes(app)
        app.buttons["denunciar"].tap()
        let enviar = app.buttons["enviar-denuncia"]
        trazerParaATela(enviar, em: app)
        XCTAssertFalse(enviar.isEnabled)
        let motivo = app.buttons["motivo-denuncia"]
        trazerParaATela(motivo, em: app)
        motivo.tap()
        for opcao in ["Assédio", "Discriminação", "Risco à segurança", "Outro"] {
            XCTAssertTrue(app.buttons[opcao].waitForExistence(timeout: 3))
        }
        app.buttons["Risco à segurança"].tap()
        let aviso = app.staticTexts["aviso-risco-imediato"]
        trazerParaATela(aviso, em: app)
        XCTAssertTrue(aviso.label.contains("190 (Polícia Militar)"))
        XCTAssertTrue(aviso.label.contains("180 (Central de Atendimento à Mulher)"))
        let relato = app.descendants(matching: .any)["relato-denuncia"].firstMatch
        trazerParaATela(relato, em: app)
        relato.tap()
        relato.typeText("Relato de risco ocorrido no estabelecimento.")
        trazerParaATela(enviar, em: app)
        enviar.tap()
        XCTAssertTrue(app.descendants(matching: .any)["protocolo-denuncia"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["prazo-denuncia"].exists)
    }

    func testBloqueioNoDetalheRemoveVagaSemReiniciar() {
        let app = abrirVaga()
        let bloquear = app.buttons["bloquear"]
        trazerParaATela(bloquear, em: app)
        bloquear.tap()
        XCTAssertTrue(app.alerts.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Vocês não voltam a se cruzar'")).firstMatch.exists)
        app.alerts.buttons["Cancelar"].tap()
        XCTAssertTrue(bloquear.exists)
        bloquear.tap()
        app.alerts.buttons["confirmar-bloqueio"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["detalhe-nao-encontrada"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertFalse(app.buttons["vaga-40000000-0000-0000-0000-000000000001"].exists)
    }

    func testPerfilDoEstabelecimentoTemAcoesEViraIndisponivel() {
        let app = abrirVaga()
        let abrir = app.buttons["abrir-perfil-estabelecimento"]
        trazerParaATela(abrir, em: app)
        abrir.tap()
        XCTAssertTrue(app.descendants(matching: .any)["perfil-publico-estabelecimento"].waitForExistence(timeout: 5))
        conferirAcoes(app)
        app.buttons["denunciar"].tap()
        let enviar = app.buttons["enviar-denuncia"]
        trazerParaATela(enviar, em: app)
        app.buttons["Fechar"].tap()
        let bloquear = app.buttons["bloquear"]
        trazerParaATela(bloquear, em: app)
        bloquear.tap()
        app.alerts.buttons["confirmar-bloqueio"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["perfil-indisponivel"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["denunciar"].exists)
    }

    func testPerfilDoConfirmadoTemAcoesEFiltraNomeAoVoltar() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "painel-contratante"]
        app.launch()
        let vaga = app.buttons["vaga-contratante-40000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(vaga.waitForExistence(timeout: 10))
        vaga.tap()
        let perfil = app.buttons["perfil-publico-82000000-0000-0000-0000-000000000002"]
        XCTAssertTrue(perfil.waitForExistence(timeout: 5))
        perfil.tap()
        conferirAcoes(app)
        app.buttons["denunciar"].tap()
        let enviar = app.buttons["enviar-denuncia"]
        trazerParaATela(enviar, em: app)
        app.buttons["Fechar"].tap()
        let bloquear = app.buttons["bloquear"]
        trazerParaATela(bloquear, em: app)
        bloquear.tap()
        app.alerts.buttons["confirmar-bloqueio"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["perfil-indisponivel"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertFalse(perfil.exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(vaga.waitForExistence(timeout: 5))
        XCTAssertFalse(vaga.label.contains("Ana Cunha"))
    }

    func testMeuTurnoDenunciaMostraProtocoloEPrazoEBloqueioComConfirmacao() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_SCENARIO", "turno-confirmado-perto",
            "-FRILA_CACHE_VAZIO_UI_TEST",
            "-AppleLanguages", "(pt-BR)",
            "-AppleLocale", "pt_BR"
        ]
        app.launch()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Meus turnos"].tap()
        let turno = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'meu-turno-'")).firstMatch
        XCTAssertTrue(turno.waitForExistence(timeout: 10))
        turno.tap()
        XCTAssertTrue(app.descendants(matching: .any)["tela-meu-turno"].waitForExistence(timeout: 10))

        conferirAcoes(app, nomeEsperado: "Bistrô Ipê")

        app.buttons["denunciar"].tap()
        let enviar = app.buttons["enviar-denuncia"]
        trazerParaATela(enviar, em: app)
        XCTAssertFalse(enviar.isEnabled)

        let motivo = app.buttons["motivo-denuncia"]
        trazerParaATela(motivo, em: app)
        motivo.tap()
        app.buttons["Risco à segurança"].tap()
        let aviso = app.staticTexts["aviso-risco-imediato"]
        trazerParaATela(aviso, em: app)
        XCTAssertTrue(aviso.label.contains("190 (Polícia Militar)"))

        let relato = app.descendants(matching: .any)["relato-denuncia"].firstMatch
        trazerParaATela(relato, em: app)
        relato.tap()
        let recolherTeclado = app.buttons["recolher-teclado"]
        if recolherTeclado.waitForExistence(timeout: 2) {
            XCTAssertTrue(recolherTeclado.isHittable)
        }
        relato.typeText("Relato de incidente durante o turno.")
        XCTAssertTrue(enviar.isHittable)
        enviar.tap()
        XCTAssertTrue(app.descendants(matching: .any)["protocolo-denuncia"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["prazo-denuncia"].exists)
        app.buttons["Fechar"].tap()

        let bloquear = app.buttons["bloquear"]
        trazerParaATela(bloquear, em: app)
        bloquear.tap()
        XCTAssertTrue(app.alerts.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Vocês não voltam a se cruzar'")).firstMatch.exists)
        app.alerts.buttons["Cancelar"].tap()
        XCTAssertTrue(bloquear.isEnabled)

        bloquear.tap()
        app.alerts.buttons["confirmar-bloqueio"].firstMatch.tap()
        trazerParaATela(bloquear, em: app)
        XCTAssertFalse(bloquear.isEnabled)
        XCTAssertTrue(app.staticTexts["etiqueta-bloqueio-turno"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["tela-meu-turno"].exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(turno.waitForExistence(timeout: 5))
    }

    func testTurnoDoContratanteDenunciaMostraProtocoloEPrazoEBloqueioComConfirmacao() {
        let app = XCUIApplication()
        let vagaID = "40000000-0000-0000-0000-000000000001"
        let turnoID = "82000000-0000-0000-0000-000000000001"
        let posicaoID = "82000000-0000-0000-0000-000000000002"
        app.launchArguments = [
            "-FRILA_ABRIR_MINHAS_VAGAS",
            "-FRILA_SCENARIO", "checkin-confirmado",
            "-AppleLanguages", "(pt-BR)",
            "-AppleLocale", "pt_BR"
        ]
        app.launch()

        let vaga = app.buttons["vaga-contratante-\(vagaID)"]
        XCTAssertTrue(vaga.waitForExistence(timeout: 15))
        vaga.tap()

        let botaoAcompanhar = app.buttons["acompanhar-turno-\(turnoID)"]
        trazerParaATela(botaoAcompanhar, em: app)
        XCTAssertTrue(botaoAcompanhar.waitForExistence(timeout: 5))
        botaoAcompanhar.tap()

        XCTAssertTrue(app.descendants(matching: .any)["turno-do-contratante"].waitForExistence(timeout: 10))

        let idDenunciar = "denunciar-\(posicaoID)"
        let idBloquear = "bloquear-\(posicaoID)"
        conferirAcoes(app, idDenunciar: idDenunciar, idBloquear: idBloquear, nomeEsperado: "Ana Cunha")

        app.buttons[idDenunciar].tap()
        let enviar = app.buttons["enviar-denuncia"]
        trazerParaATela(enviar, em: app)
        XCTAssertFalse(enviar.isEnabled)

        let relato = app.descendants(matching: .any)["relato-denuncia"].firstMatch
        trazerParaATela(relato, em: app)
        relato.tap()
        let recolherTeclado = app.buttons["recolher-teclado"]
        if recolherTeclado.waitForExistence(timeout: 2) {
            XCTAssertTrue(recolherTeclado.isHittable)
        }
        relato.typeText("Relato de conduta durante o atendimento.")
        XCTAssertTrue(enviar.isHittable)
        enviar.tap()
        XCTAssertTrue(app.descendants(matching: .any)["protocolo-denuncia"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["prazo-denuncia"].exists)
        app.buttons["Fechar"].tap()

        let bloquear = app.buttons[idBloquear]
        trazerParaATela(bloquear, em: app)
        bloquear.tap()
        XCTAssertTrue(app.alerts.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Vocês não voltam a se cruzar'")).firstMatch.exists)
        app.alerts.buttons["Cancelar"].tap()
        XCTAssertTrue(bloquear.isEnabled)

        bloquear.tap()
        app.alerts.buttons["confirmar-bloqueio"].firstMatch.tap()
        trazerParaATela(bloquear, em: app)
        XCTAssertFalse(bloquear.isEnabled)
        XCTAssertTrue(app.staticTexts["etiqueta-bloqueio-\(posicaoID)"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["turno-do-contratante"].exists)

        // Volta ao detalhe da vaga: a posição confirmada continua inteira (acompanhar e cancelar)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.descendants(matching: .any)["detalhe-vaga-contratante"].waitForExistence(timeout: 5))
        let botaoAcompanharVolta = app.buttons["acompanhar-turno-\(turnoID)"]
        trazerParaATela(botaoAcompanharVolta, em: app)
        XCTAssertTrue(botaoAcompanharVolta.exists)
        let botaoCancelar = app.buttons["cancelar-posicao-\(posicaoID)"]
        trazerParaATela(botaoCancelar, em: app)
        XCTAssertTrue(botaoCancelar.exists)
        XCTAssertTrue(app.staticTexts["etiqueta-bloqueio-\(posicaoID)"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["posicao-bloqueada-\(posicaoID)"].exists)

        // Volta para a lista de Minhas vagas
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(vaga.waitForExistence(timeout: 5))
        XCTAssertFalse(vaga.label.contains("Ana Cunha"))
    }
}
