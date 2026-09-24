import Foundation
import FrilaDominio

public enum DecodificadorErroAPI {
    public static func mapear(statusCode: Int, dados: Data) -> ErroDaApi {
        let erro = decodificar(dados)
        if statusCode == 401, erro.codigo == .desconhecido { return ErroDaApi(codigo: .naoAutenticado, codigoOriginal: erro.codigoOriginal, detalhes: erro.detalhes) }
        if statusCode == 409 { return erro }
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
        if codigo.hasPrefix("PGRST3") {
            return ErroDaApi(codigo: .naoAutenticado, codigoOriginal: codigo, detalhes: detalhes)
        }
        let tipado = CodigoErroAPI(rawValue: codigo) ?? .desconhecido
        return ErroDaApi(codigo: tipado, codigoOriginal: codigo, detalhes: detalhes)
    }
}
