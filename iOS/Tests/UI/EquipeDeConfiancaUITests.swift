import XCTest

/// Equipe de confiança do estabelecimento (#24): incluir a partir do turno cumprido, listar e remover.
@MainActor
final class EquipeDeConfiancaUITests: XCTestCase {
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"
    private let vagaID = "40000000-0000-0000-0000-000000000001"
    private let turnoID = "82000000-0000-0000-0000-000000000001"
    private let posicaoID = "82000000-0000-0000-0000-000000000002"
    private let profissionalID = "80000000-0000-0000-0000-000000000001"

    private func rolarAte(_ elemento: XCUIElement, em app: XCUIApplication) {
        for _ in 0..<8 where !elemento.isHittable { app.swipeUp() }
    }

    /// Abre a tela da equipe a partir do perfil do estabelecimento.
    private func abrirEquipe(cenario: String, argumentos: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", cenario] + argumentos
        app.launch()

        let perfil = app.buttons["abrir-perfil-estabelecimento"]
        XCTAssertTrue(perfil.waitForExistence(timeout: 10))
        perfil.tap()

        let equipe = app.buttons["estabelecimento-equipe-de-confianca"]
        XCTAssertTrue(equipe.waitForExistence(timeout: 5))
        rolarAte(equipe, em: app)
        equipe.tap()
        XCTAssertTrue(app.navigationBars["Equipe de confiança"].waitForExistence(timeout: 5))
        return app
    }

    /// Critério 5: o botão aparece no turno com presença verificada, e incluir muda para "na equipe".
    func testIncluiNaEquipePeloTurnoCumprido() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "painel-contratante"]
        app.launch()

        let vaga = app.buttons["vaga-contratante-\(vagaID)"]
        XCTAssertTrue(vaga.waitForExistence(timeout: 10))
        vaga.tap()
        let acompanhar = app.buttons["acompanhar-turno-\(turnoID)"]
        XCTAssertTrue(acompanhar.waitForExistence(timeout: 5))
        rolarAte(acompanhar, em: app)
        acompanhar.tap()

        let incluir = app.buttons["incluir-na-equipe-\(posicaoID)"]
        XCTAssertTrue(incluir.waitForExistence(timeout: 10), "o turno verificado deve oferecer Incluir na equipe")
        rolarAte(incluir, em: app)
        incluir.tap()

        let naEquipe = app.descendants(matching: .any)["na-equipe-incluir-na-equipe-\(posicaoID)"]
        XCTAssertTrue(naEquipe.waitForExistence(timeout: 5), "depois de incluir, o profissional aparece como na equipe")
        XCTAssertFalse(incluir.exists)
    }

    /// Sem presença verificada, o botão não aparece (o servidor recusaria com sem_turno_cumprido).
    func testTurnoSemPresencaVerificadaNaoOfereceIncluir() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "checkin-manual-pendente"]
        app.launch()

        let acompanhar = app.buttons["acompanhar-turno-\(turnoID)"]
        XCTAssertTrue(acompanhar.waitForExistence(timeout: 15))
        acompanhar.tap()
        XCTAssertTrue(app.staticTexts["Chegada"].waitForExistence(timeout: 5))
        let denunciar = app.buttons["denunciar-\(posicaoID)"]
        rolarAte(denunciar, em: app)
        XCTAssertTrue(denunciar.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["incluir-na-equipe-\(posicaoID)"].exists)
    }

    /// Critério 4: a tela lista a equipe e remove com confirmação, até o estado vazio.
    func testListaERemoveComConfirmacao() {
        let app = abrirEquipe(cenario: "equipe-de-confianca-com-membro")

        let membro = app.descendants(matching: .any)["membro-da-equipe-\(profissionalID)"]
        XCTAssertTrue(membro.waitForExistence(timeout: 5), "a equipe deve listar o profissional")
        XCTAssertTrue(app.staticTexts["Ana Cunha"].exists)

        let remover = app.buttons["remover-da-equipe-\(profissionalID)"]
        rolarAte(remover, em: app)
        XCTAssertTrue(remover.waitForExistence(timeout: 5))
        remover.tap()

        let alerta = app.alerts.firstMatch
        XCTAssertTrue(alerta.waitForExistence(timeout: 5), "remover pede confirmação")
        alerta.buttons["Cancelar"].tap()
        XCTAssertTrue(membro.exists, "cancelar conserva o membro")

        remover.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.buttons["confirmar-remocao"].firstMatch.tap()

        XCTAssertTrue(app.descendants(matching: .any)["equipe-vazia"].waitForExistence(timeout: 5), "sem membros, a tela mostra o estado vazio")
        XCTAssertFalse(membro.exists)
    }

    func testEquipeVaziaMostraOrientacao() {
        let app = abrirEquipe(cenario: "contratante")
        XCTAssertTrue(app.descendants(matching: .any)["equipe-vazia"].waitForExistence(timeout: 5))
    }

    /// Em AX5 nada corta nem some: o membro, o botão Remover tocável com o alvo mínimo e a confirmação.
    func testEmAX5RemoverFicaTocavel() {
        let app = abrirEquipe(cenario: "equipe-de-confianca-com-membro", argumentos: ["-UIPreferredContentSizeCategoryName", Self.ax5])

        let membro = app.descendants(matching: .any)["membro-da-equipe-\(profissionalID)"]
        XCTAssertTrue(membro.waitForExistence(timeout: 5))
        let remover = app.buttons["remover-da-equipe-\(profissionalID)"]
        rolarAte(remover, em: app)
        XCTAssertTrue(remover.isHittable, "Remover deve ficar tocável em AX5")
        XCTAssertAlvoMinimo(remover.frame.height)
        remover.tap()
        let alerta = app.alerts.firstMatch
        XCTAssertTrue(alerta.waitForExistence(timeout: 5))
        XCTAssertTrue(alerta.buttons["Cancelar"].isHittable)
        alerta.buttons["Cancelar"].tap()
    }
}
