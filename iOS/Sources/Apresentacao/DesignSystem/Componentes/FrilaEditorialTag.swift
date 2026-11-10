import SwiftUI

public typealias FrilaTipografia = FrilaTipo
public typealias EditorialTag = FrilaEditorialTag

/// Tag editorial no padrão canônico Frila com geometria 100% Capsule (cornerRadius máximo),
/// borda refinada de 1 pt na cor de marca (a ação, #F46700), fundo tingido com opacidade calibrada,
/// texto em tinta e microrrótulo em caixa alta rastreado. Utilizada para metadados curados, selos técnicos
/// e protocolos.
public struct FrilaEditorialTag: View {
    public let text: String
    public let isDark: Bool
    public let textColor: Color?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        _ text: String,
        isDark: Bool = false,
        textColor: Color? = nil
    ) {
        self.text = text
        self.isDark = isDark
        self.textColor = textColor
    }

    public init(
        text: String,
        isDark: Bool = false,
        textColor: Color? = nil
    ) {
        self.text = text
        self.isDark = isDark
        self.textColor = textColor
    }

    /// Cor do texto quando quem chama não passa uma: a tinta. A `acao` (#F46700) sobre o fundo mede 2,9:1 e sobre o
    /// próprio preenchimento da tag, 2,5:1; o DESIGN.md (Cor) a reserva para preenchimento, nunca para texto.
    static let corDoTextoPadrao: Color = FrilaCor.texto

    /// Preenchimento da tag: a marca tingida, mais densa no escuro.
    static func corDoFundo(isDark: Bool) -> Color {
        FrilaCor.marca.opacity(isDark ? 0.18 : 0.12)
    }

    private var resolvedTextColor: Color {
        textColor ?? Self.corDoTextoPadrao
    }

    private var backgroundColor: Color {
        Self.corDoFundo(isDark: isDark)
    }

    private var borderColor: Color {
        FrilaCor.marca
    }

    public var body: some View {
        Text(verbatim: text)
            .textCase(.uppercase)
            .font(FrilaTipo.microRotulo)
            .tracking(0.8)
            .foregroundStyle(resolvedTextColor)
            .multilineTextAlignment(.center)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            .padding(.horizontal, FrilaEspaco.compacto)
            .padding(.vertical, FrilaEspaco.minimo)
            .frame(minHeight: FrilaMetrica.alturaDoChip)
            .background(backgroundColor, in: FrilaForma.chipQueCresce)
            .clipShape(FrilaForma.chipQueCresce)
            .overlay(
                FrilaForma.chipQueCresce
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(verbatim: text))
            .accessibilityAddTraits(.isStaticText)
    }
}

#Preview("EditorialTag - Tamanho padrão") {
    VStack(spacing: FrilaEspaco.medio) {
        HStack(spacing: FrilaEspaco.pequeno) {
            FrilaEditorialTag("CONTRATO VERIFICADO")
            FrilaEditorialTag("STAFF")
            FrilaEditorialTag("CONFIRMADO")
        }
    }
    .padding(FrilaEspaco.medio)
    .background(FrilaCor.fundo)
}

#Preview("EditorialTag - Acessibilidade AX5") {
    VStack(spacing: FrilaEspaco.medio) {
        FrilaEditorialTag("CONTRATO VERIFICADO")
        FrilaEditorialTag("STAFF")
        FrilaEditorialTag("CONFIRMADO")
    }
    .padding(FrilaEspaco.medio)
    .background(FrilaCor.fundo)
    .environment(\.dynamicTypeSize, .accessibility5)
}
