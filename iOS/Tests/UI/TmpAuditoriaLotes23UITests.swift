import XCTest

// TEMPORÁRIO, fora do commit: auditoria de acessibilidade e capturas das telas novas dos lotes 2 e 3,
// no tamanho padrão e em AX5. Só registra os achados (linhas AUDITORIA-L23|…), sem falhar.
@MainActor
final class TmpAuditoriaLotes23UITests: XCTestCase {
    private let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"
    private let pasta = "/private/tmp/claude-502/-Users-cauecarneiro-Documents-Projetos-Frila-frila-frontend/b89e0e9e-8fc4-476c-aa11-4a3b91075c9a/scratchpad/capturas-l23"
    private let vagaComChamadaRecusada = "C1000000-0000-0000-0000-000000000003"
    private let turnoDoProfissional = "22000000-0000-0000-0000-000000000001"

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
        try? FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
    }

    private func abrir(_ argumentos: [String], grande: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = argumentos
        AjudanteDeLancamentoUITests.preparar(app)
        if grande { app.launchArguments += ["-UIPreferredContentSizeCategoryName", ax5] }
        app.launch()
        return app
    }

    private func auditar(_ tela: String, _ app: XCUIApplication, grande: Bool) {
        let tamanho = grande ? "ax5" : "padrao"
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(pasta)/\(tela)-\(tamanho).png"))
        var achados = 0
        try? app.performAccessibilityAudit(for: .all) { achado in
            achados += 1
            let elemento = achado.element.map { "\($0.elementType.rawValue):\($0.identifier):\($0.label.prefix(60))" } ?? "-"
            print("AUDITORIA-L23|\(tela)|\(tamanho)|\(achado.auditType.rawValue)|\(elemento)|\(achado.compactDescription)")
            return true
        }
        print("AUDITORIA-L23|\(tela)|\(tamanho)|total=\(achados)")
    }

    private func rolarAte(_ elemento: XCUIElement, em app: XCUIApplication) {
        let altura = app.windows.firstMatch.frame.height
        for _ in 0..<14 {
            if elemento.exists, elemento.isHittable, elemento.frame.minY > 100, elemento.frame.maxY < altura - 40 { return }
            if elemento.exists, elemento.frame.minY <= 100 { app.swipeDown() } else { app.swipeUp() }
        }
    }

    func testMeuTurnoNaoVerificado() { meuTurno(grande: false) }
    func testMeuTurnoNaoVerificadoAX5() { meuTurno(grande: true) }
    func testAcompanharChamadas() { acompanhar(grande: false) }
    func testAcompanharChamadasAX5() { acompanhar(grande: true) }
    func testResumoDaChamadaEnviada() { resumo(grande: false) }
    func testResumoDaChamadaEnviadaAX5() { resumo(grande: true) }

    private func meuTurno(grande: Bool) {
        let app = abrir(["-FRILA_SCENARIO", "turno-nao-verificado", "-FRILA_PUSH", "turno_nao_verificado",
                         "-FRILA_PUSH_ID", turnoDoProfissional], grande: grande)
        XCTAssertTrue(app.staticTexts["estado-do-turno"].waitForExistence(timeout: 15))
        auditar("meu-turno-topo", app, grande: grande)
        let aviso = app.descendants(matching: .any)["presenca-nao-verificada"]
        rolarAte(aviso, em: app)
        XCTAssertTrue(aviso.exists)
        auditar("meu-turno-presenca", app, grande: grande)
    }

    private func acompanhar(grande: Bool) {
        let app = abrir(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "chamadas-enviadas"], grande: grande)
        let cartao = app.buttons["vaga-contratante-\(vagaComChamadaRecusada)"]
        XCTAssertTrue(cartao.waitForExistence(timeout: 15))
        rolarAte(cartao, em: app)
        cartao.tap()
        let link = app.buttons["acompanhar-chamadas-\(vagaComChamadaRecusada)"]
        XCTAssertTrue(link.waitForExistence(timeout: 10))
        rolarAte(link, em: app)
        auditar("detalhe-com-acompanhar", app, grande: grande)
        link.tap()
        XCTAssertTrue(app.navigationBars["Acompanhar chamadas"].waitForExistence(timeout: 10))
        auditar("acompanhar", app, grande: grande)
    }

    private func resumo(grande: Bool) {
        let app = abrir(["-FRILA_ABRIR_EQUIPE_CONFIANCA", "-FRILA_SCENARIO", "chamada-direta"], grande: grande)
        let chamar = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'chamar-de-novo-'")).firstMatch
        XCTAssertTrue(chamar.waitForExistence(timeout: 15))
        rolarAte(chamar, em: app)
        chamar.tap()
        let valor = app.textFields["total-chamada-centavos"]
        XCTAssertTrue(valor.waitForExistence(timeout: 10))
        rolarAte(valor, em: app)
        valor.tap()
        valor.typeText("180")
        let ok = app.buttons.matching(NSPredicate(format: "label ==[c] 'ok'")).firstMatch
        if ok.exists { ok.tap() }
        let total = app.switches["confirmar-total-chamada"]
        rolarAte(total, em: app)
        total.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let enviar = app.buttons["enviar-chamada"]
        rolarAte(enviar, em: app)
        enviar.tap()
        let prazo = app.staticTexts["prazo-chamada-enviada"]
        XCTAssertTrue(prazo.waitForExistence(timeout: 10))
        rolarAte(prazo, em: app)
        auditar("resumo-topo", app, grande: grande)
        let link = app.buttons["acompanhar-chamada-enviada"]
        rolarAte(link, em: app)
        XCTAssertTrue(link.exists)
        auditar("resumo-fim", app, grande: grande)
    }
}
