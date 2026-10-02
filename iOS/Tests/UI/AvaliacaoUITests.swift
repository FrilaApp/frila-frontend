import XCTest

/// #22 C3: confere a árvore de acessibilidade da tela real, sem comparar imagens.
@MainActor
final class AvaliacaoUITests: XCTestCase {
    func testSemRedeSemSessaoNoCacheAbreDestinoGuardado() {
        conferirAberturaSemIdentidade(cache: "-FRILA_CACHE_VAZIO_UI_TEST")
    }

    func testSemRedeSemArmazenamentoAbreDestinoGuardado() {
        conferirAberturaSemIdentidade(cache: "-FRILA_SEM_CACHE_UI_TEST")
    }

    func testRotaSemIdentidadeMostraSemConexaoComNovaTentativa() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "sem-rede", "-FRILA_CACHE_VAZIO_UI_TEST",
                               "-FRILA_AVALIACAO_TURNO_ID", "22000000-0000-0000-0000-000000000001"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Avaliar turno"].waitForExistence(timeout: 10))
        let estado = app.descendants(matching: .any)["avaliacao-sem-conexao"]
        XCTAssertTrue(estado.exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Sem conexão.")).firstMatch.exists)
        XCTAssertFalse(app.buttons["resposta-sim"].exists)
        XCTAssertFalse(app.buttons["botao-enviar-avaliacao"].exists)
        app.buttons["Tentar novamente"].tap()
        XCTAssertTrue(estado.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Tentar novamente"].isEnabled)
    }

    private func conferirAberturaSemIdentidade(cache: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "sem-rede", cache]
        app.launch()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["vagas-sem-conexao"].exists)
        XCTAssertTrue(app.tabBars.buttons["Meus turnos"].exists)
    }

    private func abrir(argumentos: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_ABRIR_AVALIACAO_UI_TEST", "-FRILA_SCENARIO", "success"] + argumentos
        app.launch()
        XCTAssertTrue(app.staticTexts["pergunta-avaliacao"].waitForExistence(timeout: 10))
        return app
    }

    func testPerguntaSimNaoEmOrdemComRotuloValorESelecao() {
        let app = abrir()
        let ids = ["pergunta-avaliacao", "resposta-sim", "resposta-nao"]
        let elementos = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier IN %@", ids)).allElementsBoundByIndex
        XCTAssertEqual(elementos.map(\.identifier), ids, "a árvore deve apresentar pergunta, Sim e Não nesta ordem")
        let pergunta = app.staticTexts["pergunta-avaliacao"]
        XCTAssertEqual(pergunta.label, "Você trabalharia nesse local de novo?")
        XCTAssertFalse(pergunta.isSelected)
        XCTAssertTrue(pergunta.value == nil || (pergunta.value as? String) == "")

        let sim = app.buttons["resposta-sim"]
        let nao = app.buttons["resposta-nao"]
        XCTAssertEqual(sim.label, "Sim")
        XCTAssertEqual(nao.label, "Não")
        conferir(sim, selecionado: false)
        conferir(nao, selecionado: false)

        sim.tap()
        conferir(sim, selecionado: true)
        conferir(nao, selecionado: false)
        nao.tap()
        conferir(sim, selecionado: false)
        conferir(nao, selecionado: true)

        let arvore = XCTAttachment(string: app.debugDescription)
        arvore.name = "arvore-acessibilidade-avaliacao"
        arvore.lifetime = .keepAlways
        add(arvore)
    }

    func testRespostaGuardadaFicaSelecionadaSemPermitirTroca() {
        let app = abrir(argumentos: ["-FRILA_AVALIACAO_SALVA_UI_TEST"])
        let sim = app.buttons["resposta-sim"]
        let nao = app.buttons["resposta-nao"]
        conferir(sim, selecionado: false)
        conferir(nao, selecionado: true)
        XCTAssertFalse(sim.isEnabled)
        XCTAssertFalse(nao.isEnabled)
        XCTAssertFalse(app.buttons["botao-enviar-avaliacao"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["aviso-ja-avaliado"].exists)
    }

    private func conferir(_ botao: XCUIElement, selecionado: Bool, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(botao.isSelected, selecionado, file: file, line: line)
        XCTAssertEqual(botao.value as? String, selecionado ? "Selecionado" : "Não selecionado", file: file, line: line)
    }
}
