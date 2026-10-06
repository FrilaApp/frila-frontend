import XCTest

/// "Por que recebo vagas" com os critérios reais e o pedido de revisão do despacho (#18).
@MainActor
final class PorQueReceboVagasUITests: XCTestCase {
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"

    /// Abre a folha a partir de Meu perfil, no cenário de sucesso do dublê.
    private func abrirFolha(argumentos: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success"] + argumentos
        app.launch()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
        let botaoPerfil = app.buttons["abrir-meu-perfil"]
        XCTAssertTrue(botaoPerfil.waitForExistence(timeout: 5))
        botaoPerfil.tap()
        XCTAssertTrue(app.navigationBars["Meu perfil"].waitForExistence(timeout: 5))

        let botao = app.buttons["perfil-por-que-recebo"]
        XCTAssertTrue(botao.waitForExistence(timeout: 5))
        for _ in 0..<8 where !botao.isHittable { app.swipeUp() }
        botao.tap()
        XCTAssertTrue(app.navigationBars["Por que recebo vagas"].waitForExistence(timeout: 5))
        return app
    }

    private func rolarAte(_ elemento: XCUIElement, em app: XCUIApplication) {
        for _ in 0..<8 where !elemento.isHittable { app.swipeUp() }
    }

    func testMostraCriteriosReaisEContestaComProtocolo() {
        let app = abrirFolha()

        // 1. O texto aprovado continua, e os critérios vêm do dublê (critério 1)
        let explicacao = app.descendants(matching: .any)["perfil-explicacao-vagas"]
        XCTAssertTrue(explicacao.waitForExistence(timeout: 5))

        let funcoes = app.descendants(matching: .any)["criterios-funcoes"]
        XCTAssertTrue(funcoes.waitForExistence(timeout: 5), "a seção da função deve existir")
        XCTAssertTrue(funcoes.label.contains("Garçom"), "a função real deve aparecer: \(funcoes.label)")

        let horarios = app.descendants(matching: .any)["criterios-horarios"]
        XCTAssertTrue(horarios.exists)
        XCTAssertTrue(horarios.label.contains("Sexta-feira"), "a grade real deve aparecer: \(horarios.label)")

        let distancia = app.descendants(matching: .any)["criterios-distancia"]
        XCTAssertTrue(distancia.exists)
        XCTAssertTrue(distancia.label.contains("15 km"), "os 15 km devem aparecer: \(distancia.label)")

        let equipes = app.descendants(matching: .any)["criterios-equipes"]
        rolarAte(equipes, em: app)
        XCTAssertTrue(equipes.exists)
        XCTAssertTrue(equipes.label.contains("Bistrô Ipê"), "a equipe de confiança deve aparecer: \(equipes.label)")

        // 2. Contestar pede o relato e mostra o protocolo com o prazo (critério 2)
        let contestar = app.buttons["botao-contestar-despacho"]
        rolarAte(contestar, em: app)
        XCTAssertTrue(contestar.waitForExistence(timeout: 5))
        contestar.tap()

        let campo = app.descendants(matching: .any)["campo-relato-despacho"].firstMatch
        XCTAssertTrue(campo.waitForExistence(timeout: 5))
        campo.tap()
        campo.typeText("Não recebi a vaga de sexta no Bistrô Ipê")

        let enviar = app.buttons["botao-enviar-revisao"]
        rolarAte(enviar, em: app)
        XCTAssertTrue(enviar.waitForExistence(timeout: 5))
        enviar.tap()

        let enviado = app.descendants(matching: .any)["status-revisao-enviada"]
        XCTAssertTrue(enviado.waitForExistence(timeout: 5), "o pedido enviado deve aparecer")
        XCTAssertTrue(app.descendants(matching: .any)["protocolo-revisao-despacho"].waitForExistence(timeout: 5), "o protocolo deve aparecer")
        XCTAssertTrue(app.descendants(matching: .any)["prazo-resposta-revisao"].waitForExistence(timeout: 5), "o prazo de resposta deve aparecer")
        XCTAssertFalse(app.buttons["botao-contestar-despacho"].exists, "enviado, o botão dá lugar ao protocolo")

        // 3. Fechar volta a Meu perfil
        let fechar = app.buttons["fechar-explicacao-vagas"]
        XCTAssertTrue(fechar.waitForExistence(timeout: 5))
        fechar.tap()
        XCTAssertTrue(app.navigationBars["Meu perfil"].waitForExistence(timeout: 5))
    }

    /// Em AX5 nada corta nem some: as seções existem, Fechar fica tocável e os dois botões do
    /// formulário empilham com a largura do cartão (QA do #105 na conta suspensa).
    func testEmAX5SecoesExistemEBotoesDaRevisaoEmpilham() {
        let app = abrirFolha(argumentos: ["-UIPreferredContentSizeCategoryName", Self.ax5])

        XCTAssertTrue(app.descendants(matching: .any)["criterios-funcoes"].waitForExistence(timeout: 5))
        let fechar = app.buttons["fechar-explicacao-vagas"]
        XCTAssertTrue(fechar.exists && fechar.isHittable, "Fechar deve ficar tocável em AX5")

        let contestar = app.buttons["botao-contestar-despacho"]
        XCTAssertTrue(contestar.waitForExistence(timeout: 5))
        rolarAte(contestar, em: app)
        XCTAssertTrue(contestar.isHittable, "Contestar deve ficar tocável em AX5")
        contestar.tap()

        let enviar = app.buttons["botao-enviar-revisao"]
        let cancelar = app.buttons["botao-cancelar-revisao"]
        XCTAssertTrue(enviar.waitForExistence(timeout: 5))
        for _ in 0..<8 where !(enviar.isHittable && cancelar.isHittable) { app.swipeUp() }
        XCTAssertTrue(enviar.isHittable && cancelar.isHittable, "os dois botões devem ficar tocáveis")

        XCTAssertGreaterThanOrEqual(cancelar.frame.minY, enviar.frame.maxY, "em AX5, Cancelar fica abaixo de Enviar pedido")
        XCTAssertEqual(cancelar.frame.width, enviar.frame.width, accuracy: 2, "empilhados, os dois botões têm a largura do cartão")
        XCTAssertAlvoMinimo(enviar.frame.height)
        XCTAssertAlvoMinimo(cancelar.frame.height)
    }
}
