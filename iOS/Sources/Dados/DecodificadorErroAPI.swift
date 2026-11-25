import Foundation
import FrilaDominio

public enum DecodificadorErroAPI {
    public static func mapear(statusCode: Int, dados: Data) -> ErroDaApi {
        let erro = decodificar(dados)
        // O 401 do gateway das Edge Functions (`{"code":401,...}`, com `code` numérico) não é o
        // envelope do contrato e sai como `respostaInvalida`; o status já diz que é sessão inválida.
        if statusCode == 401, erro.codigo == .desconhecido || erro.codigo == .respostaInvalida {
            // Sem envelope, o código original é o próprio status: a telemetria ainda sabe de onde veio.
            let original = erro.codigo == .respostaInvalida ? "http_401" : erro.codigoOriginal
            return ErroDaApi(codigo: .naoAutenticado, codigoOriginal: original, detalhes: erro.detalhes)
        }
        if statusCode == 400, erro.codigo == .desconhecido || erro.codigo == .respostaInvalida {
            let original = erro.codigo == .respostaInvalida ? "http_400" : erro.codigoOriginal
            return ErroDaApi(codigo: .respostaInvalida, codigoOriginal: original, detalhes: erro.detalhes)
        }
        // 429 sem o envelope do contrato (gateway ou proxy na frente do PostgREST): o status já diz
        // que é o limite, como `limite_excedido` da busca de profissionais (0.2.88).
        if statusCode == 429, erro.codigo == .desconhecido || erro.codigo == .respostaInvalida {
            let original = erro.codigo == .respostaInvalida ? "http_429" : erro.codigoOriginal
            return ErroDaApi(codigo: .limiteExcedido, codigoOriginal: original, detalhes: erro.detalhes)
        }
        if statusCode == 422, erro.codigo == .desconhecido {
            if erro.codigoOriginal == "senha_fraca" || erro.codigoOriginal == "senha_igual" {
                return ErroDaApi(codigo: .campoInvalido, codigoOriginal: erro.codigoOriginal, detalhes: "senha")
            }
        }
        return erro
    }

    public static func decodificar(_ dados: Data) -> ErroDaApi {
        guard let envelope = try? JSONDecoder().decode(EnvelopeErroAPI.self, from: dados) else {
            return ErroDaApi(codigo: .respostaInvalida)
        }
        return mapear(codigo: envelope.code, detalhes: envelope.details)
    }

    public static func mapear(codigo: String?, detalhes: String?) -> ErroDaApi {
        guard let codigo, !codigo.isEmpty else {
            return ErroDaApi(codigo: .desconhecido, codigoOriginal: "sem_codigo", detalhes: detalhes)
        }
        // PGRST3xx: token ausente ou vencido. 42501: o papel `anon` não executa as funções do contrato,
        // que são liberadas só para `authenticated` e conferem o papel por dentro (HTTP 401 sem sessão).
        if codigo.hasPrefix("PGRST3") || codigo == "42501" {
            return ErroDaApi(codigo: .naoAutenticado, codigoOriginal: codigo, detalhes: detalhes)
        }
        let tipado = CodigoErroAPI(rawValue: codigo) ?? .desconhecido
        return ErroDaApi(codigo: tipado, codigoOriginal: codigo, detalhes: detalhes)
    }
}
