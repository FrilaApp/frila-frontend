import Foundation
import FrilaDominio
import Testing

@Suite("Janela de Disponibilidade")
struct JanelaDeDisponibilidadeTests {
    @Test("Inicialização com dia da semana de 0 a 6")
    func diasDaSemanaValidos() throws {
        let inicio = try HoraDoDia("08:00")
        let fim = try HoraDoDia("17:00")

        for dia in 0...6 {
            let janela = JanelaDeDisponibilidade(diaDaSemana: dia, inicio: inicio, fim: fim)
            #expect(janela.diaDaSemana == dia)
            #expect(janela.inicio == inicio)
            #expect(janela.fim == fim)
        }
    }

    @Test("Propriedade atravessaMeiaNoite identifica turnos diurnos e noturnos")
    func atravessaMeiaNoite() throws {
        let manhaInicio = try HoraDoDia("08:00")
        let tardeFim = try HoraDoDia("17:00")
        let janelaDiurna = JanelaDeDisponibilidade(diaDaSemana: 1, inicio: manhaInicio, fim: tardeFim)
        #expect(!janelaDiurna.atravessaMeiaNoite, "08:00 às 17:00 não atravessa meia-noite")

        let noiteInicio = try HoraDoDia("18:00")
        let madrugadaFim = try HoraDoDia("02:00")
        let janelaNoturna = JanelaDeDisponibilidade(diaDaSemana: 5, inicio: noiteInicio, fim: madrugadaFim)
        #expect(janelaNoturna.atravessaMeiaNoite, "18:00 às 02:00 atravessa meia-noite")

        let inicioTarde = try HoraDoDia("23:30")
        let fimMadrugada = try HoraDoDia("06:00")
        let janelaMadrugada = JanelaDeDisponibilidade(diaDaSemana: 6, inicio: inicioTarde, fim: fimMadrugada)
        #expect(janelaMadrugada.atravessaMeiaNoite, "23:30 às 06:00 atravessa meia-noite")

        let mesmoHorario = try HoraDoDia("12:00")
        let janelaMesmoHorario = JanelaDeDisponibilidade(diaDaSemana: 3, inicio: mesmoHorario, fim: mesmoHorario)
        #expect(janelaMesmoHorario.atravessaMeiaNoite, "12:00 às 12:00 é tratado como atravessando meia-noite (fim <= inicio)")
    }

    @Test("Roundtrip de codificação e decodificação JSON (Codable)")
    func roundtripCodable() throws {
        let inicio = try HoraDoDia("19:30")
        let fim = try HoraDoDia("03:30")
        let original = JanelaDeDisponibilidade(diaDaSemana: 4, inicio: inicio, fim: fim)

        let dados = try JSONEncoder().encode(original)
        let decodificado = try JSONDecoder().decode(JanelaDeDisponibilidade.self, from: dados)

        #expect(decodificado == original)
        #expect(decodificado.diaDaSemana == 4)
        #expect(decodificado.inicio.contrato == "19:30")
        #expect(decodificado.fim.contrato == "03:30")
        #expect(decodificado.atravessaMeiaNoite)
    }

    @Test("Igualdade estrutural (Equatable) e comportamento em coleção hash (Hashable)")
    func equatableEHashable() throws {
        let h08 = try HoraDoDia("08:00")
        let h12 = try HoraDoDia("12:00")
        let h18 = try HoraDoDia("18:00")

        let j1 = JanelaDeDisponibilidade(diaDaSemana: 1, inicio: h08, fim: h12)
        let j2 = JanelaDeDisponibilidade(diaDaSemana: 1, inicio: h08, fim: h12)
        let jDiaDiferente = JanelaDeDisponibilidade(diaDaSemana: 2, inicio: h08, fim: h12)
        let jFimDiferente = JanelaDeDisponibilidade(diaDaSemana: 1, inicio: h08, fim: h18)
        let jInicioDiferente = JanelaDeDisponibilidade(diaDaSemana: 1, inicio: h12, fim: h18)

        #expect(j1 == j2)
        #expect(j1 != jDiaDiferente)
        #expect(j1 != jFimDiferente)
        #expect(j1 != jInicioDiferente)

        var conjunto: Set<JanelaDeDisponibilidade> = []
        conjunto.insert(j1)
        conjunto.insert(j2)
        conjunto.insert(jDiaDiferente)

        #expect(conjunto.count == 2, "conjunto deve deduplicar instâncias idênticas")
        #expect(conjunto.contains(j1))
        #expect(conjunto.contains(jDiaDiferente))
    }

    @Test("Conversão de janela para parâmetros do contrato da API via FormatadorFrila")
    func formatadorJanelaParaContrato() throws {
        let inicio = try HoraDoDia("20:00")
        let fim = try HoraDoDia("04:00")
        let janela = JanelaDeDisponibilidade(diaDaSemana: 6, inicio: inicio, fim: fim)

        let formatador = FormatadorFrila()
        let tuplaContrato = formatador.janelaParaContrato(janela)

        #expect(tuplaContrato.diaSemana == 6)
        #expect(tuplaContrato.inicio == "20:00")
        #expect(tuplaContrato.fim == "04:00")
    }
}
