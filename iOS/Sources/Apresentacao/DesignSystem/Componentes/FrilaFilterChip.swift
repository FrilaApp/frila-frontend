import SwiftUI

// MARK: - CANONICAL COMPONENT: FrilaChipBounceButtonStyle
/// Estilo de botão tátil calibrado para pílulas e chips compactos.
/// Aplica compressão elástica suave (0.94x) no toque e mola de assentamento rápido,
/// respeitando estritamente a preferência de redução de movimento do sistema.
public struct FrilaChipBounceButtonStyle: ButtonStyle {
    public let reduceMotion: Bool
    public let scale: CGFloat
    
    @Environment(\.accessibilityReduceMotion) private var envReduceMotion
    
    public init(reduceMotion: Bool = false, scale: CGFloat = FrilaMotion.pressScaleChip) {
        self.reduceMotion = reduceMotion
        self.scale = scale
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        let isReduceActive = reduceMotion || envReduceMotion
        return configuration.label
            .scaleEffect(isReduceActive ? 1.0 : (configuration.isPressed ? scale : 1.0))
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(
                FrilaMovimento.animacao(FrilaMotion.chipPressSpring, reduzir: isReduceActive),
                value: configuration.isPressed
            )
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, isPressed in
                isPressed
            }
    }
}

public extension ButtonStyle where Self == FrilaChipBounceButtonStyle {
    static var chipBounce: FrilaChipBounceButtonStyle {
        FrilaChipBounceButtonStyle()
    }
    
    static func chipBounce(reduceMotion: Bool = false, scale: CGFloat = FrilaMotion.pressScaleChip) -> FrilaChipBounceButtonStyle {
        FrilaChipBounceButtonStyle(reduceMotion: reduceMotion, scale: scale)
    }
}

// MARK: - Modos de Bouncing do Chip
public enum FrilaChipBounceMode: Sendable {
    /// Apenas compressão tátil na pressão (0.94x).
    case pressOnly
    /// Compressão na pressão e overshoot elástico (1.05x) na transição para ativo (sem animação de symbol).
    case activationPop
    /// Legado / compatibilidade: mapeia para transição sem animação de symbol.
    case symbolBounce
    /// Conjunto canônico: compressão tátil e overshoot elástico de ativação no container (sem animação de symbol).
    case complete
}

// MARK: - CANONICAL COMPONENT: FrilaFilterChip
/// Chip de filtro e seleção interativo com dinâmica de Activation Pop Overshoot.
/// Aplica overshoot elástico suave (1.05x) no container ao ativar,
/// sem animação individual no SF Symbol, em conformidade com WCAG AA/AAA,
/// hitbox Apple HIG de 44pt e geometria 100% Capsule.
public struct FrilaFilterChip: View {
    public let title: String
    public let isSelected: Bool
    public let systemImage: String?
    public let bounceMode: FrilaChipBounceMode
    public let isDark: Bool
    public let reduceMotion: Bool
    public let onToggle: () -> Void
    
    @Environment(\.accessibilityReduceMotion) private var envReduceMotion
    @State private var popTrigger: Bool = false
    
    public init(
        _ title: String,
        isSelected: Bool,
        systemImage: String? = nil,
        bounceMode: FrilaChipBounceMode = .activationPop,
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
            HStack(spacing: FrilaGeometry.space6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(FrilaFonteDoSistema.fonte(size: 13, weight: isSelected ? .semibold : .medium))
                }
                
                Text(verbatim: title)
                    .font(isSelected ? FrilaTypography.captionBold : FrilaTypography.captionMedium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, FrilaGeometry.chipPaddingHorizontal)
            .frame(height: FrilaGeometry.buttonHeightCompact)
            .background(
                isSelected
                    ? FrilaColor.dynamicBrandAccent(isDark: isDark)
                    : FrilaColor.dynamicSurfaceSubtle(isDark: isDark)
            )
            .foregroundStyle(
                isSelected
                    ? Color.white
                    : FrilaColor.dynamicTextPrimary(isDark: isDark)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected
                            ? Color.clear
                            : FrilaColor.dynamicHairline(isDark: isDark),
                        lineWidth: 1
                    )
            )
            .scaleEffect(
                isReduceActive ? 1.0 : ((popTrigger && (bounceMode == .activationPop || bounceMode == .complete)) ? FrilaMotion.chipOvershootScale : 1.0)
            )
            .animation(
                FrilaMovimento.animacao(FrilaMotion.chipActivationSpring, reduzir: isReduceActive),
                value: popTrigger
            )
            .onChange(of: isSelected) { oldValue, newValue in
                if newValue && !oldValue {
                    triggerActivationPop()
                } else if !newValue {
                    popTrigger = false
                }
            }
            // 32 pt visíveis, 44 pt de toque (regra do app: alvo mínimo em todo controle)
            .frame(minHeight: FrilaGeometry.hitboxMinimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(FrilaChipBounceButtonStyle(reduceMotion: isReduceActive))
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityLabel(title)
        .accessibilityValue(Text(isSelected ? "Selecionado" : "Não selecionado", bundle: bundleApresentacao))
    }
}
