import Foundation
import FrilaDados
import FrilaDominio
import Testing

@Suite("Erros tipados da API")
struct ErrosAPITests {
    @Test("Todo código conhecido preserva o tipo", arguments: CodigoErroAPI.allCases.filter { $0 != .desconhecido })
    func codigos(codigo: CodigoErroAPI) {
        #expect(DecodificadorErroAPI.mapear(codigo: codigo.rawValue, detalhes: "x").codigo == codigo)
    }

    @Test("Resposta 409 mantém o código de negócio")
    func conflito() {
        let dados = Data(#"{"code":"posicao_ja_preenchida","message":"conflito","details":"ultima_posicao","hint":null}"#.utf8)
        let erro = DecodificadorErroAPI.mapear(statusCode: 409, dados: dados)
        #expect(erro.codigo == .posicaoJaPreenchida)
        #expect(erro.detalhes == "ultima_posicao")
    }

    @Test("Código desconhecido nunca é descartado")
    func desconhecido() {
        let erro = DecodificadorErroAPI.mapear(codigo: "codigo_novo", detalhes: nil)
        #expect(erro.codigo == .desconhecido)
        #expect(erro.codigoOriginal == "codigo_novo")
    }
}
