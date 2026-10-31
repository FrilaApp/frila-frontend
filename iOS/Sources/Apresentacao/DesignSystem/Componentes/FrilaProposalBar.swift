import SwiftUI

public typealias ProposalBar = FrilaProposalBar

/// Barra de proposta fixada na base da tela (FrilaProposalBar).
/// Apresenta o valor da hora e o total estimado do turno (100% integral e repassado
/// diretamente pelo contratante ao profissional, sem retenção de taxas ou comissões - DP-01)
/// e botão de ação primária de candidatura com retorno tátil.
public struct FrilaProposalBar: View {
    public let isDark: Bool
    public let hourlyRate: Int
    public let totalEstimate: Int
    public let isSubmitting: Bool
    public let onSubmit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var envReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let rotuloTotalEstimado = String(localized: "TOTAL ESTIMADO", bundle: bundleApresentacao)
    private let rotuloCandidatar = String(localized: "Candidatar-me", bundle: bundleApresentacao)
    private let rotuloSufixoHora = String(localized: "/h", bundle: bundleApresentacao)
    private let rotuloEstimativaPrefixo = String(localized: "Est. ", bundle: bundleApresentacao)
    private let rotuloSeloIntegral = String(localized: "100% integral", bundle: bundleApresentacao)
    private let rotuloDicaIntegral = String(localized: "Valor 100% integral sem taxas", bundle: bundleApresentacao)

    public struct CalculoDeRetencao: Equatable, Sendable {
        public let taxaLiquidaHora: Int
        public let totalLiquido: Int
        public let taxaPlataforma: Int

        public init(valorHora: Int, totalEstimado: Int) {
            self.taxaLiquidaHora = valorHora
            self.totalLiquido = totalEstimado
            self.taxaPlataforma = 0
        }
    }

    var calculoDeRetencao: CalculoDeRetencao {
        CalculoDeRetencao(valorHora: hourlyRate, totalEstimado: totalEstimate)
    }

    var netRate: Int { calculoDeRetencao.taxaLiquidaHora }
    var netTotal: Int { calculoDeRetencao.totalLiquido }
    var platformFee: Int { calculoDeRetencao.taxaPlataforma }

    public init(
        isDark: Bool = false,
        hourlyRate: Int = 160,
        totalEstimate: Int = 25600,
        isSubmitting: Bool = false,
        onSubmit: @escaping () -> Void = {}
    ) {
        self.isDark = isDark
        self.hourlyRate = hourlyRate
        self.totalEstimate = totalEstimate
        self.isSubmitting = isSubmitting
        self.onSubmit = onSubmit
    }

    private func formatarMoeda(_ valor: Int) -> String {
        let estilo = IntegerFormatStyle<Int>.Currency(code: "BRL", locale: Locale(identifier: "pt_BR"))
            .precision(.fractionLength(0))
        return valor.formatted(estilo)
    }

    public var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            dockAcessivel
        } else {
            ViewThatFits(in: .horizontal) {
                dockLargo
                dockPadrao
                dockCompacto
            }
        }
    }

    // MARK: - Variantes de Layout

    private var dockLargo: some View {
        HStack(spacing: FrilaEspaco.medio) {
            pilarDeTaxa(exibeEstimativa: false)
            Rectangle()
                .fill(FrilaCor.divisoria)
                .frame(width: 1, height: 24)
            pilarDeCapital
            Spacer(minLength: FrilaEspaco.compacto)
            botaoEnviar(expandirLargura: false)
        }
        .padding(.horizontal, FrilaEspaco.medio)
        .padding(.vertical, FrilaEspaco.compacto)
        .background(FrilaMaterial.sutil, in: RoundedRectangle(cornerRadius: FrilaRaio.folha, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FrilaRaio.folha, style: .continuous)
                .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
        )
        .elevacaoFrila(.folha)
    }

    private var dockPadrao: some View {
        HStack(spacing: 0) {
            pilarDeTaxa(exibeEstimativa: true)
            Spacer(minLength: FrilaEspaco.pequeno)
            botaoEnviar(expandirLargura: false)
        }
        .padding(.horizontal, FrilaEspaco.medio)
        .padding(.vertical, FrilaEspaco.compacto)
        .background(FrilaMaterial.sutil, in: RoundedRectangle(cornerRadius: FrilaRaio.folha, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FrilaRaio.folha, style: .continuous)
                .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
        )
        .elevacaoFrila(.folha)
    }

    private var dockCompacto: some View {
        VStack(spacing: FrilaEspaco.pequeno) {
            HStack {
                pilarDeTaxa(exibeEstimativa: true)
                Spacer(minLength: 0)
            }
            botaoEnviar(expandirLargura: true)
        }
        .padding(.horizontal, FrilaEspaco.medio)
        .padding(.vertical, FrilaEspaco.compacto)
        .background(FrilaMaterial.sutil, in: RoundedRectangle(cornerRadius: FrilaRaio.folha, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FrilaRaio.folha, style: .continuous)
                .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
        )
        .elevacaoFrila(.folha)
    }

    private var dockAcessivel: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
            pilarDeTaxa(exibeEstimativa: true)
            pilarDeCapital
            botaoEnviar(expandirLargura: true)
        }
        .padding(FrilaEspaco.medio)
        .background(FrilaMaterial.sutil, in: RoundedRectangle(cornerRadius: FrilaRaio.folha, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FrilaRaio.folha, style: .continuous)
                .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
        )
        .elevacaoFrila(.folha)
    }

    // MARK: - Pilares e Botão

    private func pilarDeTaxa(exibeEstimativa: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.minimo) {
                    FrilaPriceTag(texto: formatarMoeda(hourlyRate), leitura: FrilaMoney.spoken(reais: hourlyRate), tamanho: 26, isDark: isDark)
                    Text(verbatim: rotuloSufixoHora)
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }
                .lineLimit(1)

                if exibeEstimativa {
                    FrilaPriceTag(texto: "\(rotuloEstimativaPrefixo)\(formatarMoeda(totalEstimate))", tamanho: 13, isDark: isDark)
                }
            }

            // Selo de remuneração 100% integral (DP-01)
            HStack(spacing: FrilaEspaco.minimo) {
                Image(systemName: "checkmark.seal.fill")
                    .font(FrilaTipo.microRotulo)
                Text(verbatim: rotuloSeloIntegral)
                    .font(FrilaTipo.nota.weight(.bold))
            }
            .foregroundStyle(FrilaCor.sucesso)
            .padding(.horizontal, FrilaEspaco.pequeno)
            .padding(.vertical, FrilaEspaco.minimo)
            .frame(minHeight: FrilaMetrica.alvoMinimo)
            .background(FrilaCor.sucesso.opacity(0.12), in: Capsule())
            .contentShape(Capsule())
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(verbatim: rotuloDicaIntegral))
        }
        .accessibilityElement(children: .contain)
    }

    private var pilarDeCapital: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
            Text(verbatim: rotuloTotalEstimado)
                .font(FrilaTipo.microRotulo)
                .tracking(0.8)
                .foregroundStyle(FrilaCor.textoSecundario)
                .lineLimit(1)
            FrilaPriceTag(texto: formatarMoeda(totalEstimate), leitura: FrilaMoney.spoken(reais: totalEstimate), tamanho: 22, isDark: isDark)
        }
        .accessibilityElement(children: .combine)
    }

    private func botaoEnviar(expandirLargura: Bool) -> some View {
        let formatoDica = String(localized: "Candidatar-me ao turno no valor de %@", bundle: bundleApresentacao)
        let dicaEnvio = String(format: formatoDica, formatarMoeda(totalEstimate))
        return Button(action: onSubmit) {
            HStack(spacing: FrilaEspaco.pequeno) {
                if isSubmitting {
                    ProgressView().tint(FrilaCor.sobrePrimaria)
                } else {
                    Text(verbatim: rotuloCandidatar)
                        .font(FrilaTipo.botao)
                        .multilineTextAlignment(.center)
                    Image(systemName: "arrow.right")
                        .font(FrilaTipo.botao)
                }
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.vertical, FrilaEspaco.pequeno)
            .frame(maxWidth: expandirLargura ? .infinity : nil, minHeight: FrilaMetrica.alturaDoCampo)
            .foregroundStyle(FrilaCor.sobrePrimaria)
            .background(FrilaCor.primaria, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.tatil)
        .disabled(isSubmitting)
        .accessibilityLabel(Text(verbatim: rotuloCandidatar))
        .accessibilityHint(Text(verbatim: dicaEnvio))
    }
}

#Preview("ProposalBar - Tamanho padrão") {
    VStack {
        Spacer()
        FrilaProposalBar(
            hourlyRate: 160,
            totalEstimate: 25600
        )
    }
    .padding(FrilaEspaco.medio)
    .background(FrilaCor.fundo)
}

#Preview("ProposalBar - Acessibilidade AX5") {
    VStack {
        Spacer()
        FrilaProposalBar(
            hourlyRate: 160,
            totalEstimate: 25600
        )
    }
    .padding(FrilaEspaco.medio)
    .background(FrilaCor.fundo)
    .environment(\.dynamicTypeSize, .accessibility5)
}
