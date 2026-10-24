import SwiftUI

// MARK: - CANONICAL UNIFIED COMPONENT: FrilaLPEPriceTag

/// Canonical price display: the amount in the paradigm's hero metric, followed by a
/// smaller muted unit ("/h") on the same first baseline, with an optional estimate line.
///
/// - Digits are proportional (static value), formatted in BRL with the fixed `pt_BR`
///   locale through `FrilaLPEMoney`.
/// - The price never wraps: `lineLimit(1)`, horizontal `fixedSize` and `layoutPriority(1)`
///   make neighbours (titles, spacers) yield first, so "R$ 140/" + "h" cannot split.
/// - VoiceOver reads one element with the unit spelled out ("R$ 140 por hora, estimado R$ 33.600").
public struct FrilaLPEPriceTag: View {
    public let amount: Int
    /// `nil` renders a plain total with no unit.
    public let unit: FrilaLPEMoney.RateUnit?
    public let estimate: Int?
    public let paradigm: FrilaLPETypographyParadigm
    public let isDark: Bool

    public init(
        amount: Int,
        unit: FrilaLPEMoney.RateUnit? = .hour,
        estimate: Int? = nil,
        paradigm: FrilaLPETypographyParadigm = .swiss,
        isDark: Bool = false
    ) {
        self.amount = amount
        self.unit = unit
        self.estimate = estimate
        self.paradigm = paradigm
        self.isDark = isDark
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaLPEGeometry.priceEstimateSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: FrilaLPEGeometry.priceUnitSpacing) {
                Text(verbatim: valueText)
                    .frilaLPEType(valueSpec)
                    .foregroundStyle(FrilaLPEColor.dynamicTextPrimary(isDark: isDark))

                if let unitText {
                    Text(verbatim: unitText)
                        .font(FrilaLPETypography.captionMedium)
                        .foregroundStyle(FrilaLPEColor.dynamicTextMuted(isDark: isDark))
                }
            }

            if let estimateText {
                Text(verbatim: estimateText)
                    .font(FrilaLPETypography.captionMedium)
                    .foregroundStyle(FrilaLPEColor.dynamicTextMuted(isDark: isDark))
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: spokenLabel))
    }

    // MARK: - Derived content (internal for tests)

    var valueSpec: FrilaLPETypeSpec {
        FrilaLPETypography(paradigm: paradigm).metricHeroSpec
    }

    var valueText: String {
        FrilaLPEMoney.total(amount)
    }

    var unitText: String? {
        unit?.suffix
    }

    var estimateText: String? {
        estimate.map(FrilaLPEMoney.estimate)
    }

    var spokenLabel: String {
        var label = valueText
        if let unit {
            label += " por \(unit.spokenName)"
        }
        if let estimate {
            label += ", estimado \(FrilaLPEMoney.total(estimate))"
        }
        return label
    }
}
