import SwiftUI

// MARK: - VARIANT COMPONENT: FrilaLPCategoryChip
/// Interactive Category Chip rendered in calm, low-chroma functional pastels derived from OKLCH space.
/// Features:
/// - Three curated functional pastel themes: Terracotta Soft, Sage, and Slate.
/// - Strict WCAG AAA foreground-to-background contrast (> 7.0:1) across light and dark modes.
/// - HIG-compliant 44x44pt minimum touch hitbox.
/// - Tactile spring feedback (scale 0.96) with sensory light impact.
/// - Strictly SF Symbols for iconography (zero emojis or glyphs).
public struct FrilaLPCategoryChip: View {
    public let title: String
    public let theme: FrilaLPColor.FunctionalPastelTheme
    public let systemImage: String?
    public let isSelected: Bool
    public let isDark: Bool
    public let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        _ title: String,
        theme: FrilaLPColor.FunctionalPastelTheme = .terracotta,
        systemImage: String? = nil,
        isSelected: Bool = false,
        isDark: Bool = false,
        action: @escaping () -> Void = {}
    ) {
        self.title = title
        self.theme = theme
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.isDark = isDark
        self.action = action
    }

    // MARK: - Derived Accessibility Content (for tests)
    var accessibilityTraits: AccessibilityTraits {
        isSelected ? [.isSelected, .isButton] : [.isButton]
    }

    var accessibilityValueText: String {
        isSelected ? String(localized: "Selecionado", bundle: bundleApresentacao) : String(localized: "Não selecionado", bundle: bundleApresentacao)
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: FrilaLPGeometry.space6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(FrilaLPFonteDoSistema.fonte(size: 11, weight: .bold))
                        .accessibilityHidden(true)
                }

                Text(verbatim: title)
                    .font(FrilaLPTypography.captionBold)
                    .lineLimit(1)
            }
            .padding(.horizontal, FrilaLPGeometry.space14)
            .frame(height: FrilaLPGeometry.buttonHeightCompact)
            .foregroundStyle(chipForegroundColor)
            .background(chipBackgroundColor, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(chipBorderColor, lineWidth: 1)
            }
            .frilaLPHitbox()
        }
        .buttonStyle(FrilaLPChipSpringButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: accessibilityValueText))
        .accessibilityAddTraits(accessibilityTraits)
    }

    // MARK: - WCAG AAA Colors
    private var chipBackgroundColor: Color {
        if isSelected {
            return FrilaLPColor.dynamicPastelSelectedBg(theme: theme, isDark: isDark)
        } else {
            return FrilaLPColor.dynamicPastelBg(theme: theme, isDark: isDark)
        }
    }

    private var chipForegroundColor: Color {
        if isSelected {
            return FrilaLPColor.dynamicPastelSelectedText(theme: theme, isDark: isDark)
        } else {
            return FrilaLPColor.dynamicPastelText(theme: theme, isDark: isDark)
        }
    }

    private var chipBorderColor: Color {
        if isSelected {
            return Color.clear
        } else {
            return FrilaLPColor.dynamicPastelBorder(theme: theme, isDark: isDark)
        }
    }
}

// MARK: - Chip Tactile Spring Button Style
private struct FrilaLPChipSpringButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.96 : 1.0))
            .animation(
                FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: reduceMotion),
                value: configuration.isPressed
            )
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, isPressed in
                isPressed
            }
    }
}

// MARK: - ADDITIONAL VARIANT: FrilaLPAchromaticLineButton
/// Structure / Quiet variant: 100% capsule button with pure hairline border and no background fill.
/// Ideal for secondary archival utility actions (Share, Bookmark, Follow).
public struct FrilaLPAchromaticLineButton: View {
    public let title: String
    public let systemImage: String?
    public let isDark: Bool
    public let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        _ title: String,
        systemImage: String? = nil,
        isDark: Bool = false,
        action: @escaping () -> Void = {}
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isDark = isDark
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: FrilaLPGeometry.space6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(FrilaLPTypography.captionBold)
                        .accessibilityHidden(true)
                }
                Text(verbatim: title)
                    .font(FrilaLPTypography.captionBold)
                    .lineLimit(1)
            }
            .padding(.horizontal, FrilaLPGeometry.space16)
            .frame(height: FrilaLPGeometry.buttonHeightStandard)
            .foregroundStyle(FrilaLPColor.dynamicTextPrimary(isDark: isDark))
            .background(Color.clear, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(FrilaLPColor.dynamicBorder(isDark: isDark), lineWidth: 1)
            }
            .frilaLPHitbox()
        }
        .buttonStyle(FrilaLPChipSpringButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(Text(verbatim: title))
    }
}

// MARK: - ADDITIONAL VARIANT: FrilaLPPlacardPressStampButton
/// Type / Editorial Placard variant: Uppercase tracked pill button for authoritative commitments.
public struct FrilaLPPlacardPressStampButton: View {
    public let title: String
    public let isDark: Bool
    public let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        _ title: String,
        isDark: Bool = false,
        action: @escaping () -> Void = {}
    ) {
        self.title = title
        self.isDark = isDark
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(verbatim: title.uppercased())
                .font(FrilaLPTypography.microBold)
                .tracking(FrilaLPTypography.trackingMicro)
                .foregroundStyle(isDark ? Color.black : Color.white)
                .padding(.horizontal, FrilaLPGeometry.space20)
                .frame(height: FrilaLPGeometry.buttonHeightStandard)
                .background(FrilaLPColor.dynamicTextPrimary(isDark: isDark), in: Capsule())
                .frilaLPHitbox()
        }
        .buttonStyle(FrilaLPChipSpringButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(Text(verbatim: title))
    }
}

// MARK: - Previews
