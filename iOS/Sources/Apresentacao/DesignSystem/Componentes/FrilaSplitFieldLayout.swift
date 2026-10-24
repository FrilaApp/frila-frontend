import SwiftUI

/// Distribuição de largura entre as duas colunas do campo dividido (Categoria e Função).
/// Regra de preenchimento de água: cada coluna recebe o que o conteúdo pede; se couber, a sobra
/// é repartida em proporção ao conteúdo; se não couber, a coluna menor mantém o que precisa (até a
/// metade) e a maior ocupa o resto. Só trunca quando as duas pedem mais que a metade.
public enum FrilaSplitWidths: Sendable {
    public static func distribute(ideals: [CGFloat], available: CGFloat) -> [CGFloat] {
        guard ideals.count == 2, available > 0 else { return ideals.map { _ in max(0, available) / 2 } }
        let i0 = max(1, ideals[0]), i1 = max(1, ideals[1])
        if i0 + i1 <= available {
            let extra = available - (i0 + i1)
            let w0 = i0 + extra * i0 / (i0 + i1)
            return [w0, available - w0]
        }
        let half = available / 2
        if i0 <= half { return [i0, available - i0] }
        if i1 <= half { return [available - i1, i1] }
        return [half, half]
    }

    /// Divisão fixa por razão (usada com as roletas abertas, onde a largura não segue o rótulo).
    public static func ratio(_ ratio: CGFloat, available: CGFloat) -> [CGFloat] {
        let w0 = max(0, available) * ratio
        return [w0, max(0, available) - w0]
    }
}

/// Layout de duas colunas com divisor opcional. `ideals` guia a largura quando `ratio` é nil; o mesmo
/// layout serve ao cabeçalho e ao campo, então os rótulos ficam sempre alinhados às colunas.
/// Subviews: coluna 0, coluna 1 e, opcionalmente, um divisor (posicionado na fronteira, altura total).
public struct FrilaSplitFieldLayout: Layout {
    public var ideals: [CGFloat]
    public var ratio: CGFloat?

    public init(ideals: [CGFloat], ratio: CGFloat? = nil) {
        self.ideals = ideals
        self.ratio = ratio
    }

    private func widths(for available: CGFloat) -> [CGFloat] {
        if let ratio { return FrilaSplitWidths.ratio(ratio, available: available) }
        guard ideals.count == 2, ideals.allSatisfy({ $0 > 0 }) else { return FrilaSplitWidths.ratio(0.5, available: available) }
        return FrilaSplitWidths.distribute(ideals: ideals, available: available)
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count >= 2 else { return .zero }
        let total = proposal.width ?? ideals.reduce(0, +)
        let w = widths(for: total)
        let h0 = subviews[0].sizeThatFits(ProposedViewSize(width: w[0], height: proposal.height)).height
        let h1 = subviews[1].sizeThatFits(ProposedViewSize(width: w[1], height: proposal.height)).height
        return CGSize(width: total, height: max(h0, h1))
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count >= 2 else { return }
        let w = widths(for: bounds.width)
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.minY), anchor: .topLeading,
                          proposal: ProposedViewSize(width: w[0], height: bounds.height))
        subviews[1].place(at: CGPoint(x: bounds.minX + w[0], y: bounds.minY), anchor: .topLeading,
                          proposal: ProposedViewSize(width: w[1], height: bounds.height))
        if subviews.count > 2 {
            subviews[2].place(at: CGPoint(x: bounds.minX + w[0], y: bounds.minY), anchor: .top,
                              proposal: ProposedViewSize(width: 1, height: bounds.height))
        }
    }
}
