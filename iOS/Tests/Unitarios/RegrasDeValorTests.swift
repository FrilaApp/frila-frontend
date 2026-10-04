import Foundation
import FrilaDominio
import Testing

/// Regras de valor que nenhuma suíte chamava: a janela como vai ao contrato, hora e data em São
/// Paulo, a comparação de dinheiro e o registro do cache.
@Suite("Valores do domínio: janela no contrato, hora de São Paulo, dinheiro e cache")
struct RegrasDeValorTests {
    private static let formatador = FormatadorFrila()

    private static func instante(_ ano: Int, _ mes: Int, _ dia: Int, _ hora: Int, _ minuto: Int) throws -> Date {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = FormatadorFrila.fuso
        return try #require(calendario.date(from: DateComponents(year: ano, month: mes, day: dia, hour: hora, minute: minuto)))
    }

    @Test("A janela vai ao contrato com o dia de 0 a 6 e as horas em HH:mm, inclusive a que vira a noite")
    func janelaParaContrato() throws {
        let janela = JanelaDeDisponibilidade(diaDaSemana: 5, inicio: try HoraDoDia(hora: 18, minuto: 0), fim: try HoraDoDia(hora: 2, minuto: 30))
        let contrato = Self.formatador.janelaParaContrato(janela)
        #expect(contrato.diaSemana == 5)
        #expect(contrato.inicio == "18:00")
        #expect(contrato.fim == "02:30")
    }

    @Test("Hora e data no fuso de São Paulo, mesmo com o instante em UTC")
    func horaEDataEmSaoPaulo() throws {
        // 2026-10-09T23:30Z é 20:30 em São Paulo (UTC-3, sem horário de verão).
        let instante = try #require(ISO8601DateFormatter().date(from: "2026-10-09T23:30:00Z"))
        #expect(Self.formatador.hora(instante) == "20:30")
        #expect(Self.formatador.dataEHora(instante) == "09/10/2026 às 20:30")

        // Meia-noite em UTC ainda é o dia anterior em São Paulo.
        let viradaUTC = try #require(ISO8601DateFormatter().date(from: "2026-10-10T00:10:00Z"))
        #expect(Self.formatador.dataEHora(viradaUTC) == "09/10/2026 às 21:10")
        let dia = Self.formatador.diaDeSaoPaulo(viradaUTC)
        #expect((dia.year, dia.month, dia.day) == (2026, 10, 9))
    }

    @Test("Dinheiro compara pelos centavos e aceita zero")
    func dinheiro() {
        #expect(Dinheiro(centavos: 0) < Dinheiro(centavos: 1))
        #expect(Dinheiro(centavos: 15000) < Dinheiro(centavos: 15001))
        #expect(!(Dinheiro(centavos: 15001) < Dinheiro(centavos: 15000)))
        #expect(!(Dinheiro(centavos: 15000) < Dinheiro(centavos: 15000)))
        #expect([Dinheiro(centavos: 300), Dinheiro(centavos: 100), Dinheiro(centavos: 200)].sorted().map(\.centavos) == [100, 200, 300])
        #expect(Dinheiro(centavos: 0).centavos == 0)
    }

    @Test("TurnoEmCache guarda o turno com o id e o instante em que foi salvo")
    func turnoEmCache() throws {
        let agora = Date(timeIntervalSince1970: 1_800_000_000)
        let vaga = VagaResumo(
            id: UUID(), funcao: "Garçom", local: "Asa Sul", regiaoAdministrativa: "Plano Piloto",
            periodo: try Periodo(inicio: agora, fim: agora.addingTimeInterval(3_600)), valor: Dinheiro(centavos: 15000)
        )
        let turno = Turno(
            id: UUID(), posicaoID: UUID(), vaga: vaga,
            contraparte: PerfilPublico(id: UUID(), tipo: .estabelecimento, nome: "Bistrô",
                                       reputacao: Reputacao(positivas: 0, total: 0, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0)),
            contatoVisivelAte: agora, verificacao: .pendente, valorAcordado: vaga.valor, podeAvaliar: false, contato: nil
        )
        let registro = TurnoEmCache(id: turno.id, turno: turno, salvoEm: agora)
        #expect(registro.id == turno.id)
        #expect(registro.turno == turno)
        #expect(registro.salvoEm == agora)
        let codificado = try JSONEncoder().encode(registro)
        #expect(try JSONDecoder().decode(TurnoEmCache.self, from: codificado) == registro)
    }
}
