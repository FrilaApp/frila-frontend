import SwiftUI

/// Estado de ênfase do campo: neutro, borda da marca ou preenchimento sólido da marca.
public enum FrilaLPEFieldEmphasis: Sendable, Equatable {
    case none
    /// Borda terracota de 1,5 pt sobre a superfície neutra.
    case accentBorder
    /// Preenchimento sólido da marca (`dynamicBrandSolidFill`) com texto calibrado para AA.
    case solid
    /// Preenchimento em tinta (`dynamicTextInk`), como os selecionados do app (segmentos, chips marcados).
    case ink
    /// Preenchimento de cor definida por quem usa o campo (o grupo de seletores escolhe o que contrasta).
    case filled(Color)
}

/// Aparência da superfície do campo: o campo padrão (superfície, borda e sombra próprias) ou o recorte
/// dentro de um grupo (espaço negativo na cor da tela, sem borda nem sombra, raio fixo concêntrico).
public enum FrilaLPEFieldChrome: Sendable, Equatable {
    case standard
    case cutout(fill: Color, radius: CGFloat, stroke: Color? = nil)
}

/// Container único que morfa entre o campo fechado (52 pt, raio de campo) e a roleta aberta
/// (150 pt, raio de folha). Superfície, borda interna, sombra e recorte vivem aqui, fora do
/// conteúdo, então o raio, a altura e a máscara animam juntos e nada é cortado por um
/// retângulo duro. A altura é limitada: o undershoot da mola nunca encolhe o campo abaixo de 52 pt e o
/// overshoot da expansão tem folga curta (bounce leve) sem esticar o conteúdo.
public struct FrilaLPEMorphingFieldContainer<Content: View>: View {
    public let isOpen: Bool
    public let isDark: Bool
    /// Valor confirmado. `.accentBorder` mantém a superfície neutra; `.solid` preenche com a marca.
    /// Um fundo apenas tingido (chip claro) lia como enfeite e não como estado, por isso não existe.
    public let emphasis: FrilaLPEFieldEmphasis
    public let chrome: FrilaLPEFieldChrome
    private let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        isOpen: Bool,
        isDark: Bool,
        emphasis: FrilaLPEFieldEmphasis = .none,
        chrome: FrilaLPEFieldChrome = .standard,
        @ViewBuilder content: () -> Content
    ) {
        self.chrome = chrome
        self.isOpen = isOpen
        self.isDark = isDark
        self.emphasis = emphasis
        self.content = content()
    }

    private var closedHeight: CGFloat { FrilaLPEGeometry.buttonHeightProminent }
    private var openHeight: CGFloat { FrilaLPEWheelColumn.totalHeight }
    /// Recorte: raio fixo, para o grupo manter R_grupo = R_campo + respiro também com a roleta aberta.
    private var radius: CGFloat {
        if case .cutout(_, let fixed, _) = chrome { return fixed }
        return isOpen ? FrilaLPEGeometry.radiusSheet : FrilaLPEGeometry.radiusInput
    }

    private var isCutout: Bool {
        if case .cutout = chrome { return true }
        return false
    }

    public var body: some View {
        content
            .modifier(FrilaLPEClampedHeight(
                height: isOpen ? openHeight : closedHeight,
                lowerBound: closedHeight,
                upperBound: openHeight + FrilaLPEMotion.disclosureOvershootAllowance
            ))
            // Raio, recorte e borda numa camada com curva própria: a mola move a altura, a Bézier
            // move o canto, e o canto nunca passa do alvo
            .animation(FrilaMovimento.animacao(morphCurve, reduzir: reduceMotion) ?? .linear(duration: 0)) { surface in
                let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
                surface
                    .background(surfaceFill)
                    .clipShape(shape)
                    .overlay {
                        if !isCutout {
                            shape.strokeBorder(borderColor, lineWidth: emphasis == .accentBorder ? 1.5 : 1)
                        } else if case .cutout(_, _, let stroke?) = chrome, emphasis == .none {
                            // Recorte com filete (modo claro): separa o campo do grupo branco; confirmado, some
                            shape.strokeBorder(stroke, lineWidth: 1)
                        }
                    }
            }
            .animation(FrilaMovimento.animacao(FrilaLPEMotion.disclosureCollapse, reduzir: reduceMotion), value: emphasis)
            // Recorte é espaço negativo: sem sombra, ele não flutua sobre o grupo
            .frilaLPEFormLift(isDark: isDark, isActive: !isCutout)
            .modifier(FrilaLPEDisclosureDrop(trigger: isOpen, isOpening: isOpen, reduceMotion: reduceMotion))
    }

    private var surfaceFill: Color {
        switch emphasis {
        case .solid: return FrilaLPEColor.dynamicBrandSolidFill(isDark: isDark)
        case .ink: return FrilaLPEColor.dynamicTextInk(isDark: isDark)
        case .filled(let color): return color
        case .none, .accentBorder:
            if case .cutout(let fill, _, _) = chrome { return fill }
            return FrilaLPEColor.dynamicFormFieldSurface(isDark: isDark)
        }
    }

    private var borderColor: Color {
        switch emphasis {
        case .none: return FrilaLPEColor.dynamicFormFieldBorder(isDark: isDark)
        case .accentBorder: return FrilaLPEColor.dynamicBrandAccent(isDark: isDark)
        // Preenchidos: a borda some na cor do preenchimento, sem filete claro em volta
        case .solid: return FrilaLPEColor.dynamicBrandSolidFill(isDark: isDark)
        case .ink: return FrilaLPEColor.dynamicTextInk(isDark: isDark)
        case .filled(let color): return color
        }
    }

    private var morphCurve: Animation {
        isOpen ? FrilaLPEMotion.disclosureMorphExpand : FrilaLPEMotion.disclosureMorphCollapse
    }
}

/// Assentamento para baixo: a mola de altura faz o corpo do movimento; por cima, keyframes descem o
/// container alguns pontos e o devolvem ao lugar. Só deslocamento, sem escala.
struct FrilaLPEDisclosureDrop: ViewModifier {
    let trigger: Bool
    let isOpening: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.keyframeAnimator(initialValue: CGFloat(0), trigger: trigger) { view, offsetY in
                view.offset(y: offsetY)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(peak, duration: lead)
                    SpringKeyframe(0, duration: settle, spring: .init(duration: settle, bounce: 0))
                }
            }
        }
    }

    private var peak: CGFloat { isOpening ? FrilaLPEMotion.disclosureDropOffset : FrilaLPEMotion.disclosurePressOffset }
    private var lead: Double { isOpening ? FrilaLPEMotion.disclosureDropLead : FrilaLPEMotion.disclosurePressDip }
    private var settle: Double { isOpening ? FrilaLPEMotion.disclosureDropSettle : FrilaLPEMotion.disclosurePressSettle }
}

extension View {
    /// O mesmo assentamento para baixo dos campos morfáveis, para outros containers que abrem e fecham.
    func frilaLPEDisclosureDrop(isOpen: Bool, reduceMotion: Bool) -> some View {
        modifier(FrilaLPEDisclosureDrop(trigger: isOpen, isOpening: isOpen, reduceMotion: reduceMotion))
    }
}

/// Altura fixa e animável: a mola interpola o alvo bruto e o clamp acontece a cada quadro,
/// sem aceitar proposta de altura do pai (um frame flexível esticaria o campo fechado até
/// 220 pt quando a roleta vizinha abre).
private struct FrilaLPEClampedHeight: ViewModifier, Animatable {
    var height: CGFloat
    let lowerBound: CGFloat
    let upperBound: CGFloat

    nonisolated var animatableData: CGFloat {
        get { height }
        set { height = newValue }
    }

    func body(content: Content) -> some View {
        content.frame(height: min(max(height, lowerBound), upperBound), alignment: .top)
    }
}

extension AnyTransition {
    /// Cross-fade escalonado entre rótulo do campo fechado e linhas da roleta: o que sai some
    /// rápido antes de o que entra aparecer, então os textos nunca se sobrepõem.
    /// Ease-in na saída e ease-out na entrada: curvas de opacidade, o movimento fica com as molas.
    @MainActor static var frilaLPEFieldContent: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.98, anchor: .top))
                .animation(FrilaMovimento.animacao(FrilaLPEMotion.contentFadeIn, reduzir: FrilaLPEMovimentoReduzido.ativo)),
            removal: .opacity.animation(FrilaMovimento.animacao(FrilaLPEMotion.contentFadeOut, reduzir: FrilaLPEMovimentoReduzido.ativo))
        )
    }
}
