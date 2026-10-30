import Foundation
import FrilaDominio
@testable import FrilaApresentacao
import Testing

@Suite("LOG-017: data e modo do cartão")
struct FormatoCartaoVagaTests {
    private var calendario: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return cal
    }
    private var agora: Date {
        calendario.nextDate(after: .now, matching: DateComponents(hour: 12, weekday: 5), matchingPolicy: .nextTime)!
    }
    private func diaMes(_ data: Date) -> String {
        String(format: "%02d/%02d", calendario.component(.day, from: data), calendario.component(.month, from: data))
    }

    @Test("Hoje, amanhã e oito dias têm datas distintas", arguments: [0, 1, 8])
    func dataCompleta(dias: Int) throws {
        let base = agora
        let dia = calendario.date(byAdding: .day, value: dias, to: base)!
        let inicio = calendario.date(bySettingHour: 20, minute: 18, second: 0, of: dia)!
        let periodo = try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(2 * 3600))
        let prefixo = dias == 0 ? "Hoje, qui." : dias == 1 ? "Amanhã, sex." : "sex."
        #expect(FormatoDataVaga.cartao(periodo, agora: base) == "\(prefixo) \(diaMes(inicio)), 20h18 às 22h18")
    }

    @Test("Janela que cruza meia-noite informa dia e data do fim")
    func cruzaMeiaNoite() throws {
        let base = agora
        let dia = calendario.date(byAdding: .day, value: 1, to: base)!
        let inicio = calendario.date(bySettingHour: 20, minute: 18, second: 0, of: dia)!
        let fim = inicio.addingTimeInterval(4 * 3600)
        let periodo = try Periodo(inicio: inicio, fim: fim)
        #expect(FormatoDataVaga.cartao(periodo, agora: base) == "Amanhã, sex. \(diaMes(inicio)), 20h18 às 00h18, termina sáb. \(diaMes(fim))")
        #expect(FormatoDataVaga.hora(fim) == "00h18")
        #expect(FormatoDataVaga.apoioPreco(inicio, agora: base) == "por pessoa, amanhã 20h18")
    }

    @Test("Hora cheia mantém a grafia compartilhada do detalhe")
    func horaCheia() {
        let hora = calendario.date(bySettingHour: 20, minute: 0, second: 0, of: agora)!
        #expect(FormatoDataVaga.hora(hora) == "20h")
    }

    @Test("Seleção só vira urgência dentro de 24 h com posição aberta", arguments: [23, 24, 25], [0, 2])
    func modoEfetivo(horas: Int, posicoes: Int) {
        let base = agora
        let inicio = base.addingTimeInterval(Double(horas) * 3600)
        let esperado: ModoPreenchimento = horas <= 24 && posicoes > 0 ? .urgencia : .selecao
        #expect(FormatoDataVaga.modoEfetivo(modo: .selecao, posicoesAbertas: posicoes, inicio: inicio, agora: base) == esperado)
    }
}
