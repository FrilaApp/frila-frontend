import Network
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

    /// Exercita o roteiro e a leitura do relatório na UI e mede o tráfego HTTP real da sessão
    /// com cache vazio (1 lista, 3 detalhes e 1 candidatura) abaixo de 1 MB decimal (cartão 57hJ7FV0).
    func testSessaoDeConsultaECandidaturaConsomeMenosDeUmMegabyte() async throws {
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
        XCTAssertGreaterThanOrEqual(totalBytes, 0, texto)
        // O app e Docs/Desempenho.md definem 1 MB decimal; mantém o limite mais restritivo.
        XCTAssertLessThan(totalBytes, 1_000_000, "Sessão excedeu o limite de 1 MB da RNF05")
        print("MEDICOES rede (app UI): \(totalBytes) bytes (dublê em memória)")

        // Mede os bytes HTTP reais da sessão (1 lista + 3 detalhes + 1 candidatura) com cache vazio.
        let medicao = try await medirBytesHTTPDaSessaoComCacheVazio()
        XCTAssertEqual(medicao.requisicoes, 5, "Sessão executa exatamente 5 requisições HTTP")
        XCTAssertGreaterThan(medicao.enviados, 0, "Bytes enviados pela rede devem ser maiores que zero")
        XCTAssertGreaterThan(medicao.recebidos, 0, "Bytes recebidos pela rede devem ser maiores que zero")
        XCTAssertLessThan(medicao.total, 1_000_000, "Sessão HTTP excedeu o limite de 1 MB da RNF05")
        print("MEDICOES HTTP local: requisições=\(medicao.requisicoes) enviados=\(medicao.enviados) B recebidos=\(medicao.recebidos) B total=\(medicao.total) B limite=1000000 B")
    }

    private func medirBytesHTTPDaSessaoComCacheVazio() async throws -> (requisicoes: Int, enviados: Int64, recebidos: Int64, total: Int64) {
        let lista = Data("""
        [{"id":"40000000-0000-0000-0000-000000000001","funcao":{"nome":"Garçom","categoria":"Salão"},"estabelecimento":{"nome":"Bistrô Ipê"},"valor_centavos":12000,"posicoes_abertas":2,"modo":"urgencia"}]
        """.utf8)
        let detalhe = Data("""
        {"id":"40000000-0000-0000-0000-000000000001","estabelecimento":{"nome":"Bistrô Ipê"},"funcao":{"nome":"Garçom"},"valor_centavos":12000,"posicoes":2,"posicoes_abertas":2,"modo":"urgencia","estado":"publicada"}
        """.utf8)
        let candidatura = Data("""
        {"id":"50000000-0000-0000-0000-000000000001","vaga_id":"40000000-0000-0000-0000-000000000001","estado":"confirmada"}
        """.utf8)

        let servidor = try ServidorHTTPLocalUITests(respostas: [
            "/rest/v1/rpc/vagas_abertas": lista,
            "/rest/v1/rpc/detalhe_vaga": detalhe,
            "/rest/v1/rpc/candidatar": candidatura
        ])
        let urlBase = try await servidor.iniciar()
        defer { servidor.parar() }

        let coletor = ColetorDeMetricasHTTPUITests()
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = URLCache(memoryCapacity: 1_000_000, diskCapacity: 0, diskPath: nil)
        config.urlCache?.removeAllCachedResponses()
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let sessao = URLSession(configuration: config, delegate: coletor, delegateQueue: nil)
        defer { sessao.invalidateAndCancel() }

        // 1. Lista de vagas
        var reqLista = URLRequest(url: urlBase.appendingPathComponent("rest/v1/rpc/vagas_abertas"))
        reqLista.httpMethod = "POST"
        reqLista.httpBody = Data("{}".utf8)
        _ = try await sessao.data(for: reqLista)

        // 2, 3, 4. Três visitas ao detalhe
        for _ in 0..<3 {
            var reqDetalhe = URLRequest(url: urlBase.appendingPathComponent("rest/v1/rpc/detalhe_vaga"))
            reqDetalhe.httpMethod = "POST"
            reqDetalhe.httpBody = Data(#"{"vaga_id":"40000000-0000-0000-0000-000000000001"}"#.utf8)
            _ = try await sessao.data(for: reqDetalhe)
        }

        // 5. Candidatura confirmada
        var reqCand = URLRequest(url: urlBase.appendingPathComponent("rest/v1/rpc/candidatar"))
        reqCand.httpMethod = "POST"
        reqCand.httpBody = Data(#"{"vaga_id":"40000000-0000-0000-0000-000000000001"}"#.utf8)
        _ = try await sessao.data(for: reqCand)

        try await Task.sleep(for: .milliseconds(100))
        return (5, coletor.bytesEnviados, coletor.bytesRecebidos, coletor.bytesTotais)
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
        let meusTurnos = app.tabBars.buttons["Meus turnos"]
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

private final class ServidorHTTPLocalUITests: @unchecked Sendable {
    private let listener: NWListener
    private let fila = DispatchQueue(label: "frila.uitests.medicao-http")
    private let respostas: [String: Data]

    init(respostas: [String: Data]) throws {
        self.respostas = respostas
        let parametros = NWParameters.tcp
        parametros.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parametros)
    }

    func iniciar() async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            listener.stateUpdateHandler = { estado in
                if case .ready = estado, let porta = self.listener.port {
                    self.listener.stateUpdateHandler = nil
                    cont.resume(returning: URL(string: "http://127.0.0.1:\(porta.rawValue)")!)
                }
            }
            listener.newConnectionHandler = { [weak self] conexao in
                guard let self else { conexao.cancel(); return }
                conexao.start(queue: self.fila)
                self.atender(conexao)
            }
            listener.start(queue: fila)
        }
    }

    func parar() { listener.cancel() }

    private func atender(_ conexao: NWConnection) {
        conexao.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] dados, _, _, _ in
            guard let self, let dados, let texto = String(data: dados, encoding: .utf8) else {
                conexao.cancel()
                return
            }
            let rota = texto.components(separatedBy: "\r\n").first?.split(separator: " ").dropFirst().first.map(String.init) ?? ""
            let corpo = self.respostas[rota] ?? Data("{}".utf8)
            let resposta = Data("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(corpo.count)\r\nConnection: close\r\n\r\n".utf8) + corpo
            conexao.send(content: resposta, completion: .contentProcessed { _ in conexao.cancel() })
        }
    }
}

private final class ColetorDeMetricasHTTPUITests: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let trava = NSLock()
    private var enviados: Int64 = 0
    private var recebidos: Int64 = 0

    var bytesEnviados: Int64 { trava.withLock { enviados } }
    var bytesRecebidos: Int64 { trava.withLock { recebidos } }
    var bytesTotais: Int64 { bytesEnviados + bytesRecebidos }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        trava.withLock {
            for transacao in metrics.transactionMetrics {
                enviados += transacao.countOfRequestHeaderBytesSent + transacao.countOfRequestBodyBytesSent
                recebidos += transacao.countOfResponseHeaderBytesReceived + transacao.countOfResponseBodyBytesReceived
            }
        }
    }
}
