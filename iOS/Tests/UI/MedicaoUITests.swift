import XCTest

/// Relatório de medições (#73) com o dublê do esquema Local: o botão só aparece com `-FRILA_MEDICAO`,
/// e cada abertura entra na conta da tela.
@MainActor
final class MedicaoUITests: XCTestCase {
    private func primeiraVaga(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-'")).firstMatch
    }

    private func abrirRelatorio(_ app: XCUIApplication) {
        let botao = app.buttons["medicoes-abrir"]
        XCTAssertTrue(botao.waitForExistence(timeout: 10))
        botao.tap()
        XCTAssertTrue(app.buttons["medicoes-zerar"].waitForExistence(timeout: 5))
    }

    private func linha(_ app: XCUIApplication, _ tela: String) -> String {
        app.descendants(matching: .any)["medicoes-\(tela)"].label
    }

    private func conferirOrcamentoDaSessao(_ totalBytes: Int64, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThanOrEqual(totalBytes, 0, "O total de bytes não pode ser negativo", file: file, line: line)
        // O app e Docs/Desempenho.md definem 1 MB decimal; mantém o limite mais restritivo.
        XCTAssertLessThan(totalBytes, 1_000_000, "Sessão excedeu o limite de 1 MB da RNF05", file: file, line: line)
    }

    func testOrcamentoAceita999999BytesEReprovaUmMegabyte() {
        conferirOrcamentoDaSessao(999_999)
        XCTExpectFailure("1.000.000 bytes deve reprovar o mesmo orçamento usado no fluxo de UI") {
            self.conferirOrcamentoDaSessao(1_000_000)
        }
    }

    func testSemOArgumentoNaoHaBotaoDeMedicoes() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success"]
        app.launch()
        XCTAssertTrue(primeiraVaga(app).waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["medicoes-abrir"].exists)
    }

    func testAberturaDoDetalheEntraNoRelatorio() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success", "-FRILA_MEDICAO"]
        app.launch()
        XCTAssertTrue(primeiraVaga(app).waitForExistence(timeout: 10))
        abrirRelatorio(app)
        app.buttons["medicoes-zerar"].tap()
        XCTAssertTrue(linha(app, "detalheDaVaga").contains("sem medições"))
        app.buttons["medicoes-fechar"].tap()

        primeiraVaga(app).tap()
        XCTAssertTrue(app.buttons["candidatar"].waitForExistence(timeout: 10))
        abrirRelatorio(app)
        XCTAssertTrue(linha(app, "detalheDaVaga").contains("n=1"), linha(app, "detalheDaVaga"))
        XCTAssertTrue(linha(app, "listaDeVagas").contains("sem medições"), linha(app, "listaDeVagas"))
    }

    /// Exercita o roteiro e a leitura do relatório. `success` tem uma única vaga e não usa HTTP:
    /// o orçamento de rede com bytes não nulos é coberto por
    /// `MedicaoDeDesempenhoTests.bytesDaSessaoComHTTPReal`, sem alterar o dublê do app.
    func testSessaoDeConsultaECandidaturaConsomeMenosDeUmMegabyte() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_SCENARIO", "success", "-FRILA_LOCALIZACAO", "perto",
            "-FRILA_MEDICAO", "-FRILA_CACHE_VAZIO_UI_TEST"
        ]
        app.launch()
        XCTAssertTrue(primeiraVaga(app).waitForExistence(timeout: 10))

        // O registro persiste entre execuções. Zera antes de relançar, para incluir a lista
        // inicial na sessão medida; não zera depois que o roteiro começou.
        abrirRelatorio(app)
        app.buttons["medicoes-zerar"].tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(primeiraVaga(app).waitForExistence(timeout: 10))

        for _ in 0..<3 {
            primeiraVaga(app).tap()
            XCTAssertTrue(app.buttons["candidatar"].waitForExistence(timeout: 10))
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(primeiraVaga(app).waitForExistence(timeout: 10))
        }

        primeiraVaga(app).tap()
        let candidatar = app.buttons["candidatar"]
        XCTAssertTrue(candidatar.waitForExistence(timeout: 10))
        candidatar.tap()
        XCTAssertTrue(app.descendants(matching: .any)["resultado-confirmada"].waitForExistence(timeout: 10))
        abrirRelatorio(app)

        for (tela, minimo) in [("listaDeVagas", 1), ("detalheDaVaga", 4)] {
            let texto = linha(app, tela)
            let quantidade = try XCTUnwrap(texto.range(of: #"n=([0-9]+)"#, options: .regularExpression), texto)
            let n = try XCTUnwrap(Int(texto[quantidade].dropFirst(2)), texto)
            XCTAssertGreaterThanOrEqual(n, minimo, texto)
            print("MEDICOES \(tela): \(texto)")
        }

        let rede = app.descendants(matching: .any)["medicoes-bytes"]
        XCTAssertTrue(rede.waitForExistence(timeout: 5))
        let texto = rede.label
        let campos = texto.components(separatedBy: " · ")
        XCTAssertEqual(campos.count, 2, texto)
        let campoBytes = try XCTUnwrap(campos.last, texto)
        XCTAssertTrue(campoBytes.hasSuffix(" B"), texto)
        let totalBytes = try XCTUnwrap(Int64(campoBytes.dropLast(2)), texto)
        conferirOrcamentoDaSessao(totalBytes)
        print("MEDICOES rede: \(totalBytes) bytes (dublê em memória; não comprova tráfego HTTP)")
    }

    /// Coleta no simulador, fora da suíte: 20 aberturas de cada tela com o dublê, e o relatório no
    /// registro do teste (linhas "MEDICOES"). Liga com `TEST_RUNNER_FRILA_COLETAR_MEDICOES=1` no
    /// `xcodebuild`; o roteiro está em `Docs/Desempenho.md`.
    func testColetaVinteAberturasDeCadaTela() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FRILA_COLETAR_MEDICOES"] == "1", "coleta manual de medições")
        let vezes = 20
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success", "-FRILA_LOCALIZACAO", "perto", "-FRILA_MEDICAO", "-FRILA_CACHE_VAZIO_UI_TEST"]
        app.launch()
        XCTAssertTrue(primeiraVaga(app).waitForExistence(timeout: 10))
        abrirRelatorio(app)
        app.buttons["medicoes-zerar"].tap()
        app.buttons["medicoes-fechar"].tap()

        // Lista: puxar para atualizar.
        for _ in 0..<vezes {
            let inicio = primeiraVaga(app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            inicio.press(forDuration: 0.05, thenDragTo: inicio.withOffset(CGVector(dx: 0, dy: 350)))
            XCTAssertTrue(primeiraVaga(app).waitForExistence(timeout: 10))
        }

        // Detalhe: abrir e voltar.
        let voltar = app.navigationBars.buttons.element(boundBy: 0)
        for _ in 0..<vezes {
            primeiraVaga(app).tap()
            XCTAssertTrue(app.buttons["candidatar"].waitForExistence(timeout: 10))
            voltar.tap()
            XCTAssertTrue(primeiraVaga(app).waitForExistence(timeout: 10))
        }

        // Meu turno: candidata-se uma vez e abre o turno confirmado.
        primeiraVaga(app).tap()
        let candidatar = app.buttons["candidatar"]
        XCTAssertTrue(candidatar.waitForExistence(timeout: 10))
        candidatar.tap()
        XCTAssertTrue(app.descendants(matching: .any)["resultado-confirmada"].waitForExistence(timeout: 10))
        app.buttons["voltar-para-lista"].tap()
        let meusTurnos = app.buttons["abrir-meus-turnos"]
        XCTAssertTrue(meusTurnos.waitForExistence(timeout: 10))
        meusTurnos.tap()
        let turno = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'meu-turno-'")).firstMatch
        for _ in 0..<vezes {
            XCTAssertTrue(turno.waitForExistence(timeout: 10))
            turno.tap()
            // O telefone do exemplo do contrato (`Resources/Fixtures/contato.json`), que o dublê entrega.
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "+5561999990000")).firstMatch.waitForExistence(timeout: 10))
            voltar.tap()
        }

        abrirRelatorio(app)
        for tela in ["listaDeVagas", "detalheDaVaga", "meuTurno"] {
            let texto = linha(app, tela)
            print("MEDICOES \(tela): \(texto)")
            XCTAssertTrue(texto.contains("n="), texto)
        }
        print("MEDICOES rede: \(app.descendants(matching: .any)["medicoes-bytes"].label)")
    }
}
