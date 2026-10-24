import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Data e horários do turno no formulário de Publicar vaga
//
// Data, Início e Fim deixam de ser texto livre: cada campo abre um seletor flutuante ancorado no
// próprio campo (calendário para a data, roleta de 30 em 30 minutos para os horários). O rascunho
// continua guardando texto ("Sex, 25/09", "18:00"), então prévia e publicação não mudam.

/// Conversões entre o texto do rascunho e os valores dos seletores.
enum FrilaJobShiftFormat {
    /// Janela de datas oferecida no calendário, igual à do fluxo de turnos.
    static let bookableDays = 60

    /// "Sex, 25/09".
    static func dateLabel(_ date: Date, calendar: Calendar = FrilaShiftCalendar.brasilia) -> String {
        let weekday = FrilaShiftCalendar.weekdayShort(date, calendar: calendar)
        return "\(weekday.prefix(1).uppercased())\(weekday.dropFirst()), \(FrilaShiftCalendar.dayMonth(date, calendar: calendar))"
    }

    private static let weekdayFullNames = [
        "domingo", "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado"
    ]
    private static let monthNames = [
        "janeiro", "fevereiro", "março", "abril", "maio", "junho",
        "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"
    ]

    /// Data por extenso para leitura imediata: "Sexta-feira, 25 de setembro". O ano só aparece quando
    /// não é o ano corrente (a janela de 60 dias pode virar o ano). O rascunho segue com o formato curto.
    static func longDateLabel(_ date: Date, now: Date, calendar: Calendar = FrilaShiftCalendar.brasilia) -> String {
        let parts = calendar.dateComponents([.weekday, .day, .month, .year], from: date)
        let weekday = weekdayFullNames[(parts.weekday ?? 1) - 1]
        let month = monthNames[(parts.month ?? 1) - 1]
        var label = "\(weekday.prefix(1).uppercased())\(weekday.dropFirst()), \(parts.day ?? 1) de \(month)"
        if let year = parts.year, year != calendar.component(.year, from: now) { label += " de \(year)" }
        return label
    }

    /// "Hoje" ou "Amanhã" quando a data é tão próxima que a referência relativa diz mais que o dia.
    static func relativeDayLabel(_ date: Date, now: Date, calendar: Calendar = FrilaShiftCalendar.brasilia) -> String? {
        if calendar.isDate(date, inSameDayAs: now) { return "Hoje" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) { return "Amanhã" }
        return nil
    }

    private static let monthShortNames = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]

    /// Data curta para um segmento estreito: "Sex, 25 set". Dia da semana e mês por nome, sem barra.
    static func compactDateLabel(_ date: Date, calendar: Calendar = FrilaShiftCalendar.brasilia) -> String {
        let weekday = FrilaShiftCalendar.weekdayShort(date, calendar: calendar)
        let parts = calendar.dateComponents([.day, .month], from: date)
        let month = monthShortNames[(parts.month ?? 1) - 1]
        return "\(weekday.prefix(1).uppercased())\(weekday.dropFirst()), \(parts.day ?? 1) \(month)"
    }

    /// Lê "Sex, 25/09" (ou "25/09") de volta como a próxima ocorrência a partir de hoje.
    static func parseDate(_ text: String, now: Date, calendar: Calendar = FrilaShiftCalendar.brasilia) -> Date? {
        guard let dayMonth = text.split(separator: " ").last else { return nil }
        let parts = dayMonth.split(separator: "/").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        let today = calendar.startOfDay(for: now)
        var components = calendar.dateComponents([.year], from: today)
        components.day = parts[0]
        components.month = parts[1]
        guard let candidate = calendar.date(from: components) else { return nil }
        if candidate >= today { return candidate }
        components.year = (components.year ?? 0) + 1
        return calendar.date(from: components)
    }

    /// Lê "18:00" como relógio do turno.
    static func parseClock(_ text: String) -> FrilaShiftClock? {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else { return nil }
        return FrilaShiftClock(hour: parts[0], minute: parts[1])
    }

    /// Fim igual ou antes do início: o turno atravessa a meia-noite.
    static func endsNextDay(start: String, end: String) -> Bool {
        guard let start = parseClock(start), let end = parseClock(end) else { return false }
        return end <= start
    }

    /// Duração do turno em minutos, atravessando a meia-noite quando o fim vem antes do início.
    /// Nil quando falta um dos horários ou quando início e fim são iguais.
    static func durationMinutes(start: String, end: String) -> Int? {
        guard let start = parseClock(start), let end = parseClock(end), start != end else { return nil }
        return (end.minutes - start.minutes + 1440) % 1440
    }

    /// "8h", "7h30".
    static func durationLabel(minutes: Int) -> String {
        let hours = minutes / 60, rest = minutes % 60
        return rest == 0 ? "\(hours)h" : "\(hours)h\(String(format: "%02d", rest))"
    }

    /// "8 horas", "7 horas e 30 minutos", para o VoiceOver.
    static func durationSpoken(minutes: Int) -> String {
        let hours = minutes / 60, rest = minutes % 60
        let hoursText = hours == 1 ? "1 hora" : "\(hours) horas"
        guard rest > 0 else { return hoursText }
        return hours == 0 ? "\(rest) minutos" : "\(hoursText) e \(rest) minutos"
    }

    /// Turnos acima disso recebem um aviso (não bloqueia).
    static let longShiftMinutes = 12 * 60

    /// Problema que impede calcular o turno. Nil quando os horários estão válidos ou incompletos.
    static func blockingIssue(start: String, end: String) -> String? {
        guard let start = parseClock(start), let end = parseClock(end) else { return nil }
        return start == end ? "Início e fim não podem ser iguais." : nil
    }

    /// Aviso de turno longo, sem bloquear a publicação.
    static func longShiftWarning(start: String, end: String) -> String? {
        guard let minutes = durationMinutes(start: start, end: end), minutes > longShiftMinutes else { return nil }
        return "Turno de \(durationLabel(minutes: minutes)). Confira se os horários estão certos."
    }

    /// Sugestão de fim ao abrir a roleta vazia: 6 horas depois do início, ou 02:00.
    static func suggestedEnd(after start: String) -> FrilaShiftClock {
        guard let start = parseClock(start) else { return FrilaShiftClock(hour: 2) }
        return FrilaShiftClock(hour: start.hour + 6, minute: start.minute)
    }
}

// MARK: - Linha Data, Início e Fim

/// Campo de data ou horário em edição. Só um seletor fica aberto por vez; o valor só entra no rascunho
/// no OK explícito, então abrir e fechar nunca preenche um campo sem intenção.
enum FrilaJobShiftField: String, Identifiable, CaseIterable {
    case date, start, end
    var id: String { rawValue }

    /// Ordem linear do turno, começando no campo de entrada e seguindo em ciclo: entrar por Início
    /// percorre Início, Fim e Data; entrar por Fim, Fim, Data e Início. Cada campo aparece uma vez.
    static func flow(startingAt entry: FrilaJobShiftField) -> [FrilaJobShiftField] {
        let all = allCases
        guard let index = all.firstIndex(of: entry) else { return all }
        return Array(all[index...] + all[..<index])
    }

    /// Nome completo da etapa, falado pelo VoiceOver no calendário e nas roletas.
    var stepTitle: String {
        switch self {
        case .date: return "Data do turno"
        case .start: return "Início do turno"
        case .end: return "Fim do turno"
        }
    }

    /// Nome da linha na lista de etapas do cartão: o mesmo rótulo do campo no formulário.
    var rowTitle: String {
        switch self {
        case .date: return "Data"
        case .start: return "Início"
        case .end: return "Fim"
        }
    }
}

/// Valores da lista de etapas do cartão do turno (`FrilaJobShiftStepList`). A etapa ativa mostra o valor vivo
/// do miolo (o dia marcado no calendário, o horário parado na roleta), que acompanha o gesto; as demais
/// mostram o que já está no rascunho, ou "A definir" quando ainda não foram escolhidas.
enum FrilaJobShiftOverview {
    /// Etapa ainda sem valor: uma pista apagada, sem traço nem ponto no lugar do valor.
    static let pendingLabel = "A definir"

    /// Valor guardado no rascunho, como a linha mostra: data por extenso (ou curta, nos segmentos do
    /// modelo B) ou horário. Nil quando vazio.
    static func savedValue(_ field: FrilaJobShiftField, shiftDate: String, startTime: String, endTime: String, now: Date, compact: Bool = false) -> String? {
        switch field {
        case .date:
            return FrilaJobShiftFormat.parseDate(shiftDate, now: now).map { dateValue($0, now: now, compact: compact) }
        case .start:
            return FrilaJobShiftFormat.parseClock(startTime)?.fieldLabel
        case .end:
            return FrilaJobShiftFormat.parseClock(endTime)?.fieldLabel
        }
    }

    /// Valor que o miolo marca agora, para a linha da etapa ativa.
    static func liveValue(_ field: FrilaJobShiftField, date: Date, start: FrilaShiftClock, end: FrilaShiftClock, now: Date, compact: Bool = false) -> String {
        switch field {
        case .date: return dateValue(date, now: now, compact: compact)
        case .start: return start.fieldLabel
        case .end: return end.fieldLabel
        }
    }

    private static func dateValue(_ date: Date, now: Date, compact: Bool) -> String {
        compact ? FrilaJobShiftFormat.compactDateLabel(date) : FrilaJobShiftFormat.longDateLabel(date, now: now)
    }
}

/// Chegada no formulário dos valores escolhidos no cartão do turno.
///
/// O fluxo do cartão grava Data, Início e Fim enquanto o véu cobre o formulário: quem tocou só em Data
/// volta e encontra Início e Fim preenchidos sem ter visto acontecer, e relê os campos para conferir. Ao
/// fechar, os campos que o fluxo mudou acendem em cascata, na ordem do formulário (contorno da marca e um
/// check no lugar da pista), e o painel de horas fecha a onda. O VoiceOver ouve o mesmo resumo.
enum FrilaJobShiftLanding {
    /// Campos que o fluxo preencheu ou mudou, na ordem do formulário. Campo esvaziado não conta.
    static func changedFields(before: [FrilaJobShiftField: String], after: [FrilaJobShiftField: String]) -> [FrilaJobShiftField] {
        FrilaJobShiftField.allCases.filter { field in
            let new = after[field] ?? ""
            return !new.isEmpty && new != (before[field] ?? "")
        }
    }

    /// Resumo falado: "Data preenchida", "Início e fim preenchidos", "Data, início e fim preenchidos".
    static func announcement(for fields: [FrilaJobShiftField]) -> String? {
        guard let first = fields.first else { return nil }
        if fields.count == 1 { return "\(first.rowTitle) \(first == .date ? "preenchida" : "preenchido")" }
        let names = fields.enumerated().map { $0.offset == 0 ? $0.element.rowTitle : $0.element.rowTitle.lowercased() }
        let list = names.dropLast().joined(separator: ", ") + " e " + names[names.count - 1]
        return "\(list) preenchidos"
    }
}

/// Como o cartão do turno navega entre as etapas (teste A/B por argumento de lançamento).
public enum FrilaJobShiftNavigationStyle: Equatable, Sendable {
    /// Modelo A: lista das três etapas entre o miolo e o botão, na zona do polegar (`FrilaJobShiftStepList`).
    case overviewList
    /// Modelo B, experimental: seletor segmentado no topo do cartão, com a seleção ativa deslizando
    /// (`FrilaJobShiftStepPicker`), e um cartão mais compacto.
    case topPicker

    /// Largura máxima do miolo, a mesma em todas as etapas: o cartão só muda de altura. Com larguras por
    /// etapa (calendário largo, roleta estreita), o calendário (UIKit) assumia a largura final de uma vez e
    /// era cortado nas bordas enquanto o cartão crescia, e os segmentos do modelo B escorregavam de lugar.
    /// A: 328, o calendário encosta na margem de 20 pt de um iPhone de 402 pt (cartão de 360). B: 312, um
    /// cartão de 344, mais compacto. É um teto: em telas estreitas o cartão encolhe e mantém a margem.
    var contentWidth: CGFloat { self == .overviewList ? 328 : 312 }

    /// Altura da roleta: cinco linhas com folga no A; no B, a altura compacta de antes (150).
    var wheelHeight: CGFloat { self == .overviewList ? 180 : 150 }
}

/// Posição de uma etapa no fluxo do cartão: ordem completa, etapa atual e se é a última.
struct FrilaJobShiftStep: Equatable {
    let order: [FrilaJobShiftField]
    let current: FrilaJobShiftField

    var index: Int { order.firstIndex(of: current) ?? 0 }
    var isLast: Bool { index == order.count - 1 }
    var next: FrilaJobShiftField? { isLast ? nil : order[index + 1] }
    var previous: FrilaJobShiftField? { index == 0 ? nil : order[index - 1] }

    /// Botão do cartão: avança nas intermediárias, conclui na última.
    var confirmTitle: String { isLast ? "Concluir" : "Próximo" }
}

struct FrilaJobFormShiftTimeRow: View {
    @Binding var draft: FrilaJobCreationDraft
    @Binding var editing: FrilaJobShiftField?
    let isDark: Bool
    let navigationStyle: FrilaJobShiftNavigationStyle
    var now: Date = Date()
    /// Verdadeiro depois de tentar publicar com campos faltando: campos vazios ganham contorno de erro.
    var showsMissing: Bool = false

    private typealias Field = FrilaJobShiftField
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Valores do rascunho quando o cartão abriu, para saber o que o fluxo mudou.
    @State private var valuesAtOpen: [Field: String]?
    /// Campos acesos agora pela cascata de chegada (ver `FrilaJobShiftLanding`).
    @State private var landed: Set<Field> = []
    @State private var hoursLanded = false
    @State private var landingTask: Task<Void, Never>?

    private var currentValues: [Field: String] {
        [.date: draft.shiftDate, .start: draft.startTime, .end: draft.endTime]
    }

    /// Cartão abriu: guarda os valores. Cartão fechou: acende em cascata o que mudou, depois de o cartão
    /// sumir (`hoursHighlightDelayMs`), um campo a cada `shiftLandingStaggerMs`, e o painel de horas por
    /// último; tudo apaga junto depois de `conclusionHold`. Movimento reduzido: acende e apaga sem cascata.
    private func editingChanged(from old: Field?, to new: Field?) {
        if old == nil, new != nil {
            landingTask?.cancel()
            landed = []
            hoursLanded = false
            valuesAtOpen = currentValues
            return
        }
        guard new == nil, let before = valuesAtOpen else { return }
        valuesAtOpen = nil
        let fields = FrilaJobShiftLanding.changedFields(before: before, after: currentValues)
        guard !fields.isEmpty else { return }
        let lightsHours = FrilaJobShiftFormat.durationMinutes(start: draft.startTime, end: draft.endTime) != nil
            && (fields.contains(.start) || fields.contains(.end))
        if let text = FrilaJobShiftLanding.announcement(for: fields) {
            AccessibilityNotification.Announcement(text).post()
        }
        landingTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(FrilaMotion.hoursHighlightDelayMs))
            for field in fields {
                guard !Task.isCancelled else { return }
                withAnimation(FrilaMovimento.animacao(.easeOut(duration: 0.2), reduzir: reduceMotion)) { _ = landed.insert(field) }
                if !reduceMotion { try? await Task.sleep(for: .milliseconds(FrilaMotion.shiftLandingStaggerMs)) }
            }
            if lightsHours { withAnimation(FrilaMovimento.animacao(.easeOut(duration: 0.2), reduzir: reduceMotion)) { hoursLanded = true } }
            try? await Task.sleep(for: .seconds(FrilaMotion.conclusionHold))
            guard !Task.isCancelled else { return }
            withAnimation(FrilaMovimento.animacao(.easeIn(duration: 0.4), reduzir: reduceMotion)) {
                landed = []
                hoursLanded = false
            }
        }
    }

    /// Nota abaixo dos horários: erro bloqueante, aviso de turno longo ou duração.
    private enum Note: Equatable {
        case issue(String), warning(String), missing, duration(minutes: Int, nextDay: Bool)
    }

    private var note: Note? {
        let start = draft.startTime, end = draft.endTime
        if let issue = FrilaJobShiftFormat.blockingIssue(start: start, end: end) { return .issue(issue) }
        if showsMissing, draft.shiftDate.isEmpty || start.isEmpty || end.isEmpty { return .missing }
        if let warning = FrilaJobShiftFormat.longShiftWarning(start: start, end: end) { return .warning(warning) }
        if let minutes = FrilaJobShiftFormat.durationMinutes(start: start, end: end) {
            return .duration(minutes: minutes, nextDay: FrilaJobShiftFormat.endsNextDay(start: start, end: end))
        }
        return nil
    }

    private var noteKey: String { note.map { "\($0)" } ?? "" }

    @ViewBuilder
    private var shiftNote: some View {
        switch note {
        case .issue(let text):
            Label(text, systemImage: "exclamationmark.circle.fill")
                .frilaType(FrilaFormType.detail, dynamic: true)
                .foregroundColor(FrilaColor.dynamicError(isDark: isDark))
                .transition(.opacity)
        case .missing:
            Label(String(localized: "Escolha a data e os horários do turno.", table: "Estudio", bundle: bundleApresentacao), systemImage: "exclamationmark.circle.fill")
                .frilaType(FrilaFormType.detail, dynamic: true)
                .foregroundColor(FrilaColor.dynamicError(isDark: isDark))
                .transition(.opacity)
        case .warning(let text):
            Label(text, systemImage: "clock.badge.exclamationmark")
                .frilaType(FrilaFormType.detail, dynamic: true)
                .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
                .transition(.opacity)
        case .duration:
            // As horas têm painel próprio logo abaixo dos campos (FrilaJobShiftHoursPanel)
            EmptyView()
        case nil:
            EmptyView()
        }
    }

    private var parsedDate: Date? { FrilaJobShiftFormat.parseDate(draft.shiftDate, now: now) }

    /// Início e Fim lado a lado; em tamanhos de acessibilidade empilham.
    private func timesLayout<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let fields = content()
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: FrilaGeometry.space10) { fields }
            } else {
                HStack(alignment: .top, spacing: FrilaGeometry.space10) { fields }
            }
        }
    }

    /// Data em largura total, por extenso ("Sexta-feira, 25 de setembro", com "Hoje" ou "Amanhã" à direita
    /// quando couber); embaixo, Início e Fim divididos. Três campos espremidos numa linha abreviavam a data
    /// ("Sex, 25/09") e obrigavam o contratante a decifrar o dia: a informação chega pronta para ler.
    var body: some View {
        VStack(alignment: .leading, spacing: FrilaGeometry.space12) {
            FrilaJobFormLabeledField(label: "Data", isDark: isDark) {
                FrilaJobFormPickerField(
                    value: draft.shiftDate,
                    displayValue: parsedDate.map { FrilaJobShiftFormat.longDateLabel($0, now: now) },
                    hint: parsedDate.flatMap { FrilaJobShiftFormat.relativeDayLabel($0, now: now) },
                    placeholder: "Sexta-feira, 25 de setembro",
                    icon: "calendar",
                    isTime: false,
                    spokenLabel: "Data do turno",
                    spokenValue: parsedDate.map { FrilaShiftCalendar.spoken($0) },
                    isActive: editing == .date,
                    showsMissing: showsMissing,
                    isLanded: landed.contains(.date),
                    identifier: "datepicker-data",
                    isDark: isDark
                ) { editing = .date }
            }

            timesLayout {
                FrilaJobFormLabeledField(label: "Início", isDark: isDark) {
                    FrilaJobFormPickerField(
                        value: draft.startTime,
                        placeholder: "18:00",
                        icon: "clock",
                        isTime: true,
                        spokenLabel: "Início do turno",
                        spokenValue: FrilaJobShiftFormat.parseClock(draft.startTime)?.spokenLabel,
                        isActive: editing == .start,
                        showsMissing: showsMissing,
                        isLanded: landed.contains(.start),
                        filledTint: FrilaColor.dynamicBrandText(isDark: isDark),
                        identifier: "datepicker-inicio",
                        isDark: isDark
                    ) { editing = .start }
                }
                FrilaJobFormLabeledField(label: "Fim", isDark: isDark) {
                    FrilaJobFormPickerField(
                        value: draft.endTime,
                        placeholder: "02:00",
                        icon: "clock",
                        isTime: true,
                        spokenLabel: "Fim do turno",
                        spokenValue: FrilaJobShiftFormat.parseClock(draft.endTime)?.spokenLabel,
                        isActive: editing == .end,
                        showsMissing: showsMissing,
                        isLanded: landed.contains(.end),
                        filledTint: FrilaColor.dynamicBrandText(isDark: isDark),
                        identifier: "datepicker-fim",
                        isDark: isDark
                    ) { editing = .end }
                }
            }

            FrilaJobShiftHoursPanel(
                minutes: FrilaJobShiftFormat.durationMinutes(start: draft.startTime, end: draft.endTime),
                endsNextDay: FrilaJobShiftFormat.endsNextDay(start: draft.startTime, end: draft.endTime),
                isLanded: hoursLanded,
                isDark: isDark
            )

            shiftNote
        }
        .animation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: reduceMotion), value: noteKey)
        .onChange(of: editing) { old, new in editingChanged(from: old, to: new) }
        .onDisappear { landingTask?.cancel() }
    }
}

// MARK: - Campo que abre um seletor flutuante

/// Campo contornado com a mesma aparência dos campos de texto, que abre o seletor flutuante (`FrilaJobShiftOverlay`) ao toque.
///
/// Vazio e preenchido se distinguem por mais de uma pista (não só a cor): vazio usa peso regular, cor
/// discreta e um ícone de calendário ou relógio, que também anuncia que o campo abre um seletor.
/// Preenchido usa peso semibold, cor primária e números tabulares; os horários, na tinta da marca
/// (`filledTint`), lidos de relance como escolhidos. O contorno laranja da marca marca a seleção, sem ícone
/// nem mensagem; erro usa a cor de erro, com ícone e texto. Na chegada do fluxo (`isLanded`), o contorno
/// acende por um instante e um check da marca toma o lugar da pista à direita.
struct FrilaJobFormPickerField: View {
    let value: String
    /// Texto mostrado no lugar do valor guardado (ex.: a data por extenso). Nil mostra o próprio valor.
    var displayValue: String? = nil
    /// Referência curta à direita, em cor apagada ("Hoje", "Amanhã").
    var hint: String? = nil
    let placeholder: String
    let icon: String
    let isTime: Bool
    let spokenLabel: String
    let spokenValue: String?
    let isActive: Bool
    let showsMissing: Bool
    /// Aceso pela cascata de chegada depois do fluxo do cartão (`FrilaJobShiftLanding`).
    var isLanded: Bool = false
    /// Cor do valor preenchido. Nil: cor primária.
    var filledTint: Color? = nil
    /// Enxerto: identificador para os testes de UI do app (os mesmos do formulário antigo).
    var identifier: String? = nil
    let isDark: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isEmpty: Bool { value.isEmpty }
    private var isMissing: Bool { showsMissing && isEmpty && !isActive }

    private var outlineColor: Color {
        isMissing ? FrilaColor.dynamicError(isDark: isDark) : FrilaColor.dynamicBrandAccent(isDark: isDark)
    }

    private var shownText: String { isEmpty ? placeholder : (displayValue ?? value) }

    /// Mesmo texto, fonte e peso nos dois ramos do ViewThatFits: só o ícone some, os dígitos não pulam.
    /// Troca de texto escalonada (M15), por identidade: a interpolação padrão morfava os glifos entre a
    /// fonte do placeholder e a do valor e mostrava ":" ou duas datas sobrepostas no meio da troca.
    private var valueText: some View {
        ZStack(alignment: .leading) {
            valueLabel
                .id("\(isEmpty)|\(shownText)")
                .transition(.frilaFieldContent)
        }
    }

    private var valueLabel: some View {
        Text(verbatim: shownText)
            // Vazio: corpo de entrada. Data: valor em SF Semibold. Horário: mesmo corpo com dígitos tabulares.
            .frilaType(isEmpty ? FrilaFormType.input : (isTime ? FrilaFormType.value.withDigits(.tabular) : FrilaFormType.value), dynamic: true)
            .foregroundColor(
                isEmpty
                    ? FrilaColor.dynamicFormTextMuted(isDark: isDark)
                    : (filledTint ?? FrilaColor.dynamicTextPrimary(isDark: isDark))
            )
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var label: some View {
        HStack(spacing: FrilaGeometry.space6) {
            valueText
            if !isEmpty {
                Spacer(minLength: FrilaGeometry.space8)
                // Pista e check dividem o mesmo lugar e trocam por opacidade: o check da chegada não empurra
                // o texto
                ZStack(alignment: .trailing) {
                    if let hint {
                        Text(verbatim: hint)
                            .frilaType(FrilaFormType.detail, dynamic: true)
                            .foregroundColor(FrilaColor.dynamicFormTextMuted(isDark: isDark))
                            .opacity(isLanded ? 0 : 1)
                            // Troca escalonada (M15): quem sai esmaece rápido, quem entra espera
                            .animation(FrilaMovimento.animacao((isLanded ? FrilaMotion.contentFadeOut : FrilaMotion.contentFadeIn), reduzir: reduceMotion), value: isLanded)
                    }
                    Image(systemName: "checkmark")
                        .font(FrilaFonteDoSistema.fonte(size: 13, weight: .semibold))
                        .foregroundColor(FrilaColor.dynamicBrandAccent(isDark: isDark))
                        .scaleEffect(isLanded || reduceMotion ? 1 : 0.6)
                        .opacity(isLanded ? 1 : 0)
                        .animation(FrilaMovimento.animacao((isLanded ? FrilaMotion.contentFadeIn : FrilaMotion.contentFadeOut), reduzir: reduceMotion), value: isLanded)
                }
                .accessibilityHidden(true)
            }
            if isEmpty {
                Spacer(minLength: 0)
                Image(systemName: icon)
                    .font(FrilaFonteDoSistema.fonte(size: 13, weight: .regular))
                    .foregroundColor(FrilaColor.dynamicFormTextMuted(isDark: isDark))
                    .accessibilityHidden(true)
            }
        }
    }

    var body: some View {
        Button(action: action) {
            ViewThatFits(in: .horizontal) {
                label
                // Sem espaço para o ícone, o texto vale sozinho
                valueText
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .jobFormInputChrome(isDark: isDark, horizontalPadding: FrilaGeometry.space12)
            .overlay {
                // A animação fica só no contorno: aplicada ao campo inteiro, ela também animava a troca do
                // texto (o valor gravado pelo fluxo no mesmo instante em que o campo deixava de estar ativo),
                // e o texto interpolava entre placeholder e valor ("18:00" virava ":" por alguns quadros)
                RoundedRectangle(cornerRadius: FrilaGeometry.radiusInput, style: .continuous)
                    .strokeBorder(outlineColor, lineWidth: 1.5)
                    .opacity(isActive || isMissing || isLanded ? 1 : 0)
                    .animation(FrilaMovimento.animacao(FrilaMotion.tactileSpring, reduzir: reduceMotion), value: isActive)
                    .animation(FrilaMovimento.animacao(FrilaMotion.tactileSpring, reduzir: reduceMotion), value: isLanded)
            }
            .contentShape(RoundedRectangle(cornerRadius: FrilaGeometry.radiusInput, style: .continuous))
        }
        .buttonStyle(FrilaHapticBounceButtonStyle(reduceMotion: reduceMotion, scale: 0.98))
        .accessibilityIdentifier(identifier ?? "")
        .accessibilityLabel(spokenLabel)
        .accessibilityValue(spokenValue ?? (isMissing ? String(localized: "obrigatório, não definido", table: "Estudio", bundle: bundleApresentacao) : String(localized: "não definido", table: "Estudio", bundle: bundleApresentacao)))
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Seletor flutuante centralizado

/// Saída animada do cartão centralizado: roda a ação (gravar no rascunho) depois de o cartão sumir.
private struct FrilaJobShiftAnimatedDismissKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: ((@escaping () -> Void) -> Void)? = nil
}

extension EnvironmentValues {
    fileprivate var jobShiftAnimatedDismiss: ((@escaping () -> Void) -> Void)? {
        get { self[FrilaJobShiftAnimatedDismissKey.self] }
        set { self[FrilaJobShiftAnimatedDismissKey.self] = newValue }
    }
}

/// Véu e cartão ancorado embaixo, no centro horizontal. A entrada e a saída são das duas camadas (véu com
/// ease, cartão com mola e fade), sem apresentação do sistema, que subiria da borda como uma folha.
///
/// Alcance com uma mão: o cartão assenta na base da tela, a `bottomMargin` acima do indicador de início, e
/// cresce para cima. O botão e a lista de etapas ficam no terço inferior, na zona confortável do polegar,
/// e não mudam de lugar entre as etapas: só a borda de cima do cartão acompanha a altura do miolo. Com o
/// cartão centralizado (ou com um desvio fixo abaixo do centro), cada troca de altura movia o botão e a
/// lista, e o calendário alto empurrava o botão para a metade da tela.
private struct FrilaJobShiftCenteredHost<Content: View>: View {
    let dismiss: () -> Void
    @ViewBuilder let content: () -> Content

    /// Distância entre a base do cartão e a área segura inferior (o indicador de início).
    private static var bottomMargin: CGFloat { FrilaGeometry.space24 }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var isShown = false
    /// Trava de reentrada: duplo toque no OK, ou OK seguido do véu, encerra uma vez só.
    @State private var isClosing = false

    /// Curvas separadas por camada, todas só de opacidade ou escala: o véu esmaece com ease (sem mola, que
    /// faria a opacidade passar do alvo), o cartão fica com a mola de disclosure e o fade acompanha.
    private var cardScaleAnimation: Animation {
        isShown ? FrilaMotion.disclosureExpand : .easeIn(duration: 0.16)
    }
    private var cardFadeAnimation: Animation {
        isShown ? .easeOut(duration: 0.22).delay(0.04) : .easeIn(duration: 0.14)
    }

    var body: some View {
        ZStack {
            // No escuro o véu é mais denso: o cartão precisa se separar de um fundo já escuro
            Color.black.opacity(isShown ? (colorScheme == .dark ? 0.55 : 0.28) : 0)
                .ignoresSafeArea()
                .animation(FrilaMovimento.animacao(isShown ? .easeOut(duration: 0.28) : .easeIn(duration: 0.18), reduzir: reduceMotion), value: isShown)
                .onTapGesture(perform: close)
                .accessibilityHidden(true)
            // Centro horizontal e base da tela: o botão fica no alcance do polegar de destros e canhotos,
            // sem depender de qual mão segura o aparelho. A escala de entrada parte da base, onde o cartão assenta.
            content()
                .scaleEffect(isShown ? 1 : 0.96, anchor: .bottom)
                .animation(FrilaMovimento.animacao(cardScaleAnimation, reduzir: reduceMotion), value: isShown)
                .opacity(isShown ? 1 : 0)
                .animation(FrilaMovimento.animacao(cardFadeAnimation, reduzir: reduceMotion), value: isShown)
                .accessibilityAddTraits(.isModal)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, Self.bottomMargin)
        }
        .accessibilityAction(.escape, close)
        .environment(\.jobShiftAnimatedDismiss, animatedDismiss)
        .onAppear { isShown = true }
    }

    private func close() { animatedDismiss {} }

    /// Esmaece o cartão e o véu (ease-in curto, mais rápido que a entrada) e só então encerra a apresentação.
    private func animatedDismiss(_ after: @escaping () -> Void) {
        guard !isClosing else { return }
        isClosing = true
        let duration = reduceMotion ? 0.0 : 0.2
        isShown = false
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            after()
            dismiss()
        }
    }
}

/// Seletor flutuante de data e horários, desenhado como camada do próprio formulário (sem apresentação do
/// sistema): não há folha deslizando da borda, nem corrida entre apresentações, e o véu escuro só esmaece.
/// Aplicar sobre a pilha de navegação inteira para o véu cobrir também a barra superior.
struct FrilaJobShiftOverlay: View {
    @Binding var editing: FrilaJobShiftField?
    @Binding var draft: FrilaJobCreationDraft
    let isDark: Bool
    let navigationStyle: FrilaJobShiftNavigationStyle
    var now: Date = Date()

    /// Campo por onde o fluxo entrou: define a ordem cíclica das etapas.
    @State private var entry: FrilaJobShiftField?

    var body: some View {
        ZStack {
            if let field = editing {
                FrilaJobShiftCenteredHost(dismiss: { editing = nil }) {
                    FrilaJobShiftFlowCard(
                        field: field,
                        order: FrilaJobShiftField.flow(startingAt: entry ?? field),
                        draft: $draft,
                        editing: $editing,
                        isDark: isDark,
                        now: now,
                        navigation: navigationStyle
                    )
                }
                .transition(.identity)
            }
        }
        .onChange(of: editing) { old, new in
            if old == nil { entry = new }
            if new == nil { entry = nil }
        }
    }
}

/// Política pura e determinística do calendário do turno, compartilhada entre iOS e macOS.
public enum FrilaJobShiftCalendarPolicy {
    /// Janela padrão de datas reserváveis no calendário (60 dias).
    public static let defaultBookableDays: Int = 60

    /// Intervalo de datas reserváveis a partir de `now` (janela de 60 dias a contar do início do dia em Brasília).
    public static func bookableInterval(
        now: Date,
        calendar: Calendar = FrilaShiftCalendar.brasilia,
        bookableDays: Int = defaultBookableDays
    ) -> DateInterval {
        let lower = calendar.startOfDay(for: now)
        let upper = FrilaShiftCalendar.date(byAddingDays: bookableDays, to: now)
        return DateInterval(start: lower, end: upper)
    }

    /// Faixa fechada de datas reserváveis (`ClosedRange<Date>`).
    public static func bookableRange(
        now: Date,
        calendar: Calendar = FrilaShiftCalendar.brasilia,
        bookableDays: Int = defaultBookableDays
    ) -> ClosedRange<Date> {
        let lower = calendar.startOfDay(for: now)
        let upper = FrilaShiftCalendar.date(byAddingDays: bookableDays, to: now)
        return lower...upper
    }

    /// Data inicial exibida: limita datas fora da janela para a borda mais próxima sem escrita transitória.
    public static func displayedDate(
        rawDate: Date,
        now: Date,
        calendar: Calendar = FrilaShiftCalendar.brasilia,
        bookableDays: Int = defaultBookableDays
    ) -> Date {
        let range = bookableRange(now: now, calendar: calendar, bookableDays: bookableDays)
        return min(max(rawDate, range.lowerBound), range.upperBound)
    }

    /// Determina se os componentes de data podem ser selecionados dentro da faixa disponível.
    public static func canSelect(
        components: DateComponents?,
        in range: ClosedRange<Date>,
        calendar: Calendar = FrilaShiftCalendar.brasilia
    ) -> Bool {
        guard let components, let date = calendar.date(from: components) else { return false }
        return range.contains(date)
    }

    /// Compara componentes para evitar atualizações redundantes e loops de seleção.
    public static func shouldUpdateSelection(
        current: DateComponents?,
        newDate: Date,
        calendar: Calendar = FrilaShiftCalendar.brasilia
    ) -> (shouldUpdate: Bool, components: DateComponents) {
        let newComps = calendar.dateComponents([.year, .month, .day], from: newDate)
        guard let current else { return (true, newComps) }
        let isDifferent = current.year != newComps.year || current.month != newComps.month || current.day != newComps.day
        return (isDifferent, newComps)
    }

    /// Número de semanas do mês no calendário de referência (5 ou 6).
    public static func numberOfWeeks(
        in date: Date,
        calendar: Calendar = FrilaShiftCalendar.brasilia
    ) -> Int {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return 5 }
        let range = calendar.range(of: .weekOfMonth, in: .month, for: monthInterval.start)
        return range?.count ?? 5
    }

    /// Detecta se a transição entre duas datas ou meses altera a contagem de semanas (5 ↔ 6).
    public static func isWeekCountTransition(
        from oldDate: Date,
        to newDate: Date,
        calendar: Calendar = FrilaShiftCalendar.brasilia
    ) -> Bool {
        numberOfWeeks(in: oldDate, calendar: calendar) != numberOfWeeks(in: newDate, calendar: calendar)
    }
}

#if os(iOS)
/// Representable de UICalendarView com UICalendarSelectionSingleDate para seleção estável e determinística.
///
/// A UICalendarView nativa não sofre do atraso de layout do DatePicker(.graphical) do SwiftUI:
/// a altura e as posições de células e cabeçalho são intrínsecas e estáveis desde a abertura,
/// sem reorganização nem salto vertical ao receber o primeiro toque em um dia.
public struct FrilaJobShiftCalendarRepresentable: UIViewRepresentable {
    @Binding var date: Date
    let range: ClosedRange<Date>
    let isDark: Bool
    let calendar: Calendar
    let locale: Locale
    let reduceMotion: Bool

    @Environment(\.accessibilityReduceMotion) private var envReduceMotion

    var effectiveReduceMotion: Bool {
        reduceMotion || envReduceMotion
    }

    public init(
        date: Binding<Date>,
        range: ClosedRange<Date>,
        isDark: Bool,
        calendar: Calendar = FrilaShiftCalendar.brasilia,
        locale: Locale = Locale(identifier: "pt_BR"),
        reduceMotion: Bool = false
    ) {
        self._date = date
        self.range = range
        self.isDark = isDark
        self.calendar = calendar
        self.locale = locale
        self.reduceMotion = reduceMotion
    }

    public func makeUIView(context: Context) -> UICalendarView {
        let calendarView = UICalendarView()
        calendarView.calendar = calendar
        calendarView.locale = locale
        calendarView.timeZone = calendar.timeZone
        calendarView.availableDateRange = DateInterval(start: range.lowerBound, end: range.upperBound)
        calendarView.tintColor = isDark ? FrilaColor.uiPrimary400 : FrilaColor.uiPrimary500
        calendarView.overrideUserInterfaceStyle = isDark ? .dark : .light
        calendarView.accessibilityLabel = "Data do turno"
        calendarView.delegate = context.coordinator

        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        selection.selectedDate = calendar.dateComponents([.year, .month, .day], from: date)
        calendarView.selectionBehavior = selection

        let initialMonth = calendar.dateComponents([.year, .month], from: date)
        calendarView.setVisibleDateComponents(initialMonth, animated: false)

        calendarView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        calendarView.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)

        return calendarView
    }

    /// Sincroniza os atributos mutáveis da UICalendarView e renova o parent no coordenador.
    public static func synchronize(
        _ calendarView: UICalendarView,
        coordinator: Coordinator,
        with representable: FrilaJobShiftCalendarRepresentable
    ) {
        coordinator.parent = representable
        calendarView.calendar = representable.calendar
        calendarView.locale = representable.locale
        calendarView.timeZone = representable.calendar.timeZone
        calendarView.availableDateRange = DateInterval(start: representable.range.lowerBound, end: representable.range.upperBound)
        calendarView.tintColor = representable.isDark ? FrilaColor.uiPrimary400 : FrilaColor.uiPrimary500
        calendarView.overrideUserInterfaceStyle = representable.isDark ? .dark : .light
        if let selection = calendarView.selectionBehavior as? UICalendarSelectionSingleDate {
            let check = FrilaJobShiftCalendarPolicy.shouldUpdateSelection(
                current: selection.selectedDate,
                newDate: representable.date,
                calendar: representable.calendar
            )
            if check.shouldUpdate {
                selection.setSelected(check.components, animated: false)
            }
        }
    }

    public func updateUIView(_ calendarView: UICalendarView, context: Context) {
        Self.synchronize(calendarView, coordinator: context.coordinator, with: self)
    }

    public func sizeThatFits(_ proposal: ProposedViewSize, uiView: UICalendarView, context: Context) -> CGSize? {
        let width = proposal.width ?? 328
        return uiView.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        public var parent: FrilaJobShiftCalendarRepresentable

        init(_ parent: FrilaJobShiftCalendarRepresentable) {
            self.parent = parent
        }

        public func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let dateComponents,
                  let selectedDate = parent.calendar.date(from: dateComponents) else { return }
            parent.date = selectedDate
        }

        public func dateSelection(_ selection: UICalendarSelectionSingleDate, canSelectDate dateComponents: DateComponents?) -> Bool {
            FrilaJobShiftCalendarPolicy.canSelect(components: dateComponents, in: parent.range, calendar: parent.calendar)
        }

        public func calendarView(_ calendarView: UICalendarView, didChangeVisibleDateComponentsFrom previousDateComponents: DateComponents) {
            if parent.effectiveReduceMotion {
                calendarView.invalidateIntrinsicContentSize()
            } else {
                withAnimation(FrilaMovimento.animacao(FrilaMotion.shiftCardMorph, reduzir: FrilaMovimentoReduzido.ativo)) {
                    calendarView.invalidateIntrinsicContentSize()
                }
            }
        }
    }
}
#endif

/// O cartão do fluxo do turno: um só container do começo ao fim, que muda de forma em vez de ser trocado.
///
/// Um dono para o morph (filosofia de movimento, princípio 3): fundo, borda, raio e sombra vivem neste
/// cartão, que fica de pé durante o fluxo inteiro. A lista de etapas e o botão também ficam: a camada de
/// seleção desliza até a etapa ativa e o botão troca de texto no lugar. Só o miolo (calendário ou roleta) é
/// trocado, com a troca escalonada dos campos (`frilaFieldContent`). Largura e altura do cartão acompanham o
/// miolo numa mola suave com bounce leve (`shiftCardMorph`): do calendário, largo e alto, para a roleta,
/// mais estreita e baixa. A versão anterior trocava o cartão inteiro com deslize lateral e lia como outro
/// cartão chegando, não como a mesma coisa progredindo.
///
/// Ordem de cima para baixo: miolo, lista de etapas, botão. Com o cartão ancorado na base da tela, o que se
/// toca a cada etapa (a lista e o botão) fica fixo no terço inferior, e o miolo, de altura variável, cresce
/// para cima.
struct FrilaJobShiftFlowCard: View {
    let field: FrilaJobShiftField
    let order: [FrilaJobShiftField]
    @Binding var draft: FrilaJobCreationDraft
    @Binding var editing: FrilaJobShiftField?
    let isDark: Bool
    let now: Date
    let navigation: FrilaJobShiftNavigationStyle

    @Environment(\.jobShiftAnimatedDismiss) private var animatedDismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var date: Date
    @State private var start: FrilaShiftClock
    @State private var end: FrilaShiftClock

    private static let clockOptions = FrilaShiftClock.options(stepMinutes: 30)

    #if !os(iOS)
    @State private var calendarHeight: CGFloat
    @State private var currentWeekCount: Int
    #endif

    init(field: FrilaJobShiftField, order: [FrilaJobShiftField], draft: Binding<FrilaJobCreationDraft>, editing: Binding<FrilaJobShiftField?>, isDark: Bool, now: Date, navigation: FrilaJobShiftNavigationStyle = .overviewList) {
        self.field = field
        self.order = order
        self._draft = draft
        self._editing = editing
        self.isDark = isDark
        self.now = now
        self.navigation = navigation
        let current = draft.wrappedValue
        // Data do rascunho fora da janela de 60 dias abre na borda mais próxima, sem gravar fora do intervalo
        let rawDate = FrilaJobShiftFormat.parseDate(current.shiftDate, now: now) ?? now
        let displayedDate = FrilaJobShiftCalendarPolicy.displayedDate(rawDate: rawDate, now: now)
        self._date = State(initialValue: displayedDate)
        self._start = State(initialValue: Self.nearest(FrilaJobShiftFormat.parseClock(current.startTime) ?? FrilaShiftClock(hour: 18)))
        self._end = State(initialValue: Self.nearest(
            FrilaJobShiftFormat.parseClock(current.endTime) ?? FrilaJobShiftFormat.suggestedEnd(after: current.startTime)
        ))
        #if !os(iOS)
        let initialWeeks = Self.numberOfWeeks(in: displayedDate)
        self._currentWeekCount = State(initialValue: initialWeeks)
        let navWidth = navigation.contentWidth
        self._calendarHeight = State(initialValue: Self.calendarHeight(for: initialWeeks, width: navWidth))
        #endif
    }

    #if !os(iOS)
    /// Altura determinística do calendário no macOS (fallback de compilação por semanas e largura).
    static func calendarHeight(for weeks: Int = 5, width: CGFloat = 328) -> CGFloat {
        let base: CGFloat = 104.0 + 2.0 / 3.0
        let row: CGFloat = 45.0
        let normalizedWeeks = max(weeks, 4)
        let scale = width / 328.0
        return (base + CGFloat(normalizedWeeks) * row) * scale
    }
    #endif

    /// Número de semanas do mês no calendário de referência (5 ou 6).
    static func numberOfWeeks(in date: Date, calendar: Calendar = FrilaShiftCalendar.brasilia) -> Int {
        FrilaJobShiftCalendarPolicy.numberOfWeeks(in: date, calendar: calendar)
    }

    /// A roleta anda de 30 em 30: um horário fora da grade abre na opção mais próxima.
    private static func nearest(_ clock: FrilaShiftClock) -> FrilaShiftClock {
        clockOptions.min { abs($0.minutes - clock.minutes) < abs($1.minutes - clock.minutes) } ?? clock
    }

    private var step: FrilaJobShiftStep { FrilaJobShiftStep(order: order, current: field) }

    private var range: ClosedRange<Date> {
        FrilaJobShiftCalendarPolicy.bookableRange(now: now)
    }

    /// Modelo de navegação entre etapas (A: lista embaixo; B: seletor no topo).
    /// Largura máxima do miolo, igual em todas as etapas (ver `FrilaJobShiftNavigationStyle.contentWidth`).
    private var contentWidth: CGFloat { navigation.contentWidth }

    #if !os(iOS)
    /// Altura do espaço do miolo na etapa atual no macOS.
    private var coreHeight: CGFloat { field == .date ? calendarHeight : navigation.wheelHeight }
    #endif

    /// Valor de cada etapa: vivo na ativa, guardado nas demais. `compact`: data curta, para os segmentos.
    private func overviewValue(_ row: FrilaJobShiftField, compact: Bool) -> String? {
        if row == field { return FrilaJobShiftOverview.liveValue(row, date: date, start: start, end: end, now: now, compact: compact) }
        return FrilaJobShiftOverview.savedValue(row, shiftDate: draft.shiftDate, startTime: draft.startTime, endTime: draft.endTime, now: now, compact: compact)
    }

    var body: some View {
        VStack(spacing: FrilaGeometry.space12) {
            if navigation == .topPicker {
                FrilaJobShiftStepPicker(
                    current: field,
                    value: { overviewValue($0, compact: true) },
                    spokenValue: { overviewValue($0, compact: false) },
                    isDark: isDark,
                    onSelect: jump
                )
            }

            core

            if navigation == .overviewList {
                FrilaJobShiftStepList(current: field, value: { overviewValue($0, compact: false) }, isDark: isDark, onSelect: jump)
                    // A lista avança sobre o padding do cartão como no seletor de experiência: linhas a 4 pt
                    // da borda e texto a 14 pt
                    .padding(.horizontal, -(FrilaGeometry.space16 - FrilaGeometry.space4))
            }

            FrilaJobShiftPopoverConfirm(title: step.confirmTitle, isDark: isDark, action: confirm)
        }
        .frame(maxWidth: contentWidth)
        .modifier(FrilaJobShiftCardChrome(isDark: isDark))
    }

    #if os(iOS)
    /// O miolo no iOS: o calendário adota sua altura intrínseca via `sizeThatFits` da UICalendarView,
    /// sem números mágicos nem medições redundantes, e as roletas mantêm a altura padrão.
    private var core: some View {
        Group {
            if field == .date {
                FrilaJobShiftCalendarRepresentable(
                    date: $date,
                    range: range,
                    isDark: isDark,
                    calendar: FrilaShiftCalendar.brasilia,
                    locale: Locale(identifier: "pt_BR"),
                    reduceMotion: reduceMotion
                )
                .transition(reduceMotion ? .identity : .asymmetric(
                    insertion: .opacity.animation(FrilaMovimento.animacao(FrilaMotion.coreSwapFadeIn, reduzir: FrilaMovimentoReduzido.ativo)),
                    removal: .opacity.animation(FrilaMovimento.animacao(FrilaMotion.contentFadeOut, reduzir: FrilaMovimentoReduzido.ativo))
                ))
            } else if field == .start {
                clockWheel(title: FrilaJobShiftField.start.stepTitle, selection: $start)
                    .transition(reduceMotion ? .identity : .asymmetric(
                        insertion: .opacity.animation(FrilaMovimento.animacao(FrilaMotion.coreSwapFadeIn, reduzir: FrilaMovimentoReduzido.ativo)),
                        removal: .opacity.animation(FrilaMovimento.animacao(FrilaMotion.contentFadeOut, reduzir: FrilaMovimentoReduzido.ativo))
                    ))
            } else {
                clockWheel(title: FrilaJobShiftField.end.stepTitle, selection: $end)
                    .transition(reduceMotion ? .identity : .asymmetric(
                        insertion: .opacity.animation(FrilaMovimento.animacao(FrilaMotion.coreSwapFadeIn, reduzir: FrilaMovimentoReduzido.ativo)),
                        removal: .opacity.animation(FrilaMovimento.animacao(FrilaMotion.contentFadeOut, reduzir: FrilaMovimentoReduzido.ativo))
                    ))
            }
        }
        .clipped()
    }
    #else
    /// O miolo no macOS: container com altura explícita animada na troca de etapas e overlay ancorado embaixo.
    private var core: some View {
        Color.clear
            .frame(height: coreHeight)
            .overlay(alignment: .bottom) {
                if field == .date {
                    DatePicker("Data do turno", selection: $date, in: range, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "pt_BR"))
                        .environment(\.calendar, FrilaShiftCalendar.brasilia)
                        .environment(\.timeZone, FrilaShiftCalendar.brasilia.timeZone)
                        .frame(height: calendarHeight)
                        .clipped()
                        .onChange(of: date) { _, newDate in
                            let weeks = Self.numberOfWeeks(in: newDate)
                            if weeks != currentWeekCount {
                                currentWeekCount = weeks
                                withAnimation(FrilaMovimento.animacao(FrilaMotion.shiftCardMorph, reduzir: reduceMotion)) {
                                    calendarHeight = Self.calendarHeight(for: weeks, width: contentWidth)
                                }
                            }
                        }
                        .transition(reduceMotion ? .identity : .asymmetric(
                            insertion: .opacity.animation(FrilaMovimento.animacao(FrilaMotion.coreSwapFadeIn, reduzir: FrilaMovimentoReduzido.ativo)),
                            removal: .opacity.animation(FrilaMovimento.animacao(FrilaMotion.contentFadeOut, reduzir: FrilaMovimentoReduzido.ativo))
                        ))
                }
            }
            .overlay(alignment: .bottom) {
                coreLayer(.start) { clockWheel(title: FrilaJobShiftField.start.stepTitle, selection: $start) }
            }
            .overlay(alignment: .bottom) {
                coreLayer(.end) { clockWheel(title: FrilaJobShiftField.end.stepTitle, selection: $end) }
            }
            .clipped()
    }

    /// Uma camada do miolo no macOS: visível só na própria etapa, sem toque nem VoiceOver quando escondida.
    private func coreLayer<Content: View>(_ owner: FrilaJobShiftField, @ViewBuilder _ content: () -> Content) -> some View {
        let isShown = field == owner
        return content()
            .opacity(isShown ? 1 : 0)
            .animation(FrilaMovimento.animacao((isShown ? FrilaMotion.coreSwapFadeIn : FrilaMotion.contentFadeOut), reduzir: reduceMotion), value: isShown)
            .allowsHitTesting(isShown)
            .accessibilityElement(children: isShown ? .contain : .ignore)
            .accessibilityHidden(!isShown)
    }
    #endif

    private func clockWheel(title: String, selection: Binding<FrilaShiftClock>) -> some View {
        Picker(title, selection: selection) {
            ForEach(Self.clockOptions) { clock in
                Text(verbatim: clock.fieldLabel)
                    .font(FrilaTypography.metricTabular(size: 22, weight: .medium))
                    .tag(clock)
                    .accessibilityLabel(clock.spokenLabel)
            }
        }
        #if os(iOS)
        .pickerStyle(.wheel)
        #endif
        .labelsHidden()
        .frame(height: navigation.wheelHeight)
    }

    /// Toque numa linha da lista: grava a etapa atual e salta para a escolhida, no mesmo cartão. Liberdade
    /// de ir e voltar entre as três etapas sem passar pelo botão. A troca anda na mola da lista
    /// (`selectionWashSlide`): camada, miolo e cartão na mesma transação, então a camada nunca se descola
    /// das linhas enquanto o cartão muda de altura.
    private func jump(to target: FrilaJobShiftField) {
        guard target != field else { return }
        writer(for: field)()
        withAnimation(FrilaMovimento.animacao(FrilaMotion.selectionWashSlide, reduzir: reduceMotion)) { editing = target }
    }

    /// Grava a etapa. Intermediária: avança no mesmo cartão, que muda de forma. Última: o cartão fecha
    /// e só então grava, como antes.
    private func confirm() {
        let write = writer(for: field)
        guard let next = step.next else {
            // A última gravação acontece com o cartão já fora: anima para o campo trocar o texto com a
            // troca escalonada, não num corte seco
            let animatedWrite = { withAnimation(FrilaMovimento.animacao(FrilaMotion.contentFadeIn, reduzir: reduceMotion)) { write() } }
            if let animatedDismiss { animatedDismiss(animatedWrite) } else { animatedWrite() }
            return
        }
        write()
        withAnimation(FrilaMovimento.animacao(FrilaMotion.shiftCardMorph, reduzir: reduceMotion)) { editing = next }
    }

    private func writer(for field: FrilaJobShiftField) -> () -> Void {
        switch field {
        case .date:
            let chosen = date
            return { draft.shiftDate = FrilaJobShiftFormat.dateLabel(chosen) }
        case .start:
            let chosen = start
            return {
                draft.startTime = chosen.fieldLabel
                draft.recalculateTotalBudget()
                // Fim ainda vazio: a roleta de fim abre na sugestão a partir do início que acabou de entrar
                if draft.endTime.isEmpty { end = Self.nearest(FrilaJobShiftFormat.suggestedEnd(after: draft.startTime)) }
            }
        case .end:
            let chosen = end
            return {
                draft.endTime = chosen.fieldLabel
                draft.recalculateTotalBudget()
            }
        }
    }
}

/// Lista de etapas do cartão do turno: Data, Início e Fim, sempre as três, na ordem do formulário.
///
/// Transplante da lista aberta do seletor de experiência (peças em `FrilaSelectionLayerList.swift`): uma
/// linha de largura total por etapa, com o nome e o valor atual; uma camada única de seleção atrás das
/// linhas marca a etapa cujo miolo (calendário ou roleta) está aberto, e o nome dela ganha peso com o
/// cross-fade desfocado. Tocar numa linha grava a etapa atual e salta para a tocada.
///
/// Diferenças mínimas do original: a camada usa `dynamicRaisedSelectionLayer` (no escuro o cartão já é o
/// tom do campo, e a camada sobe um degrau); o valor da linha muda com `numericText` (M15); não há
/// recolhimento, porque a lista é o mapa do fluxo e o cartão fecha no Concluir.
struct FrilaJobShiftStepList: View {
    let current: FrilaJobShiftField
    let value: (FrilaJobShiftField) -> String?
    let isDark: Bool
    let onSelect: (FrilaJobShiftField) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Mesmo raio das linhas do seletor de experiência (cartão de 16 menos o respiro de 4). As linhas não
    /// tocam os cantos do cartão do turno, então o raio dele não as governa.
    private let rowRadius = FrilaGeometry.concentricInnerRadius(outerRadius: FrilaGeometry.radiusCard, padding: FrilaGeometry.space4)
    /// Respiro do texto: com a lista a 4 pt da borda do cartão, o texto fica a 14 pt, como no original.
    private let rowTextPadding: CGFloat = FrilaGeometry.space10

    private var layerFill: Color { FrilaColor.dynamicRaisedSelectionLayer(isDark: isDark) }
    /// Filete de 8% só no claro, como os campos do grupo; no escuro o degrau de tom basta.
    private var layerStroke: Color? { FrilaPickerGroupStyle.neutral.fieldStroke(isDark: isDark) }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(FrilaJobShiftField.allCases) { field in
                row(field)
                    .frilaSelectionRow(id: field.rawValue)
            }
        }
        .frilaSelectionLayerBackground(selectedID: current.rawValue, radius: rowRadius, fill: layerFill, stroke: layerStroke)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Etapas do turno", table: "Estudio", bundle: bundleApresentacao))
    }

    /// Valor da linha (M15, sem duas camadas de texto legíveis ao mesmo tempo): entre "A definir" e um
    /// valor, e entre duas datas, a troca escalonada dos campos; entre dois horários, os dígitos rolam
    /// (`numericText`), acompanhando a roleta. Valor em tinta secundária (AA também sobre a camada);
    /// pendente em cinza apagado.
    private func valueText(_ field: FrilaJobShiftField, _ shown: String?) -> some View {
        ZStack(alignment: .leading) {
            if let shown {
                Text(verbatim: shown)
                    .frilaType(field == .date ? FrilaFormType.detail : FrilaFormType.detail.withDigits(.tabular), dynamic: true)
                    .foregroundColor(FrilaColor.dynamicInkSecondary(isDark: isDark))
                    .lineLimit(1)
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .id(field == .date ? shown : "valor")
                    .transition(.frilaFieldContent)
            } else {
                Text(verbatim: FrilaJobShiftOverview.pendingLabel)
                    .frilaType(FrilaFormType.detail, dynamic: true)
                    .foregroundColor(FrilaColor.dynamicFormTextMuted(isDark: isDark))
                    .transition(.frilaFieldContent)
            }
        }
        .animation(FrilaMovimento.animacao(FrilaMotion.selectionTextCrossfade, reduzir: reduceMotion), value: shown)
    }

    private func row(_ field: FrilaJobShiftField) -> some View {
        let isActive = field == current
        let shown = value(field)
        return Button { onSelect(field) } label: {
            VStack(alignment: .leading, spacing: FrilaGeometry.space2) {
                FrilaWeightCrossfadeTitle(text: field.rowTitle, isEmphasized: isActive, color: FrilaColor.dynamicTextPrimary(isDark: isDark))
                valueText(field, shown)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, rowTextPadding)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(FrilaPreselectionButtonStyle(radius: rowRadius, fill: layerFill, isSelected: isActive, reduceMotion: reduceMotion))
        // A etapa aberta não recebe toque: um aperto sem efeito seria uma pista falsa
        .allowsHitTesting(!isActive)
        .frilaHitbox()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(field.rowTitle), \(shown ?? FrilaJobShiftOverview.pendingLabel.lowercased())"))
        .accessibilityHint(isActive ? "" : String(localized: "Toque para editar", table: "Estudio", bundle: bundleApresentacao))
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}

/// Modelo B (experimental): seletor segmentado no topo do cartão, com as três etapas lado a lado.
///
/// O seletor com seleção ativa no lugar da lista: uma trilha em cápsula afundada no cartão, um segmento por
/// etapa (Data, Início, Fim, na ordem do formulário) com o nome e o valor curto ("Qui, 1 out", "18:00", "A
/// definir"), e uma cápsula elevada única que desliza até a etapa aberta. Lê como abas de um passo curto,
/// o padrão de Entrada e Saída do Airbnb, e deixa o cartão mais baixo que o modelo A (sem a lista de 180 pt).
/// Reaproveita as peças da lista (`frilaSelectionRow`, `frilaSelectionLayerBackground`,
/// `FrilaWeightCrossfadeTitle`): mesma camada única, mesmo cross-fade de peso.
struct FrilaJobShiftStepPicker: View {
    let current: FrilaJobShiftField
    /// Valor curto mostrado no segmento.
    let value: (FrilaJobShiftField) -> String?
    /// Valor completo para o VoiceOver ("quinta-feira, 1 de outubro").
    let spokenValue: (FrilaJobShiftField) -> String?
    let isDark: Bool
    let onSelect: (FrilaJobShiftField) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Segmento e cápsula de 52 pt (altura proeminente); trilha de 60 pt com respiro de 4 (R 30 = 26 + 4).
    private let segmentHeight = FrilaGeometry.buttonHeightProminent
    private let inset = FrilaGeometry.space4

    /// Trilha afundada no cartão: no claro o cinza da camada de seleção sobre o branco; no escuro o tom do
    /// grupo, abaixo do cartão.
    private var trackFill: Color {
        isDark ? FrilaColor.dynamicGroupGraphite(isDark: true) : FrilaColor.dynamicSelectionWash(isDark: false)
    }
    /// Cápsula ativa elevada: branca com filete de 8% no claro; um degrau acima do cartão no escuro.
    private var gliderFill: Color {
        isDark ? FrilaColor.dynamicRaisedSelectionLayer(isDark: true) : FrilaColor.canvasLight
    }
    private var gliderStroke: Color? { isDark ? nil : FrilaColor.groupFieldStrokeLight }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(FrilaJobShiftField.allCases) { field in
                segment(field)
                    .frilaSelectionRow(id: field.rawValue)
            }
        }
        .frilaSelectionLayerBackground(selectedID: current.rawValue, radius: segmentHeight / 2, fill: gliderFill, stroke: gliderStroke)
        .padding(inset)
        .background(trackFill, in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Etapas do turno", table: "Estudio", bundle: bundleApresentacao))
    }

    private func segment(_ field: FrilaJobShiftField) -> some View {
        let isActive = field == current
        let shown = value(field)
        return Button { onSelect(field) } label: {
            VStack(spacing: 0) {
                FrilaWeightCrossfadeTitle(text: field.rowTitle, isEmphasized: isActive, color: FrilaColor.dynamicTextPrimary(isDark: isDark), alignment: .center)
                segmentValue(field, shown)
            }
            .frame(maxWidth: .infinity)
            .frame(height: segmentHeight)
            .contentShape(Capsule())
        }
        .buttonStyle(FrilaPreselectionButtonStyle(radius: segmentHeight / 2, fill: gliderFill, isSelected: isActive, reduceMotion: reduceMotion))
        .allowsHitTesting(!isActive)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "\(field.rowTitle), \(spokenValue(field) ?? FrilaJobShiftOverview.pendingLabel.lowercased())", table: "Estudio", bundle: bundleApresentacao))
        .accessibilityHint(isActive ? "" : String(localized: "Toque para editar", table: "Estudio", bundle: bundleApresentacao))
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }

    /// Mesma regra de troca da lista (M15): escalonada entre pendente e valor e entre datas; dígitos rolando
    /// entre horários.
    private func segmentValue(_ field: FrilaJobShiftField, _ shown: String?) -> some View {
        ZStack {
            if let shown {
                Text(verbatim: shown)
                    .frilaType(field == .date ? FrilaFormType.detail : FrilaFormType.detail.withDigits(.tabular), dynamic: true)
                    .foregroundColor(FrilaColor.dynamicInkSecondary(isDark: isDark))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .id(field == .date ? shown : "valor")
                    .transition(.frilaFieldContent)
            } else {
                Text(verbatim: FrilaJobShiftOverview.pendingLabel)
                    .frilaType(FrilaFormType.detail, dynamic: true)
                    .foregroundColor(FrilaColor.dynamicFormTextMuted(isDark: isDark))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .transition(.frilaFieldContent)
            }
        }
        .animation(FrilaMovimento.animacao(FrilaMotion.selectionTextCrossfade, reduzir: reduceMotion), value: shown)
    }
}

/// Chrome único do cartão do turno: superfície, borda, raio, sombra, padding de 16 pt e margem lateral de
/// 20 pt (o cartão do calendário, 360 pt, cabe com 21 pt de cada lado num iPhone de 402 pt).
/// Aplicado uma vez, no cartão persistente: o recorte acompanha o tamanho animado, então o miolo
/// nunca vaza durante o redimensionamento.
private struct FrilaJobShiftCardChrome: ViewModifier {
    let isDark: Bool

    func body(content: Content) -> some View {
        content
            .padding(FrilaGeometry.space16)
            // No escuro, o cartão um tom acima do fundo (#2A2A27): sobre o véu denso ele se destaca. No claro,
            // branco, como o grupo do seletor de experiência: a camada #F6F6F4 com filete lê sobre ele
            .background(isDark ? FrilaColor.dynamicGroupGraphiteField(isDark: true) : FrilaPickerGroupStyle.neutral.fill(isDark: false))
            .clipShape(RoundedRectangle(cornerRadius: FrilaGeometry.radiusCardEditorial, style: .continuous))
            // Cartão em foco sobre o véu: Beautiful Shadows lg (anel e seis camadas)
            .frilaModalElevation(isDark: isDark, cornerRadius: FrilaGeometry.radiusCardEditorial)
            .padding(.horizontal, FrilaGeometry.space20)
    }
}

/// Confirmação explícita dos seletores: cápsula primária de 44 pt. "Próximo" com chevron nas etapas
/// intermediárias, "Concluir" na última.
struct FrilaJobShiftPopoverConfirm: View {
    var title: String = "OK"
    let isDark: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Troca escalonada do rótulo (sai, depois entra): o cross-fade simultâneo sobrepunha "Próximo"
            // e "Concluir" no meio da troca (M15)
            ZStack {
                HStack(spacing: FrilaGeometry.space6) {
                    Text(verbatim: title)
                        .font(FrilaTypography.button)
                    if title == "Próximo" {
                        Image(systemName: "chevron.right")
                            .font(FrilaFonteDoSistema.fonte(size: 12, weight: .bold))
                    }
                }
                .id(title)
                .transition(.frilaFieldContent)
            }
            .frame(maxWidth: .infinity)
            .frame(height: FrilaGeometry.buttonHeightStandard)
        }
        .buttonStyle(FrilaPillButtonStyle(variant: .primary, isDark: isDark))
    }
}


// MARK: - Painel de horas contratadas

/// Horas contratadas em evidência, logo abaixo dos campos do turno: o número que o contratante paga
/// (e que define o total no valor por hora) não pode ficar numa linha de apoio.
///
/// Número em SF Pro tabular (anima ao mudar). A borda do painel acende no tom da marca como o fim da
/// cascata de chegada do fluxo do cartão (`isLanded`, controlado por `FrilaJobFormShiftTimeRow`): o olhar desce
/// pelos campos preenchidos até o novo valor. Antes o painel acendia sozinho 380 ms depois de o número
/// mudar, e no fluxo linear isso acontecia ainda sob o véu. Movimento reduzido: sem rolagem do número.
struct FrilaJobShiftHoursPanel: View {
    let minutes: Int?
    let endsNextDay: Bool
    var isLanded: Bool = false
    let isDark: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .center, spacing: FrilaGeometry.space12) {
            VStack(alignment: .leading, spacing: FrilaGeometry.space2) {
                Text("Horas contratadas", tableName: "Estudio", bundle: bundleApresentacao)
                    .frilaType(FrilaFormType.fieldLabel, dynamic: true)
                    .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
                if let minutes {
                    Text(verbatim: FrilaJobShiftFormat.durationLabel(minutes: minutes))
                        .font(FrilaTypography.metricTabular(size: 26, weight: .bold))
                        .foregroundColor(FrilaColor.dynamicTextPrimary(isDark: isDark))
                        .contentTransition(reduceMotion ? .identity : .numericText(value: Double(minutes)))
                } else {
                    Text("Escolha o início e o fim", tableName: "Estudio", bundle: bundleApresentacao)
                        .frilaType(FrilaFormType.detail, dynamic: true)
                        .foregroundColor(FrilaColor.dynamicFormTextMuted(isDark: isDark))
                }
            }
            Spacer(minLength: FrilaGeometry.space8)
            if minutes != nil && endsNextDay {
                Label(String(localized: "Termina no dia seguinte", table: "Estudio", bundle: bundleApresentacao), systemImage: "moon.stars")
                    .frilaType(FrilaFormType.detail, dynamic: true)
                    .foregroundColor(FrilaColor.dynamicTextMuted(isDark: isDark))
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, FrilaGeometry.space14)
        .padding(.vertical, FrilaGeometry.space12)
        .background(FrilaColor.dynamicFormFieldSurface(isDark: isDark), in: RoundedRectangle(cornerRadius: FrilaGeometry.radiusInput, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FrilaGeometry.radiusInput, style: .continuous)
                .strokeBorder(FrilaColor.dynamicBrandAccent(isDark: isDark), lineWidth: 1.5)
                .opacity(isLanded ? 1 : 0)
        }
        .animation(FrilaMovimento.animacao(FrilaMotion.tactileSpring, reduzir: reduceMotion), value: minutes)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            minutes.map { String(localized: "Horas contratadas: \(FrilaJobShiftFormat.durationSpoken(minutes: $0))\(endsNextDay ? ", termina no dia seguinte" : "")", table: "Estudio", bundle: bundleApresentacao) }
                ?? String(localized: "Horas contratadas: escolha o início e o fim", table: "Estudio", bundle: bundleApresentacao)
        )
    }
}
