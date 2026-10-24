import Foundation

// Formatação visual de moeda do design system (origem: FrilaLowPhase `FrilaMoney`).
//
// Preços em BRL com o `pt_BR` fixo (`FrilaMoney.locale`, em `DesignTokens.swift`), para qualquer
// aparelho mostrar "R$ 33.600" (milhar com ponto, reais inteiros, sem centavos). A leitura falada
// para VoiceOver (`spoken(cents:por:)`) mora em `DesignTokens.swift`.
//
// Entregue o resultado a `Text(_:)` como `String`: interpolar num literal vira `LocalizedStringKey`
// e reagrupa os dígitos com a localidade do aparelho.
public extension FrilaMoney {
    /// Período de uma taxa. `.hour` ("/h") é a unidade canônica: não escreva "/ hr", "/hr" ou "/HR".
    enum RateUnit: String, CaseIterable, Sendable {
        case hour = "h"
        case day = "dia"
        case week = "sem"
        case month = "mês"

        /// Sufixo compacto depois do valor, ex. "/h".
        public var suffix: String { "/\(rawValue)" }

        /// Palavra lida pelo VoiceOver no lugar da abreviação, ex. "hora".
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

    /// Reais inteiros: `total(33600)` -> "R$ 33.600".
    static func total(_ amount: Int) -> String {
        amount.formatted(currencyStyle)
    }

    /// Taxa com unidade: `rate(160, per: .hour)` -> "R$ 160/h".
    static func rate(_ amount: Int, per unit: RateUnit = .hour) -> String {
        total(amount) + unit.suffix
    }

    /// Estimativa: `estimate(33600)` -> "Est. R$ 33.600".
    static func estimate(_ amount: Int) -> String {
        "Est. " + total(amount)
    }

    // MARK: - Centavos (Turnos)

    /// Valor em centavos, reais inteiros quando não há centavos: `total(cents: 28_000)` -> "R$ 280",
    /// `total(cents: 28_050)` -> "R$ 280,50".
    static func total(cents: Int) -> String {
        guard cents % 100 != 0 else { return total(cents / 100) }
        return decimal(cents: cents).formatted(
            .currency(code: "BRL").locale(locale).precision(.fractionLength(2))
        )
    }

    /// Valor editável sem o símbolo, sempre com centavos: `fieldDigits(cents: 14_000)` -> "140,00".
    static func fieldDigits(cents: Int) -> String {
        decimal(cents: cents).formatted(.number.locale(locale).precision(.fractionLength(2)))
    }

    private static func decimal(cents: Int) -> Decimal {
        Decimal(cents) / 100
    }

    /// Horas semanais: `weeklyHours(40)` -> "40 h/sem".
    static func weeklyHours(_ hours: Int) -> String {
        "\(hours) h/sem"
    }

    /// Faixa de horas semanais: `weeklyHours(20, to: 40)` -> "20–40 h/sem".
    static func weeklyHours(_ minHours: Int, to maxHours: Int) -> String {
        "\(minHours)–\(maxHours) h/sem"
    }
}
