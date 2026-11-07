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

/// Cartão expansível das funções do profissional: uma função por linha, agrupadas por categoria, com
/// a busca como apoio. Começa sempre fechado: sem escolha é um convite de uma linha, com escolha é o resumo.
/// Abrir, fechar, buscar e filtrar nunca mexem na seleção.
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

    /// Sem escolha e fechado, o cartão é um botão cheio na cor Quente (o convite). Ao abrir, o mesmo
    /// elemento vira o cartão: o preenchimento esmaece, a superfície e o fio entram e a lista sai de dentro.
    private var convite: Bool { escolhidas.isEmpty && !aberto }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cabecalho
            if aberto {
                conteudoAberto
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
        .padding(.vertical, FrilaEspaco.minimo)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous)
                .fill(FrilaCor.superficie.opacity(convite ? 0 : 1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous)
                .strokeBorder(convite ? Color.clear : FrilaCor.divisoria, lineWidth: 1)
        )
    }

    // MARK: - Cabeçalho

    private var cabecalho: some View {
        let pendente = escolhidas.isEmpty
        return Button(action: alternarAbertura) {
            HStack(spacing: FrilaEspaco.compacto) {
                VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                    Text(verbatim: pendente
                         ? TextosDoProfissional.Perfil.escolherFuncoes
                         : TextosDoProfissional.Perfil.funcoesSelecionadas(escolhidas.count))
                        .font(pendente ? FrilaTipo.botaoSobreQuente : FrilaTipo.corpo.weight(.semibold))
                        .foregroundStyle(convite ? FrilaCor.sobreSelecao : FrilaCor.texto)
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
                    .foregroundStyle(convite ? FrilaCor.sobreSelecao : FrilaCor.textoSecundario)
                    .rotationEffect(.degrees(aberto ? 180 : 0))
                    .accessibilityHidden(true)
            }
            // Borda interna única: o texto fica a 16 pt da borda do contêiner nos dois estados.
            .padding(.horizontal, FrilaEspaco.medio)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo, alignment: .leading)
            .background(
                Capsule().fill(FrilaCor.quente.opacity(convite ? 1 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloDoCabecalhoDeFuncoes(convite: convite))
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
                            .accessibilityIdentifier("categoria-\(grupo.categoria)")
                        ForEach(Array(grupo.funcoes.enumerated()), id: \.element.id) { indice, funcao in
                            linha(funcao)
                            if indice < grupo.funcoes.count - 1 {
                                // O divisor some ao lado de uma linha preenchida, para os blocos não ganharem um fio entre si.
                                let ladoAladoMarcado = selecionadas.contains(funcao.id) || selecionadas.contains(grupo.funcoes[indice + 1].id)
                                Rectangle()
                                    .fill(FrilaCor.divisoria)
                                    .frame(height: 1)
                                    .padding(.horizontal, FrilaEspaco.medio)
                                    .opacity(ladoAladoMarcado ? 0 : 1)
                                    .animation(FrilaMovimento.animacao(.easeOut(duration: 0.14), reduzir: reduzirMovimento), value: ladoAladoMarcado)
                            }
                        }
                    }
                }
            }
        }
        .padding(.bottom, FrilaEspaco.pequeno)
        // Filtrar não corta a lista: as linhas que saem e as que voltam esmaecem e o resto desliza.
        .animation(
            FrilaMovimento.animacao(.easeOut(duration: 0.18), reduzir: reduzirMovimento),
            value: grupos.flatMap { $0.funcoes.map(\.id) }
        )
    }

    private func linha(_ funcao: Funcao) -> some View {
        let marcada = selecionadas.contains(funcao.id)
        return Button {
            alternar(funcao.id)
        } label: {
            HStack(spacing: FrilaEspaco.pequeno) {
                Text(verbatim: funcao.nome)
                    .font(marcada ? FrilaTipo.corpo.weight(.semibold) : FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                Spacer(minLength: FrilaEspaco.pequeno)
                Image(systemName: "checkmark")
                    .font(FrilaTipo.meta.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
                    .opacity(marcada ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, FrilaEspaco.pequeno)
            .padding(.vertical, FrilaEspaco.compacto)
            .frame(maxWidth: .infinity, alignment: .leading)
            // A seleção é neutra: fundo de campo, texto em semibold e visto em tinta. O Quente fica para foco e ação,
            // nunca para marcar escolha (nada de tom alaranjado esmaecido em contêiner). Não muda a geometria da linha.
            .background(
                RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                    .fill(FrilaCor.superficieDoCampo.opacity(marcada ? 1 : 0))
            )
            .animation(FrilaMovimento.animacao(.easeOut(duration: 0.14), reduzir: reduzirMovimento), value: marcada)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, FrilaEspaco.pequeno)
        .sensoryFeedback(.selection, trigger: marcada)
        .accessibilityAddTraits(marcada ? .isSelected : [])
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
        .padding(.horizontal, FrilaEspaco.pequeno)
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

    /// Encerra a busca: limpa o texto, solta o foco e devolve a lista inteira, sem tocar na seleção.
    private func encerrarBusca() {
        consulta = ""
        focoNaBusca = false
    }
}

// MARK: - Toque no cabeçalho

/// Feedback do toque: o cabeçalho afunda (3% no botão cheio, 2% no cartão) e o botão escurece um pouco.
/// Entra rápido e sai um pouco mais lento, com curva ease-out forte (sem ease-in, que atrasa o início).
private struct EstiloDoCabecalhoDeFuncoes: ButtonStyle {
    let convite: Bool
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    func makeBody(configuration: Configuration) -> some View {
        let pressionado = configuration.isPressed
        let curva = Animation.timingCurve(0.23, 1, 0.32, 1, duration: pressionado ? 0.14 : 0.2)
        return configuration.label
            .brightness(convite && pressionado ? -0.05 : 0)
            .scaleEffect(reduzirMovimento ? 1 : (pressionado ? (convite ? 0.97 : 0.98) : 1))
            .animation(FrilaMovimento.animacao(curva, reduzir: reduzirMovimento), value: pressionado)
    }
}
