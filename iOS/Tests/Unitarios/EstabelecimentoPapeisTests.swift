import Foundation
import FrilaDominio
import Testing

@Suite("Domínio - Tipo de Estabelecimento e Papel de Membro (Contrato, UC01, Permissões)")
struct EstabelecimentoPapeisTests {

    // MARK: - TipoEstabelecimento - Decodificação Canônica e Completude

    @Test("Decodificação canônica dos 6 tipos oficiais de estabelecimento")
    func decodificacaoCanonicaTipoEstabelecimento() throws {
        let casos: [(String, TipoEstabelecimento)] = [
            ("\"food_service\"", .foodService),
            ("\"evento\"", .evento),
            ("\"varejo\"", .varejo),
            ("\"logistica\"", .logistica),
            ("\"servico_domestico\"", .servicoDomestico),
            ("\"outro\"", .outro)
        ]

        let decoder = JSONDecoder()
        for (json, esperado) in casos {
            let data = try #require(json.data(using: .utf8))
            let decodificado = try decoder.decode(TipoEstabelecimento.self, from: data)
            #expect(decodificado == esperado)
            #expect(decodificado.rawValue == esperado.rawValue)
        }
    }

    @Test("Completude: todos os casos de TipoEstabelecimento possuem rawValue canônico mapeado")
    func completudeTipoEstabelecimento() {
        let esperados: Set<String> = [
            "food_service", "evento", "varejo", "logistica", "servico_domestico", "outro"
        ]
        let rawValues = Set(TipoEstabelecimento.allCases.map(\.rawValue))
        #expect(rawValues == esperados)
        #expect(TipoEstabelecimento.allCases.count == 6)
    }

    // MARK: - TipoEstabelecimento - Fallback Defensivo

    @Test(
        "Decodificação defensiva de TipoEstabelecimento: tipo novo ou desconhecido cai em .outro",
        arguments: ["hotelaria", "clinica", "educacao", "tipo_futuro_v3", "", "arbitrario_xyz"]
    )
    func fallbackResilienteTipoEstabelecimento(tipoDesconhecido: String) throws {
        let json = "\"\(tipoDesconhecido)\""
        let data = try #require(json.data(using: .utf8))
        let decodificado = try JSONDecoder().decode(TipoEstabelecimento.self, from: data)
        #expect(decodificado == .outro)
    }

    @Test(
        "Decodificação de TipoEstabelecimento recusa payloads que não sejam string",
        arguments: ["123", "true", "[]", "{}"]
    )
    func recusaTiposInvalidosTipoEstabelecimento(jsonInvalido: String) {
        let data = jsonInvalido.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TipoEstabelecimento.self, from: data)
        }
    }

    @Test("Codificação de TipoEstabelecimento preserva snake_case exato do contrato")
    func codificacaoTipoEstabelecimento() throws {
        let encoder = JSONEncoder()
        for tipo in TipoEstabelecimento.allCases {
            let dados = try encoder.encode(tipo)
            let texto = try #require(String(data: dados, encoding: .utf8))
            #expect(texto == "\"\(tipo.rawValue)\"")
        }
    }

    // MARK: - PapelMembro - Decodificação Canônica e Segurança

    @Test("Decodificação canônica dos papéis oficiais de membro")
    func decodificacaoCanonicaPapelMembro() throws {
        let casos: [(String, PapelMembro)] = [
            ("\"administrador\"", .administrador),
            ("\"operador\"", .operador)
        ]

        let decoder = JSONDecoder()
        for (json, esperado) in casos {
            let data = try #require(json.data(using: .utf8))
            let decodificado = try decoder.decode(PapelMembro.self, from: data)
            #expect(decodificado == esperado)
            #expect(decodificado.rawValue == esperado.rawValue)
        }
    }

    @Test("Completude: todos os casos de PapelMembro possuem rawValue canônico mapeado")
    func completudePapelMembro() {
        let esperados: Set<String> = ["administrador", "operador"]
        let rawValues = Set(PapelMembro.allCases.map(\.rawValue))
        #expect(rawValues == esperados)
        #expect(PapelMembro.allCases.count == 2)
    }

    @Test(
        "Segurança de permissões: papel novo ou desconhecido do contrato cai obrigatoriamente em .operador (menor privilégio)",
        arguments: ["proprietario", "gerente", "supervisor", "auditor", "superadmin", "", "desconhecido"]
    )
    func segurancaMenorPrivilegioPapelMembro(papelDesconhecido: String) throws {
        let json = "\"\(papelDesconhecido)\""
        let data = try #require(json.data(using: .utf8))
        let decodificado = try JSONDecoder().decode(PapelMembro.self, from: data)
        #expect(decodificado == .operador, "Papel desconhecido deve cair em .operador para nunca conceder permissão administrativa indevida na interface")
    }

    @Test(
        "Decodificação de PapelMembro recusa payloads que não sejam string",
        arguments: ["123", "true", "[]", "{}"]
    )
    func recusaTiposInvalidosPapelMembro(jsonInvalido: String) {
        let data = jsonInvalido.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(PapelMembro.self, from: data)
        }
    }

    @Test("Codificação de PapelMembro preserva os valores exatos do contrato")
    func codificacaoPapelMembro() throws {
        let encoder = JSONEncoder()
        for papel in PapelMembro.allCases {
            let dados = try encoder.encode(papel)
            let texto = try #require(String(data: dados, encoding: .utf8))
            #expect(texto == "\"\(papel.rawValue)\"")
        }
    }

    // MARK: - Estabelecimento - Decodificação Integrada

    @Test("Estabelecimento decodifica corretamente todos os campos com papéis e tipos canônicos")
    func decodificacaoEstabelecimentoCompleto() throws {
        let json = """
        {
            "id": "11111111-2222-3333-4444-555555555555",
            "nome": "Restaurante Central",
            "documento": "12.345.678/0001-90",
            "tipo": "food_service",
            "endereco": "SCS Quadra 2 Bloco C",
            "regiaoAdministrativa": "Plano Piloto",
            "ponto": {
                "latitude": -15.7942,
                "longitude": -47.8822
            },
            "papel": "administrador"
        }
        """
        let data = try #require(json.data(using: .utf8))
        let estab = try JSONDecoder().decode(Estabelecimento.self, from: data)

        #expect(estab.id == UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        #expect(estab.nome == "Restaurante Central")
        #expect(estab.documento == "12.345.678/0001-90")
        #expect(estab.tipo == .foodService)
        #expect(estab.endereco == "SCS Quadra 2 Bloco C")
        #expect(estab.regiaoAdministrativa == "Plano Piloto")
        #expect(estab.ponto.latitude == -15.7942)
        #expect(estab.ponto.longitude == -47.8822)
        #expect(estab.papel == .administrador)
    }

    @Test("Estabelecimento com tipo desconhecido e papel desconhecido faz fallback defensivo integrado")
    func decodificacaoEstabelecimentoComFallbacks() throws {
        let json = """
        {
            "id": "22222222-3333-4444-5555-666666666666",
            "nome": "Complexo Hospitalar",
            "documento": "98.765.432/0001-10",
            "tipo": "hospital",
            "endereco": "Setor Hospitalar Sul",
            "regiaoAdministrativa": "Plano Piloto",
            "ponto": {
                "latitude": -15.8000,
                "longitude": -47.8900
            },
            "papel": "diretor_geral"
        }
        """
        let data = try #require(json.data(using: .utf8))
        let estab = try JSONDecoder().decode(Estabelecimento.self, from: data)

        #expect(estab.tipo == .outro, "Tipo novo no contrato 'hospital' deve decodificar como .outro")
        #expect(estab.papel == .operador, "Papel desconhecido 'diretor_geral' deve decodificar como .operador por princípio do menor privilégio")
    }
}
