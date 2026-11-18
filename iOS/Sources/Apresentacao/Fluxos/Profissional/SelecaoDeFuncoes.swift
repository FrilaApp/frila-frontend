import FrilaDominio
import SwiftUI

/// Funções de uma categoria, já ordenadas, como a lista as mostra.
public struct GrupoDeFuncoes: Identifiable, Equatable, Sendable {
    public let categoria: String
    public let funcoes: [Funcao]
    public var id: String { categoria }
}

/// Agrupamento, busca e resumo da seleção de funções. É só apresentação: a seleção continua sendo o
/// conjunto de UUIDs do `PerfilProfissionalViewModel`, e a identidade de uma função é o UUID, nunca o nome.
public enum OrganizacaoDeFuncoes {
    /// Mapeamento de sinônimos conhecidos normalizados para o nome canônico da função (CD-T04 / CD-T05).
    public static var sinonimosPadrao: [String: String] { ResolucaoDeFuncoes.sinonimosPadrao }

    /// Sem acento, sem diferença de caixa e sem espaços nas pontas, para comparar e buscar.
    public static func normalizar(_ texto: String) -> String {
        ResolucaoDeFuncoes.normalizar(texto)
    }

    /// Resolve até 5 funções candidatas pelo termo digitado (por sinônimo e por nome), sem duplicar (RN44 / CD-T04).
    public static func resolver(termo: String, em funcoes: [Funcao], sinonimos: [String: String] = ResolucaoDeFuncoes.sinonimosPadrao) -> [Funcao] {
        ResolucaoDeFuncoes.resolver(termo: termo, em: funcoes, sinonimos: sinonimos)
    }

    /// Agrupa pela categoria recebida (comparada sem acento nem caixa, exibida como veio), com as
    /// categorias e as funções em ordem alfabética localizada. A categoria vazia vai para o fim, em
    /// `categoriaVazia`. Com `busca`, mostra as funções correspondentes por sinônimo ou nome sem duplicar.
    public static func agrupar(
        _ funcoes: [Funcao],
        busca: String = "",
        categoriaVazia: String,
        sinonimos: [String: String] = sinonimosPadrao
    ) -> [GrupoDeFuncoes] {
        let consulta = normalizar(busca)
        let visiveis: [Funcao]
        if consulta.isEmpty {
            visiveis = funcoes
        } else {
            let correspondentes = resolver(termo: consulta, em: funcoes, sinonimos: sinonimos)
            if !correspondentes.isEmpty {
                visiveis = correspondentes
            } else {
                visiveis = funcoes.filter { normalizar($0.nome).contains(consulta) }
            }
        }

        var titulos: [String: String] = [:]
        var porCategoria: [String: [Funcao]] = [:]
        for funcao in visiveis {
            let titulo = funcao.categoria.trimmingCharacters(in: .whitespacesAndNewlines)
            let chave = normalizar(titulo)
            if titulos[chave] == nil { titulos[chave] = titulo.isEmpty ? categoriaVazia : titulo }
            porCategoria[chave, default: []].append(funcao)
        }

        let chaves = porCategoria.keys.sorted { a, b in
            if a.isEmpty != b.isEmpty { return b.isEmpty }
            return (titulos[a] ?? "").localizedStandardCompare(titulos[b] ?? "") == .orderedAscending
        }
        return chaves.map { chave in
            GrupoDeFuncoes(
                categoria: titulos[chave] ?? categoriaVazia,
                funcoes: (porCategoria[chave] ?? []).sorted { $0.nome.localizedStandardCompare($1.nome) == .orderedAscending }
            )
        }
    }

    /// As funções escolhidas que estão no catálogo, em ordem alfabética. Uma escolha que ficou fora do
    /// catálogo ativo não aparece na lista e, por isso, também não entra na contagem.
    public static func escolhidasVisiveis(_ funcoes: [Funcao], selecionadas: Set<UUID>) -> [Funcao] {
        funcoes.filter { selecionadas.contains($0.id) }
            .sorted { $0.nome.localizedStandardCompare($1.nome) == .orderedAscending }
    }

    /// Linha de resumo do cartão fechado: as duas primeiras escolhidas e quantas ficam de fora.
    public static func resumo(_ escolhidas: [Funcao]) -> String? {
        guard !escolhidas.isEmpty else { return nil }
        return TextosDoProfissional.Perfil.resumoDeFuncoes(
            nomes: escolhidas.prefix(2).map(\.nome),
            restantes: max(0, escolhidas.count - 2)
        )
    }
}

/// Seleção das funções do profissional: um cabeçalho que abre a lista, com uma função por linha agrupada por categoria
/// e a busca como apoio. Começa sempre fechado: sem escolha é um convite de uma linha, com escolha é o resumo.
/// A escolha é um check em tinta (sem laranja e sem fundo de cor). Abrir, fechar, buscar e filtrar nunca mexem na seleção.
struct SecaoDeFuncoes: View {
    let funcoes: [Funcao]
    let selecionadas: Set<UUID>
    let alternar: (UUID) -> Void

    @State private var aberto: Bool
    @State private var consulta = ""
    @FocusState private var focoNaBusca: Bool
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    init(funcoes: [Funcao], selecionadas: Set<UUID>, alternar: @escaping (UUID) -> Void) {
        self.funcoes = funcoes
        self.selecionadas = selecionadas
        self.alternar = alternar
        _aberto = State(initialValue: false)
    }

    private var escolhidas: [Funcao] {
        OrganizacaoDeFuncoes.escolhidasVisiveis(funcoes, selecionadas: selecionadas)
    }

    private var grupos: [GrupoDeFuncoes] {
        OrganizacaoDeFuncoes.agrupar(funcoes, busca: consulta, categoriaVazia: TextosDoProfissional.Perfil.outrasFuncoes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
            FrilaGrupoDeLinhas(linhasComIcone: false) {
                cabecalho
            }
            if aberto {
                conteudoAberto
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Cabeçalho

    private var cabecalho: some View {
        let pendente = escolhidas.isEmpty
        return Button(action: alternarAbertura) {
            HStack(spacing: FrilaEspaco.item) {
                VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                    Text(verbatim: pendente
                         ? TextosDoProfissional.Perfil.escolherFuncoes
                         : TextosDoProfissional.Perfil.funcoesSelecionadas(escolhidas.count))
                        .font(FrilaTipo.rotuloSecundario)
                        .foregroundStyle(FrilaCor.texto)
                    if !aberto, let resumo = OrganizacaoDeFuncoes.resumo(escolhidas) {
                        Text(verbatim: resumo)
                            .font(FrilaTipo.apoio)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .lineLimit(1)
                    }
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: FrilaEspaco.item)
                Image(systemName: "chevron.down")
                    .font(FrilaTipo.apoio.weight(.semibold))
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .rotationEffect(.degrees(aberto ? 180 : 0))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, FrilaMedidaDeLinha.margem)
            .padding(.vertical, FrilaEspaco.item)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvo, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloDeLinhaTocavel())
        .accessibilityIdentifier("botao-expandir-funcoes")
    }

    private func alternarAbertura() {
        let animacao = aberto ? FrilaMotion.disclosureCollapse : FrilaMotion.disclosureExpand
        if aberto { encerrarBusca() }
        withAnimation(FrilaMovimento.animacao(animacao, reduzir: reduzirMovimento)) {
            aberto.toggle()
        }
    }

    // MARK: - Conteúdo aberto

    private var conteudoAberto: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
            barraDeBusca
            if grupos.isEmpty {
                semResultado
            } else {
                ForEach(grupos) { grupo in
                    VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                        Text(verbatim: grupo.categoria)
                            .font(FrilaTipo.rotuloDeGrupo)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("categoria-\(grupo.categoria)")
                        FrilaGrupoDeLinhas(linhasComIcone: false) {
                            ForEach(grupo.funcoes, id: \.id) { funcao in
                                linha(funcao)
                            }
                        }
                    }
                }
            }
        }
        // Filtrar não corta a lista: as linhas que saem e as que voltam esmaecem e o resto desliza.
        .animation(
            FrilaMovimento.animacao(.easeOut(duration: 0.18), reduzir: reduzirMovimento),
            value: grupos.flatMap { $0.funcoes.map(\.id) }
        )
    }

    /// Uma função: o nome e, quando marcada, o check em tinta.
    private func linha(_ funcao: Funcao) -> some View {
        let marcada = selecionadas.contains(funcao.id)
        return FrilaLinhaDeOpcao(titulo: funcao.nome, remate: .marcada(marcada)) {
            alternar(funcao.id)
        }
        .sensoryFeedback(.selection, trigger: marcada)
        .accessibilityIdentifier("pill-funcao-\(funcao.id)")
    }

    // MARK: - Busca

    private var barraDeBusca: some View {
        FrilaSearchBar(
            texto: $consulta,
            foco: $focoNaBusca,
            rotulo: TextosDoProfissional.Perfil.buscarFuncao,
            idDoCampo: "perfil_funcoes_busca",
            identificador: "campo-busca-funcao",
            limpar: (TextosDoProfissional.Perfil.fecharBuscaDeFuncao, "botao-fechar-busca-funcao"),
            recuoInicial: FrilaEspaco.pequeno
        )
    }

    /// Nenhuma função bate com a busca: o fato e o caminho de volta, sem ícone e sem cor.
    private var semResultado: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: TextosDoProfissional.Perfil.nenhumaFuncaoEncontrada)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
            Button { consulta = "" } label: {
                Text(verbatim: TextosDoProfissional.Perfil.limparBusca)
            }
            .buttonStyle(.frilaLink)
            .accessibilityIdentifier("botao-limpar-busca-funcao")
        }
    }

    /// Encerra a busca: limpa o texto, solta o foco e devolve a lista inteira, sem tocar na seleção.
    private func encerrarBusca() {
        consulta = ""
        focoNaBusca = false
    }
}
