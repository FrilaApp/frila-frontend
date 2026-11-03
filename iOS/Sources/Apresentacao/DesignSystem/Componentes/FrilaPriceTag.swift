import SwiftUI

/// Valor canônico do LOG-016: Jost 600, moeda na marca e centavos menores.
/// Preserva o formatador da superfície e a leitura em um elemento só.
/// O preço não quebra linha e mantém a linha de base entre moeda, inteiro e centavos.
public struct FrilaPriceTag: View {
    public let amount: Int
    /// `nil` renders a plain total with no unit.
    public let unit: FrilaMoney.RateUnit?
    public let estimate: Int?
    public let paradigm: FrilaTypographyParadigm
    public let isDark: Bool
    @Environment(\.colorScheme) private var esquema
    private var textoFormatado: String?
    private var leituraFormatada: String?
    private var tamanho: CGFloat?
    private var temaExplicito = true

    /// Recebe o formatador da superfície, preservando centavos e leitura falada.
    public init(texto: String, leitura: String? = nil, tamanho: CGFloat = 22, isDark: Bool? = nil) {
        self.init(amount: 0, unit: nil, isDark: isDark ?? false)
        textoFormatado = texto
        leituraFormatada = leitura ?? texto
        self.tamanho = tamanho
        temaExplicito = isDark != nil
    }

    private var escuro: Bool { temaExplicito ? isDark : esquema == .dark }
    private var tamanhoInteiro: CGFloat { tamanho ?? valueSpec.size }

    public init(
        amount: Int,
        unit: FrilaMoney.RateUnit? = .hour,
        estimate: Int? = nil,
        paradigm: FrilaTypographyParadigm = .swiss,
        isDark: Bool = false
    ) {
        self.amount = amount
        self.unit = unit
        self.estimate = estimate
        self.paradigm = paradigm
        self.isDark = isDark
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaGeometry.priceEstimateSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: FrilaGeometry.priceUnitSpacing) {
                composicao(valueText)

                if let unitText {
                    Text(verbatim: unitText)
                        .font(FrilaTypography.captionMedium)
                        .foregroundStyle(FrilaColor.dynamicTextMuted(isDark: escuro))
                }
            }

            if let estimateText {
                FrilaPriceTag(texto: estimateText, tamanho: 13, isDark: escuro)
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: spokenLabel))
    }

    private func composicao(_ texto: String) -> some View {
        let partes = FrilaPartesValor(texto)
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            if !partes.prefixo.isEmpty {
                Text(verbatim: partes.prefixo).font(FrilaTypography.captionMedium)
            }
            if !partes.moeda.isEmpty {
                Text(verbatim: partes.moeda)
                    .font(FrilaTipo.fonteValor(tamanho: tamanhoInteiro * 0.65))
                    .tracking(-tamanhoInteiro * 0.65 * 0.04)
                    .foregroundStyle(FrilaColor.dynamicBrandAccent(isDark: escuro))
                    .padding(.trailing, 1)
            }
            Text(verbatim: partes.inteiro)
                .font(FrilaTipo.fonteValor(tamanho: tamanhoInteiro))
                .tracking(-tamanhoInteiro * 0.055)
            if !partes.centavos.isEmpty {
                Text(verbatim: partes.centavos)
                    .font(FrilaTipo.fonteValor(tamanho: tamanhoInteiro * 0.725))
                    .tracking(-tamanhoInteiro * 0.725 * 0.04)
                    .padding(.leading, -1)
            }
            if !partes.sufixo.isEmpty {
                Text(verbatim: partes.sufixo).font(FrilaTypography.captionMedium)
            }
        }
        .foregroundStyle(FrilaColor.dynamicTextPrimary(isDark: escuro))
    }

    // MARK: - Derived content (internal for tests)

    var valueSpec: FrilaTypeSpec {
        FrilaTypography(paradigm: paradigm).metricHeroSpec
    }

    var valueText: String {
        textoFormatado ?? FrilaMoney.total(amount)
    }

    var unitText: String? {
        unit?.suffix
    }

    var estimateText: String? {
        estimate.map(FrilaMoney.estimate)
    }

    var spokenLabel: String {
        if let leituraFormatada { return leituraFormatada }
        var label = FrilaMoney.spoken(reais: amount, por: unit?.spokenName)
        if let estimate {
            label += ", estimado \(FrilaMoney.spoken(reais: estimate))"
        }
        return label
    }
}
