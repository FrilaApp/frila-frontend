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

    private func conferirAcoes(_ app: XCUIApplication) {
        for (id, rotulo) in [("denunciar", "Denunciar"), ("bloquear", "Bloquear")] {
            let botao = app.buttons[id]
            trazerParaATela(botao, em: app)
            XCTAssertEqual(botao.label, rotulo)
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
}
