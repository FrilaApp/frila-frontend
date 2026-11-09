import FrilaDominio
import SwiftUI

/// T1b · Escolher funções (protótipo: `prototipo/telas/lote1/T1b.html` e `estados/T1b-sem-resultado.html`).
/// Sheet com busca em cápsula, atalho das mais procuradas, lista por categoria e contagem dinâmica.
public struct TelaEscolherFuncoes: View {
    private let funcoes: [Funcao]
    private let selecionadas: Set<UUID>
    private let alternar: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @State private var consulta: String = ""

    private static let nomesMaisProcuradas = ["Bartender", "Garçom", "Auxiliar de cozinha", "Caixa"]

    public init(
        funcoes: [Funcao],
        selecionadas: Set<UUID>,
        alternar: @escaping (UUID) -> Void
    ) {
        self.funcoes = funcoes
        self.selecionadas = selecionadas
        self.alternar = alternar
    }

    private var grupos: [GrupoDeFuncoes] {
        OrganizacaoDeFuncoes.agrupar(funcoes, busca: consulta, categoriaVazia: String(localized: "Outras", bundle: bundleApresentacao))
    }

    private var maisProcuradas: [Funcao] {
        Self.nomesMaisProcuradas.compactMap { nome in
            funcoes.first { OrganizacaoDeFuncoes.normalizar($0.nome) == OrganizacaoDeFuncoes.normalizar(nome) }
        }
    }

    private var textoApoioContagem: String {
        let count = selecionadas.count
        if count == 0 {
            return String(localized: "Nenhuma escolhida. Cada toque já salva.", bundle: bundleApresentacao)
        } else if count == 1 {
            return String(localized: "1 escolhida. Cada toque já salva.", bundle: bundleApresentacao)
        } else {
            return String(localized: "\(count) escolhidas. Cada toque já salva.", bundle: bundleApresentacao)
        }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                cabecalhoFixo
                    .padding(.horizontal, FrilaEspaco.medio)
                    .padding(.top, FrilaEspaco.compacto)
                    .padding(.bottom, FrilaEspaco.pequeno)

                ScrollView {
                    VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
                        if grupos.isEmpty && !consulta.isEmpty {
                            estadoSemResultado
                        } else {
                            if consulta.isEmpty && !maisProcuradas.isEmpty {
                                secaoMaisProcuradas
                            }
                            secaoCategorias
                        }
                    }
                    .padding(.horizontal, FrilaEspaco.medio)
                    .padding(.bottom, FrilaEspaco.grande)
                }
            }
            .background(FrilaCor.fundo)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Concluir", bundle: bundleApresentacao)) {
                        dismiss()
                    }
                    .font(FrilaTipo.corpo.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityIdentifier("concluir-funcoes")
                }
            }
            .accessibilityIdentifier("tela-escolher-funcoes")
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Topo Fixo

    private var cabecalhoFixo: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text("Funções", bundle: bundleApresentacao)
                .font(FrilaTipo.tituloDaTela)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: FrilaEspaco.compacto) {
                Image(systemName: "magnifyingglass")
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityHidden(true)

                TextField(String(localized: "Buscar função", bundle: bundleApresentacao), text: $consulta)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .accessibilityIdentifier("campo-buscar-funcao")

                if !consulta.isEmpty {
                    Button {
                        consulta = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(FrilaTipo.corpo)
                            .foregroundStyle(FrilaCor.textoSecundario)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Limpar busca", bundle: bundleApresentacao))
                    .accessibilityIdentifier("limpar-busca-funcao")
                }
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .frame(height: 48)
            .background(FrilaCor.superficie, in: Capsule())
            .overlay(Capsule().strokeBorder(FrilaCor.bordaDoCampo, lineWidth: 1))

            Text(verbatim: textoApoioContagem)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
        }
    }

    // MARK: - Mais Procuradas

    private var secaoMaisProcuradas: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text("Mais procuradas agora", bundle: bundleApresentacao)
                .font(FrilaTipo.corpo.weight(.semibold))
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FrilaEspaco.compacto) {
                    ForEach(maisProcuradas) { funcao in
                        let selecionada = selecionadas.contains(funcao.id)
                        Button {
                            alternar(funcao.id)
                        } label: {
                            Text(verbatim: funcao.nome)
                                .font(FrilaTipo.chip)
                                .padding(.horizontal, FrilaEspaco.medio)
                                .frame(height: 36)
                                .foregroundStyle(selecionada ? FrilaCor.sobreSelecao : FrilaCor.texto)
                                .background(selecionada ? FrilaCor.selecao : FrilaCor.superficie, in: Capsule())
                                .overlay(Capsule().strokeBorder(selecionada ? Color.clear : FrilaCor.borda, lineWidth: 1))
                                .animation(FrilaMovimento.animacao(FrilaMovimento.transicaoDeEstado, reduzir: reduzirMovimento), value: selecionada)
                        }
                        .buttonStyle(.plain)
                        .frame(minHeight: 48)
                        .accessibilityIdentifier("chip-procurada-\(funcao.id.uuidString)")
                    }
                }
            }
        }
    }

    // MARK: - Categorias

    private var secaoCategorias: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
            ForEach(grupos) { grupo in
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: grupo.categoria)
                        .font(FrilaTipo.corpo.weight(.semibold))
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .padding(.bottom, FrilaEspaco.pequeno)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(grupo.funcoes) { funcao in
                        let selecionada = selecionadas.contains(funcao.id)
                        Button {
                            alternar(funcao.id)
                        } label: {
                            HStack {
                                Text(verbatim: funcao.nome)
                                    .font(FrilaTipo.corpo)
                                    .foregroundStyle(FrilaCor.texto)
                                Spacer()
                                Image(systemName: "checkmark")
                                    .font(FrilaTipo.corpo.weight(.semibold))
                                    .foregroundStyle(FrilaCor.texto)
                                    .opacity(selecionada ? 1 : 0)
                                    .accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(FrilaCor.borda)
                                .frame(height: 1)
                        }
                        .accessibilityIdentifier("funcao-linha-\(funcao.id.uuidString)")
                    }
                }
            }
        }
    }

    // MARK: - Estado Sem Resultado (T1b-sem-resultado.html)

    private var estadoSemResultado: some View {
        VStack(spacing: FrilaEspaco.pequeno) {
            Text(String(localized: "Nenhuma função com “\(consulta)”.", bundle: bundleApresentacao))
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
                .multilineTextAlignment(.center)

            Text("Tente outra busca.", bundle: bundleApresentacao)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, FrilaEspaco.enorme)
        .accessibilityIdentifier("estado-sem-resultado-funcoes")
    }
}
