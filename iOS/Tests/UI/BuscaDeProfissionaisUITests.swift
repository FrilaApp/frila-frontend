import XCTest

/// A busca de profissionais (telas PROVISÓRIAS) no dublê, cenário `busca-de-profissionais`:
/// Minhas vagas → Encontrar profissional → buscar → selecionar 2 → chamar → "enviada".
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
        selecoes.element(boundBy: 0).tap()
        selecoes.element(boundBy: 1).tap()

        let chamar = app.buttons["chamar-selecionados"]
        XCTAssertTrue(chamar.isEnabled, "com dois selecionados, dá para chamar")
        chamar.tap()

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
        XCTAssertTrue(enviar.waitForExistence(timeout: 5))
        XCTAssertTrue(enviar.isEnabled, "com valor e total confirmado, o envio libera")
        enviar.tap()

        let enviadas = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'resultado-chamada-' AND label == 'Chamada enviada'"))
        let doisEnviados = expectation(for: NSPredicate(format: "count == 2"), evaluatedWith: enviadas)
        wait(for: [doisEnviados], timeout: 20)
    }

    func testComAChaveDesligadaOBotaoNaoExiste() {
        let app = abrir(cenario + ["-FRILA_CHAMADA_DIRETA_DESLIGADA"])
        XCTAssertTrue(app.buttons["publicar-vaga-entrada"].waitForExistence(timeout: 20) || app.navigationBars["Minhas vagas"].waitForExistence(timeout: 5), "Minhas vagas abre")
        XCTAssertFalse(app.buttons["encontrar-profissional"].waitForExistence(timeout: 6),
                       "com a chave desligada, Encontrar profissional não existe")
    }

    // MARK: Capturas (padrão e AX5), em /tmp/f035-4-capturas/

    private func salvar(_ app: XCUIApplication, _ nome: String) {
        let pasta = URL(fileURLWithPath: "/tmp/f035-4-capturas", isDirectory: true)
        try? FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        let captura = app.screenshot()
        try? captura.pngRepresentation.write(to: pasta.appendingPathComponent("\(nome).png"))
        let anexo = XCTAttachment(screenshot: captura)
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)
    }

    private func capturar(ax5: Bool) {
        let sufixo = ax5 ? "ax5" : "padrao"
        let app = abrir(cenario + (ax5 ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] : []))
        abrirABusca(app)
        buscar(app)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'selecionar-profissional-'")).firstMatch
            .waitForExistence(timeout: 15))
        salvar(app, "busca-com-resultados-\(sufixo)")

        // Outro serviço: ninguém oferece, a busca fica vazia e oferece "Publicar para todos".
        let servico = app.buttons["busca-servico"]
        XCTAssertTrue(servico.waitForExistence(timeout: 5))
        servico.tap()
        let opcoes = app.buttons.allElementsBoundByIndex.filter { $0.isHittable && $0.label != "Serviço" && !$0.label.isEmpty }
        XCTAssertFalse(opcoes.isEmpty, "o seletor de serviço lista o catálogo")
        if let outra = app.collectionViews.buttons.allElementsBoundByIndex.last(where: { $0.isHittable }) ?? opcoes.last { outra.tap() }
        buscar(app)
        XCTAssertTrue(app.descendants(matching: .any)["busca-vazia"].waitForExistence(timeout: 15), "sem ninguém, a busca fica vazia")
        salvar(app, "busca-vazia-\(sufixo)")
    }

    func testCapturaPadrao() { capturar(ax5: false) }
    func testCapturaAX5() { capturar(ax5: true) }
}
