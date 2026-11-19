import Foundation
@testable import FrilaApresentacao
import Testing

/// O horário do turno num formato só no lado da casa (R8b, D-12).
struct FormatoDeHorarioDoTurnoTests {
    private func instante(_ iso: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: iso))
    }

    @Test("O horário vem como \"06:30 às 09:30\", no fuso de São Paulo")
    func horario() throws {
        // 06:30 e 09:30 em São Paulo (UTC-3) são 09:30 e 12:30 em UTC.
        let inicio = try instante("2026-11-18T09:30:00Z")
        let fim = try instante("2026-11-18T12:30:00Z")
        #expect(FormatoDeHorarioDoTurno().horario(inicio: inicio, fim: fim) == "06:30 às 09:30")
    }

    @Test("Com o dia vem como \"Qua, 18/11, 06:30 às 09:30\"")
    func comDia() throws {
        let inicio = try instante("2026-11-18T09:30:00Z")
        let fim = try instante("2026-11-18T12:30:00Z")
        #expect(FormatoDeHorarioDoTurno().comDia(inicio: inicio, fim: fim) == "Qua, 18/11, 06:30 às 09:30")
    }

    @Test("O dia é o de São Paulo, não o de UTC: 22:30 de quarta em São Paulo já é quinta em UTC")
    func diaDeSaoPauloDiferenteDeUTC() throws {
        let inicio = try instante("2026-11-19T01:30:00Z") // quarta 18/11, 22:30 em São Paulo
        let fim = try instante("2026-11-19T05:30:00Z") // quinta 19/11, 02:30 em São Paulo
        let texto = FormatoDeHorarioDoTurno().comDia(inicio: inicio, fim: fim)
        #expect(texto == "Qua, 18/11, 22:30 às 02:30")
    }

    @Test("Um instante só vem como \"Qua, 18/11, 06:30\", com espaço para quebrar a linha em texto grande")
    func instanteComDia() throws {
        let momento = try instante("2026-11-18T09:30:00Z")
        #expect(FormatoDeHorarioDoTurno().instanteComDia(momento) == "Qua, 18/11, 06:30")
    }
}
