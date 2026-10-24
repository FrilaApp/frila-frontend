import SwiftUI

// MARK: - Core Button Style Definitions
public enum FrilaLPButtonStyleVariant {
    case primary
    case ink
    case outline
    case ghost
    case glass
}

public struct FrilaLPPillButtonStyle: ButtonStyle {
    public let variant: FrilaLPButtonStyleVariant
    public let isDark: Bool
    public let size: FrilaLPButtonSize
    public let customHorizontalPadding: CGFloat?
    
    public init(
        variant: FrilaLPButtonStyleVariant = .primary,
        isDark: Bool = false,
        size: FrilaLPButtonSize = .standard,
        horizontalPadding: CGFloat? = nil,
        cornerRadius: CGFloat? = nil
    ) {
        self.variant = variant
        self.isDark = isDark
        self.size = size
        self.customHorizontalPadding = horizontalPadding
        _ = cornerRadius
    }
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public func makeBody(configuration: Configuration) -> some View {
        return configuration.label
            .font(labelFont)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, customHorizontalPadding ?? horizontalPadding)
            .frame(height: visualHeight)
            .frame(minHeight: FrilaLPGeometry.hitboxMinimum)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .foregroundColor(foregroundColor)
            .clipShape(Capsule())
            .overlay(borderOverlay())
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.97 : 1.0))
            .animation(
                FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: reduceMotion),
                value: configuration.isPressed
            )
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, isPressed in
                isPressed
            }
    }
    
    private var visualHeight: CGFloat {
        switch size {
        case .compact: return FrilaLPGeometry.buttonHeightCompact
        case .standard: return FrilaLPGeometry.buttonHeightStandard
        case .prominent: return FrilaLPGeometry.buttonHeightProminent
        }
    }
    
    private var horizontalPadding: CGFloat {
        switch size {
        case .compact: return 16
        case .standard: return 24
        case .prominent: return 28
        }
    }
    
    private var labelFont: Font {
        switch size {
        case .compact: return FrilaLPTypography.captionBold
        case .standard: return FrilaLPTypography.button
        case .prominent: return FrilaLPTypography.sans(size: FrilaLPTypeScaleStep.placard.pointSize, weight: .bold)
        }
    }
    
    @ViewBuilder
    private func backgroundColor(isPressed: Bool) -> some View {
        switch variant {
        case .primary:
            isPressed ? FrilaLPColor.primary600 : FrilaLPColor.dynamicBrandAccent(isDark: isDark)
        case .ink:
            isPressed ? FrilaLPColor.dynamicTextInk(isDark: isDark) : FrilaLPColor.dynamicTextPrimary(isDark: isDark)
        case .outline:
            isPressed ? FrilaLPColor.dynamicSurfaceSubtle(isDark: isDark) : Color.clear
        case .ghost:
            isPressed ? FrilaLPColor.dynamicSurfaceSubtle(isDark: isDark) : Color.clear
        case .glass:
            Color.white.opacity(isPressed ? 0.95 : 0.85)
        }
    }
    
    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return .white
        case .ink:
            return FrilaLPColor.dynamicCanvas(isDark: isDark)
        case .outline:
            return FrilaLPColor.dynamicTextPrimary(isDark: isDark)
        case .ghost:
            return FrilaLPColor.dynamicTextMuted(isDark: isDark)
        case .glass:
            return FrilaLPColor.dynamicTextPrimary(isDark: isDark)
        }
    }
    
    @ViewBuilder
    private func borderOverlay() -> some View {
        if variant == .outline {
            Capsule()
                .stroke(FrilaLPColor.dynamicBorder(isDark: isDark), lineWidth: 1)
        } else if variant == .glass {
            let topWhite = isDark ? 0.40 : 0.80
            let bottomTint = isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(topWhite), bottomTint],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
    }
}

// MARK: - Passive Status Chip (Genie Sent Pattern)
/// Non-interactive status indicator. Text only, or text with a leading SF Symbol:
/// never an emoji or glyph baked into the label.
public struct FrilaLPStatusChip: View {
    public enum ChipStyle: Sendable {
        case neutral
        case verified
        case warning
        case brand

        func foreground(isDark: Bool) -> Color {
            switch self {
            case .neutral: return FrilaLPColor.dynamicTextMuted(isDark: isDark)
            case .verified: return FrilaLPColor.dynamicVerified(isDark: isDark)
            case .warning: return FrilaLPColor.dynamicWarningText(isDark: isDark)
            case .brand: return FrilaLPColor.dynamicBrandChipText(isDark: isDark)
            }
        }

        func background(isDark: Bool) -> Color {
            switch self {
            case .neutral: return FrilaLPColor.dynamicInputBg(isDark: isDark)
            case .verified: return FrilaLPColor.dynamicVerifiedBg(isDark: isDark)
            case .warning: return FrilaLPColor.dynamicWarningBg(isDark: isDark)
            case .brand: return FrilaLPColor.dynamicBrandChipBg(isDark: isDark)
            }
        }
    }

    public let text: String
    public let style: ChipStyle
    /// Optional leading SF Symbol name, e.g. "checkmark.shield.fill".
    public let systemImage: String?
    public let isDark: Bool
    /// Optional trigger to execute a subtle single-cycle presence bounce/ping (1.04x).
    public let pulseTrigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsingInternal: Bool = false

    public init(
        _ text: String,
        style: ChipStyle = .neutral,
        systemImage: String? = nil,
        isDark: Bool = false,
        pulseTrigger: Int = 0
    ) {
        self.text = text
        self.style = style
        self.systemImage = systemImage
        self.isDark = isDark
        self.pulseTrigger = pulseTrigger
    }

    public var body: some View {
        HStack(spacing: FrilaLPGeometry.chipIconSpacing) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
                    .accessibilityHidden(true)
            }
            Text(verbatim: text)
                .lineLimit(1)
        }
        .font(FrilaLPTypography.captionMedium)
        .foregroundStyle(style.foreground(isDark: isDark))
        .padding(.horizontal, FrilaLPGeometry.chipPaddingHorizontal)
        .frame(height: FrilaLPGeometry.chipHeight)
        .background(style.background(isDark: isDark))
        .clipShape(Capsule())
        .overlay {
            if style == .brand && isDark {
                Capsule()
                    .stroke(FrilaLPColor.dynamicBrandChipBorder(isDark: isDark), lineWidth: 1)
            }
        }
        .scaleEffect(reduceMotion ? 1.0 : (isPulsingInternal ? FrilaLPMotion.chipPulseScale : 1.0))
        .animation(FrilaMovimento.animacao(FrilaLPMotion.chipActivationSpring, reduzir: reduceMotion), value: isPulsingInternal)
        .onChange(of: pulseTrigger) { _, newValue in
            guard newValue > 0 else { return }
            isPulsingInternal = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                isPulsingInternal = false
            }
        }
    }
}

// MARK: - CANONICAL COMPONENT: FrilaLPButton
/// Standard button variants for the unified Frila Design System.
public enum FrilaLPButtonVariant: String, CaseIterable, Sendable {
    case primary
    case secondary
    case outline
    case ghost
    case glass
}

/// Standard size tiers enforcing HIG 44pt minimum touch hitboxes across all sizes.
public enum FrilaLPButtonSize: String, CaseIterable, Sendable {
    /// 32pt visual height with invisible 44pt touch extension
    case compact
    /// 44pt standard interactive height
    case standard
    /// 52pt high-emphasis hero commitment height
    case prominent
}

/// Icon placement relative to button label.
public enum FrilaLPButtonIconPosition: Sendable {
    case leading
    case trailing
}

/// The definitive, curated Button component for Frila.
/// Incorporates better-ui spring physics (scale 0.96), better-accessibility (44pt hitbox & VoiceOver),
/// and better-layout (asymmetric spacing resilience).
public struct FrilaLPButton: View {
    public let title: String
    public let icon: String?
    public let variant: FrilaLPButtonVariant
    public let size: FrilaLPButtonSize
    public let isDark: Bool
    public let isFullWidth: Bool
    public let isLoading: Bool
    public let iconPosition: FrilaLPButtonIconPosition
    public let action: () -> Void
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init(
        _ title: String,
        icon: String? = nil,
        variant: FrilaLPButtonVariant = .primary,
        size: FrilaLPButtonSize = .standard,
        isDark: Bool = false,
        isFullWidth: Bool = false,
        isLoading: Bool = false,
        iconPosition: FrilaLPButtonIconPosition = .leading,
        action: @escaping () -> Void = {}
    ) {
        self.title = title
        self.icon = icon
        self.variant = variant
        self.size = size
        self.isDark = isDark
        self.isFullWidth = isFullWidth
        self.isLoading = isLoading
        self.iconPosition = iconPosition
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            guard !isLoading else { return }
            action()
        }) {
            ZStack {
                // Content layer defining intrinsic dimensions
                HStack(spacing: iconSpacing) {
                    if iconPosition == .leading, let icon = icon {
                        Image(systemName: icon)
                            .font(iconFont)
                    }
                    
                    Text(verbatim: title)
                        .font(labelFont)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    
                    if iconPosition == .trailing, let icon = icon {
                        Image(systemName: icon)
                            .font(iconFont)
                    }
                }
                .opacity(isLoading ? 0 : 1)
                .scaleEffect(isLoading && !reduceMotion ? 0.94 : 1.0)
                
                // Centered native ProgressView with foreground color tint
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(progressControlSize)
                        .tint(buttonForeground)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .scale(scale: 0.82).combined(with: .opacity)
                        )
                }
            }
            .animation(
                FrilaMovimento.animacao(.spring(response: 0.24, dampingFraction: 0.78), reduzir: reduceMotion),
                value: isLoading
            )
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.horizontal, horizontalPadding)
            .frame(height: visualHeight)
            .background(buttonBackground)
            .foregroundColor(buttonForeground)
            .clipShape(Capsule())
            .overlay(buttonBorder)
            .contentShape(Rectangle())
            .frame(minHeight: FrilaLPGeometry.hitboxMinimum)
        }
        .buttonStyle(FrilaLPHapticBounceButtonStyle(reduceMotion: reduceMotion))
        .disabled(isLoading)
        .accessibilityLabel(isLoading ? String(localized: "Carregando: \(title)", bundle: bundleApresentacao) : title)
    }
    
    private var progressControlSize: ControlSize {
        switch size {
        case .compact: return .small
        case .standard: return .regular
        case .prominent: return .regular
        }
    }
    
    private var visualHeight: CGFloat {
        switch size {
        case .compact: return FrilaLPGeometry.buttonHeightCompact
        case .standard: return FrilaLPGeometry.buttonHeightStandard
        case .prominent: return FrilaLPGeometry.buttonHeightProminent
        }
    }
    
    private var horizontalPadding: CGFloat {
        switch size {
        case .compact: return 12
        case .standard: return 20
        case .prominent: return 24
        }
    }
    
    private var iconSpacing: CGFloat {
        switch size {
        case .compact: return 4
        case .standard: return 6
        case .prominent: return 8
        }
    }
    
    private var labelFont: Font {
        switch size {
        case .compact: return FrilaLPTypography.captionBold
        case .standard: return FrilaLPTypography.button
        case .prominent: return FrilaLPTypography.sans(size: FrilaLPTypeScaleStep.placard.pointSize, weight: .bold)
        }
    }
    
    private var iconFont: Font {
        switch size {
        case .compact: return FrilaLPFonteDoSistema.fonte(size: FrilaLPTypeScaleStep.micro.pointSize, weight: .bold)
        case .standard: return FrilaLPFonteDoSistema.fonte(size: FrilaLPTypeScaleStep.caption.pointSize, weight: .semibold)
        case .prominent: return FrilaLPFonteDoSistema.fonte(size: FrilaLPTypeScaleStep.body.pointSize, weight: .bold)
        }
    }
    
    @ViewBuilder
    private var buttonBackground: some View {
        switch variant {
        case .primary:
            FrilaLPColor.dynamicBrandAccent(isDark: isDark)
        case .secondary:
            FrilaLPColor.dynamicTextInk(isDark: isDark)
        case .outline, .ghost:
            Color.clear
        case .glass:
            Color.white.opacity(isDark ? 0.20 : 0.85)
        }
    }
    
    private var buttonForeground: Color {
        switch variant {
        case .primary:
            return .white
        case .secondary:
            return FrilaLPColor.dynamicCanvas(isDark: isDark)
        case .outline:
            return FrilaLPColor.dynamicTextPrimary(isDark: isDark)
        case .ghost:
            return FrilaLPColor.dynamicTextMuted(isDark: isDark)
        case .glass:
            return FrilaLPColor.dynamicTextPrimary(isDark: isDark)
        }
    }
    
    @ViewBuilder
    private var buttonBorder: some View {
        if variant == .outline {
            Capsule().stroke(FrilaLPColor.dynamicBorder(isDark: isDark), lineWidth: 1)
        } else if variant == .glass {
            Capsule().stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.8), Color.black.opacity(0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        }
    }
}

public struct FrilaLPHapticBounceButtonStyle: ButtonStyle {
    public let reduceMotion: Bool
    public let scale: CGFloat
    
    @Environment(\.accessibilityReduceMotion) private var envReduceMotion
    
    public init(reduceMotion: Bool = false, scale: CGFloat = 0.96) {
        self.reduceMotion = reduceMotion
        self.scale = scale
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        let isReduceActive = reduceMotion || envReduceMotion
        return configuration.label
            .scaleEffect(isReduceActive ? 1.0 : (configuration.isPressed ? scale : 1.0))
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(
                FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: isReduceActive),
                value: configuration.isPressed
            )
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, isPressed in
                isPressed
            }
    }
}

public extension ButtonStyle where Self == FrilaLPHapticBounceButtonStyle {
    static var hapticBounce: FrilaLPHapticBounceButtonStyle {
        FrilaLPHapticBounceButtonStyle()
    }
    
    static func hapticBounce(reduceMotion: Bool = false, scale: CGFloat = 0.96) -> FrilaLPHapticBounceButtonStyle {
        FrilaLPHapticBounceButtonStyle(reduceMotion: reduceMotion, scale: scale)
    }
}

// MARK: - Previews
