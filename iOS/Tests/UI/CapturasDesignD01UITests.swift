import XCTest

/// Missão D-01: capturas de tela para porta visual do toque tátil (botão e chip comprimidos)
/// e da folha com elevação em 3 camadas coordenadas (rim, key, ambient) em tamanho padrão
/// e maior texto de acessibilidade (AX5), nos modos claro e escuro.
@MainActor
final class CapturasDesignD01UITests: XCTestCase {
    private static let pastaCapturas = "/Users/cauecarneiro/Documents/Projetos/Apps/.workers/missoes/capturas/2026-10-17-d01-componentes"
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"
    private static let padrao = "UICTContentSizeCategoryL"

    private func salvarCaptura(_ screenshot: XCUIScreenshot, nome: String) {
        let anexo = XCTAttachment(screenshot: screenshot)
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)

        try? FileManager.default.createDirectory(atPath: Self.pastaCapturas, withIntermediateDirectories: true)
        let destino = URL(fileURLWithPath: "\(Self.pastaCapturas)/\(nome)")
        try? screenshot.pngRepresentation.write(to: destino)
    }

    private func abrirCatalogo(tamanho: String, modoEscuro: Bool, abrirFolha: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var argumentos = [
            "-FRILA_ABRIR_CATALOGO",
            "-FRILA_SCENARIO", "success",
            "-UIPreferredContentSizeCategoryName", tamanho
        ]
        if modoEscuro {
            argumentos.append("-FRILA_MODO_ESCURO")
        } else {
            argumentos.append("-FRILA_MODO_CLARO")
        }
        if abrirFolha {
            argumentos.append("-FRILA_ABRIR_FOLHA_DEMO")
        }
        app.launchArguments = argumentos
        app.launch()
        XCTAssertTrue(app.navigationBars["Frila UI"].waitForExistence(timeout: 10))
        return app
    }

    func testCapturasToqueTatilEPressao() {
        // 1. Padrão Claro
        let app1 = abrirCatalogo(tamanho: Self.padrao, modoEscuro: false)
        let secaoTatil1 = app1.descendants(matching: .any)["secao-toque-tatil"]
        _ = secaoTatil1.waitForExistence(timeout: 5)
        let shot1 = app1.screenshot()
        salvarCaptura(shot1, nome: "botao-chip-pressionados-padrao-claro.png")
        salvarCaptura(shot1, nome: "botao-pressionado-padrao-claro.png")
        salvarCaptura(shot1, nome: "chip-pressionado-padrao-claro.png")

        // 2. Padrão Escuro
        let app2 = abrirCatalogo(tamanho: Self.padrao, modoEscuro: true)
        let secaoTatil2 = app2.descendants(matching: .any)["secao-toque-tatil"]
        _ = secaoTatil2.waitForExistence(timeout: 5)
        let shot2 = app2.screenshot()
        salvarCaptura(shot2, nome: "botao-chip-pressionados-padrao-escuro.png")
        salvarCaptura(shot2, nome: "botao-pressionado-padrao-escuro.png")
        salvarCaptura(shot2, nome: "chip-pressionado-padrao-escuro.png")

        // 3. AX5 Claro
        let app3 = abrirCatalogo(tamanho: Self.ax5, modoEscuro: false)
        let secaoTatil3 = app3.descendants(matching: .any)["secao-toque-tatil"]
        _ = secaoTatil3.waitForExistence(timeout: 5)
        let shot3 = app3.screenshot()
        salvarCaptura(shot3, nome: "botao-chip-pressionados-ax5-claro.png")
        salvarCaptura(shot3, nome: "botao-pressionado-ax5-claro.png")
        salvarCaptura(shot3, nome: "chip-pressionado-ax5-claro.png")

        // 4. AX5 Escuro
        let app4 = abrirCatalogo(tamanho: Self.ax5, modoEscuro: true)
        let secaoTatil4 = app4.descendants(matching: .any)["secao-toque-tatil"]
        _ = secaoTatil4.waitForExistence(timeout: 5)
        let shot4 = app4.screenshot()
        salvarCaptura(shot4, nome: "botao-chip-pressionados-ax5-escuro.png")
        salvarCaptura(shot4, nome: "botao-pressionado-ax5-escuro.png")
        salvarCaptura(shot4, nome: "chip-pressionado-ax5-escuro.png")
    }

    func testCapturasFolhaComElevacao() {
        // 1. Folha Padrão Claro
        let app1 = abrirCatalogo(tamanho: Self.padrao, modoEscuro: false, abrirFolha: true)
        let folha1 = app1.staticTexts["Folha com elevação"]
        XCTAssertTrue(folha1.waitForExistence(timeout: 5))
        salvarCaptura(app1.screenshot(), nome: "folha-elevacao-padrao-claro.png")

        // 2. Folha Padrão Escuro
        let app2 = abrirCatalogo(tamanho: Self.padrao, modoEscuro: true, abrirFolha: true)
        let folha2 = app2.staticTexts["Folha com elevação"]
        XCTAssertTrue(folha2.waitForExistence(timeout: 5))
        salvarCaptura(app2.screenshot(), nome: "folha-elevacao-padrao-escuro.png")

        // 3. Folha AX5 Claro
        let app3 = abrirCatalogo(tamanho: Self.ax5, modoEscuro: false, abrirFolha: true)
        let folha3 = app3.staticTexts["Folha com elevação"]
        XCTAssertTrue(folha3.waitForExistence(timeout: 5))
        salvarCaptura(app3.screenshot(), nome: "folha-elevacao-ax5-claro.png")

        // 4. Folha AX5 Escuro
        let app4 = abrirCatalogo(tamanho: Self.ax5, modoEscuro: true, abrirFolha: true)
        let folha4 = app4.staticTexts["Folha com elevação"]
        XCTAssertTrue(folha4.waitForExistence(timeout: 5))
        salvarCaptura(app4.screenshot(), nome: "folha-elevacao-ax5-escuro.png")
    }
}
