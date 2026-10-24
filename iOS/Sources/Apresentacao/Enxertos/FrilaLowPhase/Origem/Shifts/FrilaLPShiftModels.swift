import Foundation

// MARK: - Relógio do turno

/// Hora do dia em minutos (0 a 1439), no fuso de Brasília.
public struct FrilaLPShiftClock: Hashable, Comparable, Identifiable, Sendable {
    public let minutes: Int

    public init(hour: Int, minute: Int = 0) {
        let raw = hour * 60 + minute
        minutes = ((raw % 1440) + 1440) % 1440
    }

    public var id: Int { minutes }
    public var hour: Int { minutes / 60 }
    public var minute: Int { minutes % 60 }

    public static func < (lhs: FrilaLPShiftClock, rhs: FrilaLPShiftClock) -> Bool { lhs.minutes < rhs.minutes }

    /// Rótulo de campo: "18:00", "02:30".
    public var fieldLabel: String {
        String(format: "%02d:%02d", hour, minute)
    }

    /// Rótulo corrido: "18h", "02h", "18h30".
    public var shortLabel: String {
        minute == 0 ? String(format: "%02dh", hour) : String(format: "%02dh%02d", hour, minute)
    }

    /// Leitura do VoiceOver: "18 horas", "1 hora e 30 minutos", "meia-noite".
    public var spokenLabel: String {
        if minutes == 0 { return "meia-noite" }
        let hours = hour == 1 ? "1 hora" : "\(hour) horas"
        return minute == 0 ? hours : "\(hours) e \(minute) minutos"
    }

    /// Opções de 30 em 30 minutos, de 00:00 a 23:30.
    public static func options(stepMinutes: Int = 30) -> [FrilaLPShiftClock] {
        stride(from: 0, to: 1440, by: stepMinutes).map { FrilaLPShiftClock(hour: 0, minute: $0) }
    }
}

/// Janela de trabalho. Quando o fim é menor ou igual ao início, o turno atravessa a meia-noite.
public struct FrilaLPShiftWindow: Hashable, Sendable {
    public var start: FrilaLPShiftClock
    public var end: FrilaLPShiftClock

    public init(start: FrilaLPShiftClock, end: FrilaLPShiftClock) {
        self.start = start
        self.end = end
    }

    public var isValid: Bool { start != end }
    public var crossesMidnight: Bool { end <= start }

    public var durationMinutes: Int {
        crossesMidnight ? (1440 - start.minutes) + end.minutes : end.minutes - start.minutes
    }

    /// "18h às 02h".
    public var rangeLabel: String {
        "\(start.shortLabel) às \(end.shortLabel)"
    }

    /// "das 18 horas às 2 horas".
    public var spokenRange: String {
        "das \(start.spokenLabel) às \(end.spokenLabel)"
    }
}

// MARK: - Calendário pt-BR (Brasília)

public enum FrilaLPShiftCalendar {
    /// Calendário gregoriano no fuso do DF, independente do aparelho.
    public static let brasilia: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .current
        calendar.locale = Locale(identifier: "pt_BR")
        return calendar
    }()

    private static let weekdayShortNames = ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"]
    private static let weekdayLongNames = ["domingo", "segunda", "terça", "quarta", "quinta", "sexta", "sábado"]

    /// "sex".
    public static func weekdayShort(_ date: Date, calendar: Calendar = brasilia) -> String {
        weekdayShortNames[calendar.component(.weekday, from: date) - 1]
    }

    /// "sexta".
    public static func weekdayLong(_ date: Date, calendar: Calendar = brasilia) -> String {
        weekdayLongNames[calendar.component(.weekday, from: date) - 1]
    }

    /// "25/09".
    public static func dayMonth(_ date: Date, calendar: Calendar = brasilia) -> String {
        let parts = calendar.dateComponents([.day, .month], from: date)
        return String(format: "%02d/%02d", parts.day ?? 0, parts.month ?? 0)
    }

    /// "sex 25/09".
    public static func compact(_ date: Date, calendar: Calendar = brasilia) -> String {
        "\(weekdayShort(date, calendar: calendar)) \(dayMonth(date, calendar: calendar))"
    }

    /// "sexta, 25 de setembro", para o VoiceOver.
    public static func spoken(_ date: Date, calendar: Calendar = brasilia) -> String {
        let months = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho",
                      "agosto", "setembro", "outubro", "novembro", "dezembro"]
        let parts = calendar.dateComponents([.day, .month], from: date)
        let monthIndex = (parts.month ?? 1) - 1
        return "\(weekdayLong(date, calendar: calendar)), \(parts.day ?? 0) de \(months[monthIndex])"
    }

    public static func dayOffset(of date: Date, from now: Date, calendar: Calendar = brasilia) -> Int {
        let from = calendar.startOfDay(for: now)
        let to = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    public static func date(byAddingDays days: Int, to date: Date, calendar: Calendar = brasilia) -> Date {
        calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: date)) ?? date
    }

    /// Dia relativo em minúsculas, para frases: "hoje", "amanhã", "sáb 27/09".
    public static func relativeLabel(_ date: Date, now: Date, calendar: Calendar = brasilia) -> String {
        switch dayOffset(of: date, from: now, calendar: calendar) {
        case 0: return "hoje"
        case 1: return "amanhã"
        default: return compact(date, calendar: calendar)
        }
    }
}

extension String {
    /// Só a primeira letra em maiúscula: "sáb 27/09" vira "Sáb 27/09".
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}


// MARK: - Dia do formulário "Nova vaga"

public enum FrilaLPShiftDayChoice: Hashable, Sendable {
    case today
    case tomorrow
    case other(Date)
}
