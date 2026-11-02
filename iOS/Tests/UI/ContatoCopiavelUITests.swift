import XCTest

@MainActor
final class ContatoCopiavelUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Os testes de cópia rodam sem a parada Editar: arrastar até a margem direita cai em "Copiar".
    private func abrirConta(comEdicao: Bool = false) -> (XCUIApplication, XCUIElement) {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success", "-FRILA_ABA_CONTA"]
        if !comEdicao { app.launchArguments.append("-FRILA_SEM_EDICAO_DE_CONTATO") }
        app.launch()
        let valor = app.staticTexts["perfil-telefone-valor"]
        XCTAssertTrue(valor.waitForExistence(timeout: Espera.aparecer))
        return (app, valor)
    }

    private func direitaDaTela(_ app: XCUIApplication, naAlturaDe elemento: XCUIElement) -> XCUICoordinate {
        let janela = app.windows.firstMatch
        return janela.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: janela.frame.width - 24, dy: elemento.frame.midY))
    }

    func testToqueCopiaEMostraOTip() {
        let (app, valor) = abrirConta()
        XCTAssertFalse(app.staticTexts["perfil-telefone-copiado"].exists)
        valor.tap()
        XCTAssertTrue(app.staticTexts["perfil-telefone-copiado"].waitForExistence(timeout: 1))
    }

    private func noEspacoVazio(_ app: XCUIApplication, de elemento: XCUIElement, margem: CGFloat) -> XCUICoordinate {
        let janela = app.windows.firstMatch
        return janela.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: janela.frame.width - margem, dy: elemento.frame.midY))
    }

    func testToqueNoEspacoVazioCopiaOCampoDaLinha() {
        let (app, _) = abrirConta()
        let email = app.staticTexts["perfil-email-valor"]
        noEspacoVazio(app, de: email, margem: 24).tap()
        XCTAssertTrue(app.staticTexts["perfil-email-copiado"].waitForExistence(timeout: 1))
        XCTAssertFalse(app.staticTexts["perfil-telefone-copiado"].exists)
    }

    func testSegurarESoltarNaFaixaDaMargemNaoCopiaNemAbre() {
        let (app, valor) = abrirConta()
        noEspacoVazio(app, de: valor, margem: 24).press(forDuration: 0.8)
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertFalse(app.staticTexts["perfil-telefone-copiado"].exists)
    }

    func testSegurarEDeslizarComecandoNoVazioCopia() {
        let (app, valor) = abrirConta()
        noEspacoVazio(app, de: valor, margem: 160).press(
            forDuration: 0.7,
            thenDragTo: direitaDaTela(app, naAlturaDe: valor),
            withVelocity: XCUIGestureVelocity(rawValue: 80),
            thenHoldForDuration: 1.2
        )
        XCTAssertTrue(app.staticTexts["perfil-telefone-copiado"].waitForExistence(timeout: 10))
    }

    func testRolarComecandoNoEspacoVazioNaoCopia() {
        let (app, valor) = abrirConta()
        let yAntes = app.staticTexts["perfil-email-valor"].frame.minY
        noEspacoVazio(app, de: valor, margem: 60)
            .press(forDuration: 0.01, thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.05)))
        XCTAssertLessThan(app.staticTexts["perfil-email-valor"].frame.minY, yAntes, "A tela deve rolar")
        XCTAssertFalse(app.staticTexts["perfil-telefone-copiado"].exists)
    }

    func testSegurarEDeslizarAteEditarAbreOCampoComTeclado() {
        let (app, valor) = abrirConta(comEdicao: true)
        valor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.7,
            thenDragTo: direitaDaTela(app, naAlturaDe: valor),
            withVelocity: XCUIGestureVelocity(rawValue: 80),
            thenHoldForDuration: 0.6
        )
        let campo = app.textFields["perfil-telefone-editar"]
        XCTAssertTrue(campo.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["perfil-telefone-copiado"].exists)
    }

    func testEditarETocarForaDescartaORascunho() {
        let (app, valor) = abrirConta(comEdicao: true)
        valor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.7,
            thenDragTo: direitaDaTela(app, naAlturaDe: valor),
            withVelocity: XCUIGestureVelocity(rawValue: 80),
            thenHoldForDuration: 0.6
        )
        let campo = app.textFields["perfil-telefone-editar"]
        XCTAssertTrue(campo.waitForExistence(timeout: 5))
        campo.typeText("1")
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.04)).tap()
        XCTAssertTrue(app.staticTexts["perfil-telefone-valor"].waitForExistence(timeout: 3))
        XCTAssertFalse(campo.exists)
        XCTAssertEqual(app.staticTexts["perfil-telefone-valor"].label, "+5561988887777")
    }

    func testEditarEPressionarReturnGrava() {
        let (app, valor) = abrirConta(comEdicao: true)
        valor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.7,
            thenDragTo: direitaDaTela(app, naAlturaDe: valor),
            withVelocity: XCUIGestureVelocity(rawValue: 80),
            thenHoldForDuration: 0.6
        )
        let campo = app.textFields["perfil-telefone-editar"]
        XCTAssertTrue(campo.waitForExistence(timeout: 5))
        campo.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20))
        campo.typeText("61977776666\n")
        XCTAssertTrue(app.staticTexts["perfil-telefone-valor"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["perfil-telefone-valor"].label, "+5561977776666")
    }

    func testSegurarEDeslizarNoMesmoGestoCopia() {
        let (app, valor) = abrirConta()
        valor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.7,
            thenDragTo: direitaDaTela(app, naAlturaDe: valor),
            withVelocity: XCUIGestureVelocity(rawValue: 80),
            thenHoldForDuration: 1.2
        )
        XCTAssertTrue(app.staticTexts["perfil-telefone-copiado"].waitForExistence(timeout: 10))
    }

    func testSegurarESoltarNaoCopia() {
        let (app, valor) = abrirConta()
        valor.press(forDuration: 0.7)
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertFalse(app.staticTexts["perfil-telefone-copiado"].exists)
    }

    func testRolarComecandoNoContatoNaoCopia() {
        let (app, valor) = abrirConta()
        let yAntes = app.staticTexts["perfil-email-valor"].frame.minY
        valor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.01, thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.05)))
        XCTAssertLessThan(app.staticTexts["perfil-email-valor"].frame.minY, yAntes, "A tela deve rolar")
        XCTAssertFalse(app.staticTexts["perfil-telefone-copiado"].exists)
    }

    func testMapearAreaDeToqueComValidacao() {
        let xs: [(String, CGFloat)] = [
            ("sobre o texto", 60),
            ("à direita do texto", 200),
            ("perto da margem direita", 378)
        ]

        for (nomeX, x) in xs {
            var (app, telValor) = abrirConta()
            let yBase = telValor.frame.minY
            let telRotulo = app.staticTexts["perfil-telefone-rotulo"]
            let emailRotulo = app.staticTexts["perfil-email-rotulo"]
            let emailValor = app.staticTexts["perfil-email-valor"]
            let janela = app.windows.firstMatch

            print("=== INICIO X = \(x) (\(nomeX)) | yBase = \(yBase) ===")
            print("telRotulo: \(telRotulo.frame), telValor: \(telValor.frame)")
            print("emailRotulo: \(emailRotulo.frame), emailValor: \(emailValor.frame)")

            let yInicio: CGFloat = 162
            let yFim: CGFloat = 282

            var y = yInicio
            while y <= yFim {
                if abs(telValor.frame.minY - yBase) > 0.5 {
                    print("REINICIO PRE-TOQUE: tela rolou de \(yBase) para \(telValor.frame.minY). Reabrindo...")
                    (app, telValor) = abrirConta()
                }

                while app.staticTexts["perfil-telefone-copiado"].exists || app.staticTexts["perfil-email-copiado"].exists {
                    Thread.sleep(forTimeInterval: 0.1)
                }

                janela.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y)).tap()

                var tocouTel = false
                var tocouEmail = false
                for _ in 0..<5 {
                    if app.staticTexts["perfil-telefone-copiado"].exists {
                        tocouTel = true
                        break
                    }
                    if app.staticTexts["perfil-email-copiado"].exists {
                        tocouEmail = true
                        break
                    }
                    Thread.sleep(forTimeInterval: 0.05)
                }

                if abs(telValor.frame.minY - yBase) > 0.5 {
                    print("DESCARTADO: toque em y=\(y) causou rolagem para \(telValor.frame.minY). Reabrindo...")
                    (app, telValor) = abrirConta()
                    continue
                }

                if tocouTel {
                    print("MAPA_VALIDADO [x=\(x), y=\(y)] -> TELEFONE")
                } else if tocouEmail {
                    print("MAPA_VALIDADO [x=\(x), y=\(y)] -> EMAIL")
                } else {
                    print("MAPA_VALIDADO [x=\(x), y=\(y)] -> NENHUM")
                }

                y += 2
            }
            print("=== FIM X = \(x) ===")
        }
    }
}
