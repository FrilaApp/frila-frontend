import Foundation
import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

@Suite("Erros tipados da API")
struct ErrosAPITests {
    @Test("Todo código conhecido preserva o tipo", arguments: CodigoErroAPI.allCases.filter { $0 != .desconhecido })
    func codigos(codigo: CodigoErroAPI) {
        #expect(DecodificadorErroAPI.mapear(codigo: codigo.rawValue, detalhes: "x").codigo == codigo)
    }

    @Test("Todo código da tabela de erros do contrato espelhado tem caso próprio em CodigoErroAPI")
    func catalogoDoContrato() throws {
        // Lê a tabela do Contrato/openapi.yaml, e não o próprio enum: um código novo no contrato
        // sem caso no app falha aqui, em vez de cair calado em `.desconhecido`.
        let contrato = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Contrato/openapi.yaml")
        let texto = try String(contentsOf: contrato, encoding: .utf8)
        // A segunda coluna pode trazer mais de um código (`conta_existente`, `documento_ja_cadastrado`);
        // a terceira, com os `details`, fica de fora.
        let linha = /(?m)^\s*\| [0-9]{3} \| ([^|]+)\|/
        let codigo = /`([a-z0-9_]+)`/
        let codigos = Set(texto.matches(of: linha).flatMap { coluna in
            coluna.output.1.matches(of: codigo).map { String($0.output.1) }
        })
        #expect(codigos.count >= 28, "a tabela de erros do contrato não foi encontrada inteira")
        let semCaso = codigos.filter { CodigoErroAPI(rawValue: $0) == nil }.sorted()
        #expect(semCaso.isEmpty, "códigos do contrato sem caso em CodigoErroAPI: \(semCaso)")
    }

    @Test("Todo exemplo de erro do contrato é decodificado e preserva seus detalhes")
    func exemplosDoContrato() throws {
        for envelope in try FixturesDoContrato.todosOsErros() {
            let dados = try JSONEncoder().encode(envelope)
            let erro = DecodificadorErroAPI.decodificar(dados)
            let esperado = envelope.code.hasPrefix("PGRST3")
                ? CodigoErroAPI.naoAutenticado
                : CodigoErroAPI(rawValue: envelope.code) ?? .desconhecido
            #expect(erro.codigo == esperado)
            #expect(erro.codigoOriginal == envelope.code)
            #expect(erro.detalhes == envelope.details)
        }
    }

    @Test("Resposta 409 mantém o código de negócio")
    func conflito() {
        let dados = Data(#"{"code":"posicao_ja_preenchida","message":"conflito","details":"ultima_posicao","hint":null}"#.utf8)
        let erro = DecodificadorErroAPI.mapear(statusCode: 409, dados: dados)
        #expect(erro.codigo == .posicaoJaPreenchida)
        #expect(erro.detalhes == "ultima_posicao")
    }

    @Test("Todo 409 novo ou existente chega tipado à camada de apresentação", arguments: [
        ("posicao_ja_preenchida", CodigoErroAPI.posicaoJaPreenchida, "Esta vaga acabou de ser preenchida. Escolha outra oportunidade."),
        ("vaga_encerrada", CodigoErroAPI.vagaEncerrada, "Esta vaga não está mais disponível."),
        ("checkin_pendente", CodigoErroAPI.checkinPendente, "Faça o check-in antes de continuar."),
        ("checkin_ja_confirmado", CodigoErroAPI.checkinJaConfirmado, "Este check-in já foi confirmado."),
        ("posicao_nao_cancelavel", CodigoErroAPI.posicaoNaoCancelavel, "Esta posição não pode mais ser cancelada."),
    ])
    func conflitosChegamATela(codigo: String, esperado: CodigoErroAPI, mensagem: String) throws {
        let envelope = EnvelopeErroAPI(code: codigo, message: "conflito", details: nil, hint: nil)
        let erro = DecodificadorErroAPI.mapear(statusCode: 409, dados: try JSONEncoder().encode(envelope))
        #expect(erro.codigo == esperado)
        #expect(MensagemDoErroAPI.texto(erro) == mensagem)
    }

    @Test("Chamada sem sessão chega como não autenticado", arguments: ["PGRST301", "PGRST302", "42501"])
    func semSessao(codigo: String) {
        let erro = DecodificadorErroAPI.mapear(codigo: codigo, detalhes: nil)
        #expect(erro.codigo == .naoAutenticado)
        #expect(erro.codigoOriginal == codigo)
    }

    @Test("Código desconhecido nunca é descartado")
    func desconhecido() {
        let erro = DecodificadorErroAPI.mapear(codigo: "codigo_novo", detalhes: nil)
        #expect(erro.codigo == .desconhecido)
        #expect(erro.codigoOriginal == "codigo_novo")
    }
}
