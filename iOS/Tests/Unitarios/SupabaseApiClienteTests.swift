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

@Suite("Cliente Supabase contra respostas HTTP do contrato")
struct SupabaseApiClienteTests {
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
