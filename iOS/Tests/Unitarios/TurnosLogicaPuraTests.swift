import Foundation
@testable import FrilaApresentacao
import FrilaDominio
import Testing

@Suite("K-002 · Testes de Lógica Pura e Formatação de Turnos")
struct TurnosLogicaPuraTests {

    // MARK: - 1. FrilaShiftClock

    @Test("FrilaShiftClock normaliza valores de hora e minuto dentro de 0..<1440")
    func relogioDoTurnoNormalizacao() {
        let relogioPadrao = FrilaShiftClock(hour: 18, minute: 30)
        #expect(relogioPadrao.minutes == 18 * 60 + 30)
        #expect(relogioPadrao.hour == 18)
        #expect(relogioPadrao.minute == 30)

        // Hora maior que 24h dá a volta no relógio (módulo 1440)
        let relogioUltrapassa = FrilaShiftClock(hour: 25, minute: 15)
        #expect(relogioUltrapassa.minutes == 1 * 60 + 15)
        #expect(relogioUltrapassa.hour == 1)
        #expect(relogioUltrapassa.minute == 15)

        // Hora negativa dá a volta para o final do dia
        let relogioNegativo = FrilaShiftClock(hour: -1, minute: 0)
        #expect(relogioNegativo.minutes == 23 * 60)
        #expect(relogioNegativo.hour == 23)
        #expect(relogioNegativo.minute == 0)

        // Meia-noite exata
        let meiaNoite = FrilaShiftClock(hour: 0, minute: 0)
        #expect(meiaNoite.minutes == 0)
        #expect(meiaNoite.hour == 0)
        #expect(meiaNoite.minute == 0)
    }

    @Test("FrilaShiftClock gera rótulos de campo, rótulos curtos e ordenação")
    func relogioDoTurnoRotulosEOrdem() {
        let inicio = FrilaShiftClock(hour: 8, minute: 5)
        #expect(inicio.fieldLabel == "08:05")
        #expect(inicio.shortLabel == "08h05")

        let horaCheia = FrilaShiftClock(hour: 18, minute: 0)
        #expect(horaCheia.fieldLabel == "18:00")
        #expect(horaCheia.shortLabel == "18h")

        let fim = FrilaShiftClock(hour: 19, minute: 0)
        #expect(inicio < fim)
        #expect(!(fim < inicio))

        // Opções de passo padrão geram 48 intervalos de 30 minutos
        let opcoes = FrilaShiftClock.options(stepMinutes: 30)
        #expect(opcoes.count == 48)
        #expect(opcoes.first?.fieldLabel == "00:00")
        #expect(opcoes.last?.fieldLabel == "23:30")
    }

    @Test("FrilaShiftClock gera spokenLabel fonético para VoiceOver")
    func relogioDoTurnoSpokenLabel() {
        #expect(FrilaShiftClock(hour: 0, minute: 0).spokenLabel == "meia-noite")
        #expect(FrilaShiftClock(hour: 1, minute: 0).spokenLabel == "1 hora")
        #expect(FrilaShiftClock(hour: 2, minute: 0).spokenLabel == "2 horas")
        #expect(FrilaShiftClock(hour: 1, minute: 30).spokenLabel == "1 hora e 30 minutos")
        #expect(FrilaShiftClock(hour: 18, minute: 45).spokenLabel == "18 horas e 45 minutos")
    }

    // MARK: - 2. FrilaShiftWindow

    @Test("FrilaShiftWindow calcula duração e detecta travessia de meia-noite")
    func janelaDoTurnoCalculosEDuracao() {
        // Turno diurno: 08:00 às 17:00 (9 horas = 540 minutos)
        let janelaDiurna = FrilaShiftWindow(
            start: FrilaShiftClock(hour: 8, minute: 0),
            end: FrilaShiftClock(hour: 17, minute: 0)
        )
        #expect(janelaDiurna.isValid)
        #expect(!janelaDiurna.crossesMidnight)
        #expect(janelaDiurna.durationMinutes == 540)
        #expect(janelaDiurna.rangeLabel == "08h às 17h")
        #expect(janelaDiurna.spokenRange == "das 8 horas às 17 horas")

        // Turno noturno atravessando meia-noite: 18:00 às 02:00 (8 horas = 480 minutos)
        let janelaNoturna = FrilaShiftWindow(
            start: FrilaShiftClock(hour: 18, minute: 0),
            end: FrilaShiftClock(hour: 2, minute: 0)
        )
        #expect(janelaNoturna.isValid)
        #expect(janelaNoturna.crossesMidnight)
        #expect(janelaNoturna.durationMinutes == 480)
        #expect(janelaNoturna.rangeLabel == "18h às 02h")
        #expect(janelaNoturna.spokenRange == "das 18 horas às 2 horas")

        // Início e fim iguais é inválido
        let janelaInvalida = FrilaShiftWindow(
            start: FrilaShiftClock(hour: 12, minute: 0),
            end: FrilaShiftClock(hour: 12, minute: 0)
        )
        #expect(!janelaInvalida.isValid)
        #expect(janelaInvalida.crossesMidnight)
    }

    // MARK: - 3. FrilaMoney

    @Test("FrilaMoney formata valores inteiros, taxas, estimativas e horas semanais")
    func frilaMoneyFormatacaoBasica() {
        // Reais inteiros com símbolo BRL completo e formatação exata de milhar
        #expect(normalizarMoeda(FrilaMoney.total(33600)) == "R$ 33.600")

        // Taxa com unidade e sufixo canônico
        #expect(FrilaMoney.RateUnit.hour.suffix == "/h")
        #expect(FrilaMoney.RateUnit.hour.spokenName == "hora")
        #expect(FrilaMoney.RateUnit.day.suffix == "/dia")
        #expect(FrilaMoney.RateUnit.day.spokenName == "dia")
        #expect(FrilaMoney.RateUnit.week.suffix == "/sem")
        #expect(FrilaMoney.RateUnit.week.spokenName == "semana")
        #expect(FrilaMoney.RateUnit.month.suffix == "/mês")
        #expect(FrilaMoney.RateUnit.month.spokenName == "mês")

        let taxa = FrilaMoney.rate(160, per: .hour)
        #expect(normalizarMoeda(taxa) == "R$ 160/h")

        // Estimativa com prefixo e valor BRL exato
        let estimativa = FrilaMoney.estimate(1200)
        #expect(normalizarMoeda(estimativa) == "Est. R$ 1.200")

        // Horas semanais
        #expect(FrilaMoney.weeklyHours(40) == "40 h/sem")
        #expect(FrilaMoney.weeklyHours(20, to: 40) == "20–40 h/sem")
    }

    @Test("FrilaMoney trata centavos suprimindo zeros quando exato e formatando campos")
    func frilaMoneyCentavosECampos() {
        // Centavos redondos omitem fração decimal e exigem saída BRL exata
        #expect(normalizarMoeda(FrilaMoney.total(cents: 28_000)) == "R$ 280")

        // Centavos fracionados incluem 2 casas decimais com vírgula pt-BR e moeda BRL
        #expect(normalizarMoeda(FrilaMoney.total(cents: 28_050)) == "R$ 280,50")

        // Dígitos de campo sem o símbolo monetário
        #expect(FrilaMoney.fieldDigits(cents: 14_000) == "140,00")
        #expect(FrilaMoney.fieldDigits(cents: 14_075) == "140,75")
        #expect(FrilaMoney.fieldDigits(cents: 50) == "0,50")
    }

    // MARK: - Auxiliares

    /// Normaliza variações de espaço em branco Unicode (NBSP \u{00A0} e NNBSP \u{202F})
    /// geradas por formatadores monetários de Foundation entre o símbolo de moeda e os dígitos.
    private func normalizarMoeda(_ texto: String) -> String {
        texto
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
    }

    // MARK: - 4. FrilaShiftCalendar

    @Test("FrilaShiftCalendar formata dias da semana e datas no calendário de Brasília")
    func frilaShiftCalendarFormatacoes() throws {
        var calendario = Calendar(identifier: .gregorian)
        let fusoSP = try #require(TimeZone(identifier: "America/Sao_Paulo"))
        calendario.timeZone = fusoSP

        // 25 de setembro de 2026 caiu em uma sexta-feira
        let componentes = DateComponents(year: 2026, month: 9, day: 25, hour: 12, minute: 0)
        let dataSexta = try #require(calendario.date(from: componentes))

        #expect(FrilaShiftCalendar.weekdayShort(dataSexta, calendar: calendario) == "sex")
        #expect(FrilaShiftCalendar.weekdayLong(dataSexta, calendar: calendario) == "sexta")
        #expect(FrilaShiftCalendar.dayMonth(dataSexta, calendar: calendario) == "25/09")
        #expect(FrilaShiftCalendar.compact(dataSexta, calendar: calendario) == "sex 25/09")
        #expect(FrilaShiftCalendar.spoken(dataSexta, calendar: calendario) == "sexta, 25 de setembro")

        // Diferença relativa de dias e rótulo amigável
        let dataAmanha = try #require(calendario.date(byAdding: .day, value: 1, to: dataSexta))
        let dataDepois = try #require(calendario.date(byAdding: .day, value: 2, to: dataSexta))

        #expect(FrilaShiftCalendar.dayOffset(of: dataSexta, from: dataSexta, calendar: calendario) == 0)
        #expect(FrilaShiftCalendar.dayOffset(of: dataAmanha, from: dataSexta, calendar: calendario) == 1)
        #expect(FrilaShiftCalendar.dayOffset(of: dataDepois, from: dataSexta, calendar: calendario) == 2)

        #expect(FrilaShiftCalendar.relativeLabel(dataSexta, now: dataSexta, calendar: calendario) == "hoje")
        #expect(FrilaShiftCalendar.relativeLabel(dataAmanha, now: dataSexta, calendar: calendario) == "amanhã")
        #expect(FrilaShiftCalendar.relativeLabel(dataDepois, now: dataSexta, calendar: calendario) == "dom 27/09")

        // Capitalização segura da primeira letra
        #expect("sáb 27/09".frilaCapitalizedFirst == "Sáb 27/09")
        #expect("hoje".frilaCapitalizedFirst == "Hoje")
        #expect("".frilaCapitalizedFirst == "")
    }

    // MARK: - 5. FrilaShiftRole e FrilaShiftVenue

    @Test("FrilaShiftRole pluraliza corretamente todas as funções do catálogo")
    func frilaShiftRolePluralizacao() {
        #expect(FrilaShiftRole.garcom.title == "Garçom")
        #expect(FrilaShiftRole.garcom.pluralTitle == "Garçons")
        #expect(FrilaShiftRole.garcom.counted(1) == "1 Garçom")
        #expect(FrilaShiftRole.garcom.counted(2) == "2 Garçons")

        #expect(FrilaShiftRole.cumim.title == "Cumim")
        #expect(FrilaShiftRole.cumim.pluralTitle == "Cumins")
        #expect(FrilaShiftRole.cumim.counted(1) == "1 Cumim")
        #expect(FrilaShiftRole.cumim.counted(3) == "3 Cumins")

        #expect(FrilaShiftRole.bartender.counted(1) == "1 Bartender")
        #expect(FrilaShiftRole.bartender.counted(2) == "2 Bartenders")

        #expect(FrilaShiftRole.recepcionista.counted(1) == "1 Recepcionista")
        #expect(FrilaShiftRole.recepcionista.counted(4) == "4 Recepcionistas")

        #expect(FrilaShiftRole.auxiliarDeCozinha.counted(1) == "1 Auxiliar de cozinha")
        #expect(FrilaShiftRole.auxiliarDeCozinha.counted(2) == "2 Auxiliares de cozinha")

        #expect(FrilaShiftRole.promotor.counted(1) == "1 Promotor")
        #expect(FrilaShiftRole.promotor.counted(5) == "5 Promotores")
    }

    @Test("FrilaShiftVenue e RehireRecord formatam distância e razão de recontratação")
    func frilaShiftVenueDistanciaEReputacao() {
        let venue1 = FrilaShiftVenue(
            id: "venue-1",
            name: "Bar do Lago",
            address: "CLS 405 Bloco C",
            region: "Asa Sul",
            distanceKm: 3.2,
            rehire: FrilaShiftRehireRecord(yes: 18, total: 19)
        )
        #expect(venue1.distanceLabel == "3,2 km")
        #expect(venue1.spokenDistance == "3,2 quilômetros")
        #expect(venue1.rehire?.ratioLabel == "18 de 19")

        let venue2 = FrilaShiftVenue(
            id: "venue-2",
            name: "Restaurante Central",
            address: "CLN 102 Bloco A",
            region: "Asa Norte",
            distanceKm: 14.0,
            rehire: FrilaShiftRehireRecord(yes: 0, total: 0)
        )
        #expect(venue2.distanceLabel == "14 km")
        #expect(venue2.spokenDistance == "14 quilômetros")
        #expect(venue2.rehire?.ratioLabel == "0 de 0")
    }
}
