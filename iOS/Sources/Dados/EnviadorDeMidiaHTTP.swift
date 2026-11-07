import Foundation
import FrilaDominio

/// Envia o JPEG para a URL assinada do bucket privado `midia-perfil` (contrato 0.2.54). A URL já traz
/// a autorização, por isso a chamada não leva o token da sessão: ele não deve vazar para o Storage.
public struct EnviadorDeMidiaHTTP: EnviadorDeMidia {
    private let sessao: URLSession

    public init(sessao: URLSession = SupabaseApiCliente.sessaoComPrazo()) {
        self.sessao = sessao
    }

    public func enviar(_ jpeg: Data, para url: URL) async throws {
        guard url.scheme?.lowercased() == "https" else { throw ErroDaApi(codigo: .respostaInvalida, codigoOriginal: "upload_url_insegura") }
        var pedido = URLRequest(url: url)
        pedido.httpMethod = "PUT"
        pedido.setValue(LimitesDaFoto.mime, forHTTPHeaderField: "Content-Type")
        let resposta: URLResponse
        do {
            (_, resposta) = try await sessao.upload(for: pedido, from: jpeg)
        } catch let erro as URLError where SupabaseApiCliente.codigosDeRedeIndisponivel.contains(erro.code) {
            throw ErroDaApi(codigo: .semRede)
        }
        guard let http = resposta as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ErroDaApi(codigo: .desconhecido, codigoOriginal: "upload_http_\((resposta as? HTTPURLResponse)?.statusCode ?? 0)")
        }
    }
}
