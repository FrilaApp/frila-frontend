import SwiftUI

/// Frila Design System - FrilaLPEStatCard
/// Componente editorial de exibição quantitativa de alto impacto ("Dado em Destaque").
/// Concebido para a síntese: cada card comunica um dado protagonista e uma linha explicativa,
/// sem sombras difusas da web, com borda nítida de 2px e tipografia sans refinada.
public struct FrilaLPEStatCard: View {
    public enum Content: Sendable {
        /// Número protagonista em cor de sinal (#EA5A36) com rótulo e proveniência
        case metric(number: String, label: String, source: String? = nil, isMonumental: Bool = false)
        /// Citação editorial com aspas curvas em cor de sinal e metadados sans limpos
        case quote(text: String, author: String, role: String? = nil)
    }
    
    public let content: Content
    public let isDark: Bool
    public let padding: CGFloat
    public let shadow: FrilaLPEShadowElevation

    public init(
        content: Content,
        isDark: Bool = false,
        padding: CGFloat = 24,
        shadow: FrilaLPEShadowElevation = .subtle
    ) {
        self.content = content
        self.isDark = isDark
        self.padding = padding
        self.shadow = shadow
    }

    private var backgroundColor: Color {
        FrilaLPEColor.dynamicCanvas(isDark: isDark)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaLPEGeometry.space14) {
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
        .clipShape(RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusCardEditorial, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusCardEditorial, style: .continuous)
                .strokeBorder(FrilaLPEColor.dynamicDividerStrong(isDark: isDark), lineWidth: 2)
        )
        .frilaLPEShadow(shadow, isDark: isDark)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityAddTraits(accessibilityTraits)
    }

    @ViewBuilder
    private func metricView(number: String, label: String, source: String?, isMonumental: Bool) -> some View {
        Text(verbatim: number)
            .font(isMonumental ? FrilaLPETypography.metricMonumental : FrilaLPETypography.metricCardBig)
            .tracking(isMonumental ? FrilaLPETypography.metricMonumentalSpec.tracking : FrilaLPETypography.metricCardBigSpec.tracking)
            .foregroundColor(FrilaLPEColor.dynamicBrandAccent(isDark: isDark))
            .lineLimit(1)
            .minimumScaleFactor(0.6)

        Text(verbatim: label)
            .font(FrilaLPETypography.bodyMedium)
            .foregroundColor(FrilaLPEColor.dynamicInk(isDark: isDark))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)

        if let source, !source.isEmpty {
            Text(verbatim: source)
                .font(FrilaLPETypography.caption)
                .foregroundColor(FrilaLPEColor.dynamicSubtle(isDark: isDark))
                .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func quoteView(text: String, author: String, role: String?) -> some View {
        VStack(alignment: .leading, spacing: FrilaLPEGeometry.space14) {
            Image(systemName: "quote.opening")
                .font(FrilaLPEFonteDoSistema.fonte(size: 28, weight: .bold))
                .foregroundColor(FrilaLPEColor.dynamicBrandAccent(isDark: isDark))

            Text(verbatim: text)
                .font(FrilaLPETypography.title)
                .foregroundColor(FrilaLPEColor.dynamicInk(isDark: isDark))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: FrilaLPEGeometry.space2) {
                Text(verbatim: author)
                    .font(FrilaLPETypography.bodyBold)
                    .foregroundColor(FrilaLPEColor.dynamicInk(isDark: isDark))

                if let role, !role.isEmpty {
                    Text(verbatim: role)
                        .font(FrilaLPETypography.caption)
                        .foregroundColor(FrilaLPEColor.dynamicSubtle(isDark: isDark))
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
