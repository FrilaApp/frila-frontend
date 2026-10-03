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

    private func alcançar(_ elemento: XCUIElement, app: XCUIApplication) {
        for _ in 0..<6 {
            if elemento.exists && elemento.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(elemento.isHittable)
    }

    private func conferirAcoes(_ app: XCUIApplication) {
        for (id, rotulo) in [("denunciar", "Denunciar"), ("bloquear", "Bloquear")] {
            let botao = app.buttons[id]
            alcançar(botao, app: app)
            XCTAssertEqual(botao.label, rotulo)
            XCTAssertTrue(botao.isEnabled)
            XCTAssertGreaterThanOrEqual(botao.frame.height, 44)
        }
    }

    func testDenunciaNoDetalheMostraEmergenciaProtocoloEPrazo() {
        let app = abrirVaga()
        conferirAcoes(app)
        app.buttons["denunciar"].tap()
        let enviar = app.buttons["enviar-denuncia"]
        XCTAssertTrue(enviar.waitForExistence(timeout: 5))
        XCTAssertFalse(enviar.isEnabled)
        app.buttons["motivo-denuncia"].tap()
        for motivo in ["Assédio", "Discriminação", "Risco à segurança", "Outro"] {
            XCTAssertTrue(app.buttons[motivo].waitForExistence(timeout: 3))
        }
        app.buttons["Risco à segurança"].tap()
        let aviso = app.staticTexts["aviso-risco-imediato"]
        XCTAssertTrue(aviso.waitForExistence(timeout: 5))
        XCTAssertTrue(aviso.label.contains("190 (Polícia Militar)"))
        XCTAssertTrue(aviso.label.contains("180 (Central de Atendimento à Mulher)"))
        let relato = app.descendants(matching: .any)["relato-denuncia"].firstMatch
        XCTAssertTrue(relato.waitForExistence(timeout: 5))
        relato.tap()
        relato.typeText("Relato de risco ocorrido no estabelecimento.")
        alcançar(enviar, app: app)
        enviar.tap()
        XCTAssertTrue(app.descendants(matching: .any)["protocolo-denuncia"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["prazo-denuncia"].exists)
    }

    func testBloqueioNoDetalheRemoveVagaSemReiniciar() {
        let app = abrirVaga()
        alcançar(app.buttons["bloquear"], app: app)
        app.buttons["bloquear"].tap()
        XCTAssertTrue(app.alerts.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Vocês não voltam a se cruzar'")).firstMatch.exists)
        app.alerts.buttons["Cancelar"].tap()
        XCTAssertTrue(app.buttons["bloquear"].exists)
        app.buttons["bloquear"].tap()
        app.alerts.buttons["confirmar-bloqueio"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["detalhe-nao-encontrada"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertFalse(app.buttons["vaga-40000000-0000-0000-0000-000000000001"].exists)
    }

    func testPerfilDoEstabelecimentoTemAcoesEViraIndisponivel() {
        let app = abrirVaga()
        let abrir = app.buttons["abrir-perfil-estabelecimento"]
        alcançar(abrir, app: app)
        abrir.tap()
        XCTAssertTrue(app.descendants(matching: .any)["perfil-publico-estabelecimento"].waitForExistence(timeout: 5))
        conferirAcoes(app)
        app.buttons["denunciar"].tap()
        XCTAssertTrue(app.buttons["enviar-denuncia"].waitForExistence(timeout: 5))
        app.buttons["Fechar"].tap()
        app.buttons["bloquear"].tap()
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
        XCTAssertTrue(app.buttons["enviar-denuncia"].waitForExistence(timeout: 5))
        app.buttons["Fechar"].tap()
        app.buttons["bloquear"].tap()
        app.alerts.buttons["confirmar-bloqueio"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["perfil-indisponivel"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertFalse(perfil.exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(vaga.waitForExistence(timeout: 5))
        XCTAssertFalse(vaga.label.contains("Ana Cunha"))
    }
}
