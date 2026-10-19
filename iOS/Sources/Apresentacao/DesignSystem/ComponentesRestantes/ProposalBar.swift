import SwiftUI

public typealias ProposalBar = FrilaProposalBar

/// Barra de proposta fixada na base da tela (FrilaProposalBar).
/// Apresenta o valor da hora e do capital estimado, detalhamento progressivo
/// de taxas e retenções (disclosure) e botão de ação primária com retorno tátil.
public struct FrilaProposalBar: View {
    public let isDark: Bool
    public let hourlyRate: Int
    public let totalEstimate: Int
    public let isSubmitting: Bool
    public let onSubmit: () -> Void

    @State private var showingFeeDetails: Bool = false
    @Environment(\.accessibilityReduceMotion) private var envReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let rotuloValoracaoBruta = String(localized: "Valoração Bruta do Contrato:", bundle: bundleApresentacao)
    private let rotuloTaxaPlataforma = String(localized: "Taxa de Serviço da Plataforma (5%):", bundle: bundleApresentacao)
    private let rotuloRepasseLiquido = String(localized: "Repasse Líquido Estimado:", bundle: bundleApresentacao)
    private let rotuloCapitalEst = String(localized: "CAPITAL EST.", bundle: bundleApresentacao)
    private let rotuloEnviarProposta = String(localized: "Enviar Proposta", bundle: bundleApresentacao)
    private let rotuloSufixoHora = String(localized: "/h", bundle: bundleApresentacao)
    private let rotuloEstimativaPrefixo = String(localized: "Est. ", bundle: bundleApresentacao)
    private let estadoTaxasVisivel = String(localized: "Detalhamento de taxas visível", bundle: bundleApresentacao)
    private let estadoTaxasOculto = String(localized: "Detalhamento de taxas oculto", bundle: bundleApresentacao)
    private let hintExpandirTaxas = String(localized: "Toque para alternar o detalhamento de taxas da plataforma", bundle: bundleApresentacao)

    public struct CalculoDeRetencao: Equatable, Sendable {
        public let taxaLiquidaHora: Int
        public let totalLiquido: Int
        public let taxaPlataforma: Int

        public init(valorHora: Int, totalEstimado: Int) {
            let liqHora = Int(Double(valorHora) * 0.95)
            let liqTotal = Int(Double(totalEstimado) * 0.95)
            self.taxaLiquidaHora = liqHora
            self.totalLiquido = liqTotal
            self.taxaPlataforma = totalEstimado - liqTotal
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
        VStack(spacing: 0) {
            if showingFeeDetails {
                detalhamentoDeTaxas
            }

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
    }

    // MARK: - Detalhamento de Taxas (Progressive Disclosure)

    private var detalhamentoDeTaxas: some View {
        VStack(spacing: FrilaEspaco.pequeno) {
            linhaDetalhamento(
                rotulo: rotuloValoracaoBruta,
                valor: formatarMoeda(totalEstimate),
                corDoValor: FrilaCor.texto
            )
            linhaDetalhamento(
                rotulo: rotuloTaxaPlataforma,
                valor: "−\(formatarMoeda(platformFee))",
                corDoValor: FrilaCor.alerta
            )
            Divider().background(FrilaCor.divisoria)
            linhaDetalhamento(
                rotulo: rotuloRepasseLiquido,
                valor: "\(formatarMoeda(netTotal)) (\(formatarMoeda(netRate))/h)",
                corDoValor: FrilaCor.sucesso,
                destaque: true
            )
        }
        .padding(FrilaEspaco.medio)
        .background(FrilaCor.controle, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
        .padding(.horizontal, FrilaEspaco.medio)
        .padding(.bottom, FrilaEspaco.pequeno)
        .transition(
            envReduceMotion
                ? .opacity
                : .asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .bottom)),
                    removal: .opacity
                )
        )
    }

    private func linhaDetalhamento(rotulo: String, valor: String, corDoValor: Color, destaque: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: rotulo)
                .font(destaque ? FrilaTipo.meta.weight(.semibold) : FrilaTipo.nota)
                .foregroundStyle(destaque ? FrilaCor.texto : FrilaCor.textoSecundario)
            Spacer(minLength: FrilaEspaco.pequeno)
            Text(verbatim: valor)
                .font(FrilaTipo.meta.weight(.bold).monospacedDigit())
                .foregroundStyle(corDoValor)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: FrilaRaio.folha, style: .continuous))
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: FrilaRaio.folha, style: .continuous))
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: FrilaRaio.folha, style: .continuous))
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: FrilaRaio.folha, style: .continuous))
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
                    Text(verbatim: formatarMoeda(hourlyRate))
                        .font(FrilaTipo.preco)
                        .foregroundStyle(FrilaCor.texto)
                    Text(verbatim: rotuloSufixoHora)
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }
                .lineLimit(1)

                if exibeEstimativa {
                    Text(verbatim: "\(rotuloEstimativaPrefixo)\(formatarMoeda(totalEstimate))")
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .lineLimit(1)
                }
            }

            // Alternador de taxa líquida (disclosure)
            let textoTaxaLiquida = String(localized: "Líq. \(formatarMoeda(netRate))/h", bundle: bundleApresentacao)
            let rotuloA11yLiquido = String(localized: "Líquido \(FrilaMoney.spoken(reais: netRate, por: "hora"))", bundle: bundleApresentacao)
            Button(action: {
                withAnimation(FrilaMovimento.animacao(.spring(response: 0.28, dampingFraction: 0.75), reduzir: envReduceMotion)) {
                    showingFeeDetails.toggle()
                }
            }) {
                HStack(spacing: FrilaEspaco.minimo) {
                    Text(verbatim: textoTaxaLiquida)
                        .font(FrilaTipo.nota.weight(.bold))
                    Image(systemName: "chevron.down")
                        .font(FrilaTipo.microRotulo)
                        .rotationEffect(.degrees(showingFeeDetails && !envReduceMotion ? 180 : 0))
                }
                .foregroundStyle(FrilaCor.sucesso)
                .padding(.horizontal, FrilaEspaco.pequeno)
                .padding(.vertical, FrilaEspaco.minimo)
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .background(FrilaCor.sucesso.opacity(0.12), in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.tatil)
            .accessibilityLabel(Text(verbatim: rotuloA11yLiquido))
            .accessibilityValue(Text(verbatim: showingFeeDetails ? estadoTaxasVisivel : estadoTaxasOculto))
            .accessibilityHint(Text(verbatim: hintExpandirTaxas))
        }
        .accessibilityElement(children: .contain)
    }

    private var pilarDeCapital: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
            Text(verbatim: rotuloCapitalEst)
                .font(FrilaTipo.microRotulo)
                .tracking(0.8)
                .foregroundStyle(FrilaCor.textoSecundario)
                .lineLimit(1)
            Text(verbatim: formatarMoeda(totalEstimate))
                .font(FrilaTipo.tituloDoCartao)
                .foregroundStyle(FrilaCor.texto)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    private func botaoEnviar(expandirLargura: Bool) -> some View {
        let dicaEnvio = String(localized: "Envia proposta a \(FrilaMoney.spoken(reais: hourlyRate, por: "hora"))", bundle: bundleApresentacao)
        return Button(action: onSubmit) {
            HStack(spacing: FrilaEspaco.pequeno) {
                if isSubmitting {
                    ProgressView().tint(FrilaCor.sobrePrimaria)
                } else {
                    Text(verbatim: rotuloEnviarProposta)
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
        .accessibilityLabel(Text(verbatim: rotuloEnviarProposta))
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
