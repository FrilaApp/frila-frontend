import SwiftUI

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
/// Conforme especificação Hi-Fi (§2–4, REFERENCIA.md e LOG-010):
/// - Três linhas visíveis em repouso (estado padrão compacto), totalmente legíveis e sem fade no texto;
/// - Faixa decorativa própria de esmaecimento após a terceira linha quando houver mais de 3 itens;
/// - Identificação por índice no ForEach para prevenir colisões de itens repetidos;
/// - Botão mini-CTA com alvo mínimo de 44 pt: "Ver tudo (N)" (onde N é o total) e "Ver menos";
/// - Expansão estritamente em linha (inline), sem rolagem aninhada e sem transição para sheet/modal;
/// - Física de animação respeitando `FrilaMotion.disclosureExpand` e `FrilaMotion.disclosureCollapse`;
/// - Respeito estrito a `accessibilityReduceMotion` (transição instantânea sem bounce);
/// - Chaves de texto localizadas via `bundleApresentacao`.
public struct FrilaListaInclusos: View {
    public let itens: [FrilaItemIncluso]

    @State private var expandido: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(itens: [FrilaItemIncluso]) {
        self.itens = itens
    }

    private var itensVisiveis: [FrilaItemIncluso] {
        if expandido || itens.count <= 3 {
            return itens
        }
        return Array(itens.prefix(3))
    }

    private func linha(_ item: FrilaItemIncluso) -> some View {
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
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var listaItensView: some View {
        let visiveis = itensVisiveis
        VStack(spacing: 0) {
            ForEach(0..<visiveis.count, id: \.self) { index in
                if index > 0 {
                    Divider()
                        .overlay(FrilaCor.divisoria)
                }
                linha(visiveis[index])
            }
        }
    }

    @ViewBuilder
    private var faixaEsmaecimentoDecorativa: some View {
        LinearGradient(
            colors: [
                FrilaCor.superficie.opacity(0),
                FrilaCor.divisoria.opacity(0.4)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var botaoToggle: some View {
        Button {
            let animacao = expandido ? FrilaMotion.disclosureCollapse : FrilaMotion.disclosureExpand
            if reduceMotion {
                expandido.toggle()
            } else {
                withAnimation(animacao) {
                    expandido.toggle()
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
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
            .padding(.horizontal, FrilaEspaco.medio)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("toggle-inclusos")
    }

    public var body: some View {
        VStack(spacing: 0) {
            listaItensView

            if !expandido && itens.count > 3 {
                faixaEsmaecimentoDecorativa
            }

            if itens.count > 3 {
                Divider()
                    .overlay(FrilaCor.divisoria)

                botaoToggle
            }
        }
        .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous)
                .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
        )
    }
}
