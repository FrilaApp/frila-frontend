import XCTest

/// A busca de profissionais (telas PROVISÓRIAS) no dublê, cenário `busca-de-profissionais`:
/// Minhas vagas → Encontrar profissional → buscar → selecionar 2 → chamar → "enviada". No cenário
/// `busca-com-termos-pendentes`, a busca pede o aceite dos Termos e repete depois dele.
@MainActor
final class BuscaDeProfissionaisUITests: XCTestCase {
    // Pelo fluxo real do contratante (o atalho -FRILA_ABRIR_MINHAS_VAGAS monta a tela sem o fluxo e sem a entrada da busca).
    private let cenario = ["-FRILA_SCENARIO", "busca-de-profissionais"]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func abrir(_ argumentos: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = argumentos
        AjudanteDeLancamentoUITests.preparar(app)
        app.launch()
        return app
    }

    private func abrirABusca(_ app: XCUIApplication) {
        let entrada = app.buttons["encontrar-profissional"]
        XCTAssertTrue(entrada.waitForExistence(timeout: 20), "com a chave ligada, Minhas vagas oferece Encontrar profissional")
        entrada.tap()
        XCTAssertTrue(app.navigationBars["Encontrar profissional"].waitForExistence(timeout: 10))
    }

    private func buscar(_ app: XCUIApplication) {
        let buscar = app.buttons["buscar-profissionais"]
        XCTAssertTrue(buscar.waitForExistence(timeout: 10))
        // O serviço padrão chega com o catálogo; até lá o botão fica desligado.
        let habilitado = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: buscar)
        wait(for: [habilitado], timeout: 15)
        buscar.tap()
    }

    func testBuscarSelecionarDoisChamarMostraEnviada() {
        let app = abrir(cenario)
        abrirABusca(app)
        buscar(app)

        let selecoes = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'selecionar-profissional-'"))
        XCTAssertTrue(selecoes.firstMatch.waitForExistence(timeout: 15), "a busca traz profissionais")
        XCTAssertGreaterThanOrEqual(selecoes.count, 2, "a busca traz ao menos duas pessoas para selecionar")
        selecoes.element(boundBy: 0).tap()
        selecoes.element(boundBy: 1).tap()

        let chamar = app.buttons["chamar-selecionados"]
        XCTAssertTrue(chamar.isEnabled, "com dois selecionados, dá para chamar")
        chamar.tap()

        let valor = app.textFields["busca-valor-total"]
        XCTAssertTrue(valor.waitForExistence(timeout: 10), "a folha de chamada abre com um toque só")
        valor.tap()
        valor.typeText("200")
        let confirmo = app.switches["busca-confirmo-total"]
        XCTAssertTrue(confirmo.waitForExistence(timeout: 5))
        // O centro da linha não aciona o switch: toca no lado dele (como na chamada direta).
        confirmo.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let enviar = app.buttons["busca-enviar-chamadas"]
        for _ in 0..<4 where !(enviar.exists && enviar.isHittable) { app.swipeUp() }
        XCTAssertTrue(enviar.waitForExistence(timeout: 5))
        XCTAssertTrue(enviar.isEnabled, "com valor e total confirmado, o envio libera")
        enviar.tap()

        let enviadas = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'resultado-chamada-' AND label == 'Chamada enviada'"))
        let doisEnviados = expectation(for: NSPredicate(format: "count == 2"), evaluatedWith: enviadas)
        wait(for: [doisEnviados], timeout: 20)
    }

    // MARK: B-124

    /// Na folha de chamada da busca o valor fora da faixa de referência avisa e não trava o envio.
    private func avisarValorForaDaFaixaSemTravar(ax5: Bool) throws {
        let app = abrir(cenario + (ax5 ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] : []))
        abrirABusca(app)
        buscar(app)
        let pessoa = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'selecionar-profissional-'")).firstMatch
        XCTAssertTrue(pessoa.waitForExistence(timeout: 15) || procurar(pessoa, em: app), "a busca traz profissionais")
        XCTAssertTrue(procurar(pessoa, em: app))
        pessoa.tap()
        let chamar = app.buttons["chamar-selecionados"]
        // Em AX5 o botão fica no fim da lista, milhares de pontos abaixo: o `procurar` desiste antes e se contenta com o
        // elemento existir, e o toque cairia fora da tela. Rola até ele ficar tocável.
        for _ in 0..<40 where !chamar.isHittable { app.swipeUp(velocity: .fast) }
        XCTAssertTrue(chamar.isHittable, "com uma pessoa selecionada, dá para chamar")
        chamar.tap()

        let valor = app.textFields["busca-valor-total"]
        XCTAssertTrue(valor.waitForExistence(timeout: 10), "a folha de chamada abre")
        XCTAssertTrue(procurar(valor, em: app))
        valor.tap()
        XCTAssertTrue(esperarFocoDoTeclado(valor, timeout: 5))
        valor.typeText("30")
        let aviso = app.staticTexts["aviso-valor-busca"]
        XCTAssertTrue(aviso.waitForExistence(timeout: 5), "abaixo de R$ 50 a folha avisa")
        XCTAssertEqual(aviso.label, "Valor muito baixo.")

        valor.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2) + "2500")
        let alto = NSPredicate(format: "label == 'Valor muito alto, confira.'")
        wait(for: [expectation(for: alto, evaluatedWith: aviso)], timeout: 5)
        // Em AX5 o teclado numérico cobre o aviso, e a auditoria mediria o contraste das teclas: sobe a folha até o aviso
        // ficar inteiro acima dele, e cobra isso antes de auditar.
        func limite() -> CGFloat {
            let teclado = app.keyboards.firstMatch
            return teclado.exists ? teclado.frame.minY : app.windows.firstMatch.frame.maxY
        }
        for _ in 0..<10 where !(aviso.frame.minY > 140 && aviso.frame.maxY < limite() - 8) {
            let de = app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.45))
            de.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.30)))
        }
        XCTAssertTrue(aviso.frame.minY > 140 && aviso.frame.maxY < limite() - 8, "o aviso fica inteiro à vista: \(aviso.frame)")
        salvar(app, "busca-aviso-valor-alto-\(ax5 ? "ax5" : "padrao")")
        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped, .contrast]) { achado in
            achado.element?.identifier != "aviso-valor-busca"
        }

        let confirmo = app.switches["busca-confirmo-total"]
        XCTAssertTrue(procurar(confirmo, em: app))
        confirmo.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let enviar = app.buttons["busca-enviar-chamadas"]
        XCTAssertTrue(procurar(enviar, em: app))
        XCTAssertTrue(enviar.isEnabled, "com o aviso na tela, o envio segue ligado")
    }

    func testValorForaDaFaixaAvisaSemTravarOEnvio() throws { try avisarValorForaDaFaixaSemTravar(ax5: false) }
    func testValorForaDaFaixaAvisaSemTravarOEnvioEmAX5() throws { try avisarValorForaDaFaixaSemTravar(ax5: true) }

    func testComAChaveDesligadaOBotaoNaoExiste() {
        let app = abrir(cenario + ["-FRILA_CHAMADA_DIRETA_DESLIGADA"])
        XCTAssertTrue(app.buttons["publicar-vaga-entrada"].waitForExistence(timeout: 20) || app.navigationBars["Minhas vagas"].waitForExistence(timeout: 5), "Minhas vagas abre")
        XCTAssertFalse(app.buttons["encontrar-profissional"].waitForExistence(timeout: 6),
                       "com a chave desligada, Encontrar profissional não existe")
    }

    // MARK: Envio incerto sobrevive a publicar uma vaga (#798, item 3)

    /// A resposta do 1º envio se perde (`-FRILA_BUSCA_RESPOSTA_PERDIDA`, só no DEBUG) e a busca trava no envio incerto.
    /// Fechar, abrir "Publicar vaga" (Minhas vagas sai da tela) e cancelar não pode soltar a trava: reaberta, a busca é a
    /// mesma e o "Tentar de novo" resolve com a mesma chave (o dublê devolve a chamada já criada).
    func testEnvioIncertoSobreviveAPublicarVagaEVoltar() {
        let app = abrir(cenario + ["-FRILA_BUSCA_RESPOSTA_PERDIDA"])
        abrirABusca(app)
        buscar(app)
        let pessoa = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'selecionar-profissional-'")).firstMatch
        XCTAssertTrue(pessoa.waitForExistence(timeout: 15), "a busca traz profissionais")
        pessoa.tap()
        app.buttons["chamar-selecionados"].tap()
        enviarPelaFolha(app)
        XCTAssertTrue(app.staticTexts["busca-envio-incerto"].waitForExistence(timeout: 20), "a resposta se perdeu: a busca trava")

        app.buttons["busca-fechar"].tap()
        let publicar = app.buttons["publicar-vaga-entrada"]
        XCTAssertTrue(publicar.waitForExistence(timeout: 10), "Minhas vagas volta com a entrada de publicar")
        publicar.tap()
        let cancelar = app.buttons["cancelar-publicacao"]
        XCTAssertTrue(cancelar.waitForExistence(timeout: 10), "a publicação abre no lugar de Minhas vagas")
        cancelar.tap()

        abrirABusca(app)
        XCTAssertTrue(app.staticTexts["busca-envio-incerto"].waitForExistence(timeout: 10),
                      "depois de publicar e voltar, a busca segue travada no mesmo envio")
        let tentar = app.buttons["busca-tentar-de-novo"]
        XCTAssertTrue(tentar.waitForExistence(timeout: 5))
        tentar.tap()
        let enviada = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'resultado-chamada-' AND label == 'Chamada enviada'"))
        XCTAssertTrue(enviada.firstMatch.waitForExistence(timeout: 20), "o Tentar de novo resolve com a mesma chave")
        XCTAssertFalse(app.staticTexts["busca-envio-incerto"].exists, "resolvido, a trava sai")
    }

    /// A folha de chamada: valor 200, confirma o total e envia.
    private func enviarPelaFolha(_ app: XCUIApplication) {
        let valor = app.textFields["busca-valor-total"]
        XCTAssertTrue(valor.waitForExistence(timeout: 10), "a folha de chamada abre")
        valor.tap()
        valor.typeText("200")
        let confirmo = app.switches["busca-confirmo-total"]
        XCTAssertTrue(confirmo.waitForExistence(timeout: 5))
        // O centro da linha não aciona o switch: toca no lado dele (como na chamada direta).
        confirmo.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let enviar = app.buttons["busca-enviar-chamadas"]
        for _ in 0..<4 where !(enviar.exists && enviar.isHittable) { app.swipeUp() }
        XCTAssertTrue(enviar.waitForExistence(timeout: 5) && enviar.isEnabled, "com valor e total confirmado, o envio libera")
        enviar.tap()
    }

    // MARK: Capturas (padrão e AX5), só como anexos do XCTest

    private func salvar(_ app: XCUIApplication, _ nome: String) {
        let anexo = XCTAttachment(screenshot: app.screenshot())
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)
    }

    /// Em AX5 os filtros ocupam a tela e a lista fica abaixo: rola até o elemento aparecer.
    private func procurar(_ elemento: XCUIElement, em app: XCUIApplication, paraBaixo: Bool = true) -> Bool {
        for _ in 0..<12 {
            if elemento.exists && elemento.isHittable { return true }
            if paraBaixo { app.swipeUp() } else { app.swipeDown() }
        }
        return elemento.exists
    }

    private func capturar(ax5: Bool) {
        let sufixo = ax5 ? "ax5" : "padrao"
        let app = abrir(cenario + (ax5 ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] : []))
        abrirABusca(app)
        buscar(app)
        let primeiraPessoa = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'selecionar-profissional-'")).firstMatch
        XCTAssertTrue(primeiraPessoa.waitForExistence(timeout: 15) || procurar(primeiraPessoa, em: app), "a busca traz profissionais")
        salvar(app, "busca-com-resultados-\(sufixo)")

        // Outro serviço: ninguém oferece, a busca fica vazia e oferece "Publicar para todos".
        let servico = app.buttons["busca-servico"]
        XCTAssertTrue(procurar(servico, em: app, paraBaixo: false), "o filtro de serviço aparece")
        servico.tap()
        // Espera a opção no menu do seletor, sem perguntar isHittable a cada botão enquanto ele abre: no dublê todos
        // oferecem Garçom (o selecionado), e "Bartender" só existe no menu.
        let outroServico = app.collectionViews.buttons["Bartender"]
        XCTAssertTrue(outroServico.waitForExistence(timeout: 10), "o seletor de serviço lista o catálogo")
        outroServico.tap()
        buscar(app)
        let vazia = app.descendants(matching: .any)["busca-vazia"]
        XCTAssertTrue(vazia.waitForExistence(timeout: 15) || procurar(vazia, em: app), "sem ninguém, a busca fica vazia")
        salvar(app, "busca-vazia-\(sufixo)")
    }

    func testCapturaPadrao() { capturar(ax5: false) }
    func testCapturaAX5() { capturar(ax5: true) }

    // MARK: Termos 1.1 pendentes (contrato 0.2.90), cenário `busca-com-termos-pendentes`

    /// A conta ainda não aceitou os Termos 1.1: a busca pede o aceite e, depois dele, a mesma busca traz gente.
    private func aceitarOsTermosERepetirABusca(ax5: Bool) {
        let sufixo = ax5 ? "ax5" : "padrao"
        let app = abrir(["-FRILA_SCENARIO", "busca-com-termos-pendentes"]
                        + (ax5 ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] : []))
        abrirABusca(app)
        buscar(app)

        let aceitar = app.buttons["aceite-termos-aceitar"]
        XCTAssertTrue(aceitar.waitForExistence(timeout: 15) || procurar(aceitar, em: app), "sem os Termos 1.1, a busca pede o aceite")
        XCTAssertTrue(app.descendants(matching: .any)["aceite-termos-link"].exists, "o aceite leva aos Termos de Uso")
        // A versão aceita cobre os Termos 1.2 e a Política 1.3: a Política também está na tela (revisão do #800).
        XCTAssertTrue(app.descendants(matching: .any)["aceite-politica-link"].exists, "o aceite leva à Política de Privacidade")
        XCTAssertTrue(app.staticTexts["aceite-termos-titulo"].label.contains("Política de Privacidade"),
                      "a frase do topo cita os Termos e a Política")
        let selecoes = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'selecionar-profissional-'"))
        XCTAssertEqual(selecoes.count, 0, "antes do aceite a busca não traz ninguém")
        // Em AX5 os filtros ocupam a tela: a captura sai depois de rolar até o aceite.
        XCTAssertTrue(procurar(aceitar, em: app), "o botão Aceitar fica alcançável")
        salvar(app, "busca-termos-pendentes-\(sufixo)")

        aceitar.tap()
        let primeira = selecoes.firstMatch
        XCTAssertTrue(primeira.waitForExistence(timeout: 15) || procurar(primeira, em: app),
                      "depois do aceite, a mesma busca traz profissionais")
        XCTAssertFalse(app.buttons["aceite-termos-aceitar"].exists, "com o aceite feito, o pedido some")
        XCTAssertTrue(procurar(primeira, em: app), "o primeiro cartão fica alcançável")
        salvar(app, "busca-depois-do-aceite-\(sufixo)")
    }

    func testTermosPendentesPedeOAceiteEABuscaPassa() { aceitarOsTermosERepetirABusca(ax5: false) }
    func testTermosPendentesAX5() { aceitarOsTermosERepetirABusca(ax5: true) }
}
