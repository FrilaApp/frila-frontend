import XCTest

@MainActor
final class ServicosDoProfissionalUITests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }

    private func abrir(_ cenario: String = "perfil-rico-habilitado", ax5: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", cenario, "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR"]
        if ax5 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Conta"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Conta"].tap()
        tocar(app.buttons["perfil-funcoes-horarios"], app)
        tocar(app.buttons["editar-servicos"], app)
        XCTAssertTrue(app.buttons["salvar-servicos"].waitForExistence(timeout: 15))
        return app
    }

    private func tocar(_ elemento: XCUIElement, _ app: XCUIApplication) {
        XCTAssertTrue(elemento.waitForExistence(timeout: 10))
        for _ in 0..<12 {
            let quadro = elemento.frame
            let topo = app.navigationBars.firstMatch.frame.maxY
            let base = app.tabBars.firstMatch.frame.minY
            if elemento.isHittable, quadro.minY >= topo, quadro.maxY <= base { break }
            if quadro.minY < topo { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(elemento.isHittable)
        elemento.tap()
    }

    func testDiariaSalvaERetornaComPrecoEEspecialidade() {
        let app = abrir()
        XCTAssertEqual(app.textFields["valor-servico"].value as? String, "180,00")
        XCTAssertEqual(app.textFields["horas-servico"].value as? String, "8")
        let captura = XCTAttachment(screenshot: app.screenshot())
        captura.name = "servicos-diaria-padrao"; captura.lifetime = .keepAlways
        add(captura)
        tocar(app.switches["Buffet"], app)
        XCTAssertEqual(app.switches["Buffet"].value as? String, "1")
        tocar(app.buttons["salvar-servicos"], app)
        XCTAssertTrue(app.staticTexts["servicos-sucesso"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tocar(app.buttons["editar-servicos"], app)
        XCTAssertEqual(app.textFields["valor-servico"].value as? String, "180,00")
        XCTAssertEqual(app.switches["Buffet"].value as? String, "1")
    }

    func testACombinarSalvaSemPreco() {
        let app = abrir()
        tocar(app.buttons["unidade-servico"], app)
        app.buttons["A combinar"].tap()
        XCTAssertFalse(app.textFields["valor-servico"].exists)
        tocar(app.buttons["salvar-servicos"], app)
        XCTAssertTrue(app.staticTexts["servicos-sucesso"].waitForExistence(timeout: 10))
    }

    func testLimitaEspecialidadesA8SemOferecerInativasOuDeOutraFuncao() {
        let app = abrir()
        let nomes = ["Serviço à francesa", "Serviço à inglesa", "Buffet", "Eventos corporativos", "Casamentos", "Coquetéis", "Café da manhã", "Recepção"]
        for nome in nomes { tocar(app.switches[nome], app) }
        XCTAssertFalse(app.switches["Serviço volante"].isEnabled)
        XCTAssertFalse(app.switches["Especialidade desativada"].exists)
        XCTAssertFalse(app.switches["Coquetelaria"].exists)
        tocar(app.buttons["salvar-servicos"], app)
        XCTAssertTrue(app.staticTexts["servicos-sucesso"].waitForExistence(timeout: 10))
    }

    func testServicosOpcionaisPermitemContinuarNasVagas() {
        let app = abrir("servicos-vazios")
        XCTAssertFalse(app.textFields["valor-servico"].exists)
        tocar(app.buttons["salvar-servicos"], app)
        XCTAssertTrue(app.staticTexts["servicos-sucesso"].waitForExistence(timeout: 10))
        app.tabBars.buttons["briefcase"].tap()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
    }

    func testRecusaDeInclusosMantemTextoEIndicaCampo() {
        let app = abrir("servicos-inclusos-recusados")
        let campo = app.descendants(matching: .any).matching(identifier: "inclui-servico").firstMatch
        tocar(campo, app)
        campo.typeText("Texto sintetico para recusa")
        tocar(app.buttons["salvar-servicos"], app)
        XCTAssertTrue(app.staticTexts["erro-servico-inclui"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["servicos-sucesso"].exists)
        XCTAssertEqual(campo.value as? String, "Texto sintetico para recusa")
    }

    func testEditorEmAX5MantemSalvarAcessivel() {
        let app = abrir(ax5: true)
        tocar(app.buttons["salvar-servicos"], app)
        XCTAssertTrue(app.staticTexts["servicos-sucesso"].waitForExistence(timeout: 10))
        let captura = XCTAttachment(screenshot: app.screenshot())
        captura.name = "servicos-ax5"; captura.lifetime = .keepAlways
        add(captura)
    }
}
