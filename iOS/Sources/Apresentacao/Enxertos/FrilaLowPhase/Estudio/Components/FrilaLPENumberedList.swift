import SwiftUI

/// Item representativo de uma linha de lista numerada editorial.
public struct FrilaLPENumberedListItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let index: String
    public let title: String
    public let description: String

    public init(
        id: String = UUID().uuidString,
        index: String,
        title: String,
        description: String
    ) {
        self.id = id
        self.index = index
        self.title = title
        self.description = description
    }
}

/// Frila Design System - FrilaLPENumberedList
/// Transposição da lista `.nl` do deck para listas de requisitos de vagas,
/// entregáveis de contrato e escopos de projeto.
/// Oferece dois estilos de apresentação:
/// - `.card`: Container fechado com cantos contínuos (FrilaLPEGeometry.radiusCardEditorial),
///   background drywall, borda de 2pt e divisores internos flutuantes com recuo lateral
///   sem barras soltas ou duplicadas nas extremidades superior e inferior.
/// - `.plain`: Tabela aberta para inserção direta no canvas, delimitada por bordas de 2pt superior e inferior.
public struct FrilaLPENumberedList: View {
    public enum Style: Sendable, Equatable {
        /// Container em card com cantos arredondados, fundo drywall e divisores internos flutuantes.
        case card
        /// Tabela aberta com bordas superior e inferior de 2pt para uso direto no canvas.
        case plain
    }

    public let items: [FrilaLPENumberedListItem]
    public let style: Style
    public let isDark: Bool
    public let shadow: FrilaLPEShadowElevation

    public init(
        items: [FrilaLPENumberedListItem],
        style: Style = .card,
        isDark: Bool = false,
        shadow: FrilaLPEShadowElevation = .subtle
    ) {
        self.items = items
        self.style = style
        self.isDark = isDark
        self.shadow = shadow
    }

    private var backgroundColor: Color {
        FrilaLPEColor.dynamicCanvas(isDark: isDark)
    }

    public var body: some View {
        switch style {
        case .card:
            cardBody
        case .plain:
            plainBody
        }
    }

    // MARK: - Estilo Card (Fechado, sem barras soltas no topo/base)
    private var cardBody: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    // Divisores horizontais internos entre itens: flutuantes, sem encostar na outline
                    Rectangle()
                        .fill(FrilaLPEColor.dynamicDividerStrong(isDark: isDark))
                        .frame(height: 1)
                        .padding(.horizontal, FrilaLPEGeometry.space24)
                }

                rowContent(for: item)
                    .padding(.horizontal, FrilaLPEGeometry.space24)
                    .padding(.vertical, FrilaLPEGeometry.space20)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(accessibilityLabel(for: item))
                    .accessibilityAddTraits(accessibilityTraits(for: item))
            }
        }
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusCardEditorial, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusCardEditorial, style: .continuous)
                .strokeBorder(FrilaLPEColor.dynamicDividerStrong(isDark: isDark), lineWidth: 2)
        )
        .frilaLPEShadow(shadow, isDark: isDark)
    }

    // MARK: - Estilo Plain (Tabela Aberta)
    private var plainBody: some View {
        VStack(spacing: 0) {
            if !items.isEmpty {
                // Borda superior de 2pt
                Rectangle()
                    .fill(FrilaLPEColor.dynamicDividerStrong(isDark: isDark))
                    .frame(height: 2)

                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        // Divisores internos de 2pt
                        Rectangle()
                            .fill(FrilaLPEColor.dynamicDividerStrong(isDark: isDark))
                            .frame(height: 2)
                    }

                    rowContent(for: item)
                        .padding(.vertical, FrilaLPEGeometry.space16)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(accessibilityLabel(for: item))
                        .accessibilityAddTraits(accessibilityTraits(for: item))
                }

                // Borda inferior de fechamento de 2pt
                Rectangle()
                    .fill(FrilaLPEColor.dynamicDividerStrong(isDark: isDark))
                    .frame(height: 2)
            }
        }
    }

    // MARK: - Conteúdo da Linha (Alinhamento Óptico por Baseline)
    private func rowContent(for item: FrilaLPENumberedListItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FrilaLPEGeometry.space12) {
            // Coluna da esquerda: Índice em proporção sans limpa
            Text(verbatim: item.index)
                .font(FrilaLPETypography.bricolage(size: 15, weight: .bold))
                .foregroundColor(FrilaLPEColor.dynamicBrandAccent(isDark: isDark))
                .frame(width: 26, alignment: .leading)

            // Coluna da direita: Título e Descrição harmônicos
            VStack(alignment: .leading, spacing: FrilaLPEGeometry.space4) {
                Text(verbatim: item.title)
                    .font(FrilaLPETypography.bodyBold)
                    .foregroundColor(FrilaLPEColor.dynamicInk(isDark: isDark))

                Text(verbatim: item.description)
                    .font(FrilaLPETypography.body)
                    .foregroundColor(FrilaLPEColor.dynamicInkSecondary(isDark: isDark))
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Derived Accessibility Content (for tests and VoiceOver)
    public func accessibilityLabel(for item: FrilaLPENumberedListItem) -> String {
        "Item \(item.index): \(item.title). \(item.description)"
    }

    public func accessibilityTraits(for item: FrilaLPENumberedListItem) -> AccessibilityTraits {
        [.isStaticText]
    }
}
