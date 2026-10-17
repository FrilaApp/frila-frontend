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

    private func capturarDurantePressao(elemento: XCUIElement, duracao: TimeInterval = 2.0, nome: String) {
        let exp = expectation(description: "captura-\(nome)")
        let pasta = Self.pastaCapturas
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.6) {
            let shot = XCUIScreen.main.screenshot()
            try? FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
            let destino = URL(fileURLWithPath: "\(pasta)/\(nome)")
            try? shot.pngRepresentation.write(to: destino)
            exp.fulfill()
        }
        elemento.press(forDuration: duracao)
        wait(for: [exp], timeout: duracao + 3.0)
    }

    func testCapturasToqueTatilEPressao() {
        executarCapturasToque(tamanho: Self.padrao, modoEscuro: false, sufixo: "padrao-claro")
        executarCapturasToque(tamanho: Self.padrao, modoEscuro: true, sufixo: "padrao-escuro")
        executarCapturasToque(tamanho: Self.ax5, modoEscuro: false, sufixo: "ax5-claro")
        executarCapturasToque(tamanho: Self.ax5, modoEscuro: true, sufixo: "ax5-escuro")
    }

    private func executarCapturasToque(tamanho: String, modoEscuro: Bool, sufixo: String) {
        let app = abrirCatalogo(tamanho: tamanho, modoEscuro: modoEscuro)
        let secaoTatil = app.descendants(matching: .any)["secao-toque-tatil"]
        _ = secaoTatil.waitForExistence(timeout: 5)

        // 1. Captura da visão geral / comparação normal
        let shotNormal = app.screenshot()
        salvarCaptura(shotNormal, nome: "botao-chip-pressionados-\(sufixo).png")

        // 2. Captura com o botão de fato pressionado (compressão tátil ativa)
        let botao = app.buttons["Continuar"].firstMatch
        if botao.waitForExistence(timeout: 5) {
            capturarDurantePressao(elemento: botao, nome: "botao-pressionado-\(sufixo).png")
        }

        // 3. Captura com o chip de fato pressionado (compressão tátil ativa)
        let chip = app.buttons["Perto de mim"].firstMatch
        if chip.waitForExistence(timeout: 5) {
            capturarDurantePressao(elemento: chip, nome: "chip-pressionado-\(sufixo).png")
        }
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
