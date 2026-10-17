import Foundation
import FrilaDominio
import Testing

@Suite("Formatação Brasil e São Paulo")
struct FormatadorTests {
    @Test("Valor é BRL pt-BR")
    func moeda() {
        let resultado = FormatadorFrila().dinheiro(Dinheiro(centavos: 12345))
        #expect(resultado.contains("123,45"))
        #expect(resultado.contains("R$"))
    }

    @Test("Distância formatada em km no padrão pt-BR")
    func distancia() {
        let formatador = FormatadorFrila()
        #expect(formatador.distancia(2.5) == "2,5 km")
        #expect(formatador.distancia(10.0) == "10 km")
        #expect(formatador.distancia(0) == "0 km")
        #expect(formatador.distancia(12.34) == "12,3 km")
    }

    @Test("Intervalo atravessando meia-noite mostra os dois dias")
    func intervaloNoturno() throws {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = FormatadorFrila.fuso
        let inicio = try #require(calendario.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 23)))
        let fim = try #require(calendario.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: 3)))
        #expect(FormatadorFrila().intervalo(try Periodo(inicio: inicio, fim: fim)) == "sex 23:00 – sáb 03:00")
    }

    @Test("Dia operacional independe do fuso configurado no aparelho")
    func fusoFixo() throws {
        let instante = try #require(ISO8601DateFormatter().date(from: "2026-09-26T02:30:00Z"))
        let componentes = FormatadorFrila().diaDeSaoPaulo(instante)
        #expect(componentes.day == 25)
    }

    @Test("Hora e minuto no fuso de São Paulo (24h)")
    func horaNoFusoDeSaoPaulo() throws {
        let formatador = FormatadorFrila()
        let instante1 = try #require(ISO8601DateFormatter().date(from: "2026-10-17T18:30:00Z"))
        #expect(formatador.hora(instante1) == "15:30")

        let instante2 = try #require(ISO8601DateFormatter().date(from: "2026-10-18T01:15:00Z"))
        #expect(formatador.hora(instante2) == "22:15")
    }

    @Test("Data civil formatada no padrão brasileiro dd/MM/yyyy")
    func dataCivilFormatadaPadraoBrasileiro() throws {
        let formatador = FormatadorFrila()
        #expect(formatador.data(try DataCivil(ano: 2026, mes: 10, dia: 8)) == "08/10/2026")
        #expect(formatador.data(try DataCivil(ano: 2026, mes: 3, dia: 5)) == "05/03/2026")
        #expect(formatador.data(try DataCivil(ano: 2027, mes: 1, dia: 1)) == "01/01/2027")
    }

    @Test("Data a partir de instante Date formatada em dd/MM/yyyy no fuso de São Paulo")
    func dataInstanteNoFusoDeSaoPaulo() throws {
        let formatador = FormatadorFrila()
        // 01:30 UTC do dia 18 ainda é 22:30 do dia 17 em São Paulo (UTC-3)
        let instanteAntesMeiaNoite = try #require(ISO8601DateFormatter().date(from: "2026-10-18T01:30:00Z"))
        #expect(formatador.data(instanteAntesMeiaNoite) == "17/10/2026")

        // 03:00 UTC do dia 18 é exatamente 00:00 do dia 18 em São Paulo
        let instanteMeiaNoite = try #require(ISO8601DateFormatter().date(from: "2026-10-18T03:00:00Z"))
        #expect(formatador.data(instanteMeiaNoite) == "18/10/2026")
    }

    @Test("Data e hora completas formatadas no padrão dd/MM/yyyy 'às' HH:mm em São Paulo")
    func dataEHoraCompleta() throws {
        let formatador = FormatadorFrila()
        let instante = try #require(ISO8601DateFormatter().date(from: "2026-10-08T18:00:00Z"))
        #expect(formatador.dataEHora(instante) == "08/10/2026 às 15:00")

        let instanteNoturno = try #require(ISO8601DateFormatter().date(from: "2026-10-18T02:45:00Z"))
        #expect(formatador.dataEHora(instanteNoturno) == "17/10/2026 às 23:45")
    }

    @Test("janelaParaContrato decompõe dia da semana e horários contratuais")
    func janelaParaContrato() throws {
        let formatador = FormatadorFrila()
        let janela = JanelaDeDisponibilidade(
            diaDaSemana: 0,
            inicio: try HoraDoDia("09:00"),
            fim: try HoraDoDia("18:30")
        )
        let tupla = formatador.janelaParaContrato(janela)
        #expect(tupla.diaSemana == 0)
        #expect(tupla.inicio == "09:00")
        #expect(tupla.fim == "18:30")
    }
}
