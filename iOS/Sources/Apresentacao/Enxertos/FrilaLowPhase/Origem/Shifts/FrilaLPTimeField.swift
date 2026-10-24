import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Campo de horário: mostra "18:00" no campo contornado e, no toque, abre um popover ancorado
/// no próprio campo com a roda nativa de horas e minutos (24 h, passo de 15 min).
/// O valor muda enquanto a roda gira; tocar fora fecha.
public struct FrilaLPTimeField: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public let title: String
    @Binding public var selection: FrilaLPShiftClock
    public let minuteInterval: Int
    @State private var isPicking = false

    public init(_ title: String, selection: Binding<FrilaLPShiftClock>, minuteInterval: Int = 15, initiallyPicking: Bool = false) {
        self.title = title
        self._selection = selection
        self.minuteInterval = minuteInterval
        self._isPicking = State(initialValue: initiallyPicking)
    }

    private var isDark: Bool { colorScheme == .dark }
    private var secondary: Color { FrilaLPColor.dynamicSecondaryText(isDark: isDark) }

    public var body: some View {
        Button {
            isPicking = true
        } label: {
            FrilaLPOutlinedField(isFocused: isPicking) {
                Image(systemName: "clock")
                    .foregroundStyle(secondary)
                    .accessibilityHidden(true)
                Text(verbatim: selection.fieldLabel)
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .animation(FrilaMovimento.animacao(FrilaLPMotion.tactileSpring, reduzir: reduceMotion), value: selection)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(secondary)
                    .rotationEffect(.degrees(isPicking && !reduceMotion ? 180 : 0))
                    .animation(FrilaMovimento.animacao(FrilaLPMotion.tactileSpring, reduzir: reduceMotion), value: isPicking)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(FrilaLPHapticBounceButtonStyle(scale: 0.98))
        .popover(isPresented: $isPicking, arrowEdge: .bottom) {
            picker
                .presentationCompactAdaptation(.popover)
        }
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityLabel(title)
        .accessibilityValue(selection.spokenLabel)
        .accessibilityHint(Text("Toque para escolher o horário", bundle: bundleApresentacao))
    }

    private var picker: some View {
        VStack(spacing: FrilaLPGeometry.space4) {
            Text(verbatim: title)
                .font(FrilaLPTypography.Native.fieldLabel)
                .foregroundStyle(FrilaLPColor.dynamicTextPrimary(isDark: isDark))
                .padding(.top, FrilaLPGeometry.space12)
            FrilaLPShiftTimeWheel(selection: $selection, minuteInterval: minuteInterval)
                .frame(width: 220, height: 180)
        }
        .padding(.horizontal, FrilaLPGeometry.space12)
        .padding(.bottom, FrilaLPGeometry.space8)
    }
}

// MARK: - Conversão entre FrilaLPShiftClock e Date

extension FrilaLPShiftClock {
    /// Hora do dia como `Date` num dia de referência fixo, no fuso de Brasília.
    func referenceDate(calendar: Calendar = FrilaLPShiftCalendar.brasilia) -> Date {
        let day = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? Date(timeIntervalSince1970: 0)
        return calendar.date(byAdding: .minute, value: minutes, to: day) ?? day
    }

    init(date: Date, calendar: Calendar = FrilaLPShiftCalendar.brasilia) {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }
}

// MARK: - Roda de horário

#if os(iOS)
/// `UIDatePicker` em modo horário com rodas: único jeito nativo de ter passo de minutos.
struct FrilaLPShiftTimeWheel: UIViewRepresentable {
    @Binding var selection: FrilaLPShiftClock
    let minuteInterval: Int

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .wheels
        picker.minuteInterval = minuteInterval
        picker.locale = Locale(identifier: "pt_BR")
        picker.timeZone = FrilaLPShiftCalendar.brasilia.timeZone
        picker.calendar = FrilaLPShiftCalendar.brasilia
        picker.date = selection.referenceDate()
        picker.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        picker.setContentHuggingPriority(.defaultLow, for: .horizontal)
        picker.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        context.coordinator.selection = $selection
        let current = FrilaLPShiftClock(date: picker.date)
        if current != selection {
            picker.setDate(selection.referenceDate(), animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    final class Coordinator: NSObject {
        var selection: Binding<FrilaLPShiftClock>

        init(selection: Binding<FrilaLPShiftClock>) {
            self.selection = selection
        }

        @objc func changed(_ picker: UIDatePicker) {
            selection.wrappedValue = FrilaLPShiftClock(date: picker.date)
        }
    }
}
#else
/// No macOS, o seletor de horário nativo em campo.
struct FrilaLPShiftTimeWheel: View {
    @Binding var selection: FrilaLPShiftClock
    let minuteInterval: Int

    var body: some View {
        DatePicker(
            "Horário",
            selection: Binding(
                get: { selection.referenceDate() },
                set: { selection = FrilaLPShiftClock(date: $0) }
            ),
            displayedComponents: .hourAndMinute
        )
        .labelsHidden()
        .datePickerStyle(.stepperField)
        .environment(\.locale, Locale(identifier: "pt_BR"))
        .environment(\.timeZone, FrilaLPShiftCalendar.brasilia.timeZone)
    }
}
#endif
