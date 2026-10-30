import SwiftUI

/// Superelipse de expoente 2,5: pontas amplas com tangência suave nas retas.
struct FormaDoBotaoFrila: Shape {
    func path(in rect: CGRect) -> Path {
        let alcance = min(rect.height, rect.width / 2)
        let meiaAltura = rect.height / 2
        let expoente: CGFloat = 2.5
        let amostras = 64
        var caminho = Path()
        caminho.move(to: CGPoint(x: rect.minX + alcance, y: rect.minY))
        caminho.addLine(to: CGPoint(x: rect.maxX - alcance, y: rect.minY))

        // Cada quadrante segue |x/a|^n + |y/b|^n = 1.
        // Quadráticas entre pontos médios suavizam a aproximação sem ultrapassá-la.
        func quadrante(centroX: CGFloat, inicio: CGFloat) {
            var pontos: [CGPoint] = []
            for indice in 0...amostras {
                let angulo = inicio + CGFloat(indice) / CGFloat(amostras) * .pi / 2
                let cosseno = cos(angulo)
                let seno = sin(angulo)
                pontos.append(CGPoint(
                    x: centroX + alcance * (cosseno < 0 ? -1 : 1) * pow(abs(cosseno), 2 / expoente),
                    y: rect.midY + meiaAltura * (seno < 0 ? -1 : 1) * pow(abs(seno), 2 / expoente)
                ))
            }
            for indice in 0..<amostras {
                let ponto = pontos[indice]
                let proximo = pontos[indice + 1]
                let meio = CGPoint(x: (ponto.x + proximo.x) / 2, y: (ponto.y + proximo.y) / 2)
                caminho.addQuadCurve(to: meio, control: ponto)
            }
            caminho.addQuadCurve(to: pontos[amostras], control: pontos[amostras])
        }

        quadrante(centroX: rect.maxX - alcance, inicio: -.pi / 2)
        quadrante(centroX: rect.maxX - alcance, inicio: 0)
        caminho.addLine(to: CGPoint(x: rect.minX + alcance, y: rect.maxY))
        quadrante(centroX: rect.minX + alcance, inicio: .pi / 2)
        quadrante(centroX: rect.minX + alcance, inicio: .pi)
        caminho.closeSubpath()
        return caminho
    }
}

// MARK: - Core Button Style Definitions
public enum FrilaButtonStyleVariant {
    case primary
    case ink
    case outline
    case ghost
    case glass
}

public struct FrilaPillButtonStyle: ButtonStyle {
    public let variant: FrilaButtonStyleVariant
    public let isDark: Bool
    public let size: FrilaButtonSize
    public let customHorizontalPadding: CGFloat?
    
    public init(
        variant: FrilaButtonStyleVariant = .primary,
        isDark: Bool = false,
        size: FrilaButtonSize = .standard,
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
            .background(backgroundColor(isPressed: configuration.isPressed))
            .foregroundColor(foregroundColor)
            .clipShape(FrilaButton.formato)
            .overlay(borderOverlay())
            .frame(minHeight: FrilaGeometry.hitboxMinimum)
            .contentShape(FrilaButton.formato)
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
        case .compact: return FrilaGeometry.buttonHeightCompact
        case .standard: return FrilaGeometry.buttonHeightStandard
        case .prominent: return FrilaGeometry.buttonHeightProminent
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
        case .compact: return FrilaTypography.captionBold
        case .standard: return FrilaTypography.button
        case .prominent: return FrilaTypography.sans(size: FrilaTypeScaleStep.placard.pointSize, weight: .bold)
        }
    }
    
    @ViewBuilder
    private func backgroundColor(isPressed: Bool) -> some View {
        switch variant {
        case .primary:
            isPressed ? FrilaColor.primary600 : FrilaColor.dynamicBrandAccent(isDark: isDark)
        case .ink:
            isPressed ? FrilaColor.dynamicTextInk(isDark: isDark) : FrilaColor.dynamicTextPrimary(isDark: isDark)
        case .outline:
            isPressed ? FrilaColor.dynamicSurfaceSubtle(isDark: isDark) : Color.clear
        case .ghost:
            isPressed ? FrilaColor.dynamicSurfaceSubtle(isDark: isDark) : Color.clear
        case .glass:
            Color.white.opacity(isPressed ? 0.95 : 0.85)
        }
    }
    
    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return .white
        case .ink:
            return FrilaColor.dynamicCanvas(isDark: isDark)
        case .outline:
            return FrilaColor.dynamicTextPrimary(isDark: isDark)
        case .ghost:
            return FrilaColor.dynamicTextMuted(isDark: isDark)
        case .glass:
            return FrilaColor.dynamicTextPrimary(isDark: isDark)
        }
    }
    
    @ViewBuilder
    private func borderOverlay() -> some View {
        if variant == .outline {
            FrilaButton.formato
                .stroke(FrilaColor.dynamicBorder(isDark: isDark), lineWidth: 1)
        } else if variant == .glass {
            let topWhite = isDark ? 0.40 : 0.80
            let bottomTint = isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
            FrilaButton.formato
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
public struct FrilaStatusChip: View {
    public enum ChipStyle: Sendable {
        case neutral
        case verified
        case warning
        case brand

        func foreground(isDark: Bool) -> Color {
            switch self {
            case .neutral: return FrilaColor.dynamicTextMuted(isDark: isDark)
            case .verified: return FrilaColor.dynamicVerified(isDark: isDark)
            case .warning: return FrilaColor.dynamicWarningText(isDark: isDark)
            case .brand: return FrilaColor.dynamicBrandChipText(isDark: isDark)
            }
        }

        func background(isDark: Bool) -> Color {
            switch self {
            case .neutral: return FrilaColor.dynamicInputBg(isDark: isDark)
            case .verified: return FrilaColor.dynamicVerifiedBg(isDark: isDark)
            case .warning: return FrilaColor.dynamicWarningBg(isDark: isDark)
            case .brand: return FrilaColor.dynamicBrandChipBg(isDark: isDark)
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
        HStack(spacing: FrilaGeometry.chipIconSpacing) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
                    .accessibilityHidden(true)
            }
            Text(verbatim: text)
                .lineLimit(1)
        }
        .font(FrilaTypography.captionMedium)
        .foregroundStyle(style.foreground(isDark: isDark))
        .padding(.horizontal, FrilaGeometry.chipPaddingHorizontal)
        .frame(height: FrilaGeometry.chipHeight)
        .background(style.background(isDark: isDark))
        .clipShape(Capsule())
        .overlay {
            if style == .brand && isDark {
                Capsule()
                    .stroke(FrilaColor.dynamicBrandChipBorder(isDark: isDark), lineWidth: 1)
            }
        }
        .scaleEffect(reduceMotion ? 1.0 : (isPulsingInternal ? FrilaMotion.chipPulseScale : 1.0))
        .animation(FrilaMovimento.animacao(FrilaMotion.chipActivationSpring, reduzir: reduceMotion), value: isPulsingInternal)
        .onChange(of: pulseTrigger) { _, newValue in
            guard newValue > 0 else { return }
            isPulsingInternal = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                isPulsingInternal = false
            }
        }
    }
}

// MARK: - CANONICAL COMPONENT: FrilaButton
/// Standard button variants for the unified Frila Design System.
public enum FrilaButtonVariant: String, CaseIterable, Sendable {
    case primary
    case secondary
    case outline
    case ghost
    case glass
}

/// Standard size tiers enforcing HIG 44pt minimum touch hitboxes across all sizes.
public enum FrilaButtonSize: String, CaseIterable, Sendable {
    /// 32pt visual height with invisible 44pt touch extension
    case compact
    /// 44pt standard interactive height
    case standard
    /// 52pt high-emphasis hero commitment height
    case prominent
}

/// Icon placement relative to button label.
public enum FrilaButtonIconPosition: Sendable {
    case leading
    case trailing
}

/// The definitive, curated Button component for Frila.
/// Incorporates better-ui spring physics (scale 0.96), better-accessibility (44pt hitbox & VoiceOver),
/// and better-layout (asymmetric spacing resilience).
public struct FrilaButton: View {
    /// Curva contínua compartilhada pelos botões de ação, inclusive a candidatura.
    static var formato: FormaDoBotaoFrila {
        FormaDoBotaoFrila()
    }

    public let title: String
    public let icon: String?
    public let variant: FrilaButtonVariant
    public let size: FrilaButtonSize
    public let isDark: Bool
    public let isFullWidth: Bool
    public let isLoading: Bool
    public let iconPosition: FrilaButtonIconPosition
    public let action: () -> Void
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init(
        _ title: String,
        icon: String? = nil,
        variant: FrilaButtonVariant = .primary,
        size: FrilaButtonSize = .standard,
        isDark: Bool = false,
        isFullWidth: Bool = false,
        isLoading: Bool = false,
        iconPosition: FrilaButtonIconPosition = .leading,
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
            .clipShape(Self.formato)
            .overlay(buttonBorder)
            .frame(minHeight: FrilaGeometry.hitboxMinimum)
            .contentShape(FrilaButton.formato)
        }
        .buttonStyle(FrilaHapticBounceButtonStyle(reduceMotion: reduceMotion))
        .disabled(isLoading)
        .accessibilityLabel(isLoading ? String(localized: "Carregando: \(title)", table: "Estudio", bundle: bundleApresentacao) : title)
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
        case .compact: return FrilaGeometry.buttonHeightCompact
        case .standard: return FrilaGeometry.buttonHeightStandard
        case .prominent: return FrilaGeometry.buttonHeightProminent
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
        case .compact: return FrilaTypography.captionBold
        case .standard: return FrilaTypography.button
        case .prominent: return FrilaTypography.sans(size: FrilaTypeScaleStep.placard.pointSize, weight: .bold)
        }
    }
    
    private var iconFont: Font {
        switch size {
        case .compact: return FrilaFonteDoSistema.fonte(size: FrilaTypeScaleStep.micro.pointSize, weight: .bold)
        case .standard: return FrilaFonteDoSistema.fonte(size: FrilaTypeScaleStep.caption.pointSize, weight: .semibold)
        case .prominent: return FrilaFonteDoSistema.fonte(size: FrilaTypeScaleStep.body.pointSize, weight: .bold)
        }
    }
    
    @ViewBuilder
    private var buttonBackground: some View {
        switch variant {
        case .primary:
            FrilaColor.dynamicBrandAccent(isDark: isDark)
        case .secondary:
            FrilaColor.dynamicTextInk(isDark: isDark)
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
            return FrilaColor.dynamicCanvas(isDark: isDark)
        case .outline:
            return FrilaColor.dynamicTextPrimary(isDark: isDark)
        case .ghost:
            return FrilaColor.dynamicTextMuted(isDark: isDark)
        case .glass:
            return FrilaColor.dynamicTextPrimary(isDark: isDark)
        }
    }
    
    @ViewBuilder
    private var buttonBorder: some View {
        if variant == .outline {
            Self.formato.stroke(FrilaColor.dynamicBorder(isDark: isDark), lineWidth: 1)
        } else if variant == .glass {
            Self.formato.stroke(
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

public struct FrilaHapticBounceButtonStyle: ButtonStyle {
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

public extension ButtonStyle where Self == FrilaHapticBounceButtonStyle {
    static var hapticBounce: FrilaHapticBounceButtonStyle {
        FrilaHapticBounceButtonStyle()
    }
    
    static func hapticBounce(reduceMotion: Bool = false, scale: CGFloat = 0.96) -> FrilaHapticBounceButtonStyle {
        FrilaHapticBounceButtonStyle(reduceMotion: reduceMotion, scale: scale)
    }
}

// MARK: - Previews
