import SwiftUI

// MARK: - Lista plana com camada de seleção única
//
// Peças da lista aberta do seletor de experiência (`FrilaLPEExperienceLevelPicker`), separadas para que
// outras listas curtas de escolha usem o mesmo desenho e o mesmo movimento sem duplicar código. Hoje:
// o seletor de experiência, a lista de etapas do cartão do turno (`FrilaLPEJobShiftStepList`, modelo A) e os
// segmentos do seletor de etapas no topo do cartão (`FrilaLPEJobShiftStepPicker`, modelo B).
//
// - Uma linha de largura total por item, com nome e detalhe.
// - Uma camada só, atrás de todas as linhas, desenhada no retângulo da linha escolhida. Quando a escolha
//   muda dentro de uma animação, a camada desliza na vertical até a nova linha. Uma camada por linha
//   passava por cima do texto das linhas do meio durante o deslize.
// - O nome da linha escolhida ganha peso por um cross-fade com desfoque leve (`selectionTextCrossfade`).

/// Limites de cada linha, para a camada única de seleção saber onde parar. Chave: id da linha.
struct FrilaLPESelectionRowBoundsKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Resolve qual linha está sob o dedo num deslize de seleção.
enum FrilaLPESlideSelection {
    /// A linha cujo intervalo vertical está mais perto de `y` (a que contém `y` tem distância zero).
    /// Fora das pontas, vale a linha da ponta; na divisa, a de cima (a lista vem em ordem).
    static func rowID(atY y: CGFloat, in rows: [(id: String, frame: CGRect)]) -> String? {
        func distance(_ frame: CGRect) -> CGFloat {
            y < frame.minY ? frame.minY - y : (y > frame.maxY ? y - frame.maxY : 0)
        }
        return rows.min { distance($0.frame) < distance($1.frame) }?.id
    }
}

/// A camada de seleção (preenchimento e filete opcional), desenhada no retângulo da linha escolhida.
struct FrilaLPESelectionLayer: View {
    let rect: CGRect
    let radius: CGFloat
    let fill: Color
    var stroke: Color? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(fill)
            .overlay {
                if let stroke {
                    RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(stroke, lineWidth: 1)
                }
            }
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
    }
}

extension View {
    /// Marca esta linha para a camada única de seleção.
    func frilaLPESelectionRow(id: String) -> some View {
        anchorPreference(key: FrilaLPESelectionRowBoundsKey.self, value: .bounds) { [id: $0] }
    }

    /// Camada única de seleção atrás das linhas marcadas com `frilaLPESelectionRow(id:)`: fica no retângulo da
    /// linha `selectedID` e desliza junto com a animação que mudar a escolha.
    func frilaLPESelectionLayerBackground(
        selectedID: String?,
        isVisible: Bool = true,
        radius: CGFloat,
        fill: Color,
        stroke: Color? = nil
    ) -> some View {
        backgroundPreferenceValue(FrilaLPESelectionRowBoundsKey.self) { anchors in
            GeometryReader { proxy in
                if isVisible, let selectedID, let anchor = anchors[selectedID] {
                    FrilaLPESelectionLayer(rect: proxy[anchor], radius: radius, fill: fill, stroke: stroke)
                        .transition(.opacity)
                }
            }
        }
    }
}

/// Nome da linha com troca de peso suave e larguras casadas: Bricolage Bold quando escolhida, Regular nas
/// demais. As duas versões têm suas larguras medidas via `onGeometryChange`. A Bold entra com escala
/// horizontal (eixo x) casada com a largura da Regular e expande até 1, enquanto a Regular expande até a largura
/// da Bold conforme esmaece (sem escala vertical, para a altura da linha não oscilar). O desfoque de pico é
/// controlado pelo token canônico `FrilaLPEMotion.selectionTextCrossfadeBlur` (0,6 pt). Em Reduce Motion, desfoque e
/// escala são removidos, mantendo a troca instantânea (M15).
struct FrilaLPEWeightCrossfadeTitle: View {
    let text: String
    let isEmphasized: Bool
    let color: Color
    /// Alinhamento das duas versões: à esquerda nas linhas, ao centro em segmentos.
    var alignment: Alignment = .leading

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var regularWidth: CGFloat = 0
    @State private var boldWidth: CGFloat = 0

    private var anchorPoint: UnitPoint {
        alignment == .center ? .center : .leading
    }

    private var regularScaleX: CGFloat {
        guard !reduceMotion, regularWidth > 0, boldWidth > 0,
              regularWidth.isFinite, boldWidth.isFinite else { return 1.0 }
        return isEmphasized ? (boldWidth / regularWidth) : 1.0
    }

    private var boldScaleX: CGFloat {
        guard !reduceMotion, regularWidth > 0, boldWidth > 0,
              regularWidth.isFinite, boldWidth.isFinite else { return 1.0 }
        return isEmphasized ? 1.0 : (regularWidth / boldWidth)
    }

    private var regularBlur: CGFloat {
        reduceMotion || !isEmphasized ? 0 : FrilaLPEMotion.selectionTextCrossfadeBlur
    }

    private var boldBlur: CGFloat {
        reduceMotion || isEmphasized ? 0 : FrilaLPEMotion.selectionTextCrossfadeBlur
    }

    var body: some View {
        ZStack(alignment: alignment) {
            Text(verbatim: text)
                .frilaLPEType(FrilaLPEFormType.answerContext, dynamic: true)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.width
                } action: { width in
                    regularWidth = width
                }
                .scaleEffect(x: regularScaleX, y: 1.0, anchor: anchorPoint)
                .opacity(isEmphasized ? 0 : 1)
                .blur(radius: regularBlur)

            Text(verbatim: text)
                .frilaLPEType(FrilaLPEFormType.answer, dynamic: true)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.width
                } action: { width in
                    boldWidth = width
                }
                .scaleEffect(x: boldScaleX, y: 1.0, anchor: anchorPoint)
                .opacity(isEmphasized ? 1 : 0)
                .blur(radius: boldBlur)
        }
        .foregroundColor(color)
        .animation(FrilaMovimento.animacao(FrilaLPEMotion.selectionTextCrossfade, reduzir: reduceMotion), value: isEmphasized)
    }
}

/// Camada cinza de pré-seleção enquanto o dedo está na linha, mais o leve aperto (0,98).
/// Na linha já escolhida a camada já está lá, então o toque só aperta.
/// `isDragging`: um deslize de seleção está em curso e a camada é quem marca a linha; a linha onde o dedo
/// começou não mostra estado de pressão (senão haveria dois cinzas ao mesmo tempo).
struct FrilaLPEPreselectionButtonStyle: ButtonStyle {
    let radius: CGFloat
    let fill: Color
    let isSelected: Bool
    let reduceMotion: Bool
    var isDragging: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed && !isDragging
        return configuration.label
            .background {
                if isPressed && !isSelected {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(fill)
                }
            }
            .scaleEffect(reduceMotion ? 1 : (isPressed ? 0.98 : 1))
            .animation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: reduceMotion), value: isPressed)
    }
}
