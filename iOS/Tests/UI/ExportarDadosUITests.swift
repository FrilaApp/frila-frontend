import XCTest

@MainActor
final class ExportarDadosUITests: XCTestCase {
    func testExportarMeusDadosNoPerfilProfissionalAbreCompartilhamento() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success"]
        app.launch()

        // 1. Abre a lista de vagas e navega para o perfil do profissional
        let botaoPerfil = app.buttons["abrir-meu-perfil"]
        XCTAssertTrue(botaoPerfil.waitForExistence(timeout: 10), "Botão de abrir perfil deve estar visível")
        botaoPerfil.tap()

        // 2. No perfil, localiza e toca no item "Exportar meus dados"
        let botaoExportar = app.buttons["perfil-exportar-dados"]
        XCTAssertTrue(botaoExportar.waitForExistence(timeout: 5), "Botão exportar dados deve existir no perfil")

        let explicacao = app.staticTexts["perfil-exportar-dados-explicacao"]
        XCTAssertTrue(explicacao.waitForExistence(timeout: 5), "Explicação do que vem no arquivo deve estar visível")

        anexar(app, "perfil-profissional-com-item-exportar")
        botaoExportar.tap()

        // 3. A folha de compartilhar do sistema aparece
        let apareceuCompartilhamento = app.otherElements["ActivityListView"].waitForExistence(timeout: 5)
            || app.navigationBars["UIActivityContentView"].waitForExistence(timeout: 5)
            || app.collectionViews.firstMatch.waitForExistence(timeout: 5)
            || app.sheets.firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(apareceuCompartilhamento, "A folha de compartilhamento deve aparecer após tocar em exportar dados")

        anexar(app, "perfil-profissional-folha-compartilhamento")
    }

    func testExportarMeusDadosNoPerfilEstabelecimentoAbreCompartilhamento() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "contratante"]
        app.launch()

        // 1. Abre o fluxo do contratante e navega para o perfil do estabelecimento
        let botaoPerfil = app.buttons["abrir-perfil-estabelecimento"]
        XCTAssertTrue(botaoPerfil.waitForExistence(timeout: 10), "Botão de perfil do estabelecimento deve estar visível")
        botaoPerfil.tap()

        // 2. No perfil do estabelecimento, localiza e toca no item "Exportar meus dados"
        let botaoExportar = app.buttons["estabelecimento-exportar-dados"]
        XCTAssertTrue(botaoExportar.waitForExistence(timeout: 5), "Botão exportar dados deve existir no estabelecimento")

        let explicacao = app.staticTexts["estabelecimento-exportar-dados-explicacao"]
        XCTAssertTrue(explicacao.waitForExistence(timeout: 5), "Explicação do que vem no arquivo deve estar visível no estabelecimento")

        anexar(app, "perfil-estabelecimento-com-item-exportar")
        botaoExportar.tap()

        // 3. A folha de compartilhar do sistema aparece
        let apareceuCompartilhamento = app.otherElements["ActivityListView"].waitForExistence(timeout: 5)
            || app.navigationBars["UIActivityContentView"].waitForExistence(timeout: 5)
            || app.collectionViews.firstMatch.waitForExistence(timeout: 5)
            || app.sheets.firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(apareceuCompartilhamento, "A folha de compartilhamento deve aparecer no perfil do estabelecimento")

        anexar(app, "perfil-estabelecimento-folha-compartilhamento")
    }

    private func anexar(_ app: XCUIApplication, _ nome: String) {
        let anexo = XCTAttachment(screenshot: app.screenshot())
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)
    }
}
