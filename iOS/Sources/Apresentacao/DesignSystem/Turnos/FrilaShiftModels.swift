import Foundation

// MARK: - Função (catálogo fechado)

/// Funções do catálogo fechado da v1.0. Um profissional escolhe uma ou mais; uma vaga tem uma só.
public enum FrilaShiftRole: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    case garcom
    case bartender
    case cumim
    case recepcionista
    case auxiliarDeCozinha
    case promotor

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .garcom: return "Garçom"
        case .bartender: return "Bartender"
        case .cumim: return "Cumim"
        case .recepcionista: return "Recepcionista"
        case .auxiliarDeCozinha: return "Auxiliar de cozinha"
        case .promotor: return "Promotor"
        }
    }

    public var pluralTitle: String {
        switch self {
        case .garcom: return "Garçons"
        case .bartender: return "Bartenders"
        case .cumim: return "Cumins"
        case .recepcionista: return "Recepcionistas"
        case .auxiliarDeCozinha: return "Auxiliares de cozinha"
        case .promotor: return "Promotores"
        }
    }

    /// "1 Garçom", "2 Garçons".
    public func counted(_ count: Int) -> String {
        "\(count) \(count == 1 ? title : pluralTitle)"
    }
}

// MARK: - Relógio do turno

/// Hora do dia em minutos (0 a 1439), no fuso de Brasília.
public struct FrilaShiftClock: Hashable, Comparable, Identifiable, Sendable {
    public let minutes: Int

    public init(hour: Int, minute: Int = 0) {
        let raw = hour * 60 + minute
        minutes = ((raw % 1440) + 1440) % 1440
    }

    public var id: Int { minutes }
    public var hour: Int { minutes / 60 }
    public var minute: Int { minutes % 60 }

    public static func < (lhs: FrilaShiftClock, rhs: FrilaShiftClock) -> Bool { lhs.minutes < rhs.minutes }

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
    public static func options(stepMinutes: Int = 30) -> [FrilaShiftClock] {
        stride(from: 0, to: 1440, by: stepMinutes).map { FrilaShiftClock(hour: 0, minute: $0) }
    }
}

/// Janela de trabalho. Quando o fim é menor ou igual ao início, o turno atravessa a meia-noite.
public struct FrilaShiftWindow: Hashable, Sendable {
    public var start: FrilaShiftClock
    public var end: FrilaShiftClock

    public init(start: FrilaShiftClock, end: FrilaShiftClock) {
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

public enum FrilaShiftCalendar {
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
    var frilaCapitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

// MARK: - Local

/// Reputação com denominador: "18 de 19 trabalhariam lá de novo". Sem registro, "Sem histórico".
public struct FrilaShiftRehireRecord: Hashable, Sendable {
    public let yes: Int
    public let total: Int

    public init(yes: Int, total: Int) {
        self.yes = yes
        self.total = total
    }

    /// "18 de 19".
    public var ratioLabel: String { "\(yes) de \(total)" }
}

public struct FrilaShiftVenue: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let address: String
    public let region: String
    /// Distância até o ponto base do profissional.
    public let distanceKm: Double
    public let rehire: FrilaShiftRehireRecord?

    public init(id: String, name: String, address: String, region: String, distanceKm: Double, rehire: FrilaShiftRehireRecord?) {
        self.id = id
        self.name = name
        self.address = address
        self.region = region
        self.distanceKm = distanceKm
        self.rehire = rehire
    }
}

// MARK: - Vaga publicada

public struct FrilaShiftPosting: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let role: FrilaShiftRole
    public let venue: FrilaShiftVenue
    /// Início do dia do turno (meia-noite em Brasília).
    public let day: Date
    public let window: FrilaShiftWindow
    public let positions: Int
    public let payPerPositionCents: Int

    public init(
        id: UUID = UUID(),
        role: FrilaShiftRole,
        venue: FrilaShiftVenue,
        day: Date,
        window: FrilaShiftWindow,
        positions: Int,
        payPerPositionCents: Int
    ) {
        self.id = id
        self.role = role
        self.venue = venue
        self.day = day
        self.window = window
        self.positions = positions
        self.payPerPositionCents = payPerPositionCents
    }

    public var totalCents: Int { positions * payPerPositionCents }

    /// Linha do card: "Hoje, 18h às 02h", "Sáb 27/09, 19h às 01h".
    public func whenLabel(now: Date, calendar: Calendar = FrilaShiftCalendar.brasilia) -> String {
        "\(FrilaShiftCalendar.relativeLabel(day, now: now, calendar: calendar).frilaCapitalizedFirst), \(window.rangeLabel)"
    }

    /// "3,2 km, Asa Norte".
    public var placeLabel: String {
        "\(venue.distanceLabel), \(venue.region)"
    }

    public func accessibilityLabel(now: Date, calendar: Calendar = FrilaShiftCalendar.brasilia) -> String {
        let dayOffset = FrilaShiftCalendar.dayOffset(of: day, from: now, calendar: calendar)
        let spokenDay: String
        switch dayOffset {
        case 0: spokenDay = "hoje"
        case 1: spokenDay = "amanhã"
        default: spokenDay = FrilaShiftCalendar.spoken(day, calendar: calendar)
        }
        let reputation = venue.rehire.map { "\($0.ratioLabel) trabalhariam lá de novo" }
            ?? "sem histórico, primeira vaga deste local no Frila"
        return [
            role.title,
            venue.name,
            "\(FrilaMoney.spoken(cents: payPerPositionCents)) por turno",
            "\(spokenDay), \(window.spokenRange)",
            "\(venue.spokenDistance), \(venue.region)",
            reputation
        ].joined(separator: ", ")
    }
}

// MARK: - Rascunho do formulário "Nova vaga"

public enum FrilaShiftDayChoice: Hashable, Sendable {
    case today
    case tomorrow
    case other(Date)
}

public struct FrilaShiftDraft: Equatable, Sendable {
    public static let positionsRange = 1...20

    public var role: FrilaShiftRole
    public var positions: Int
    public var payPerPositionCents: Int
    public var dayChoice: FrilaShiftDayChoice
    public var window: FrilaShiftWindow
    public var venue: FrilaShiftVenue

    public init(
        role: FrilaShiftRole = .garcom,
        positions: Int = 2,
        payPerPositionCents: Int = 14_000,
        dayChoice: FrilaShiftDayChoice = .today,
        window: FrilaShiftWindow = FrilaShiftWindow(start: FrilaShiftClock(hour: 18), end: FrilaShiftClock(hour: 2)),
        venue: FrilaShiftVenue
    ) {
        self.role = role
        self.positions = positions
        self.payPerPositionCents = payPerPositionCents
        self.dayChoice = dayChoice
        self.window = window
        self.venue = venue
    }

    /// Rascunho inicial: hoje, a menos que o início padrão já tenha passado.
    public static func initial(venue: FrilaShiftVenue, now: Date, calendar: Calendar = FrilaShiftCalendar.brasilia) -> FrilaShiftDraft {
        var draft = FrilaShiftDraft(venue: venue)
        if draft.startHasPassed(now: now, calendar: calendar) {
            draft.dayChoice = .tomorrow
        }
        return draft
    }

    public var totalCents: Int { positions * payPerPositionCents }

    public func day(now: Date, calendar: Calendar = FrilaShiftCalendar.brasilia) -> Date {
        switch dayChoice {
        case .today: return calendar.startOfDay(for: now)
        case .tomorrow: return FrilaShiftCalendar.date(byAddingDays: 1, to: now, calendar: calendar)
        case .other(let date): return calendar.startOfDay(for: date)
        }
    }

    public func startDate(now: Date, calendar: Calendar = FrilaShiftCalendar.brasilia) -> Date {
        calendar.date(byAdding: .minute, value: window.start.minutes, to: day(now: now, calendar: calendar)) ?? now
    }

    public func startHasPassed(now: Date, calendar: Calendar = FrilaShiftCalendar.brasilia) -> Bool {
        startDate(now: now, calendar: calendar) <= now
    }

    /// Primeiro problema que impede publicar, em linguagem de balcão. `nil` quando dá para publicar.
    public func blockingIssue(now: Date, calendar: Calendar = FrilaShiftCalendar.brasilia) -> String? {
        if payPerPositionCents <= 0 { return "Informe o valor por posição." }
        if !window.isValid { return "O fim precisa ser diferente do início." }
        if startHasPassed(now: now, calendar: calendar) { return "Esse início já passou. Escolha outro horário ou outra data." }
        return nil
    }

    /// "Termina no dia seguinte: sáb 26/09, às 02:00."
    public func overnightNote(now: Date, calendar: Calendar = FrilaShiftCalendar.brasilia) -> String? {
        guard window.isValid, window.crossesMidnight else { return nil }
        let endDay = FrilaShiftCalendar.date(byAddingDays: 1, to: day(now: now, calendar: calendar), calendar: calendar)
        return "Termina no dia seguinte: \(FrilaShiftCalendar.compact(endDay, calendar: calendar)), às \(window.end.fieldLabel)."
    }

    /// "2 Garçons, hoje, sex 25/09, 18h às 02h".
    public func summary(now: Date, calendar: Calendar = FrilaShiftCalendar.brasilia) -> String {
        let date = day(now: now, calendar: calendar)
        let compact = FrilaShiftCalendar.compact(date, calendar: calendar)
        let dayPart: String
        switch FrilaShiftCalendar.dayOffset(of: date, from: now, calendar: calendar) {
        case 0: dayPart = "hoje, \(compact)"
        case 1: dayPart = "amanhã, \(compact)"
        default: dayPart = compact
        }
        return "\(role.counted(positions)), \(dayPart), \(window.rangeLabel)"
    }

    /// "2 posições de R$ 140".
    public var breakdownLabel: String {
        let unit = positions == 1 ? "posição" : "posições"
        return "\(positions) \(unit) de " + FrilaMoney.total(cents: payPerPositionCents)
    }

    public func makePosting(now: Date, calendar: Calendar = FrilaShiftCalendar.brasilia) -> FrilaShiftPosting {
        FrilaShiftPosting(
            role: role,
            venue: venue,
            day: day(now: now, calendar: calendar),
            window: window,
            positions: positions,
            payPerPositionCents: payPerPositionCents
        )
    }
}

// MARK: - Perfil do profissional

/// Dias na ordem de leitura brasileira, de segunda a domingo.
public enum FrilaShiftWeekday: Int, CaseIterable, Identifiable, Hashable, Sendable {
    case monday = 2, tuesday, wednesday, thursday, friday, saturday
    case sunday = 1

    public static let displayOrder: [FrilaShiftWeekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .monday: return "Segunda"
        case .tuesday: return "Terça"
        case .wednesday: return "Quarta"
        case .thursday: return "Quinta"
        case .friday: return "Sexta"
        case .saturday: return "Sábado"
        case .sunday: return "Domingo"
        }
    }

    public var next: FrilaShiftWeekday {
        let index = Self.displayOrder.firstIndex(of: self) ?? 0
        return Self.displayOrder[(index + 1) % Self.displayOrder.count]
    }

    /// "do sábado", "da segunda".
    var withArticle: String {
        switch self {
        case .saturday, .sunday: return "do \(title.lowercased())"
        default: return "da \(title.lowercased())"
        }
    }

    /// "no sábado", "na sexta".
    public var onDay: String {
        switch self {
        case .saturday, .sunday: return "no \(title.lowercased())"
        default: return "na \(title.lowercased())"
        }
    }

    /// "18h às 02h do sábado" quando atravessa a meia-noite; "11h às 23h" caso contrário.
    public func availabilityLabel(for window: FrilaShiftWindow) -> String {
        window.crossesMidnight ? "\(window.rangeLabel) \(next.withArticle)" : window.rangeLabel
    }
}

public struct FrilaWorkerProfile: Equatable, Sendable {
    public var roles: Set<FrilaShiftRole>
    public var baseRegion: String
    public var availability: [FrilaShiftWeekday: FrilaShiftWindow]

    public init(roles: Set<FrilaShiftRole>, baseRegion: String, availability: [FrilaShiftWeekday: FrilaShiftWindow]) {
        self.roles = roles
        self.baseRegion = baseRegion
        self.availability = availability
    }

    /// Sem função ou sem horário o perfil salva, mas nenhuma vaga chega.
    public var isReadyToReceive: Bool {
        !roles.isEmpty && !availability.isEmpty
    }

    public var orderedRoles: [FrilaShiftRole] {
        FrilaShiftRole.allCases.filter(roles.contains)
    }
}

// MARK: - Filtros da lista "Vagas no DF"

public enum FrilaShiftDateFilter: String, CaseIterable, Identifiable, Sendable {
    case any
    case today
    case tomorrow
    case weekend

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .any: return "Qualquer data"
        case .today: return "Hoje"
        case .tomorrow: return "Amanhã"
        case .weekend: return "Fim de semana"
        }
    }

    public func matches(_ day: Date, now: Date, calendar: Calendar = FrilaShiftCalendar.brasilia) -> Bool {
        let offset = FrilaShiftCalendar.dayOffset(of: day, from: now, calendar: calendar)
        switch self {
        case .any: return offset >= 0
        case .today: return offset == 0
        case .tomorrow: return offset == 1
        case .weekend:
            let weekday = calendar.component(.weekday, from: day)
            return offset >= 0 && offset < 7 && (weekday == 1 || weekday == 7 || weekday == 6)
        }
    }
}

public enum FrilaShiftFeedCopy {
    /// "Garçom +1", "Bartender", "Todas as funções".
    public static func rolesFilterLabel(_ roles: Set<FrilaShiftRole>) -> String {
        let ordered = FrilaShiftRole.allCases.filter(roles.contains)
        guard let first = ordered.first else { return "Todas as funções" }
        let others = ordered.count - 1
        return others == 0 ? first.title : "\(first.title) +\(others)"
    }

    /// "3 vagas, pela distância do seu ponto base."
    public static func countCaption(_ count: Int) -> String {
        "\(count) \(count == 1 ? "vaga" : "vagas"), pela distância do seu ponto base."
    }
}
