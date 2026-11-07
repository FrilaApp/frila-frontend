import XCTest

/// A foto de perfil em Meu perfil (contrato 0.2.54): cada um dos sete estados, as ações de cada um e a
/// auditoria de acessibilidade da seção no tamanho padrão e em AX5. O seletor de fotos do sistema roda
/// fora do app e não é automatizado aqui: o envio de ponta a ponta está nos testes unitários.
final class FotoDePerfilUITests: XCTestCase {
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    private func abrir(_ cenario: String, ax5: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var argumentos = ["-FRILA_SCENARIO", cenario]
        if ax5 { argumentos += ["-UIPreferredContentSizeCategoryName", Self.ax5] }
        AjudanteDeLancamentoUITests.abrir(app, argumentos: argumentos)
        let conta = app.tabBars.buttons["Conta"]
        XCTAssertTrue(conta.waitForExistence(timeout: Espera.aparecer), "A aba Conta deve existir")
        conta.tap()
        return app
    }

    private func texto(_ id: String, em app: XCUIApplication) -> String {
        let elemento = app.staticTexts[id]
        XCTAssertTrue(elemento.waitForExistence(timeout: Espera.aparecer), "\(id) deve existir")
        return elemento.label
    }

    private func anexar(_ app: XCUIApplication, _ nome: String) {
        let anexo = XCTAttachment(screenshot: app.screenshot())
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)
    }

    private func existe(_ id: String, em app: XCUIApplication) -> Bool {
        app.buttons[id].waitForExistence(timeout: 2)
    }

    // MARK: Os sete estados

    @MainActor
    func testSemFotoOfereceEscolher() {
        let app = abrir("foto-sem-foto")
        XCTAssertEqual(texto("perfil-foto-estado", em: app), "Foto de perfil")
        XCTAssertTrue(existe("perfil-foto-escolher", em: app))
        XCTAssertFalse(app.buttons["perfil-foto-remover"].exists, "sem foto não há o que remover")
        XCTAssertFalse(app.buttons["perfil-foto-nova-analise"].exists)
        anexar(app, "foto-sem-foto")
    }

    @MainActor
    func testEmAnaliseSoPermiteRemover() {
        let app = abrir("foto-em-analise")
        XCTAssertEqual(texto("perfil-foto-estado", em: app), "Foto em análise")
        XCTAssertTrue(texto("perfil-foto-texto", em: app).contains("depois de aprovada"))
        XCTAssertTrue(existe("perfil-foto-remover", em: app))
        XCTAssertFalse(app.buttons["perfil-foto-escolher"].exists)
        XCTAssertFalse(app.buttons["perfil-foto-nova-analise"].exists)
        anexar(app, "foto-em-analise")
    }

    @MainActor
    func testAprovadaPermiteTrocarERemover() {
        let app = abrir("foto-aprovada")
        XCTAssertEqual(texto("perfil-foto-estado", em: app), "Foto publicada")
        XCTAssertTrue(existe("perfil-foto-escolher", em: app))
        XCTAssertEqual(app.buttons["perfil-foto-escolher"].label, "Trocar foto")
        XCTAssertTrue(app.buttons["perfil-foto-remover"].exists)
        XCTAssertTrue(app.images["perfil-foto-imagem"].exists, "a foto aprovada aparece no círculo")
        anexar(app, "foto-aprovada")
    }

    @MainActor
    func testRecusadaDizOMotivoEOferecePedirNovaAnalise() {
        let app = abrir("foto-recusada")
        XCTAssertEqual(texto("perfil-foto-estado", em: app), "Foto não publicada")
        XCTAssertTrue(texto("perfil-foto-texto", em: app).contains("sem texto, telefone, Pix, QR code ou documento"))
        XCTAssertTrue(existe("perfil-foto-tentar-outra", em: app))
        XCTAssertTrue(app.buttons["perfil-foto-nova-analise"].exists)
        XCTAssertTrue(app.buttons["perfil-foto-remover"].exists)
        anexar(app, "foto-recusada")
    }

    @MainActor
    func testNaoPublicadaOferecePedirNovaAnalise() {
        let app = abrir("foto-nao-publicada")
        XCTAssertEqual(texto("perfil-foto-estado", em: app), "Foto não publicada")
        XCTAssertTrue(texto("perfil-foto-texto", em: app).contains("Não conseguimos analisar"))
        XCTAssertTrue(existe("perfil-foto-nova-analise", em: app))
        XCTAssertTrue(app.buttons["perfil-foto-tentar-outra"].exists)
        anexar(app, "foto-nao-publicada")
    }

    @MainActor
    func testOcultadaSoOfereceOutraFoto() {
        let app = abrir("foto-ocultada")
        XCTAssertEqual(texto("perfil-foto-estado", em: app), "Foto oculta")
        XCTAssertTrue(existe("perfil-foto-tentar-outra", em: app))
        XCTAssertFalse(app.buttons["perfil-foto-nova-analise"].exists, "a ocultação por denúncia não se desfaz por nova análise")
        anexar(app, "foto-ocultada")
    }

    @MainActor
    func testRecursoDesligadoComFotoSoPermiteRemover() {
        let app = abrir("foto-recurso-desligado")
        XCTAssertTrue(texto("perfil-foto-texto", em: app).contains("indisponíveis por enquanto"))
        XCTAssertTrue(existe("perfil-foto-remover", em: app))
        XCTAssertFalse(app.buttons["perfil-foto-escolher"].exists)
        XCTAssertFalse(app.buttons["perfil-foto-tentar-outra"].exists)
        anexar(app, "foto-recurso-desligado")
    }

    @MainActor
    func testRecursoDesligadoSemFotoEscondeASecao() {
        let app = abrir("success")
        XCTAssertTrue(app.buttons["perfil-sair-ou-excluir"].waitForExistence(timeout: Espera.aparecer), "o perfil carregou")
        XCTAssertFalse(app.staticTexts["perfil-foto-estado"].exists, "no Prod o recurso nasce desligado e a entrada some")
        XCTAssertFalse(app.buttons["perfil-foto-escolher"].exists)
    }

    // MARK: Ações

    @MainActor
    func testPedirNovaAnaliseLevaAEmAnalise() {
        let app = abrir("foto-recusada")
        tocar(app.buttons["perfil-foto-nova-analise"])
        XCTAssertEqual(texto("perfil-foto-estado", em: app), "Foto em análise")
        XCTAssertFalse(app.buttons["perfil-foto-nova-analise"].exists, "uma vez por foto")
    }

    @MainActor
    func testRemoverPedeConfirmacaoETrazDeVoltaEscolher() {
        let app = abrir("foto-aprovada")
        tocar(app.buttons["perfil-foto-remover"])
        let confirmar = app.sheets.buttons["Remover foto"].firstMatch
        XCTAssertTrue(confirmar.waitForExistence(timeout: Espera.aparecer), "a remoção pede confirmação")
        print("DEBUG FULLY MOUNTED SHEET LABELS: \(app.sheets.buttons.allElementsBoundByIndex.map(\.label))")
        print("DEBUG FULLY MOUNTED APP LABELS: \(app.buttons.allElementsBoundByIndex.map(\.label))")
        anexar(app, "foto-remover-confirmacao")
        confirmar.tap()
        XCTAssertTrue(app.buttons["perfil-foto-escolher"].waitForExistence(timeout: Espera.aparecer))
        XCTAssertEqual(app.buttons["perfil-foto-escolher"].label, "Escolher foto")
        XCTAssertFalse(app.buttons["perfil-foto-remover"].exists)
    }

    @MainActor
    func testCancelarARemocaoMantemAFoto() {
        let app = abrir("foto-aprovada")
        tocar(app.buttons["perfil-foto-remover"])
        print("DEBUG FULL HIERARCHY:\n\(app.debugDescription)")
        let cancelar = app.sheets.buttons["Cancelar"].firstMatch
        XCTAssertTrue(cancelar.waitForExistence(timeout: Espera.aparecer))
        cancelar.tap()
        XCTAssertEqual(texto("perfil-foto-estado", em: app), "Foto publicada")
    }

    // MARK: Acessibilidade

    @MainActor
    private func auditar(_ cenario: String, ax5: Bool) throws {
        let app = abrir(cenario, ax5: ax5)
        XCTAssertTrue(app.staticTexts["perfil-foto-estado"].waitForExistence(timeout: Espera.aparecer))
        try app.performAccessibilityAudit(for: [.contrast, .elementDetection, .hitRegion, .sufficientElementDescription, .trait, .textClipped]) { problema in
            // Contraste dos tokens é coberto pela suíte unitária (ContrasteDesignTokensTests);
            // a medição por pixel do XCTest em AX5 varia no simulador (AuditoriaDeAcessibilidadeUITests).
            if problema.auditType == .contrast { return true }
            // O que não é da seção da foto já é auditado pela suíte do perfil.
            let alvo = problema.element?.identifier ?? ""
            return !alvo.hasPrefix("perfil-foto")
        }
        anexar(app, "auditoria-\(cenario)-\(ax5 ? "ax5" : "padrao")")
    }

    @MainActor func testAuditoriaDaFotoRecusada() throws { try auditar("foto-recusada", ax5: false) }
    @MainActor func testAuditoriaDaFotoRecusadaEmAX5() throws { try auditar("foto-recusada", ax5: true) }
    @MainActor func testAuditoriaDaFotoAprovada() throws { try auditar("foto-aprovada", ax5: false) }
    @MainActor func testAuditoriaDaFotoAprovadaEmAX5() throws { try auditar("foto-aprovada", ax5: true) }
}
