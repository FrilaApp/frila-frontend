import SwiftUI

// MARK: - CANONICAL UNIFIED COMPONENT: FrilaPriceTag

/// Canonical price display: the amount in the paradigm's hero metric, followed by a
/// smaller muted unit ("/h") on the same first baseline, with an optional estimate line.
///
/// - Digits are proportional (static value), formatted in BRL with the fixed `pt_BR`
///   locale through `FrilaMoney`.
/// - The price never wraps: `lineLimit(1)`, horizontal `fixedSize` and `layoutPriority(1)`
///   make neighbours (titles, spacers) yield first, so "R$ 140/" + "h" cannot split.
/// - VoiceOver reads one element with the unit spelled out ("R$ 140 por hora, estimado R$ 33.600").
public struct FrilaPriceTag: View {
    public let amount: Int
    /// `nil` renders a plain total with no unit.
    public let unit: FrilaMoney.RateUnit?
    public let estimate: Int?
    public let paradigm: FrilaTypographyParadigm
    public let isDark: Bool

    public init(
        amount: Int,
        unit: FrilaMoney.RateUnit? = .hour,
        estimate: Int? = nil,
        paradigm: FrilaTypographyParadigm = .swiss,
        isDark: Bool = false
    ) {
        self.amount = amount
        self.unit = unit
        self.estimate = estimate
        self.paradigm = paradigm
        self.isDark = isDark
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaGeometry.priceEstimateSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: FrilaGeometry.priceUnitSpacing) {
                Text(verbatim: valueText)
                    .frilaType(valueSpec)
                    .foregroundStyle(FrilaColor.dynamicTextPrimary(isDark: isDark))

                if let unitText {
                    Text(verbatim: unitText)
                        .font(FrilaTypography.captionMedium)
                        .foregroundStyle(FrilaColor.dynamicTextMuted(isDark: isDark))
                }
            }

            if let estimateText {
                Text(verbatim: estimateText)
                    .font(FrilaTypography.captionMedium)
                    .foregroundStyle(FrilaColor.dynamicTextMuted(isDark: isDark))
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: spokenLabel))
    }

    // MARK: - Derived content (internal for tests)

    var valueSpec: FrilaTypeSpec {
        FrilaTypography(paradigm: paradigm).metricHeroSpec
    }

    var valueText: String {
        FrilaMoney.total(amount)
    }

    var unitText: String? {
        unit?.suffix
    }

    var estimateText: String? {
        estimate.map(FrilaMoney.estimate)
    }

    var spokenLabel: String {
        var label = valueText
        if let unit {
            label += " por \(unit.spokenName)"
        }
        if let estimate {
            label += ", estimado \(FrilaMoney.total(estimate))"
        }
        return label
    }
}
