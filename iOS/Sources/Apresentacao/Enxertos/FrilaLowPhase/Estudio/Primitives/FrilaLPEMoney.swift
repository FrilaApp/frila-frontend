import Foundation

/// Frila Design System: Money Formatting
///
/// Frila prices are quoted in BRL (R$). Formatting pins the `pt_BR` locale so any device
/// renders "R$ 33.600" (grouping with dot, whole reals, no cents).
///
/// Always hand the result to `Text(_:)` as a `String` value: never interpolate into a
/// string literal, which turns it into a `LocalizedStringKey` and re-groups digits with
/// the device locale.
public enum FrilaLPEMoney {
    /// The canonical locale used for currency in Frila.
    public static let locale = Locale(identifier: "pt_BR")

    /// Billing period of a rate. `.hour` ("/h") is the canonical unit: do not write
    /// "/ hr", "/hr", "/h " or "/HR" by hand.
    public enum RateUnit: String, CaseIterable, Sendable {
        case hour = "h"
        case day = "dia"
        case week = "sem"
        case month = "mês"

        /// Compact suffix appended to the amount, e.g. "/h".
        public var suffix: String { "/\(rawValue)" }

        /// Word read by VoiceOver instead of the abbreviation, e.g. "hora".
        public var spokenName: String {
            switch self {
            case .hour: return "hora"
            case .day: return "dia"
            case .week: return "semana"
            case .month: return "mês"
            }
        }
    }

    private static let currencyStyle = IntegerFormatStyle<Int>.Currency(code: "BRL", locale: locale)
        .precision(.fractionLength(0))

    /// Whole-real amount: `total(33600)` -> "R$ 33.600".
    public static func total(_ amount: Int) -> String {
        amount.formatted(currencyStyle)
    }

    /// Rate with its unit: `rate(160, per: .hour)` -> "R$ 160/h".
    public static func rate(_ amount: Int, per unit: RateUnit = .hour) -> String {
        total(amount) + unit.suffix
    }

    /// Project estimate label: `estimate(33600)` -> "Est. R$ 33.600".
    public static func estimate(_ amount: Int) -> String {
        "Est. " + total(amount)
    }

    // MARK: - Cents (Turnos)

    /// Amount in cents, whole reais when there are no cents: `total(cents: 28_000)` -> "R$ 280",
    /// `total(cents: 28_050)` -> "R$ 280,50".
    public static func total(cents: Int) -> String {
        guard cents % 100 != 0 else { return total(cents / 100) }
        return decimal(cents: cents).formatted(
            .currency(code: "BRL").locale(locale).precision(.fractionLength(2))
        )
    }

    /// Editable field value without the symbol, always with cents: `fieldDigits(cents: 14_000)` -> "140,00".
    public static func fieldDigits(cents: Int) -> String {
        decimal(cents: cents).formatted(.number.locale(locale).precision(.fractionLength(2)))
    }

    /// Spoken label for VoiceOver: "280 reais", "1 real", "140 reais e 50 centavos".
    public static func spoken(cents: Int) -> String {
        let reais = cents / 100
        let centavos = cents % 100
        let reaisText = reais == 1 ? "1 real" : "\(reais) reais"
        guard centavos != 0 else { return reaisText }
        let centavosText = centavos == 1 ? "1 centavo" : "\(centavos) centavos"
        return reais == 0 ? centavosText : "\(reaisText) e \(centavosText)"
    }

    private static func decimal(cents: Int) -> Decimal {
        Decimal(cents) / 100
    }

    /// Weekly hours formatted in pt-BR: `weeklyHours(40)` -> "40 h/sem".
    public static func weeklyHours(_ hours: Int) -> String {
        "\(hours) h/sem"
    }

    /// Weekly hours range formatted in pt-BR: `weeklyHours(20, to: 40)` -> "20–40 h/sem".
    public static func weeklyHours(_ minHours: Int, to maxHours: Int) -> String {
        "\(minHours)–\(maxHours) h/sem"
    }
}
