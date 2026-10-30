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
    private var peso: Font.Weight = .semibold
    private var compactarAltura = false
    @ScaledMetric private var tintaInteiro: CGFloat = 22
    @ScaledMetric private var tintaMoeda: CGFloat = 14.3
    @ScaledMetric private var tintaCentavos: CGFloat = 15.95

    /// Recebe o formatador da superfície, preservando centavos e leitura falada.
    public init(texto: String, leitura: String? = nil, tamanho: CGFloat = 22, isDark: Bool? = nil,
                peso: Font.Weight = .semibold, compactarAltura: Bool = false) {
        self.init(amount: 0, unit: nil, isDark: isDark ?? false)
        textoFormatado = texto
        leituraFormatada = leitura ?? texto
        self.tamanho = tamanho
        temaExplicito = isDark != nil
        self.peso = peso
        self.compactarAltura = compactarAltura
        _tintaInteiro = ScaledMetric(wrappedValue: tamanho, relativeTo: FrilaTypeScaleStep.nearest(to: tamanho).textStyle)
        _tintaMoeda = ScaledMetric(wrappedValue: tamanho * 0.65, relativeTo: FrilaTypeScaleStep.nearest(to: tamanho * 0.65).textStyle)
        _tintaCentavos = ScaledMetric(wrappedValue: tamanho * 0.725, relativeTo: FrilaTypeScaleStep.nearest(to: tamanho * 0.725).textStyle)
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
                valorPrincipal

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

    @ViewBuilder
    private var valorPrincipal: some View {
        if compactarAltura {
            // Cada trecho acompanha a mesma curva de Dynamic Type usada em sua Font.custom.
            let tinta = FrilaTipo.tintaValor(FrilaPartesValor(valueText),
                tamanhos: (tintaMoeda, tintaInteiro, tintaCentavos), peso: peso)
            CaixaTintaValor(acima: max(0, tinta.maxY) + 1, abaixo: max(0, -tinta.minY) + 1) {
                composicao(valueText)
            }
        } else {
            composicao(valueText)
        }
    }

    private func composicao(_ texto: String) -> some View {
        let partes = FrilaPartesValor(texto)
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            if !partes.prefixo.isEmpty {
                Text(verbatim: partes.prefixo).font(FrilaTypography.captionMedium)
            }
            if !partes.moeda.isEmpty {
                Text(verbatim: partes.moeda)
                    .font(FrilaTipo.fonteValor(tamanho: tamanhoInteiro * 0.65, peso: peso))
                    .tracking(-tamanhoInteiro * 0.65 * 0.04)
                    .foregroundStyle(FrilaColor.dynamicBrandAccent(isDark: escuro))
                    .padding(.trailing, 1)
            }
            Text(verbatim: partes.inteiro)
                .font(FrilaTipo.fonteValor(tamanho: tamanhoInteiro, peso: peso))
                .tracking(-tamanhoInteiro * 0.055)
            if !partes.centavos.isEmpty {
                Text(verbatim: partes.centavos)
                    .font(FrilaTipo.fonteValor(tamanho: tamanhoInteiro * 0.725, peso: peso))
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

/// Reserva só a tinta e 1 pt de respiro por borda; reposiciona o texto pela baseline, sem recortá-lo.
private struct CaixaTintaValor: Layout {
    let acima: CGFloat
    let abaixo: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: subviews.first?.sizeThatFits(.unspecified).width ?? 0, height: ceil(acima + abaixo))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let texto = subviews.first else { return }
        let dimensoes = texto.dimensions(in: .unspecified)
        texto.place(at: CGPoint(x: bounds.minX, y: bounds.minY + acima - dimensoes[.firstTextBaseline]),
                    proposal: .unspecified)
    }

    func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize,
                           subviews: Subviews, cache: inout ()) -> CGFloat? {
        guide == .firstTextBaseline || guide == .lastTextBaseline ? acima : nil
    }
}
