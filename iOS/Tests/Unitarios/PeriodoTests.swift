import Foundation
import FrilaDominio
import Testing

@Suite("Domínio - Período e Validação Temporal")
struct PeriodoTests {
    @Test("Criação com fim posterior ao início é aceita")
    func criacaoValida() throws {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let umaHoraDepois = base.addingTimeInterval(3_600)

        let periodo = try Periodo(inicio: base, fim: umaHoraDepois)
        #expect(periodo.inicio == base)
        #expect(periodo.fim == umaHoraDepois)
    }

    @Test("Criação com fim igual ao início lança ErroPeriodo.fimNaoPosteriorAoInicio")
    func criacaoComFimIgualAoInicio() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        #expect(throws: ErroPeriodo.fimNaoPosteriorAoInicio) {
            try Periodo(inicio: base, fim: base)
        }
    }

    @Test("Criação com fim anterior ao início lança ErroPeriodo.fimNaoPosteriorAoInicio")
    func criacaoComFimAnteriorAoInicio() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let antes = base.addingTimeInterval(-3_600)

        #expect(throws: ErroPeriodo.fimNaoPosteriorAoInicio) {
            try Periodo(inicio: base, fim: antes)
        }
    }

    @Test("Intervalos semiabertos: turnos adjacentes não sobrepõem")
    func adjacentesNaoSobrepoem() throws {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let t1 = try Periodo(inicio: base, fim: base.addingTimeInterval(3_600)) // [0, 3600)
        let t2 = try Periodo(inicio: t1.fim, fim: t1.fim.addingTimeInterval(3_600)) // [3600, 7200)

        #expect(!t1.sobrepoe(t2))
        #expect(!t2.sobrepoe(t1))
    }

    @Test("Intervalos que compartilham tempo sobrepõem")
    func sobreposicoesDiversas() throws {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let tPrincipal = try Periodo(inicio: base, fim: base.addingTimeInterval(7_200)) // [0, 7200)

        // 1. Sobreposição parcial no início
        let parcialInicio = try Periodo(inicio: base.addingTimeInterval(-1_800), fim: base.addingTimeInterval(1_800))
        #expect(tPrincipal.sobrepoe(parcialInicio))
        #expect(parcialInicio.sobrepoe(tPrincipal))

        // 2. Sobreposição parcial no fim
        let parcialFim = try Periodo(inicio: base.addingTimeInterval(5_400), fim: base.addingTimeInterval(9_000))
        #expect(tPrincipal.sobrepoe(parcialFim))
        #expect(parcialFim.sobrepoe(tPrincipal))

        // 3. Contido totalmente dentro
        let interno = try Periodo(inicio: base.addingTimeInterval(1_800), fim: base.addingTimeInterval(5_400))
        #expect(tPrincipal.sobrepoe(interno))
        #expect(interno.sobrepoe(tPrincipal))

        // 4. Totalmente fora antes
        let foraAntes = try Periodo(inicio: base.addingTimeInterval(-7_200), fim: base.addingTimeInterval(-3_600))
        #expect(!tPrincipal.sobrepoe(foraAntes))

        // 5. Totalmente fora depois
        let foraDepois = try Periodo(inicio: base.addingTimeInterval(10_800), fim: base.addingTimeInterval(14_400))
        #expect(!tPrincipal.sobrepoe(foraDepois))
    }

    @Test("Codificação e decodificação JSON preserva instantes exatos")
    func serializacaoJSON() throws {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let original = try Periodo(inicio: base, fim: base.addingTimeInterval(14_400))

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decodificado = try decoder.decode(Periodo.self, from: data)

        #expect(decodificado == original)
        #expect(decodificado.inicio == original.inicio)
        #expect(decodificado.fim == original.fim)
    }
}
