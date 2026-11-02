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
    /// Sem acento, sem diferença de caixa e sem espaços nas pontas, para comparar e buscar.
    public static func normalizar(_ texto: String) -> String {
        texto.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    /// Agrupa pela categoria recebida (comparada sem acento nem caixa, exibida como veio), com as
    /// categorias e as funções em ordem alfabética localizada. A categoria vazia vai para o fim, em
    /// `categoriaVazia`. Com `busca`, só ficam as funções cujo nome contém o texto e as categorias que
    /// ainda têm resultado.
    public static func agrupar(_ funcoes: [Funcao], busca: String = "", categoriaVazia: String) -> [GrupoDeFuncoes] {
        let consulta = normalizar(busca)
        let visiveis = consulta.isEmpty ? funcoes : funcoes.filter { normalizar($0.nome).contains(consulta) }

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

/// Cartão expansível das funções do profissional: uma função por linha, agrupadas por categoria, com
/// a busca como apoio. Abre sozinho quando não há nada escolhido (criação) e começa fechado quando há
/// (edição). Abrir, fechar, buscar e filtrar nunca mexem na seleção.
struct SecaoDeFuncoes: View {
    let funcoes: [Funcao]
    let selecionadas: Set<UUID>
    let alternar: (UUID) -> Void

    @State private var aberto: Bool
    @State private var buscando = false
    @State private var consulta = ""
    @FocusState private var focoNaBusca: Bool
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    init(funcoes: [Funcao], selecionadas: Set<UUID>, alternar: @escaping (UUID) -> Void) {
        self.funcoes = funcoes
        self.selecionadas = selecionadas
        self.alternar = alternar
        _aberto = State(initialValue: OrganizacaoDeFuncoes.escolhidasVisiveis(funcoes, selecionadas: selecionadas).isEmpty)
    }

    private var escolhidas: [Funcao] {
        OrganizacaoDeFuncoes.escolhidasVisiveis(funcoes, selecionadas: selecionadas)
    }

    private var grupos: [GrupoDeFuncoes] {
        OrganizacaoDeFuncoes.agrupar(funcoes, busca: consulta, categoriaVazia: TextosDoProfissional.Perfil.outrasFuncoes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cabecalho
            if aberto {
                conteudoAberto
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
        .padding(.horizontal, FrilaEspaco.pequeno)
        .padding(.vertical, FrilaEspaco.minimo)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous)
                .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
        )
    }

    // MARK: - Cabeçalho

    private var cabecalho: some View {
        Button(action: alternarAbertura) {
            HStack(spacing: FrilaEspaco.compacto) {
                VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                    Text(verbatim: escolhidas.isEmpty
                         ? TextosDoProfissional.Perfil.escolhaSuasFuncoes
                         : TextosDoProfissional.Perfil.funcoesSelecionadas(escolhidas.count))
                        .font(FrilaTipo.corpo.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)
                    if !aberto, let resumo = OrganizacaoDeFuncoes.resumo(escolhidas) {
                        Text(verbatim: resumo)
                            .font(FrilaTipo.meta)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: FrilaEspaco.pequeno)
                Image(systemName: "chevron.down")
                    .font(FrilaTipo.meta.weight(.semibold))
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .rotationEffect(.degrees(aberto ? 180 : 0))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            barraDeBusca
            if grupos.isEmpty {
                semResultado
            } else {
                ForEach(grupos) { grupo in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: grupo.categoria)
                            .font(FrilaTipo.microRotulo)
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .padding(.horizontal, FrilaEspaco.medio)
                            .padding(.top, FrilaEspaco.pequeno)
                            .padding(.bottom, FrilaEspaco.minimo)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(Array(grupo.funcoes.enumerated()), id: \.element.id) { indice, funcao in
                            linha(funcao)
                            if indice < grupo.funcoes.count - 1 {
                                Rectangle()
                                    .fill(FrilaCor.divisoria)
                                    .frame(height: 1)
                                    .padding(.horizontal, FrilaEspaco.medio)
                            }
                        }
                    }
                }
            }
        }
        .padding(.bottom, FrilaEspaco.pequeno)
    }

    private func linha(_ funcao: Funcao) -> some View {
        let marcada = selecionadas.contains(funcao.id)
        return Button {
            alternar(funcao.id)
        } label: {
            HStack(spacing: FrilaEspaco.pequeno) {
                Text(verbatim: funcao.nome)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                Spacer(minLength: FrilaEspaco.pequeno)
                Text(verbatim: TextosDoProfissional.Perfil.funcaoSelecionada)
                    .font(FrilaTipo.nota.weight(.semibold))
                    .foregroundStyle(FrilaCor.selecao)
                    .opacity(marcada ? 1 : 0)
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.vertical, FrilaEspaco.compacto)
            .frame(maxWidth: .infinity, alignment: .leading)
            // O contorno é só desenho sobre a linha: a geometria é a mesma nos dois estados.
            .overlay(
                RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                    .strokeBorder(marcada ? FrilaCor.selecao : Color.clear, lineWidth: 2)
            )
            .animation(FrilaMovimento.animacao(.easeOut(duration: 0.14), reduzir: reduzirMovimento), value: marcada)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: marcada)
        .accessibilityAddTraits(marcada ? .isSelected : [])
        .accessibilityIdentifier("pill-funcao-\(funcao.id)")
    }

    // MARK: - Busca

    @ViewBuilder
    private var barraDeBusca: some View {
        if buscando {
            HStack(spacing: FrilaEspaco.compacto) {
                Image(systemName: "magnifyingglass")
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityHidden(true)

                TextField(
                    text: $consulta,
                    prompt: Text(verbatim: TextosDoProfissional.Perfil.nomeDaFuncao).foregroundStyle(FrilaCor.textoSecundario)
                ) {
                    Text(verbatim: TextosDoProfissional.Perfil.buscarFuncao)
                }
                .textFieldStyle(.plain)
                .font(FrilaTipo.valorDoCampo)
                .foregroundStyle(FrilaCor.texto)
                .submitLabel(.done)
                .autocorrectionDisabled()
                .focused($focoNaBusca)
                .onSubmit { focoNaBusca = false }
                .frilaFormField(id: "perfil_funcoes_busca", isFocused: focoNaBusca, onDismiss: { focoNaBusca = false })
                .accessibilityIdentifier("campo-busca-funcao")

                Button(action: encerrarBusca) {
                    Image(systemName: "xmark.circle.fill")
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .frame(width: FrilaMetrica.alvoMinimo, height: FrilaMetrica.alvoMinimo)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: TextosDoProfissional.Perfil.fecharBuscaDeFuncao))
                .accessibilityIdentifier("botao-fechar-busca-funcao")
            }
            .padding(.leading, FrilaEspaco.medio)
            .padding(.trailing, FrilaEspaco.minimo)
            .frame(minHeight: FrilaMetrica.alturaDoCampo)
            .background(FrilaCor.superficieDoCampo, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                    .strokeBorder(FrilaCor.bordaDoCampo, lineWidth: 1)
            )
            .onAppear {
                Task { @MainActor in focoNaBusca = true }
            }
        } else {
            Button {
                buscando = true
            } label: {
                Label {
                    Text(verbatim: TextosDoProfissional.Perfil.buscarFuncao)
                        .font(FrilaTipo.meta.weight(.semibold))
                } icon: {
                    Image(systemName: "magnifyingglass")
                        .font(FrilaTipo.meta.weight(.semibold))
                }
                .foregroundStyle(FrilaCor.textoSecundario)
                .padding(.horizontal, FrilaEspaco.medio)
                .frame(minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("botao-buscar-funcao")
        }
    }

    private var semResultado: some View {
        VStack(spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoProfissional.Perfil.nenhumaFuncaoEncontrada)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
            Button {
                consulta = ""
            } label: {
                Text(verbatim: TextosDoProfissional.Perfil.limparBusca)
                    .font(FrilaTipo.meta.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
                    .frame(minHeight: FrilaMetrica.alvoMinimo)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("botao-limpar-busca-funcao")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FrilaEspaco.compacto)
    }

    /// Fecha a busca: limpa o texto, solta o foco e devolve a lista inteira, sem tocar na seleção.
    private func encerrarBusca() {
        buscando = false
        consulta = ""
        focoNaBusca = false
    }
}
