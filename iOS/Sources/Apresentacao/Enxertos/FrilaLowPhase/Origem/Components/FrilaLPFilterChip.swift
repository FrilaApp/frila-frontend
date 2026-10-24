import SwiftUI

// MARK: - CANONICAL COMPONENT: FrilaLPChipBounceButtonStyle
/// Estilo de botão tátil calibrado para pílulas e chips compactos.
/// Aplica compressão elástica suave (0.94x) no toque e mola de assentamento rápido,
/// respeitando estritamente a preferência de redução de movimento do sistema.
public struct FrilaLPChipBounceButtonStyle: ButtonStyle {
    public let reduceMotion: Bool
    public let scale: CGFloat
    
    @Environment(\.accessibilityReduceMotion) private var envReduceMotion
    
    public init(reduceMotion: Bool = false, scale: CGFloat = FrilaLPMotion.pressScaleChip) {
        self.reduceMotion = reduceMotion
        self.scale = scale
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        let isReduceActive = reduceMotion || envReduceMotion
        return configuration.label
            .scaleEffect(isReduceActive ? 1.0 : (configuration.isPressed ? scale : 1.0))
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(
                FrilaMovimento.animacao(FrilaLPMotion.chipPressSpring, reduzir: isReduceActive),
                value: configuration.isPressed
            )
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, isPressed in
                isPressed
            }
    }
}

public extension ButtonStyle where Self == FrilaLPChipBounceButtonStyle {
    static var chipBounce: FrilaLPChipBounceButtonStyle {
        FrilaLPChipBounceButtonStyle()
    }
    
    static func chipBounce(reduceMotion: Bool = false, scale: CGFloat = FrilaLPMotion.pressScaleChip) -> FrilaLPChipBounceButtonStyle {
        FrilaLPChipBounceButtonStyle(reduceMotion: reduceMotion, scale: scale)
    }
}

// MARK: - Modos de Bouncing do Chip
public enum FrilaLPChipBounceMode: Sendable {
    /// Apenas compressão tátil na pressão (0.94x).
    case pressOnly
    /// Compressão na pressão e overshoot elástico (1.05x) na transição para ativo (sem animação de symbol).
    case activationPop
    /// Legado / compatibilidade: mapeia para transição sem animação de symbol.
    case symbolBounce
    /// Conjunto canônico: compressão tátil e overshoot elástico de ativação no container (sem animação de symbol).
    case complete
}

// MARK: - CANONICAL COMPONENT: FrilaLPFilterChip
/// Chip de filtro e seleção interativo com dinâmica de Activation Pop Overshoot.
/// Aplica overshoot elástico suave (1.05x) no container ao ativar,
/// sem animação individual no SF Symbol, em conformidade com WCAG AA/AAA,
/// hitbox Apple HIG de 44pt e geometria 100% Capsule.
public struct FrilaLPFilterChip: View {
    public let title: String
    public let isSelected: Bool
    public let systemImage: String?
    public let bounceMode: FrilaLPChipBounceMode
    public let isDark: Bool
    public let reduceMotion: Bool
    public let onToggle: () -> Void
    
    @Environment(\.accessibilityReduceMotion) private var envReduceMotion
    @State private var popTrigger: Bool = false
    
    public init(
        _ title: String,
        isSelected: Bool,
        systemImage: String? = nil,
        bounceMode: FrilaLPChipBounceMode = .activationPop,
        isDark: Bool = false,
        reduceMotion: Bool = false,
        onToggle: @escaping () -> Void
    ) {
        self.title = title
        self.isSelected = isSelected
        self.systemImage = systemImage
        self.bounceMode = bounceMode
        self.isDark = isDark
        self.reduceMotion = reduceMotion
        self.onToggle = onToggle
    }
    
    private var isReduceActive: Bool {
        reduceMotion || envReduceMotion
    }
    
    private func triggerActivationPop() {
        guard !isReduceActive, bounceMode == .activationPop || bounceMode == .complete else { return }
        popTrigger = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            popTrigger = false
        }
    }
    
    public var body: some View {
        Button(action: {
            if !isSelected {
                triggerActivationPop()
            }
            onToggle()
        }) {
            HStack(spacing: FrilaLPGeometry.space6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(FrilaLPFonteDoSistema.fonte(size: 13, weight: isSelected ? .semibold : .medium))
                }
                
                Text(verbatim: title)
                    .font(isSelected ? FrilaLPTypography.captionBold : FrilaLPTypography.captionMedium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, FrilaLPGeometry.chipPaddingHorizontal)
            .frame(height: FrilaLPGeometry.buttonHeightCompact)
            .background(
                isSelected
                    ? FrilaLPColor.dynamicBrandAccent(isDark: isDark)
                    : FrilaLPColor.dynamicSurfaceSubtle(isDark: isDark)
            )
            .foregroundStyle(
                isSelected
                    ? Color.white
                    : FrilaLPColor.dynamicTextPrimary(isDark: isDark)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected
                            ? Color.clear
                            : FrilaLPColor.dynamicHairline(isDark: isDark),
                        lineWidth: 1
                    )
            )
            .scaleEffect(
                isReduceActive ? 1.0 : ((popTrigger && (bounceMode == .activationPop || bounceMode == .complete)) ? FrilaLPMotion.chipOvershootScale : 1.0)
            )
            .animation(
                FrilaMovimento.animacao(FrilaLPMotion.chipActivationSpring, reduzir: isReduceActive),
                value: popTrigger
            )
            .onChange(of: isSelected) { oldValue, newValue in
                if newValue && !oldValue {
                    triggerActivationPop()
                } else if !newValue {
                    popTrigger = false
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(FrilaLPChipBounceButtonStyle(reduceMotion: isReduceActive))
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityLabel(title)
        .accessibilityValue(Text(isSelected ? "Selecionado" : "Não selecionado", bundle: bundleApresentacao))
    }
}
