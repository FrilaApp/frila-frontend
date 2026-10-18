@testable import FrilaApresentacao
@testable import FrilaDados
import Foundation
import FrilaDominio
import Testing

@Suite("Domínio - Categoria do Chamado de Suporte (Contrato 0.2.40, UC14)")
struct CategoriaSuporteTests {

    // MARK: - Decodificação Canônica

    @Test("Decodificação canônica dos 5 casos oficiais do contrato OpenAPI")
    func decodificacaoCanonicaDeTodasAsCategorias() throws {
        let casos: [(String, CategoriaSuporte)] = [
            ("\"endereco\"", .endereco),
            ("\"atraso\"", .atraso),
            ("\"conduta\"", .conduta),
            ("\"seguranca\"", .seguranca),
            ("\"outro\"", .outro)
        ]

        let decoder = JSONDecoder()
        for (json, esperado) in casos {
            let data = try #require(json.data(using: .utf8))
            let decodificado = try decoder.decode(CategoriaSuporte.self, from: data)
            #expect(decodificado == esperado)
            #expect(decodificado.rawValue == esperado.rawValue)
        }
    }

    @Test("Completude: todos os casos de CategoriaSuporte possuem rawValue canônico mapeado")
    func completudeDeCasos() {
        let esperados: Set<String> = ["endereco", "atraso", "conduta", "seguranca", "outro"]
        let rawValues = Set(CategoriaSuporte.allCases.map(\.rawValue))
        #expect(rawValues == esperados)
        #expect(CategoriaSuporte.allCases.count == 5)
    }

    // MARK: - Decodificação Defensiva e Fallback

    @Test(
        "Decodificação defensiva: categoria desconhecida, legada ou futura faz fallback para .outro sem derrubar o app",
        arguments: ["pagamento", "assedio", "infraestrutura", "novo_motivo_v2", "", "arbitrario_xyz"]
    )
    func fallbackResilienteParaOutro(categoriaDesconhecida: String) throws {
        let json = "\"\(categoriaDesconhecida)\""
        let data = try #require(json.data(using: .utf8))
        let decodificado = try JSONDecoder().decode(CategoriaSuporte.self, from: data)
        #expect(decodificado == .outro)
    }

    @Test(
        "Decodificação recusa payloads que não sejam string com DecodingError",
        arguments: ["123", "true", "[]", "{}"]
    )
    func recusaTiposInvalidos(jsonInvalido: String) {
        let data = jsonInvalido.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(CategoriaSuporte.self, from: data)
        }
    }

    // MARK: - Codificação e Envio ao Contrato

    @Test("Codificação preserva a string exata exigida pelo contrato OpenAPI")
    func codificacaoPreservaFormatoDoContrato() throws {
        let encoder = JSONEncoder()
        for categoria in CategoriaSuporte.allCases {
            let dados = try encoder.encode(categoria)
            let texto = try #require(String(data: dados, encoding: .utf8))
            #expect(texto == "\"\(categoria.rawValue)\"")
        }
    }

    @Test("DTO AbrirSuporte serializa categoria exatamente no padrão da RPC")
    func dtoAbrirSuporteSerializaCorretamente() throws {
        let turnoID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let chave = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!

        for categoria in CategoriaSuporte.allCases {
            let dto = ContratoAPI.AbrirSuporte(turnoID: turnoID, categoria: categoria, chave: chave)
            let dados = try JSONEncoder().encode(dto)
            let json = try #require(JSONSerialization.jsonObject(with: dados) as? [String: Any])

            #expect(json["turno_id"] as? String == turnoID.uuidString)
            #expect(json["chave"] as? String == chave.uuidString)
            #expect(json["categoria"] as? String == categoria.rawValue)
        }
    }

    // MARK: - Mapeamento da Interface (MotivoSuporteTurno -> CategoriaSuporte)

    @Test("Mapeamento dos motivos de interface para as categorias contratuais oficiais")
    func mapeamentoMotivoParaCategoriaContratual() {
        let mapeamentos: [(MotivoSuporteTurno, CategoriaSuporte)] = [
            (.riscoSeguranca, .seguranca),
            (.atrasoOuImprevisto, .atraso),
            (.problemaNoLocal, .endereco),
            (.dificuldadePresenca, .conduta),
            (.outro, .outro)
        ]

        for (motivo, categoriaEsperada) in mapeamentos {
            #expect(motivo.categoriaSuporte == categoriaEsperada)
        }
    }
}
