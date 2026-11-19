import FrilaDominio
import Foundation

/// O horário de um turno num formato só, como o desenho do Fabrício o escreve: "06:30 às 09:30" e, com o dia,
/// "Qua, 18/11, 06:30 às 09:30". No lado da casa havia três (com travessão, com "até" e com o dia por extenso); só o texto
/// montado na tela muda, nada do domínio nem dos ViewModels.
public struct FormatoDeHorarioDoTurno: Sendable {
    private let formatador = FormatadorFrila()

    public init() {}

    /// "06:30 às 09:30", no fuso de São Paulo.
    public func horario(inicio: Date, fim: Date) -> String {
        TextosDoProfissional.Detalhe.intervaloHorario(inicio: formatador.hora(inicio), fim: formatador.hora(fim))
    }

    /// "Qua, 18/11, 06:30 às 09:30".
    public func comDia(inicio: Date, fim: Date) -> String {
        "\(dia(inicio)), \(horario(inicio: inicio, fim: fim))"
    }

    /// Um instante só, com o dia: "Qua, 18/11, 06:30". Quebra entre as partes em texto grande, sem partir o ano ao meio.
    public func instanteComDia(_ instante: Date) -> String {
        "\(dia(instante)), \(formatador.hora(instante))"
    }

    /// "Qua, 18/11".
    private func dia(_ instante: Date) -> String {
        let diaDaSemana = FrilaShiftCalendar.weekdayShort(instante).capitalized(with: Locale(identifier: "pt_BR"))
        return "\(diaDaSemana), \(FrilaShiftCalendar.dayMonth(instante))"
    }
}
