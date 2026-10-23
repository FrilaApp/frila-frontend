import SwiftUI

// MARK: - VARIANT COMPONENT: FrilaLPECategoryChip
/// Interactive Category Chip rendered in calm, low-chroma functional pastels derived from OKLCH space.
/// Features:
/// - Three curated functional pastel themes: Terracotta Soft, Sage, and Slate.
/// - Strict WCAG AAA foreground-to-background contrast (> 7.0:1) across light and dark modes.
/// - HIG-compliant 44x44pt minimum touch hitbox.
/// - Tactile spring feedback (scale 0.96) with sensory light impact.
/// - Strictly SF Symbols for iconography (zero emojis or glyphs).
public struct FrilaLPECategoryChip: View {
    public let title: String
    public let theme: FrilaLPEColor.FunctionalPastelTheme
    public let systemImage: String?
    public let isSelected: Bool
    public let isDark: Bool
    public let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        _ title: String,
        theme: FrilaLPEColor.FunctionalPastelTheme = .terracotta,
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
        isSelected ? String(localized: "Selecionado", table: "FrilaLPEEstudio", bundle: bundleApresentacao) : String(localized: "Não selecionado", table: "FrilaLPEEstudio", bundle: bundleApresentacao)
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: FrilaLPEGeometry.space6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(FrilaLPEFonteDoSistema.fonte(size: 11, weight: .bold))
                        .accessibilityHidden(true)
                }

                Text(verbatim: title)
                    .font(FrilaLPETypography.captionBold)
                    .lineLimit(1)
            }
            .padding(.horizontal, FrilaLPEGeometry.space14)
            .frame(height: FrilaLPEGeometry.buttonHeightCompact)
            .foregroundStyle(chipForegroundColor)
            .background(chipBackgroundColor, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(chipBorderColor, lineWidth: 1)
            }
            .frilaLPEHitbox()
        }
        .buttonStyle(FrilaLPEChipSpringButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: accessibilityValueText))
        .accessibilityAddTraits(accessibilityTraits)
    }

    // MARK: - WCAG AAA Colors
    private var chipBackgroundColor: Color {
        if isSelected {
            return FrilaLPEColor.dynamicPastelSelectedBg(theme: theme, isDark: isDark)
        } else {
            return FrilaLPEColor.dynamicPastelBg(theme: theme, isDark: isDark)
        }
    }

    private var chipForegroundColor: Color {
        if isSelected {
            return FrilaLPEColor.dynamicPastelSelectedText(theme: theme, isDark: isDark)
        } else {
            return FrilaLPEColor.dynamicPastelText(theme: theme, isDark: isDark)
        }
    }

    private var chipBorderColor: Color {
        if isSelected {
            return Color.clear
        } else {
            return FrilaLPEColor.dynamicPastelBorder(theme: theme, isDark: isDark)
        }
    }
}

// MARK: - Chip Tactile Spring Button Style
private struct FrilaLPEChipSpringButtonStyle: ButtonStyle {
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

// MARK: - ADDITIONAL VARIANT: FrilaLPEAchromaticLineButton
/// Structure / Quiet variant: 100% capsule button with pure hairline border and no background fill.
/// Ideal for secondary archival utility actions (Share, Bookmark, Follow).
public struct FrilaLPEAchromaticLineButton: View {
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
            HStack(spacing: FrilaLPEGeometry.space6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(FrilaLPETypography.captionBold)
                        .accessibilityHidden(true)
                }
                Text(verbatim: title)
                    .font(FrilaLPETypography.captionBold)
                    .lineLimit(1)
            }
            .padding(.horizontal, FrilaLPEGeometry.space16)
            .frame(height: FrilaLPEGeometry.buttonHeightStandard)
            .foregroundStyle(FrilaLPEColor.dynamicTextPrimary(isDark: isDark))
            .background(Color.clear, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(FrilaLPEColor.dynamicBorder(isDark: isDark), lineWidth: 1)
            }
            .frilaLPEHitbox()
        }
        .buttonStyle(FrilaLPEChipSpringButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(Text(verbatim: title))
    }
}

// MARK: - ADDITIONAL VARIANT: FrilaLPEPlacardPressStampButton
/// Type / Editorial Placard variant: Uppercase tracked pill button for authoritative commitments.
public struct FrilaLPEPlacardPressStampButton: View {
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
                .font(FrilaLPETypography.microBold)
                .tracking(FrilaLPETypography.trackingMicro)
                .foregroundStyle(isDark ? Color.black : Color.white)
                .padding(.horizontal, FrilaLPEGeometry.space20)
                .frame(height: FrilaLPEGeometry.buttonHeightStandard)
                .background(FrilaLPEColor.dynamicTextPrimary(isDark: isDark), in: Capsule())
                .frilaLPEHitbox()
        }
        .buttonStyle(FrilaLPEChipSpringButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(Text(verbatim: title))
    }
}

// MARK: - Previews
