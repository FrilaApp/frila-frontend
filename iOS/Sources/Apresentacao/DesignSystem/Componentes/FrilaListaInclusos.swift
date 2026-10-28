import SwiftUI

/// Chave de preferência para medição das alturas reais das linhas da lista.
private struct AlturasItensPreferenceKey: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/// Chave de preferência para acompanhamento da posição real de rolagem do conteúdo interno.
private struct DeslocamentoRolagemPreferenceKey: PreferenceKey {
    struct Offset: Equatable, Sendable {
        let minY: CGFloat
        let maxY: CGFloat
    }
    static let defaultValue = Offset(minY: 0, maxY: 0)
    static func reduce(value: inout Offset, nextValue: () -> Offset) {
        value = nextValue()
    }
}

/// Item individual da lista de itens inclusos na vaga.
public struct FrilaItemIncluso: Identifiable, Hashable, Sendable {
    public let id: String
    public let rotulo: String
    public let valor: String

    public init(rotulo: String, valor: String, id: String? = nil) {
        self.id = id ?? "\(rotulo):\(valor)"
        self.rotulo = rotulo
        self.valor = valor
    }
}

/// Lista expansível em linha dos itens inclusos na vaga.
/// Conforme especificação Hi-Fi (§2–4, REFERENCIA.md, LOG-010, refino r2, pontos #23, #25 e #26):
/// - Lista com mais de 3 itens: ScrollView vertical nativo com rolagem livre (gesto A: arraste na lista rola lista);
/// - Viewport compacto em repouso que exibe 3 linhas completas e a metade da quarta (corte visível como affordance);
/// - Medição dinâmica das alturas reais de cada linha via PreferenceKey, suportando quebras de texto;
/// - Acompanhamento geométrico nativo dos limites reais de rolagem via `DeslocamentoRolagemPreferenceKey`;
/// - Margem vertical de 12 pt exclusiva para os indicadores de rolagem via `.contentMargins(.vertical, 12, for: .scrollIndicators)`,
///   evitando corte pelo corner radius nos extremos de topo e fim (#25);
/// - Máscara com fade progressivo superior de 12 pt apenas quando há conteúdo acima;
/// - Fade progressivo inferior de 12 pt apenas quando há conteúdo abaixo, terminando 8 pt antes da borda (região de 8 pt restante transparente);
/// - Sombra neutra de duas camadas suaves em preto neutro (`Color.black` com opacidades 0,06 e 0,03, evitando glow no modo escuro)
///   aplicada como overlay não interativo (`allowsHitTesting(false)`) na borda superior da faixa do botão,
///   projetada 8 pt para dentro da lista em ambos os estados (compacto e expandido) e persistente até o fim da rolagem;
/// - Máscara com fade inferior condicionado a conteúdo abaixo, terminando 8 pt antes da borda sem sobreposição com a sombra;
/// - Botão mini-CTA com alvo mínimo de 44 pt: rótulo e chevron centralizados na faixa do botão via `alignment: .center` (#26): "Ver tudo (N)" e "Ver menos";
/// - Expansão e recolhimento em linha respeitando `FrilaMotion.disclosureExpand` e `FrilaMotion.disclosureCollapse`;
/// - No estado expandido, renderização direta em `VStack` sem ScrollView, recriando o ScrollView no início a cada recolhimento;
/// - Respeito estrito a `accessibilityReduceMotion` (transição instantânea sem bounce);
/// - Lista curta (até 3 itens): exibição direta sem corte, sem máscara e sem botão;
/// - Chaves de texto localizadas via `bundleApresentacao`.
public struct FrilaListaInclusos: View {
    public let itens: [FrilaItemIncluso]

    @State private var expandido: Bool = false
    @State private var alturasItens: [Int: CGFloat] = [:]
    @State private var haConteudoAcima: Bool = false
    @State private var haConteudoAbaixo: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(itens: [FrilaItemIncluso]) {
        self.itens = itens
    }

    private var alturaCompactaCalculada: CGFloat {
        guard itens.count > 3 else { return 0 }
        let h0 = alturasItens[0] ?? FrilaMetrica.alturaDoCampo
        let h1 = alturasItens[1] ?? FrilaMetrica.alturaDoCampo
        let h2 = alturasItens[2] ?? FrilaMetrica.alturaDoCampo
        let h3 = alturasItens[3] ?? FrilaMetrica.alturaDoCampo
        // 3 divisores de 1 pt entre as 4 primeiras linhas
        return h0 + h1 + h2 + (h3 / 2.0) + 3.0
    }

    private func linha(_ item: FrilaItemIncluso, indice: Int) -> some View {
        HStack(alignment: .center, spacing: FrilaEspaco.compacto) {
            Text(verbatim: item.rotulo)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
            Spacer(minLength: FrilaEspaco.medio)
            Text(verbatim: item.valor)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: FrilaMetrica.alturaDoCampo)
        .padding(.horizontal, FrilaEspaco.medio)
        .background(
            Group {
                if indice < 4 {
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: AlturasItensPreferenceKey.self,
                            value: [indice: geo.size.height]
                        )
                    }
                }
            }
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var botaoToggle: some View {
        Button {
            let animacao = expandido ? FrilaMotion.disclosureCollapse : FrilaMotion.disclosureExpand
            withAnimation(FrilaMovimento.animacao(animacao, reduzir: reduceMotion)) {
                expandido.toggle()
                if !expandido {
                    haConteudoAcima = false
                    haConteudoAbaixo = true
                }
            }
        } label: {
            HStack(spacing: FrilaEspaco.minimo) {
                if expandido {
                    Text("Ver menos", bundle: bundleApresentacao)
                        .font(FrilaTipo.meta.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)
                    Image(systemName: "chevron.up")
                        .font(FrilaTipo.nota.weight(.semibold))
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .accessibilityHidden(true)
                } else {
                    Text("Ver tudo (\(itens.count))", bundle: bundleApresentacao)
                        .font(FrilaTipo.meta.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)
                    Image(systemName: "chevron.down")
                        .font(FrilaTipo.nota.weight(.semibold))
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .center)
            .padding(.horizontal, FrilaEspaco.medio)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("toggle-inclusos")
    }

    private var conteudoLista: some View {
        VStack(spacing: 0) {
            ForEach(0..<itens.count, id: \.self) { index in
                if index > 0 {
                    Divider()
                        .overlay(FrilaCor.divisoria)
                }
                linha(itens[index], indice: index)
            }
        }
    }

    @ViewBuilder
    private func mascaraRolagem(altura: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Fade superior de 12 pt apenas quando há conteúdo acima
            if haConteudoAcima {
                LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 12)
            } else {
                Color.black
                    .frame(height: 12)
            }

            // Região central totalmente opaca
            Color.black
                .frame(maxHeight: .infinity)

            // Fade inferior de 12 pt apenas quando há conteúdo abaixo,
            // terminando 8 pt antes da borda inferior (região restante transparente)
            if haConteudoAbaixo {
                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 12)

                Color.clear
                    .frame(height: 8)
            } else {
                Color.black
                    .frame(height: 20)
            }
        }
        .frame(height: altura)
    }

    @ViewBuilder
    private var sombraFaixaBotao: some View {
        ZStack {
            // Camada 1: projeção suave de contato (preto neutro opacidade 0,06)
            LinearGradient(
                colors: [Color.black.opacity(0.06), Color.clear],
                startPoint: .bottom,
                endPoint: .top
            )
            // Camada 2: dispersão suave complementar (preto neutro opacidade 0,03)
            LinearGradient(
                colors: [Color.black.opacity(0.03), Color.clear],
                startPoint: .bottom,
                endPoint: .top
            )
        }
        .frame(height: 8)
        .allowsHitTesting(false)
    }

    public var body: some View {
        VStack(spacing: 0) {
            if itens.count > 3 {
                if expandido {
                    conteudoLista
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        conteudoLista
                            .background(
                                GeometryReader { geo in
                                    let frame = geo.frame(in: .named("scrollInclusos"))
                                    Color.clear.preference(
                                        key: DeslocamentoRolagemPreferenceKey.self,
                                        value: DeslocamentoRolagemPreferenceKey.Offset(
                                            minY: frame.minY,
                                            maxY: frame.maxY
                                        )
                                    )
                                }
                            )
                    }
                    .coordinateSpace(name: "scrollInclusos")
                    .contentMargins(.vertical, 12, for: .scrollIndicators)
                    .frame(height: alturaCompactaCalculada)
                    .mask {
                        mascaraRolagem(altura: alturaCompactaCalculada)
                    }
                    .onPreferenceChange(DeslocamentoRolagemPreferenceKey.self) { offset in
                        let acima = offset.minY < -1.0
                        let abaixo = offset.maxY > (alturaCompactaCalculada + 1.0)
                        if acima != haConteudoAcima || abaixo != haConteudoAbaixo {
                            withAnimation(FrilaMovimento.animacao(.easeInOut(duration: 0.15), reduzir: reduceMotion)) {
                                haConteudoAcima = acima
                                haConteudoAbaixo = abaixo
                            }
                        }
                    }
                }

                VStack(spacing: 0) {
                    Divider()
                        .overlay(FrilaCor.divisoria)

                    botaoToggle
                }
                .overlay(alignment: .top) {
                    sombraFaixaBotao
                        .alignmentGuide(.top) { d in d[.bottom] }
                }
            } else {
                conteudoLista
            }
        }
        .onPreferenceChange(AlturasItensPreferenceKey.self) { alturas in
            self.alturasItens = alturas
        }
        .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous)
                .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous))
    }
}
