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
}
