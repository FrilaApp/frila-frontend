import SwiftUI

public extension View {
    /// Segmento de marca ("o sinal"): um filete vertical na cor Quente que acompanha, na margem à
    /// esquerda, o texto a que se refere. Aponta o próximo passo pendente da tela e some quando o passo
    /// está cumprido (`ativo: false`).
    ///
    /// Regras do padrão (ver `statement/identidade.md`, "Padrões de marca"):
    /// - a altura é exatamente a do texto acompanhado, do topo da primeira linha à base da última;
    /// - 3 pt de largura, extremidades totalmente arredondadas, a `FrilaEspaco.pequeno` do texto;
    /// - vive na margem e não empurra o texto: o alinhamento não muda com ou sem o segmento;
    /// - no máximo um por tela, e só sobre texto que pede uma ação.
    func frilaSegmento(ativo: Bool = true) -> some View {
        modifier(FrilaSegmentoDeMarca(ativo: ativo))
    }
}

private struct FrilaSegmentoDeMarca: ViewModifier {
    let ativo: Bool
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    private let largura: CGFloat = 3

    func body(content: Content) -> some View {
        content.overlay(alignment: .leading) {
            Capsule()
                .fill(FrilaCor.quente)
                .frame(width: largura)
                .offset(x: -(largura + FrilaEspaco.pequeno))
                .opacity(ativo ? 1 : 0)
                .animation(FrilaMovimento.animacao(.easeOut(duration: 0.16), reduzir: reduzirMovimento), value: ativo)
                .accessibilityHidden(true)
        }
    }
}
