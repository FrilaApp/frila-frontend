import Foundation
import FrilaDominio
import Testing

@Suite("Domínio - Dinheiro e Valores")
struct DinheiroTests {
    @Test("Criação com valor válido em centavos e representação básica")
    func criacaoValida() {
        let zero = Dinheiro(centavos: 0)
        let cinquenta = Dinheiro(centavos: 5_000)
        let centoEVinte = Dinheiro(centavos: 12_000)

        #expect(zero.centavos == 0)
        #expect(cinquenta.centavos == 5_000)
        #expect(centoEVinte.centavos == 12_000)
    }

    @Test("Comparação e ordenação estrita entre quantias (Comparable)")
    func comparacaoEOrdenacao() {
        let d10 = Dinheiro(centavos: 1_000)
        let d20 = Dinheiro(centavos: 2_000)
        let d20Outro = Dinheiro(centavos: 2_000)

        #expect(d10 < d20)
        #expect(!(d20 < d10))
        #expect(!(d20 < d20Outro))
        #expect(d20 == d20Outro)

        let lista = [d20, d10, Dinheiro(centavos: 500)]
        let ordenada = lista.sorted()
        #expect(ordenada.map(\.centavos) == [500, 1_000, 2_000])
    }

    @Test("Conformidade com Hashable, Set e dicionários")
    func hashableESets() {
        let v1 = Dinheiro(centavos: 15_000)
        let v2 = Dinheiro(centavos: 15_000)
        let v3 = Dinheiro(centavos: 18_000)

        let set: Set<Dinheiro> = [v1, v2, v3]
        #expect(set.count == 2)
        #expect(set.contains(v1))
        #expect(set.contains(v3))

        var dicionario: [Dinheiro: String] = [:]
        dicionario[v1] = "Diária padrão"
        dicionario[v3] = "Diária especial"
        #expect(dicionario[v2] == "Diária padrão")
        #expect(dicionario[v3] == "Diária especial")
    }

    @Test("Codificação e decodificação JSON estruturada (Codable)")
    func serializacaoJSON() throws {
        let original = Dinheiro(centavos: 25_500)
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let jsonString = String(decoding: data, as: UTF8.self)
        #expect(jsonString.contains("\"centavos\":25500") || jsonString.contains("\"centavos\": 25500"))

        let decoder = JSONDecoder()
        let decodificado = try decoder.decode(Dinheiro.self, from: data)

        #expect(decodificado == original)
        #expect(decodificado.centavos == 25_500)
    }

    @Test("Decodificação a partir de JSON bruto com integridade de centavos")
    func decodificacaoBruta() throws {
        let json = """
        { "centavos": 8900 }
        """.data(using: .utf8)!

        let valor = try JSONDecoder().decode(Dinheiro.self, from: json)
        #expect(valor.centavos == 8_900)
        #expect(valor == Dinheiro(centavos: 8_900))
    }

    @Test("Decodificação de centavos negativos por JSON burla a precondition do init")
    func decodificacaoNegativaBurlaPrecondition() throws {
        let json = """
        { "centavos": -1 }
        """.data(using: .utf8)!

        // O compilador sintetiza init(from: Decoder) sem invocar o init(centavos: Int).
        // Isso permite que centavos negativos sejam decodificados a partir de payload JSON externo.
        let valor = try JSONDecoder().decode(Dinheiro.self, from: json)
        #expect(valor.centavos == -1)
    }

    @Test("Formatação em moeda brasileira com FormatadorFrila")
    func formatacaoComFormatadorFrila() {
        let formatador = FormatadorFrila()
        let zero = Dinheiro(centavos: 0)
        let cemReais = Dinheiro(centavos: 10_000)
        let quebrado = Dinheiro(centavos: 12_345)

        // Limpa espaços não separáveis para asserção portável entre locales
        func normalizar(_ s: String) -> String {
            s.replacingOccurrences(of: "\u{00A0}", with: " ")
        }

        #expect(normalizar(formatador.dinheiro(zero)) == "R$ 0,00")
        #expect(normalizar(formatador.dinheiro(cemReais)) == "R$ 100,00")
        #expect(normalizar(formatador.dinheiro(quebrado)) == "R$ 123,45")
    }
}
