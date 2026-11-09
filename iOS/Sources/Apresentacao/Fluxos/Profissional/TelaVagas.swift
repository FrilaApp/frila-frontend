import FrilaDominio
import SwiftUI

/// Lista de vagas abertas do DF (#104), no quadro "Vagas" do MidFi do Fabrício. Tocar num cartão empilha o detalhe.
public struct TelaVagas: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable private var viewModel: FeedVagasViewModel
    private let abrir: (UUID) -> Void
    @State private var filtroAberto: FiltroDoFeed?
    @State private var textoBusca: String = ""

    public init(viewModel: FeedVagasViewModel, abrir: @escaping (UUID) -> Void) {
        self.viewModel = viewModel
        self.abrir = abrir
    }

    private func filtrarPorBusca(_ vagas: [VagaNaLista]) -> [VagaNaLista] {
        let busca = textoBusca.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !busca.isEmpty else { return vagas }
        return vagas.filter {
            $0.estabelecimento.nome.localizedCaseInsensitiveContains(busca) ||
            $0.funcao.nome.localizedCaseInsensitiveContains(busca)
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                cabecalhoEResumo
                campoDeBusca
                filtros
                AvisoDePermissaoDePush(perfil: .profissional)
                    .padding(.horizontal, FrilaEspaco.medio)
                conteudo
            }
            .padding(.top, FrilaEspaco.pequeno)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosDoProfissional.Lista.titulo))
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await medirAbertura(.listaDeVagas, carregar: viewModel.atualizar, pronto: listaNaTela) }
        .task { if viewModel.estado == .ociosa { await medirAbertura(.listaDeVagas, carregar: viewModel.carregar, pronto: listaNaTela) } }
        // Sem `medirAbertura`: a releitura automática não é abertura de tela e não entra na medição (#73).
        .atualizacaoAutomatica(.vagas, recarregar: viewModel.atualizarEmSilencio)
        .accessibilityIdentifier("tela-vagas")
        .sheet(item: $filtroAberto) { filtro in folhaDeFiltro(filtro) }
        .modifier(BarraInferiorDeAcessibilidade(
            ativo: dynamicTypeSize.isAccessibilitySize && viewModel.estado == .falha(.semConexao),
            rodape: {
                tentarDeNovo
                    .padding(FrilaEspaco.medio)
            }
        ))
    }

    @ViewBuilder
    private var cabecalhoEResumo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Vagas", bundle: bundleApresentacao)
                .font(FrilaTipo.tituloDaTela)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)

            if case let .carregada(vagas) = viewModel.estado {
                let filtradas = filtrarPorBusca(vagas)
                if !filtradas.isEmpty {
                    Text("\(filtradas.count) vagas até 5 km do seu ponto base", bundle: bundleApresentacao)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }
            }
        }
        .padding(.horizontal, FrilaEspaco.medio)
    }

    private var campoDeBusca: some View {
        HStack(spacing: FrilaEspaco.compacto) {
            Image(systemName: "magnifyingglass")
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityHidden(true)

            TextField(String(localized: "Buscar vagas por casa ou função", bundle: bundleApresentacao), text: $textoBusca)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityIdentifier("campo-busca-vagas")

            if !textoBusca.isEmpty {
                Button {
                    textoBusca = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Limpar busca", bundle: bundleApresentacao))
                .accessibilityIdentifier("botao-limpar-busca-vagas")
            }
        }
        .padding(.horizontal, FrilaEspaco.medio)
        .frame(height: 48)
        .background(FrilaCor.superficieDoCampo, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous).strokeBorder(FrilaCor.bordaDoCampo, lineWidth: 1))
        .padding(.horizontal, FrilaEspaco.medio)
    }

    /// Fim da medição de abertura (#73): a lista da API publicada.
    private var listaNaTela: @MainActor @Sendable () -> Bool {
        let viewModel = viewModel
        return { if case .carregada = viewModel.estado { true } else { false } }
    }

    private var totalFiltrosAplicados: Int {
        var total = 0
        if viewModel.funcaoID != nil { total += 1 }
        if viewModel.data != .qualquer { total += 1 }
        if viewModel.distancia != .qualquer { total += 1 }
        return total
    }

    private var filtros: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FrilaEspaco.pequeno) {
                Button {
                    filtroAberto = .funcao
                } label: {
                    HStack(spacing: FrilaEspaco.minimo) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(FrilaTipo.meta.weight(.semibold))
                            .accessibilityHidden(true)
                        Text(totalFiltrosAplicados > 0
                            ? String(localized: "Filtros (\(totalFiltrosAplicados))", bundle: bundleApresentacao)
                            : String(localized: "Filtros", bundle: bundleApresentacao))
                            .font(FrilaTipo.meta.weight(.medium))
                    }
                    .padding(.horizontal, FrilaEspaco.compacto)
                    .frame(height: 36)
                    .foregroundStyle(FrilaCor.texto)
                    .background(FrilaCor.superficie, in: Capsule())
                    .overlay(Capsule().strokeBorder(FrilaCor.borda, lineWidth: 1))
                    .frame(minHeight: FrilaMetrica.alvoMinimo)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(totalFiltrosAplicados > 0
                    ? String(localized: "Filtros, \(totalFiltrosAplicados) aplicados", bundle: bundleApresentacao)
                    : String(localized: "Filtros", bundle: bundleApresentacao))
                .accessibilityIdentifier("filtro-abrir")

                if let funcaoID = viewModel.funcaoID, let nome = viewModel.funcoes.first(where: { $0.id == funcaoID })?.nome {
                    chipFiltroAplicado("\(nome) ×", acessibilidade: "\(nome), remover filtro") {
                        selecionar { await $0.selecionar(funcao: nil) }
                    }
                }

                if viewModel.data != .qualquer {
                    chipFiltroAplicado("\(rotuloData) ×", acessibilidade: "\(rotuloData), remover filtro") {
                        selecionar { await $0.selecionar(data: .qualquer) }
                    }
                }

                if viewModel.distancia != .qualquer {
                    chipFiltroAplicado("\(rotuloDistancia) ×", acessibilidade: "\(rotuloDistancia), remover filtro") {
                        selecionar { await $0.selecionar(distancia: .qualquer) }
                    }
                }
            }
            .padding(.horizontal, FrilaEspaco.medio)
        }
    }

    private func chipFiltroAplicado(_ texto: String, acessibilidade: String, acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            Text(verbatim: texto)
                .font(FrilaTipo.meta.weight(.medium))
                .padding(.horizontal, FrilaEspaco.compacto)
                .frame(height: 36)
                .foregroundStyle(FrilaCor.texto)
                .background(FrilaCor.superficie, in: Capsule())
                .overlay(Capsule().strokeBorder(FrilaCor.borda, lineWidth: 1))
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: acessibilidade))
    }

    /// Cada filtro abre a própria folha (sem `Menu` nativo): tocar numa opção aplica na hora e fecha.
    private var filtroFuncao: some View {
        pilula(.funcao, titulo: rotuloFuncao, ativo: viewModel.funcaoID != nil, identificador: "filtro-funcao")
    }

    private var filtroData: some View {
        pilula(.data, titulo: rotuloData, ativo: viewModel.data != .qualquer, identificador: "filtro-data")
    }

    private var filtroDistancia: some View {
        pilula(.distancia, titulo: rotuloDistancia, ativo: viewModel.distancia != .qualquer, identificador: "filtro-distancia")
    }

    private func pilula(_ filtro: FiltroDoFeed, titulo: String, ativo: Bool, identificador: String) -> some View {
        Button { filtroAberto = filtro } label: {
            PilulaDeFiltro(titulo: titulo, ativo: ativo)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identificador)
    }

    private func folhaDeFiltro(_ filtro: FiltroDoFeed) -> some View {
        let opcoes: [OpcaoDeFiltro]
        let titulo: String
        switch filtro {
        case .funcao:
            titulo = TextosDoProfissional.Lista.filtroFuncao
            opcoes = [OpcaoDeFiltro(id: "qualquer", titulo: TextosDoProfissional.Lista.qualquerFuncao, marcada: viewModel.funcaoID == nil) {
                selecionar { await $0.selecionar(funcao: nil) }
            }] + viewModel.funcoes.map { funcao in
                OpcaoDeFiltro(id: funcao.id.uuidString, titulo: funcao.nome, marcada: viewModel.funcaoID == funcao.id) {
                    selecionar { await $0.selecionar(funcao: funcao.id) }
                }
            }
        case .data:
            titulo = TextosDoProfissional.Lista.filtroData
            opcoes = FiltroDeData.allCases.map { opcao in
                OpcaoDeFiltro(id: "\(opcao)", titulo: Self.tituloMenu(opcao), marcada: viewModel.data == opcao) {
                    selecionar { await $0.selecionar(data: opcao) }
                }
            }
        case .distancia:
            titulo = TextosDoProfissional.Lista.filtroDistancia
            opcoes = FiltroDeDistancia.opcoes.map { opcao in
                OpcaoDeFiltro(id: "\(opcao)", titulo: Self.tituloMenu(opcao), marcada: viewModel.distancia == opcao) {
                    selecionar { await $0.selecionar(distancia: opcao) }
                }
            }
        }
        return FolhaDeFiltro(titulo: titulo, opcoes: opcoes) { filtroAberto = nil }
            .presentationDetents(filtro == .funcao ? [.medium, .large] : [.height(CGFloat(opcoes.count) * 52 + 96)])
            .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var conteudo: some View {
        switch viewModel.estado {
        case .ociosa, .carregando:
            estadoCarregando
        case let .carregada(vagas) where vagas.isEmpty:
            estadoVazio
        case let .carregada(vagas):
            VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
                Text(verbatim: TextosDoProfissional.Lista.contagem(total: vagas.count, haMais: viewModel.haMaisPaginas))
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .padding(.horizontal, FrilaEspaco.medio)

                LazyVStack(spacing: FrilaEspaco.compacto) {
                    ForEach(vagas) { vaga in
                        Button { abrir(vaga.id) } label: { CartaoVaga(vaga) }
                            .buttonStyle(.plain)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .accessibilityIdentifier("vaga-\(vaga.id.uuidString)")
                            .accessibilityHint(Text("Abre o detalhe da vaga", bundle: bundleApresentacao))
                            .task { await viewModel.registrarVagaVista(id: vaga.id) }
                            .task { if vaga.id == vagas.last?.id { await viewModel.carregarMais() } }
                    }
                }
                .padding(.horizontal, FrilaEspaco.medio)
            }
        case .falha(.semConexao):
            estadoSemConexao
        case .falha(.semPontoDeReferencia):
            estadoSemPontoDeReferencia
        case .falha(.perfilIncompativel):
            estadoPerfilIncompativel
        case .falha(.erro):
            estadoErro
        }
    }

    private var estadoCarregando: some View {
        VStack(spacing: FrilaEspaco.medio) {
            ProgressView()
                .controlSize(.regular)
                .tint(FrilaCor.texto)
            Text(verbatim: TextosDoProfissional.Lista.carregando)
                .font(FrilaTipo.tituloDeEstado)
                .foregroundStyle(FrilaCor.texto)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, FrilaEspaco.enorme)
        .padding(.horizontal, FrilaEspaco.grande)
    }

    private var estadoVazio: some View {
        VStack(spacing: FrilaEspaco.medio) {
            Circle()
                .fill(FrilaCor.controle)
                .frame(width: FrilaMetrica.circuloDeEstado, height: FrilaMetrica.circuloDeEstado)
                .overlay {
                    Image(systemName: "magnifyingglass")
                        .font(FrilaTipo.secao)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .accessibilityHidden(true)
                }
            VStack(spacing: FrilaEspaco.pequeno) {
                Text(verbatim: temFiltroAtivo ? TextosDoProfissional.Lista.vazioComFiltrosTitulo : TextosDoProfissional.Lista.vazioSemFiltrosTitulo)
                    .font(FrilaTipo.tituloDeEstado)
                    .foregroundStyle(FrilaCor.texto)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: temFiltroAtivo ? TextosDoProfissional.Lista.vazioComFiltrosMensagem : TextosDoProfissional.Lista.vazioSemFiltrosMensagem)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if temFiltroAtivo {
                BotaoSecundario(verbatim: TextosDoProfissional.Lista.limparFiltros) {
                    selecionar {
                        await $0.selecionar(funcao: nil)
                        await $0.selecionar(data: .qualquer)
                        await $0.selecionar(distancia: .qualquer)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, FrilaEspaco.enorme)
        .padding(.horizontal, FrilaEspaco.grande)
        .accessibilityIdentifier("vagas-vazio")
    }

    private var estadoSemPontoDeReferencia: some View {
        VStack(spacing: FrilaEspaco.medio) {
            Image(systemName: "mappin.slash")
                .font(FrilaTipo.secao)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityHidden(true)
            VStack(spacing: FrilaEspaco.pequeno) {
                Text(verbatim: TextosDoProfissional.Lista.semPontoDeReferenciaTitulo)
                    .font(FrilaTipo.tituloDeEstado)
                    .foregroundStyle(FrilaCor.texto)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: TextosDoProfissional.Lista.semPontoDeReferenciaMensagem)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            NavigationLink(value: RotaDoProfissional.meuPerfil) {
                Text(verbatim: TextosDoProfissional.Lista.definirPontoBase)
                    .font(FrilaTipo.botao)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, FrilaEspaco.grande)
                    .padding(.vertical, FrilaEspaco.pequeno)
                    .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
                    .foregroundStyle(FrilaCor.sobrePrimaria)
                    .background(FrilaCor.primaria, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, FrilaEspaco.enorme)
        .padding(.horizontal, FrilaEspaco.grande)
        .accessibilityIdentifier("vagas-sem-referencia")
    }

    private var estadoSemConexao: some View {
        VStack(spacing: FrilaEspaco.medio) {
            Image(systemName: "wifi.slash")
                .font(FrilaTipo.secao)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityHidden(true)
            VStack(spacing: FrilaEspaco.pequeno) {
                Text(verbatim: TextosDoProfissional.Lista.semConexaoTitulo)
                    .font(FrilaTipo.tituloDeEstado)
                    .foregroundStyle(FrilaCor.texto)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("vagas-sem-conexao")
                Text(verbatim: TextosDoProfissional.Lista.semConexaoMensagem)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !dynamicTypeSize.isAccessibilitySize {
                tentarDeNovo
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, FrilaEspaco.enorme)
        .padding(.horizontal, FrilaEspaco.grande)
    }

    private var estadoErro: some View {
        VStack(spacing: FrilaEspaco.medio) {
            Image(systemName: "exclamationmark.circle")
                .font(FrilaTipo.secao)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityHidden(true)
            VStack(spacing: FrilaEspaco.pequeno) {
                Text(verbatim: TextosDoProfissional.Lista.erroMensagem)
                    .font(FrilaTipo.tituloDeEstado)
                    .foregroundStyle(FrilaCor.texto)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("vagas-erro")
                Text(verbatim: TextosDoProfissional.Lista.erroApoio)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            tentarDeNovo
        }
        .frame(maxWidth: .infinity)
        .padding(.top, FrilaEspaco.enorme)
        .padding(.horizontal, FrilaEspaco.grande)
    }

    private var estadoPerfilIncompativel: some View {
        HStack(alignment: .top, spacing: FrilaEspaco.medio) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(FrilaCor.texto)
                .accessibilityHidden(true)
            Text(verbatim: TextosDoProfissional.Lista.perfilIncompativel)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(FrilaEspaco.medio)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FrilaCor.controle, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso))
        .padding(.horizontal, FrilaEspaco.medio)
        .accessibilityIdentifier("vagas-perfil-incompativel")
    }

    private var tentarDeNovo: some View {
        BotaoSecundario(verbatim: TextosDoProfissional.Lista.tentarDeNovo) {
            Task { await viewModel.carregar() }
        }
        .accessibilityIdentifier("vagas-tentar-de-novo")
    }

    private var temFiltroAtivo: Bool {
        viewModel.funcaoID != nil || viewModel.data != .qualquer || viewModel.distancia != .qualquer
    }

    private var rotuloFuncao: String {
        if let funcaoID = viewModel.funcaoID,
           let funcao = viewModel.funcoes.first(where: { $0.id == funcaoID }) {
            return funcao.nome
        }
        return TextosDoProfissional.Lista.filtroFuncao
    }

    private var rotuloData: String {
        Self.tituloMenu(viewModel.data)
    }

    private var rotuloDistancia: String {
        switch viewModel.distancia {
        case .qualquer:
            return TextosDoProfissional.Lista.filtroDistancia
        case let .ate(km):
            return TextosDoProfissional.Lista.ateKm(km)
        }
    }

    private func selecionar(_ acao: @escaping @MainActor (FeedVagasViewModel) async -> Void) {
        let viewModel = viewModel
        Task { await acao(viewModel) }
    }

    static func tituloMenu(_ data: FiltroDeData) -> String {
        switch data {
        case .qualquer: TextosDoProfissional.Lista.qualquerData
        case .hoje: TextosDoProfissional.Lista.hoje
        case .amanha: TextosDoProfissional.Lista.amanha
        }
    }

    static func tituloMenu(_ distancia: FiltroDeDistancia) -> String {
        switch distancia {
        case .qualquer: TextosDoProfissional.Lista.qualquerDistancia
        case let .ate(km): TextosDoProfissional.Lista.ateKm(km)
        }
    }
}

/// Chip de filtro que abre a folha do filtro: ativo em fundo neutro de campo, semibold e visto; inativo sobre a superfície com fio.
/// O Quente fica fora da seleção. O estado ativo não depende só de cor: ganha um ícone. Altura visual 36 pt num alvo de 44 pt.
private struct PilulaDeFiltro: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let titulo: String
    let ativo: Bool

    private static let alturaVisual: CGFloat = FrilaEspaco.enorme + FrilaEspaco.minimo

    var body: some View {
        HStack(spacing: FrilaEspaco.minimo) {
            if ativo {
                Image(systemName: "checkmark")
                    .accessibilityHidden(true)
            }
            Text(verbatim: titulo)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            Image(systemName: "chevron.down")
                .font(FrilaTipo.nota)
                .accessibilityHidden(true)
        }
        .font(ativo ? FrilaTipo.meta.weight(.semibold) : FrilaTipo.meta.weight(.medium))
        .padding(.horizontal, FrilaEspaco.compacto)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? FrilaEspaco.pequeno : 0)
        .frame(minHeight: Self.alturaVisual)
        .foregroundStyle(FrilaCor.texto)
        .background(ativo ? FrilaCor.superficieDoCampo : FrilaCor.superficie, in: Capsule())
        .overlay(Capsule().strokeBorder(ativo ? FrilaCor.texto : FrilaCor.borda, lineWidth: ativo ? 1.5 : 1))
        .frame(minHeight: FrilaMetrica.alvoMinimo)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(ativo ? String(localized: "filtro ativo", bundle: bundleApresentacao) : "")
    }
}

private struct BarraInferiorDeAcessibilidade<Rodape: View>: ViewModifier {
    let ativo: Bool
    @ViewBuilder let rodape: () -> Rodape

    func body(content: Content) -> some View {
        if ativo {
            if #available(iOS 26, *) {
                content.safeAreaBar(edge: .bottom) {
                    rodape()
                }
            } else {
                content.safeAreaInset(edge: .bottom) {
                    rodape()
                        .background(.regularMaterial)
                }
            }
        } else {
            content
        }
    }
}

// MARK: - Folha de filtro

/// Qual filtro do feed está aberto na folha.
private enum FiltroDoFeed: Identifiable {
    case funcao, data, distancia
    var id: Self { self }
}

private struct OpcaoDeFiltro: Identifiable {
    let id: String
    let titulo: String
    let marcada: Bool
    let aoTocar: () -> Void
}

/// Folha de um filtro: título e lista de opções. A marcada usa a seleção neutra do app (fundo de campo, semibold e visto).
/// Tocar aplica na hora e fecha a folha.
private struct FolhaDeFiltro: View {
    let titulo: String
    let opcoes: [OpcaoDeFiltro]
    let fechar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: titulo)
                .font(FrilaTipo.corpo.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)
                .padding(.horizontal, FrilaEspaco.medio)
                .padding(.top, FrilaEspaco.medio)
                .accessibilityAddTraits(.isHeader)
            ScrollView {
                VStack(spacing: FrilaEspaco.minimo) {
                    ForEach(opcoes) { opcao in
                        Button {
                            opcao.aoTocar()
                            fechar()
                        } label: {
                            HStack(spacing: FrilaEspaco.pequeno) {
                                Text(verbatim: opcao.titulo)
                                    .font(opcao.marcada ? FrilaTipo.corpo.weight(.semibold) : FrilaTipo.corpo)
                                    .foregroundStyle(FrilaCor.texto)
                                Spacer(minLength: FrilaEspaco.pequeno)
                                Image(systemName: "checkmark")
                                    .font(FrilaTipo.meta.weight(.semibold))
                                    .foregroundStyle(FrilaCor.texto)
                                    .opacity(opcao.marcada ? 1 : 0)
                                    .accessibilityHidden(true)
                            }
                            .padding(.horizontal, FrilaEspaco.pequeno)
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                                    .fill(FrilaCor.superficieDoCampo.opacity(opcao.marcada ? 1 : 0))
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.selection, trigger: opcao.marcada)
                        .accessibilityAddTraits(opcao.marcada ? .isSelected : [])
                        .accessibilityIdentifier("opcao-filtro-\(opcao.id)")
                    }
                }
                .padding(.horizontal, FrilaEspaco.pequeno)
                .padding(.bottom, FrilaEspaco.medio)
            }
        }
        .background(FrilaCor.superficie)
        .accessibilityIdentifier("folha-filtro")
    }
}
