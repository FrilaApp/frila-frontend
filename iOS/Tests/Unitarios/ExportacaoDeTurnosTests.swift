import Foundation
import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

/// Responde a `/functions/v1/exportar-turnos` sem rede. O host escolhe a resposta, para os testes
/// rodarem em paralelo sem dividir estado: `csv.teste` devolve o CSV, `vazio.teste` o 204, e assim
/// por diante. Guarda o pedido que chegou por host.
private final class ExportacaoNoBackend: URLProtocol {
    struct Pedido {
        let metodo: String?
        let caminho: String
        let corpo: Data?
    }

    private static let trava = NSLock()
    nonisolated(unsafe) private static var pedidos: [String: Pedido] = [:]

    static func pedido(em host: String) -> Pedido? { trava.withLock { pedidos[host] } }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host() else { return }
        Self.trava.withLock {
            Self.pedidos[host] = Pedido(metodo: request.httpMethod, caminho: url.path, corpo: Self.corpo(de: request))
        }
        let (status, tipo, corpo): (Int, String?, Data) = switch host.split(separator: ".").first.map(String.init) {
        case "csv": (200, "text/csv; charset=utf-8", (try? FixturesDoContrato.arquivo("exportar-turnos", extensao: "csv")) ?? Data())
        case "pdf": (200, "application/pdf", (try? FixturesDoContrato.arquivo("exportar-turnos", extensao: "pdf")) ?? Data())
        case "vazio": (204, nil, Data())
        case "proibido": (403, "application/json", Data(#"{"code":"sem_permissao","message":"sem_permissao","details":null,"hint":null}"#.utf8))
        case "sessao": (401, "application/json", Data(#"{"code":401,"message":"Invalid JWT"}"#.utf8))
        case "json": (200, "application/json", Data(#"{"ok":true}"#.utf8))
        default: (500, "application/json", Data("{}".utf8))
        }
        var cabecalhos: [String: String] = [:]
        if let tipo { cabecalhos["Content-Type"] = tipo }
        let resposta = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: cabecalhos)!
        client?.urlProtocol(self, didReceive: resposta, cacheStoragePolicy: .notAllowed)
        if !corpo.isEmpty { client?.urlProtocol(self, didLoad: corpo) }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// A URLSession entrega o corpo ao URLProtocol como stream, e não em `httpBody`.
    private static func corpo(de request: URLRequest) -> Data? {
        if let corpo = request.httpBody { return corpo }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var dados = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while stream.hasBytesAvailable {
            let lidos = stream.read(&buffer, maxLength: buffer.count)
            guard lidos > 0 else { break }
            dados.append(buffer, count: lidos)
        }
        return dados
    }
}

@Suite("Exportação de turnos: domínio, contrato e cliente (#23)")
struct ExportacaoDeTurnosTests {
    static let estabelecimento = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!

    static func outubro() throws -> PeriodoDeExportacao {
        try PeriodoDeExportacao(de: DataCivil("2026-10-01"), ate: DataCivil("2026-10-31"))
    }

    private static func cliente(_ host: String) throws -> SupabaseApiCliente {
        let configuracao = URLSessionConfiguration.ephemeral
        configuracao.protocolClasses = [ExportacaoNoBackend.self]
        return SupabaseApiCliente(
            url: try #require(URL(string: "https://\(host)")),
            chavePublicavel: "sb_publishable_teste",
            telemetria: TelemetryNula(),
            sessaoHTTP: URLSession(configuration: configuracao)
        )
    }

    // MARK: Fuso

    @Test("O período cobre os dias inteiros de São Paulo: 00:00:00.000 do primeiro a 23:59:59.999 do último")
    func diaInteiroEmSaoPaulo() throws {
        let periodo = try Self.outubro()
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = try #require(TimeZone(identifier: "America/Sao_Paulo"))
        let campos: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]

        let inicio = calendario.dateComponents(campos, from: periodo.inicio)
        #expect([inicio.year, inicio.month, inicio.day, inicio.hour, inicio.minute, inicio.second] == [2026, 10, 1, 0, 0, 0])
        #expect(periodo.inicio == ContratoAPI.instante("2026-10-01T03:00:00Z"))

        let fim = calendario.dateComponents(campos, from: periodo.fim)
        #expect([fim.year, fim.month, fim.day, fim.hour, fim.minute, fim.second] == [2026, 10, 31, 23, 59, 59])
        // Um milissegundo antes da meia-noite seguinte em São Paulo, que é 03:00 UTC.
        let meiaNoiteSeguinte = try #require(ContratoAPI.instante("2026-11-01T03:00:00Z"))
        #expect(abs(meiaNoiteSeguinte.timeIntervalSince(periodo.fim) - 0.001) < 0.000_001)
    }

    @Test("No contrato, de e ate saem em UTC com milissegundos: o último milissegundo do dia não fica de fora")
    func instantesNoContrato() throws {
        let periodo = try Self.outubro()
        #expect(ContratoAPI.textoComMilissegundos(periodo.inicio) == "2026-10-01T03:00:00.000Z")
        #expect(ContratoAPI.textoComMilissegundos(periodo.fim) == "2026-11-01T02:59:59.999Z")
        let umDia = try PeriodoDeExportacao(de: DataCivil("2026-10-03"), ate: DataCivil("2026-10-03"))
        #expect(ContratoAPI.textoComMilissegundos(umDia.inicio) == "2026-10-03T03:00:00.000Z")
        #expect(ContratoAPI.textoComMilissegundos(umDia.fim) == "2026-10-04T02:59:59.999Z")
    }

    @Test("A fração arredonda para o milissegundo mais próximo, sem truncar .999 para .998")
    func arredondaMilissegundos() {
        #expect(ContratoAPI.textoComMilissegundos(Date(timeIntervalSince1970: 0.998_999_9)) == "1970-01-01T00:00:00.999Z")
        #expect(ContratoAPI.textoComMilissegundos(Date(timeIntervalSince1970: 59.999_6)) == "1970-01-01T00:01:00.000Z")
    }

    @Test("de depois de ate é recusado; o mesmo dia nas duas pontas vale")
    func ordemDasDatas() throws {
        #expect(throws: ErroPeriodoDeExportacao.inicioDepoisDoFim) {
            try PeriodoDeExportacao(de: DataCivil("2026-10-02"), ate: DataCivil("2026-10-01"))
        }
        let umDia = try PeriodoDeExportacao(de: DataCivil("2026-10-01"), ate: DataCivil("2026-10-01"))
        #expect(umDia.inicio < umDia.fim)
    }

    @Test("Atalhos: este mês vai do dia 1 até hoje; mês passado é o mês anterior inteiro, com virada de ano e fevereiro bissexto")
    func atalhos() throws {
        let esteMes = PeriodoDeExportacao.esteMes(hoje: try DataCivil("2026-10-03"))
        #expect(esteMes.de == (try DataCivil("2026-10-01")))
        #expect(esteMes.ate == (try DataCivil("2026-10-03")))
        let primeiroDia = PeriodoDeExportacao.esteMes(hoje: try DataCivil("2026-10-01"))
        #expect(primeiroDia.de == primeiroDia.ate)

        let setembro = PeriodoDeExportacao.mesPassado(hoje: try DataCivil("2026-10-03"))
        #expect(setembro.de == (try DataCivil("2026-09-01")))
        #expect(setembro.ate == (try DataCivil("2026-09-30")))
        let dezembro = PeriodoDeExportacao.mesPassado(hoje: try DataCivil("2026-01-15"))
        #expect(dezembro.de == (try DataCivil("2025-12-01")))
        #expect(dezembro.ate == (try DataCivil("2025-12-31")))
        let fevereiro = PeriodoDeExportacao.mesPassado(hoje: try DataCivil("2028-03-10"))
        #expect(fevereiro.ate == (try DataCivil("2028-02-29")))
    }

    // MARK: Corpo do pedido

    @Test("O corpo do pedido do contratante é o da fixture do contrato, campo a campo")
    func corpoDoContratante() throws {
        let pedido = PedidoExportacaoTurnos(periodo: try Self.outubro(), formato: .pdf, estabelecimentoID: Self.estabelecimento)
        #expect(try ContratoTests.objeto(ContratoAPI.ExportarTurnos(pedido)) == ContratoTests.fixture("requisicao-exportar-turnos"))
    }

    @Test("Sem estabelecimento, a chave estabelecimento_id não vai: valem os turnos de quem chama como profissional")
    func corpoDoProfissional() throws {
        let pedido = PedidoExportacaoTurnos(periodo: try Self.outubro(), formato: .csv)
        let corpo = try ContratoTests.objeto(ContratoAPI.ExportarTurnos(pedido))
        #expect(corpo["estabelecimento_id"] == nil)
        #expect(corpo["formato"] as? String == "csv")
        #expect(Set(corpo.allKeys.compactMap { $0 as? String }) == ["de", "ate", "formato"])
    }

    // MARK: Cliente Supabase

    @Test("200 text/csv: POST em /functions/v1/exportar-turnos, e o arquivo chega intacto")
    func csvChegaIntacto() async throws {
        let api = try Self.cliente("csv.teste")
        let resultado = try await api.exportarTurnos(PedidoExportacaoTurnos(periodo: try Self.outubro(), formato: .csv))

        #expect(resultado == .arquivo(try FixturesDoContrato.arquivo("exportar-turnos", extensao: "csv")))
        let pedido = try #require(ExportacaoNoBackend.pedido(em: "csv.teste"))
        #expect(pedido.metodo == "POST")
        #expect(pedido.caminho == "/functions/v1/exportar-turnos")
        let corpo = try #require(pedido.corpo.flatMap { try? JSONSerialization.jsonObject(with: $0) as? NSDictionary })
        #expect(corpo["de"] as? String == "2026-10-01T03:00:00.000Z")
        #expect(corpo["ate"] as? String == "2026-11-01T02:59:59.999Z")
        #expect(corpo["estabelecimento_id"] == nil)
    }

    @Test("200 application/pdf com estabelecimento: o corpo que sai pela rede é o do contrato e o PDF chega intacto")
    func pdfChegaIntacto() async throws {
        let api = try Self.cliente("pdf.teste")
        let pedido = PedidoExportacaoTurnos(periodo: try Self.outubro(), formato: .pdf, estabelecimentoID: Self.estabelecimento)
        let resultado = try await api.exportarTurnos(pedido)

        let pdf = try FixturesDoContrato.arquivo("exportar-turnos", extensao: "pdf")
        #expect(resultado == .arquivo(pdf))
        #expect(pdf.starts(with: Data("%PDF-".utf8)))
        let corpo = try #require(ExportacaoNoBackend.pedido(em: "pdf.teste")?.corpo)
        let enviado = try #require(JSONSerialization.jsonObject(with: corpo) as? NSDictionary)
        #expect(enviado == (try ContratoTests.fixture("requisicao-exportar-turnos")))
    }

    @Test("204: o período não tem turnos e não há arquivo")
    func semTurnos() async throws {
        let api = try Self.cliente("vazio.teste")
        #expect(try await api.exportarTurnos(PedidoExportacaoTurnos(periodo: try Self.outubro(), formato: .csv)) == .semTurnos)
    }

    @Test("403 sem_permissao chega à tela como caso tipado")
    func semPermissao() async throws {
        let api = try Self.cliente("proibido.teste")
        let erro = await #expect(throws: ErroDaApi.self) {
            _ = try await api.exportarTurnos(PedidoExportacaoTurnos(periodo: try Self.outubro(), formato: .pdf, estabelecimentoID: UUID()))
        }
        #expect(erro?.codigo == .semPermissao)
        #expect(erro.map(MensagemDoErroAPI.texto) == "Sua conta não pode realizar esta ação.")
    }

    @Test("401 do gateway é sessão inválida")
    func naoAutenticado() async throws {
        let api = try Self.cliente("sessao.teste")
        let erro = await #expect(throws: ErroDaApi.self) {
            _ = try await api.exportarTurnos(PedidoExportacaoTurnos(periodo: try Self.outubro(), formato: .csv))
        }
        #expect(erro?.codigo == .naoAutenticado)
    }

    @Test("200 com outro tipo de conteúdo não vira arquivo: um JSON não pode sair como .csv")
    func tipoInesperado() async throws {
        let api = try Self.cliente("json.teste")
        let erro = await #expect(throws: ErroDaApi.self) {
            _ = try await api.exportarTurnos(PedidoExportacaoTurnos(periodo: try Self.outubro(), formato: .csv))
        }
        #expect(erro?.codigo == .respostaInvalida)
    }

    @Test("O tipo vale sem os parâmetros e sem diferença de caixa; arquivo vazio com 200 não passa")
    func conferenciaDoTipo() throws {
        let url = try #require(URL(string: "https://frila.teste/functions/v1/exportar-turnos"))
        func resposta(_ status: Int, _ tipo: String) -> HTTPURLResponse {
            HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": tipo])!
        }
        let dados = Data("a,b\n".utf8)
        #expect(try SupabaseApiCliente.arquivoExportado(dados: dados, resposta: resposta(200, "Text/CSV; charset=utf-8"), formato: .csv) == .arquivo(dados))
        #expect(throws: ErroDaApi.self) {
            try SupabaseApiCliente.arquivoExportado(dados: dados, resposta: resposta(200, "text/csv"), formato: .pdf)
        }
        #expect(throws: ErroDaApi.self) {
            try SupabaseApiCliente.arquivoExportado(dados: Data(), resposta: resposta(200, "text/csv"), formato: .csv)
        }
    }

    // MARK: Dublê em memória

    @Test("Dublê: devolve o CSV e o PDF de exemplo, guarda o pedido e responde 204 no cenário sem turnos")
    func duble() async throws {
        let api = ApiClienteEmMemoria()
        let csv = try await api.exportarTurnos(PedidoExportacaoTurnos(periodo: try Self.outubro(), formato: .csv))
        #expect(csv == .arquivo(try FixturesDoContrato.arquivo("exportar-turnos", extensao: "csv")))
        let pdf = try await api.exportarTurnos(PedidoExportacaoTurnos(periodo: try Self.outubro(), formato: .pdf, estabelecimentoID: Self.estabelecimento))
        #expect(pdf == .arquivo(try FixturesDoContrato.arquivo("exportar-turnos", extensao: "pdf")))
        #expect(await api.pedidosDeExportacaoDeTurnos.map(\.formato) == [.csv, .pdf])

        let vazio = ApiClienteEmMemoria(cenario: .exportarTurnosSemTurnos)
        #expect(try await vazio.exportarTurnos(PedidoExportacaoTurnos(periodo: try Self.outubro(), formato: .csv)) == .semTurnos)
    }

    @Test("Dublê: estabelecimento que não é da conta é 403, e os cenários de erro das exportações valem aqui também")
    func dubleErros() async throws {
        let pedido = PedidoExportacaoTurnos(periodo: try Self.outubro(), formato: .csv, estabelecimentoID: UUID())
        let erro = await #expect(throws: ErroDaApi.self) { _ = try await ApiClienteEmMemoria().exportarTurnos(pedido) }
        #expect(erro?.codigo == .semPermissao)

        let doProfissional = PedidoExportacaoTurnos(periodo: try Self.outubro(), formato: .csv)
        await #expect(throws: ErroDaApi(codigo: .semRede)) {
            _ = try await ApiClienteEmMemoria(cenario: .exportarSemRede).exportarTurnos(doProfissional)
        }
        await #expect(throws: ErroDaApi(codigo: .desconhecido)) {
            _ = try await ApiClienteEmMemoria(cenario: .exportarErroServidor).exportarTurnos(doProfissional)
        }
    }
}
