import SwiftUI

/// Frila Design System - FrilaStatCard
/// Componente editorial de exibição quantitativa de alto impacto ("Dado em Destaque").
/// Concebido para a síntese: cada card comunica um dado protagonista e uma linha explicativa,
/// sem sombras difusas da web, com borda nítida de 2px e tipografia sans refinada.
public struct FrilaStatCard: View {
    public enum Content: Sendable {
        /// Número protagonista em cor de sinal (#EA5A36) com rótulo e proveniência
        case metric(number: String, label: String, source: String? = nil, isMonumental: Bool = false)
        /// Citação editorial com aspas curvas em cor de sinal e metadados sans limpos
        case quote(text: String, author: String, role: String? = nil)
    }
    
    public let content: Content
    public let isDark: Bool
    public let padding: CGFloat
    public let shadow: FrilaShadowElevation

    public init(
        content: Content,
        isDark: Bool = false,
        padding: CGFloat = 24,
        shadow: FrilaShadowElevation = .subtle
    ) {
        self.content = content
        self.isDark = isDark
        self.padding = padding
        self.shadow = shadow
    }

    private var backgroundColor: Color {
        FrilaColor.dynamicCanvas(isDark: isDark)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaGeometry.space14) {
            switch content {
            case .metric(let number, let label, let source, let isMonumental):
                metricView(number: number, label: label, source: source, isMonumental: isMonumental)
            case .quote(let text, let author, let role):
                quoteView(text: text, author: author, role: role)
            }
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: FrilaGeometry.radiusCardEditorial, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FrilaGeometry.radiusCardEditorial, style: .continuous)
                .strokeBorder(FrilaColor.dynamicDividerStrong(isDark: isDark), lineWidth: 2)
        )
        .frilaShadow(shadow, isDark: isDark)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityAddTraits(accessibilityTraits)
    }

    @ViewBuilder
    private func metricView(number: String, label: String, source: String?, isMonumental: Bool) -> some View {
        if number.contains("R$") {
            FrilaPriceTag(texto: number, tamanho: isMonumental ? 38 : 34, isDark: isDark)
        } else {
            Text(verbatim: number)
                .font(isMonumental ? FrilaTypography.metricMonumental : FrilaTypography.metricCardBig)
                .tracking(isMonumental ? FrilaTypography.metricMonumentalSpec.tracking : FrilaTypography.metricCardBigSpec.tracking)
                .foregroundColor(FrilaColor.dynamicBrandAccent(isDark: isDark))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }

        Text(verbatim: label)
            .font(FrilaTypography.bodyMedium)
            .foregroundColor(FrilaColor.dynamicInk(isDark: isDark))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)

        if let source, !source.isEmpty {
            Text(verbatim: source)
                .font(FrilaTypography.caption)
                .foregroundColor(FrilaColor.dynamicSubtle(isDark: isDark))
                .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func quoteView(text: String, author: String, role: String?) -> some View {
        VStack(alignment: .leading, spacing: FrilaGeometry.space14) {
            Image(systemName: "quote.opening")
                .font(FrilaFonteDoSistema.fonte(size: 28, weight: .bold))
                .foregroundColor(FrilaColor.dynamicBrandAccent(isDark: isDark))

            Text(verbatim: text)
                .font(FrilaTypography.title)
                .foregroundColor(FrilaColor.dynamicInk(isDark: isDark))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: FrilaGeometry.space2) {
                Text(verbatim: author)
                    .font(FrilaTypography.bodyBold)
                    .foregroundColor(FrilaColor.dynamicInk(isDark: isDark))

                if let role, !role.isEmpty {
                    Text(verbatim: role)
                        .font(FrilaTypography.caption)
                        .foregroundColor(FrilaColor.dynamicSubtle(isDark: isDark))
                }
            }
        }
    }

    // MARK: - Derived Accessibility Content (for tests and VoiceOver)
    public var accessibilityLabelText: String {
        switch content {
        case .metric(let number, let label, let source, _):
            if let source, !source.isEmpty {
                return "\(number), \(label). Fonte: \(source)"
            }
            return "\(number), \(label)"
        case .quote(let text, let author, let role):
            if let role, !role.isEmpty {
                return "Citação: \"\(text)\", por \(author), \(role)"
            }
            return "Citação: \"\(text)\", por \(author)"
        }
    }

    public var accessibilityTraits: AccessibilityTraits {
        switch content {
        case .metric:
            return [.isStaticText, .isSummaryElement]
        case .quote:
            return [.isStaticText]
        }
    }
}
