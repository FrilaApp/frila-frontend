import Foundation
import FrilaDominio
import Testing

@Suite("Domínio - Protocolo e Tipo de Protocolo")
struct ProtocoloTests {

    // MARK: - Protocolo Curto (Contrato 0.2.40)

    @Test("calcularProtocoloCurto extrai exatamente os 8 primeiros hexadecimais em maiúsculas sem hífens")
    func calcularProtocoloCurtoExemplos() throws {
        let casos: [(String, String)] = [
            ("6f1c2a4e-2b7d-4c5e-9a1f-3d2e1c0b9a88", "6F1C2A4E"),
            ("a1b2c3d4-e5f6-7890-abcd-ef1234567890", "A1B2C3D4"),
            ("00000000-1111-2222-3333-444455556666", "00000000"),
            ("ffffffff-aaaa-bbbb-cccc-dddddddddddd", "FFFFFFFF"),
            ("01234567-89ab-cdef-0123-456789abcdef", "01234567")
        ]

        for (uuidString, esperado) in casos {
            let uuid = try #require(UUID(uuidString: uuidString))
            let curto = Protocolo.calcularProtocoloCurto(uuid)
            #expect(curto == esperado)
            #expect(curto.count == 8)
            #expect(!curto.contains("-"))
            #expect(curto == curto.uppercased())
        }
    }

    @Test("Propriedade protocoloCurto de Protocolo coincide com o cálculo estático a partir de ocorrenciaID")
    func propriedadeProtocoloCurtoCoincideComCalculoEstatico() throws {
        let ocorrenciaID = try #require(UUID(uuidString: "8e7d6c5b-4a3f-2e1d-0c9b-8a7f6e5d4c3b"))
        let prazo = try DataCivil("2026-10-25")
        let protocolo = Protocolo(
            ocorrenciaID: ocorrenciaID,
            tipo: .suporte,
            criadaEm: Date(timeIntervalSince1970: 1_790_000_000),
            prazoRespostaAte: prazo
        )

        #expect(protocolo.protocoloCurto == "8E7D6C5B")
        #expect(protocolo.protocoloCurto == Protocolo.calcularProtocoloCurto(ocorrenciaID))
    }

    // MARK: - TipoDeProtocolo - Decodificação Canônica e Resiliente

    @Test("Decodificação canônica dos tipos conhecidos de protocolo")
    func decodificacaoCanonicaTipoDeProtocolo() throws {
        let casos: [(String, TipoDeProtocolo)] = [
            ("\"denuncia\"", .denuncia),
            ("\"contestacao\"", .contestacao),
            ("\"revisao_despacho\"", .revisaoDespacho),
            ("\"suporte\"", .suporte)
        ]

        let decoder = JSONDecoder()
        for (json, esperado) in casos {
            let data = try #require(json.data(using: .utf8))
            let decodificado = try decoder.decode(TipoDeProtocolo.self, from: data)
            #expect(decodificado == esperado)
        }
    }

    @Test("Decodificação defensiva: tipos novos ou desconhecidos caem em .denuncia para preservar o protocolo",
          arguments: ["ouvidoria", "elogio", "novo_tipo_v2", "", "arbitrario_xyz"])
    func decodificacaoDefensivaCaiEmDenuncia(tipoDesconhecido: String) throws {
        let json = "\"\(tipoDesconhecido)\""
        let data = try #require(json.data(using: .utf8))
        let decodificado = try JSONDecoder().decode(TipoDeProtocolo.self, from: data)
        #expect(decodificado == .denuncia)
    }

    @Test("Decodificação recusa valores que não são string lançando DecodingError",
          arguments: ["123", "true", "[]", "{}"])
    func decodificacaoRecusaTiposInvalidos(jsonInvalido: String) {
        let data = jsonInvalido.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TipoDeProtocolo.self, from: data)
        }
    }

    @Test("Codificação preserva snake_case exato esperado pelo backend")
    func codificacaoPreservaSnakeCase() throws {
        let encoder = JSONEncoder()
        #expect(try String(data: encoder.encode(TipoDeProtocolo.denuncia), encoding: .utf8) == "\"denuncia\"")
        #expect(try String(data: encoder.encode(TipoDeProtocolo.contestacao), encoding: .utf8) == "\"contestacao\"")
        #expect(try String(data: encoder.encode(TipoDeProtocolo.revisaoDespacho), encoding: .utf8) == "\"revisao_despacho\"")
        #expect(try String(data: encoder.encode(TipoDeProtocolo.suporte), encoding: .utf8) == "\"suporte\"")
    }

    // MARK: - Protocolo - Estrutura e Decodificação Integrada

    @Test("Decodificação de Protocolo decodifica todos os campos e calcula protocoloCurto")
    func decodificacaoProtocoloCompleto() throws {
        let json = """
        {
            "ocorrenciaID": "6f1c2a4e-2b7d-4c5e-9a1f-3d2e1c0b9a88",
            "tipo": "revisao_despacho",
            "criadaEm": 1790000000,
            "prazoRespostaAte": {
                "ano": 2026,
                "mes": 10,
                "dia": 22
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let protocolo = try decoder.decode(Protocolo.self, from: json)

        let esperadoID = try #require(UUID(uuidString: "6f1c2a4e-2b7d-4c5e-9a1f-3d2e1c0b9a88"))
        #expect(protocolo.ocorrenciaID == esperadoID)
        #expect(protocolo.tipo == .revisaoDespacho)
        #expect(protocolo.criadaEm == Date(timeIntervalSince1970: 1_790_000_000))
        #expect(protocolo.prazoRespostaAte == (try DataCivil(ano: 2026, mes: 10, dia: 22)))
        #expect(protocolo.protocoloCurto == "6F1C2A4E")
    }

    @Test("Decodificação de Protocolo com tipo inédito cai defensivamente em .denuncia sem quebrar")
    func decodificacaoProtocoloComTipoDesconhecido() throws {
        let json = """
        {
            "ocorrenciaID": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
            "tipo": "ouvidoria_externa",
            "criadaEm": 1790000000,
            "prazoRespostaAte": {
                "ano": 2026,
                "mes": 10,
                "dia": 25
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let protocolo = try decoder.decode(Protocolo.self, from: json)

        #expect(protocolo.tipo == .denuncia)
        #expect(protocolo.protocoloCurto == "A1B2C3D4")
        #expect(protocolo.prazoRespostaAte == (try DataCivil(ano: 2026, mes: 10, dia: 25)))
    }
}
