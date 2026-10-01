import Foundation
import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

/// Responde às chamadas do supabase-swift sem rede. Só `rpc/candidatar` recebe o 409 do contrato;
/// qualquer outra rota recebe um 500 sem envelope, que o teste não aceitaria como conflito.
private final class ConflitoNaCandidatura: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        let rotaEsperada = url.path == "/rest/v1/rpc/candidatar"
        let corpo = rotaEsperada
            ? #"{"code":"posicao_ja_preenchida","message":"A última posição acabou de ser preenchida.","details":"ultima_posicao","hint":null}"#
            : "{}"
        let resposta = HTTPURLResponse(
            url: url,
            statusCode: rotaEsperada ? 409 : 500,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: resposta, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(corpo.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Guarda o corpo que chega a `rpc/cadastrar_estabelecimento` e responde com a fixture do contrato.
private final class CadastroNoBackend: URLProtocol {
    private static let trava = NSLock()
    nonisolated(unsafe) private static var corpos: [Data] = []

    static var corposRecebidos: [Data] { trava.withLock { corpos } }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        let rotaEsperada = url.path == "/rest/v1/rpc/cadastrar_estabelecimento"
        if rotaEsperada, let corpo = Self.corpo(de: request) {
            Self.trava.withLock { Self.corpos.append(corpo) }
        }
        let estabelecimento = try? FixturesDoContrato.dados("estabelecimento")
        let resposta = HTTPURLResponse(
            url: url,
            statusCode: rotaEsperada && estabelecimento != nil ? 200 : 500,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: resposta, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: rotaEsperada ? estabelecimento ?? Data("{}".utf8) : Data("{}".utf8))
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

@Suite("Cliente Supabase contra respostas HTTP do contrato")
struct SupabaseApiClienteTests {
    @Test("cadastrar_estabelecimento manda regiao_administrativa no corpo e lê a região da resposta (0.2.20)")
    func cadastroEnviaARegiaoAdministrativa() async throws {
        let configuracao = URLSessionConfiguration.ephemeral
        configuracao.protocolClasses = [CadastroNoBackend.self]
        let cliente = SupabaseApiCliente(
            url: try #require(URL(string: "https://frila-teste.supabase.co")),
            chavePublicavel: "sb_publishable_teste",
            telemetria: TelemetryNula(),
            sessaoHTTP: URLSession(configuration: configuracao)
        )

        let criado = try await cliente.cadastrarEstabelecimento(CadastroEstabelecimento(
            nome: "Bistrô Ipê", documento: "12345678000190", tipo: .foodService, endereco: "CLS 405, Asa Sul, Brasília - DF",
            regiaoAdministrativa: "Plano Piloto", ponto: try Coordenada(latitude: -15.8121, longitude: -47.8997)
        ))

        #expect(criado.regiaoAdministrativa == "Plano Piloto")
        // O corpo que sai pela rede é a requisição do contrato, campo a campo.
        let corpo = try #require(CadastroNoBackend.corposRecebidos.first)
        let enviado = try #require(JSONSerialization.jsonObject(with: corpo) as? NSDictionary)
        #expect(enviado["regiao_administrativa"] as? String == "Plano Piloto")
        #expect(enviado == (try ContratoTests.fixture("requisicao-cadastrar-estabelecimento")))
    }

    @Test("409 posicao_ja_preenchida da RPC chega à tela como caso tipado")
    func conflitoDaRPCChegaATela() async throws {
        let configuracao = URLSessionConfiguration.ephemeral
        configuracao.protocolClasses = [ConflitoNaCandidatura.self]
        let cliente = SupabaseApiCliente(
            url: try #require(URL(string: "https://frila-teste.supabase.co")),
            chavePublicavel: "sb_publishable_teste",
            telemetria: TelemetryNula(),
            sessaoHTTP: URLSession(configuration: configuracao)
        )

        let erro = await #expect(throws: ErroDaApi.self) {
            _ = try await cliente.candidatar(vagaID: UUID())
        }
        #expect(erro?.codigo == .posicaoJaPreenchida)
        #expect(erro?.detalhes == "ultima_posicao")
        #expect(erro.map(MensagemDoErroAPI.texto) == "Esta vaga acabou de ser preenchida. Escolha outra oportunidade.")
    }
}
