import Foundation
import FrilaDominio
import Testing

@Suite("Domínio - Dinheiro e Valores")
struct DinheiroTests {
    @Test("Criação com valor válido em centavos, incluindo fracionados, milhar e valores grandes")
    func criacaoValida() {
        let zero = Dinheiro(centavos: 0)
        let umCentavo = Dinheiro(centavos: 1)
        let noventaENove = Dinheiro(centavos: 99)
        let cinquentaReais = Dinheiro(centavos: 5_000)
        let milhar = Dinheiro(centavos: 100_000) // R$ 1.000,00
        let valorGrande = Dinheiro(centavos: 10_000_000) // R$ 100.000,00

        #expect(zero.centavos == 0)
        #expect(umCentavo.centavos == 1)
        #expect(noventaENove.centavos == 99)
        #expect(cinquentaReais.centavos == 5_000)
        #expect(milhar.centavos == 100_000)
        #expect(valorGrande.centavos == 10_000_000)
    }

    @Test("Comparação e ordenação estrita entre quantias (Comparable)")
    func comparacaoEOrdenacao() {
        let d1 = Dinheiro(centavos: 1)
        let d99 = Dinheiro(centavos: 99)
        let d1000 = Dinheiro(centavos: 1_000)
        let d2000 = Dinheiro(centavos: 2_000)
        let d2000Outro = Dinheiro(centavos: 2_000)
        let dMilhar = Dinheiro(centavos: 100_000)

        #expect(d1 < d99)
        #expect(d99 < d1000)
        #expect(d1000 < d2000)
        #expect(!(d2000 < d1000))
        #expect(!(d2000 < d2000Outro))
        #expect(d2000 == d2000Outro)
        #expect(d2000 < dMilhar)

        let lista = [dMilhar, d2000, d1, d99, d1000]
        let ordenada = lista.sorted()
        #expect(ordenada.map(\.centavos) == [1, 99, 1_000, 2_000, 100_000])
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

        // O compilador sintetiza init(from: Decoder) que atribui a propriedade diretamente,
        // sem invocar o init(centavos: Int) que contém precondition(centavos >= 0).
        let valor = try JSONDecoder().decode(Dinheiro.self, from: json)
        #expect(valor.centavos == -1)
    }

    @Test("Formatação em moeda brasileira pt-BR com FormatadorFrila")
    func formatacaoComFormatadorFrila() {
        let formatador = FormatadorFrila()

        func validar(_ valor: Dinheiro, valorEsperado: String) {
            let formatado = formatador.dinheiro(valor)
            #expect(formatado.hasPrefix("R$"))
            #expect(formatado.contains(valorEsperado))
        }

        validar(Dinheiro(centavos: 0), valorEsperado: "0,00")
        validar(Dinheiro(centavos: 1), valorEsperado: "0,01")
        validar(Dinheiro(centavos: 99), valorEsperado: "0,99")
        validar(Dinheiro(centavos: 10_000), valorEsperado: "100,00")
        validar(Dinheiro(centavos: 12_345), valorEsperado: "123,45")
        validar(Dinheiro(centavos: 100_000), valorEsperado: "1.000,00")
        validar(Dinheiro(centavos: 5_000_000), valorEsperado: "50.000,00")
    }
}
