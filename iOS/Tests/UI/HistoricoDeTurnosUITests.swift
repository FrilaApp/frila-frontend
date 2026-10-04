import XCTest

/// Histórico e exportação de turnos (#23) contra o dublê do esquema Local.
@MainActor
final class HistoricoDeTurnosUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testProfissionalExportaCSVDesteMesEAbreCompartilhamento() {
        let app = abrir(cenario: "success", perfil: "abrir-meu-perfil", item: "perfil-historico-turnos")
        XCTAssertTrue(app.buttons["historico-este-mes"].isSelected, "Este mês é o período inicial")
        XCTAssertTrue(app.staticTexts["historico-resumo-periodo"].exists, "O período escolhido aparece por extenso")
        anexar(app, "historico-profissional")

        app.buttons["historico-exportar"].tap()

        XCTAssertTrue(folhaDeCompartilharApareceu(app), "O CSV vai para a folha de compartilhar")
        anexar(app, "historico-profissional-compartilhar")
    }

    func testContratanteExportaPDFDoMesPassadoEAbreCompartilhamento() {
        let app = abrir(cenario: "contratante", perfil: "abrir-perfil-estabelecimento", item: "estabelecimento-historico-turnos")
        app.buttons["historico-mes-passado"].tap()
        app.segmentedControls["historico-formato"].buttons["PDF"].tap()
        XCTAssertTrue(app.buttons["historico-mes-passado"].isSelected)
        anexar(app, "historico-contratante")

        app.buttons["historico-exportar"].tap()

        XCTAssertTrue(folhaDeCompartilharApareceu(app), "O PDF do estabelecimento vai para a folha de compartilhar")
        anexar(app, "historico-contratante-compartilhar")
    }

    func testPeriodoSemTurnosAvisaENaoAbreCompartilhamento() {
        let app = abrir(cenario: "exportar-turnos-sem-turnos", perfil: "abrir-meu-perfil", item: "perfil-historico-turnos")

        app.buttons["historico-exportar"].tap()

        let aviso = app.descendants(matching: .any)["historico-sem-turnos"]
        XCTAssertTrue(aviso.waitForExistence(timeout: 5), "O 204 mostra que o período não tem turnos")
        XCTAssertTrue(aviso.label.contains("Nenhum turno nesse período"))
        verificarAVista(aviso, app)
        XCTAssertFalse(app.otherElements["ActivityListView"].exists, "Sem turnos, nada vai para o compartilhar")
        XCTAssertFalse(app.navigationBars["UIActivityContentView"].exists)
        anexar(app, "historico-sem-turnos")

        // O aviso fala do pedido anterior: mudar o período o tira da tela.
        app.buttons["historico-mes-passado"].tap()
        XCTAssertFalse(aviso.exists)
    }

    func testErroDeRedeMostraMensagemETentarNovamente() {
        let app = abrir(cenario: "exportar-sem-rede", perfil: "abrir-meu-perfil", item: "perfil-historico-turnos")

        app.buttons["historico-exportar"].tap()

        let erro = app.descendants(matching: .any)["historico-erro"]
        XCTAssertTrue(erro.waitForExistence(timeout: 5), "Sem rede, a tela explica o erro")
        XCTAssertTrue(app.buttons["historico-tentar-novamente"].exists, "E oferece tentar de novo")
        verificarAVista(app.buttons["historico-tentar-novamente"], app)
        anexar(app, "historico-erro-de-rede")
    }

    func testIntervaloLivreNoMaiorTextoCabeNaTelaEExporta() {
        let app = abrir(
            cenario: "success", perfil: "abrir-meu-perfil", item: "perfil-historico-turnos",
            extras: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        )
        let largura = app.windows.firstMatch.frame.width
        for atalho in ["historico-este-mes", "historico-mes-passado", "historico-intervalo"] {
            XCTAssertLessThanOrEqual(app.buttons[atalho].frame.maxX, largura, "\(atalho) não pode sair da tela no maior texto")
        }

        app.buttons["historico-intervalo"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["historico-de"].waitForExistence(timeout: 5), "O intervalo livre mostra a data inicial")
        XCTAssertTrue(app.descendants(matching: .any)["historico-ate"].exists, "e a data final")
        anexar(app, "historico-intervalo-maior-texto")

        let exportar = app.buttons["historico-exportar"]
        app.swipeUp()
        XCTAssertTrue(exportar.isHittable, "Exportar continua alcançável no maior texto")
        exportar.tap()
        XCTAssertTrue(folhaDeCompartilharApareceu(app), "O intervalo livre também exporta")
    }

    /// O controle segmentado do sistema não acompanha o Dynamic Type: em AX5 os formatos viram
    /// pílulas que crescem com o texto (QA de 04/10, achado 4).
    func testEmAX5OFormatoViraPilulasQueCrescemComOTexto() {
        let app = abrir(
            cenario: "success", perfil: "abrir-meu-perfil", item: "perfil-historico-turnos",
            extras: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        )
        let csv = app.buttons["historico-formato-csv"]
        let pdf = app.buttons["historico-formato-pdf"]
        XCTAssertTrue(csv.waitForExistence(timeout: 5), "Em AX5 o formato aparece em pílulas")
        XCTAssertFalse(app.segmentedControls["historico-formato"].exists)
        XCTAssertTrue(csv.isSelected, "CSV é o formato inicial")
        for _ in 0..<6 where !pdf.isHittable { app.swipeUp() }

        pdf.tap()

        XCTAssertTrue(pdf.isSelected)
        XCTAssertFalse(csv.isSelected)
        XCTAssertGreaterThan(pdf.frame.height, 44 + 8, "Em AX5 a pílula cresce além do mínimo de 44 pt")
        anexar(app, "historico-formato-ax5")
    }

    private func abrir(cenario: String, perfil: String, item: String, extras: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", cenario] + extras
        app.launch()

        let botaoPerfil = app.buttons[perfil]
        XCTAssertTrue(botaoPerfil.waitForExistence(timeout: 10), "O botão do perfil deve estar visível")
        botaoPerfil.tap()

        let entrada = app.buttons[item]
        XCTAssertTrue(entrada.waitForExistence(timeout: 5), "O perfil deve ter a entrada do histórico de turnos")
        for _ in 0..<8 where !entrada.isHittable { app.swipeUp() }
        entrada.tap()

        XCTAssertTrue(app.buttons["historico-exportar"].waitForExistence(timeout: 5), "A tela do histórico abre com o botão Exportar")
        return app
    }

    /// `exists` não basta: no iPhone SE o resultado nasce abaixo da dobra, atrás da barra de abas, e
    /// a tela precisa rolar até ele. Espera a rolagem por até 3 s.
    private func verificarAVista(_ elemento: XCUIElement, _ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let barra = app.tabBars.firstMatch
        let limite = barra.exists ? barra.frame.minY : app.windows.firstMatch.frame.maxY
        let prazo = Date().addingTimeInterval(3)
        while elemento.frame.maxY > limite, Date() < prazo {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertLessThanOrEqual(elemento.frame.maxY, limite, "O resultado precisa ficar à vista, acima da barra de abas", file: file, line: line)
    }

    private func folhaDeCompartilharApareceu(_ app: XCUIApplication) -> Bool {
        app.otherElements["ActivityListView"].waitForExistence(timeout: 5)
            || app.navigationBars["UIActivityContentView"].waitForExistence(timeout: 5)
            || app.collectionViews.firstMatch.waitForExistence(timeout: 5)
            || app.sheets.firstMatch.waitForExistence(timeout: 5)
    }

    private func anexar(_ app: XCUIApplication, _ nome: String) {
        let anexo = XCTAttachment(screenshot: app.screenshot())
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)
    }
}
