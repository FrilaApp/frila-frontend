import XCTest

/// Conta > Aparência: Claro é o padrão, Escuro é escolha da pessoa, vale na hora e fica no aparelho.
@MainActor
final class AparenciaUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func abrirAparencia(argumentos: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success", "-FRILA_ABA_CONTA"] + argumentos
        app.launch()
        let linha = app.buttons["perfil-aparencia"]
        for _ in 0..<8 where !linha.exists || !linha.isHittable { app.swipeUp() }
        tocar(linha)
        XCTAssertTrue(app.otherElements["tela-aparencia"].waitForExistence(timeout: Espera.aparecer)
            || app.buttons["aparencia-claro"].waitForExistence(timeout: Espera.aparecer))
        return app
    }

    /// A preferência fica no `UserDefaults` do app, que sobrevive entre testes: devolve o claro.
    private func voltarAoClaroAoFinal() {
        addTeardownBlock { @MainActor in
            let app = self.abrirAparencia()
            if !app.buttons["aparencia-claro"].isSelected { tocar(app.buttons["aparencia-claro"]) }
            app.terminate()
        }
    }

    private func anexarCaptura(_ app: XCUIApplication, nome: String) {
        Thread.sleep(forTimeInterval: 1)
        let anexo = XCTAttachment(screenshot: app.screenshot())
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)
    }

    func testPadraoEClaroEEscuroVaiNaHoraEFicaDepoisDeReabrir() {
        voltarAoClaroAoFinal()
        let app = abrirAparencia()
        let claro = app.buttons["aparencia-claro"]
        let escuro = app.buttons["aparencia-escuro"]
        XCTAssertTrue(claro.isSelected, "Claro é o padrão")
        XCTAssertFalse(escuro.isSelected)
        XCTAssertGreaterThanOrEqual(claro.frame.height, 44)
        XCTAssertGreaterThanOrEqual(escuro.frame.height, 44)

        anexarCaptura(app, nome: "1-antes-claro")
        tocar(escuro)
        XCTAssertTrue(escuro.isSelected, "Trocar vale na hora, sem reiniciar")
        anexarCaptura(app, nome: "2-depois-de-escolher-escuro")
        XCTAssertFalse(claro.isSelected)

        app.terminate()
        let reaberto = abrirAparencia()
        XCTAssertTrue(reaberto.buttons["aparencia-escuro"].isSelected, "A escolha continua depois de fechar e abrir o app")
        XCTAssertFalse(reaberto.buttons["aparencia-claro"].isSelected)
    }

    func testOpcoesContinuamTocaveisEmAX5() {
        let app = abrirAparencia(argumentos: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        for identificador in ["aparencia-claro", "aparencia-escuro"] {
            let opcao = app.buttons[identificador]
            XCTAssertTrue(opcao.waitForExistence(timeout: Espera.aparecer), identificador)
            XCTAssertTrue(opcao.isHittable, identificador)
            XCTAssertGreaterThanOrEqual(opcao.frame.height, 44, identificador)
        }
    }
}
