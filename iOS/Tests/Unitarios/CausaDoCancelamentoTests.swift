import Foundation
import FrilaDominio
import Testing

@Suite("Domínio - Causa do Cancelamento e Decodificação Resiliente")
struct CausaDoCancelamentoTests {

    @Test("Decodificação de cada valor canônico do contrato backend")
    func decodificacaoCanonica() throws {
        let casos: [(String, CausaDoCancelamento)] = [
            ("\"profissional\"", .profissional),
            ("\"estabelecimento\"", .estabelecimento),
            ("\"reabertura_por_atraso\"", .reaberturaPorAtraso),
            ("\"no_show_sem_checkin\"", .noShowSemCheckin),
            ("\"outro\"", .outro)
        ]

        for (jsonString, causaEsperada) in casos {
            let data = try #require(jsonString.data(using: .utf8))
            let decodificado = try JSONDecoder().decode(CausaDoCancelamento.self, from: data)
            #expect(decodificado == causaEsperada)
        }
    }

    @Test("Decodificação resiliente: strings desconhecidas ou do servidor novo viram .outro sem erro",
          arguments: ["desconhecido", "forca_maior", "cancelado_admin", "", "arbitrario_123"])
    func decodificacaoResilienteCaiEmOutro(valorDesconhecido: String) throws {
        let jsonString = "\"\(valorDesconhecido)\""
        let data = try #require(jsonString.data(using: .utf8))
        let decodificado = try JSONDecoder().decode(CausaDoCancelamento.self, from: data)
        #expect(decodificado == .outro)
    }

    @Test("Decodificação recusa tipos não string lançando DecodingError",
          arguments: ["123", "true", "{}", "[]"])
    func decodificacaoRecusaTiposInvalidos(jsonInvalido: String) {
        let data = jsonInvalido.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(CausaDoCancelamento.self, from: data)
        }
    }

    @Test("Codificação preserva os nomes snake_case exatos para a API")
    func codificacaoPreservaSnakeCase() throws {
        let encoder = JSONEncoder()
        #expect(try String(data: encoder.encode(CausaDoCancelamento.profissional), encoding: .utf8) == "\"profissional\"")
        #expect(try String(data: encoder.encode(CausaDoCancelamento.estabelecimento), encoding: .utf8) == "\"estabelecimento\"")
        #expect(try String(data: encoder.encode(CausaDoCancelamento.reaberturaPorAtraso), encoding: .utf8) == "\"reabertura_por_atraso\"")
        #expect(try String(data: encoder.encode(CausaDoCancelamento.noShowSemCheckin), encoding: .utf8) == "\"no_show_sem_checkin\"")
        #expect(try String(data: encoder.encode(CausaDoCancelamento.outro), encoding: .utf8) == "\"outro\"")
    }

    @Test("Roundtrip de codificação e decodificação para todos os casos")
    func roundtripCodificacao() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for causa in CausaDoCancelamento.allCases {
            let encoded = try encoder.encode(causa)
            let decoded = try decoder.decode(CausaDoCancelamento.self, from: encoded)
            #expect(decoded == causa)
        }
    }

    @Test("Decodificação de CancelamentoDaPosicao integra causa canônica e preserva atributos")
    func decodificacaoCancelamentoDaPosicaoCanonica() throws {
        let json = """
        {
            "causa": "no_show_sem_checkin",
            "falta": true,
            "motivo": "Profissional não compareceu no horário combinado",
            "canceladaEm": 1790000000
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let cancelamento = try decoder.decode(CancelamentoDaPosicao.self, from: json)

        #expect(cancelamento.causa == .noShowSemCheckin)
        #expect(cancelamento.falta == true)
        #expect(cancelamento.motivo == "Profissional não compareceu no horário combinado")
        #expect(cancelamento.canceladaEm == Date(timeIntervalSince1970: 1_790_000_000))
    }

    @Test("Decodificação de CancelamentoDaPosicao com causa desconhecida protege o app e preenche .outro")
    func decodificacaoCancelamentoDaPosicaoResiliente() throws {
        let json = """
        {
            "causa": "cancelamento_emergencial_sistema",
            "falta": false,
            "canceladaEm": 1790000000
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let cancelamento = try decoder.decode(CancelamentoDaPosicao.self, from: json)

        #expect(cancelamento.causa == .outro)
        #expect(cancelamento.falta == false)
        #expect(cancelamento.motivo == nil)
        #expect(cancelamento.canceladaEm == Date(timeIntervalSince1970: 1_790_000_000))
    }
}
