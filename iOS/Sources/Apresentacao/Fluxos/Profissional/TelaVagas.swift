import FrilaDominio
import SwiftUI

/// Lista de vagas abertas do DF (#104), no quadro "Vagas" do MidFi do Fabrício. Tocar num cartão empilha o detalhe.
public struct TelaVagas: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable private var viewModel: FeedVagasViewModel
    private let abrir: (UUID) -> Void
    @State private var filtroAberto: FiltroDoFeed?

    public init(viewModel: FeedVagasViewModel, abrir: @escaping (UUID) -> Void) {
        self.viewModel = viewModel
        self.abrir = abrir
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                filtros
                AvisoDePermissaoDePush(perfil: .profissional)
                    .padding(.horizontal, FrilaEspaco.grupo)
                conteudo
            }
            .padding(.top, FrilaEspaco.item)
            .padding(.bottom, FrilaEspaco.grupo)
        }
        .background(FrilaCor.fundo)
        // A raiz abre sem título de página (D-DS-14): o conteúdo é o primeiro elemento. O nome continua na barra,
        // pequeno e sem repetir a aba, para o sistema, a voz e os testes de interface acharem a tela.
        .navigationTitle(Text(verbatim: TextosDoProfissional.Lista.titulo))
        .navigationBarTitleDisplayMode(.inline)
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
                    .padding(FrilaEspaco.grupo)
            }
        ))
    }

    /// Fim da medição de abertura (#73): a lista da API publicada.
    private var listaNaTela: @MainActor @Sendable () -> Bool {
        let viewModel = viewModel
        return { if case .carregada = viewModel.estado { true } else { false } }
    }

    private var filtros: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                    filtroFuncao
                    filtroData
                    filtroDistancia
                }
                .padding(.horizontal, FrilaEspaco.grupo)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FrilaEspaco.item) {
                        filtroFuncao
                        filtroData
                        filtroDistancia
                    }
                    .padding(.horizontal, FrilaEspaco.grupo)
                }
            }
        }
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

    /// Chip de filtro: marcado quando o filtro está valendo. Toca e abre a folha das opções daquele filtro.
    private func pilula(_ filtro: FiltroDoFeed, titulo: String, ativo: Bool, identificador: String) -> some View {
        FiltroPill(verbatim: titulo, selecionado: ativo) { filtroAberto = filtro }
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
            .presentationDetents(filtro == .funcao || dynamicTypeSize.isAccessibilitySize
                                 ? [.medium, .large] : [.height(CGFloat(opcoes.count) * 52 + 120)])
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
            VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                Text(verbatim: TextosDoProfissional.Lista.contagem(total: vagas.count, haMais: viewModel.haMaisPaginas))
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, FrilaEspaco.grupo)

                let destaque = CartaoDeVagaDoFeed.destaque(em: vagas)
                LazyVStack(spacing: FrilaEspaco.bloco) {
                    ForEach(vagas) { vaga in
                        Button { abrir(vaga.id) } label: { CartaoDeVagaDoFeed(vaga: vaga, emDestaque: vaga.id == destaque) }
                            .buttonStyle(EstiloDoCartaoDeVagaDoFeed())
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .accessibilityIdentifier("vaga-\(vaga.id.uuidString)")
                            .accessibilityHint(Text("Abre o detalhe da vaga", bundle: bundleApresentacao))
                            .task { await viewModel.registrarVagaVista(id: vaga.id) }
                            .task { if vaga.id == vagas.last?.id { await viewModel.carregarMais() } }
                    }
                }
                .padding(.horizontal, FrilaEspaco.grupo)
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
        EstadoCarregando()
            .accessibilityLabel(Text(verbatim: TextosDoProfissional.Lista.carregando))
            .padding(.horizontal, FrilaEspaco.grupo)
    }

    /// Vazio da lista: o fato, uma dica e, com filtro valendo, o caminho para limpá-lo.
    private var estadoVazio: some View {
        Group {
            if temFiltroAtivo {
                EstadoVazio(
                    verbatim: TextosDoProfissional.Lista.vazioComFiltrosTitulo,
                    mensagem: TextosDoProfissional.Lista.vazioComFiltrosMensagem,
                    rotuloDaAcao: TextosDoProfissional.Lista.limparFiltros
                ) {
                    selecionar {
                        await $0.selecionar(funcao: nil)
                        await $0.selecionar(data: .qualquer)
                        await $0.selecionar(distancia: .qualquer)
                    }
                }
            } else {
                EstadoVazio(verbatim: TextosDoProfissional.Lista.vazioSemFiltrosTitulo,
                            mensagem: TextosDoProfissional.Lista.vazioSemFiltrosMensagem)
            }
        }
        .padding(.horizontal, FrilaEspaco.grupo)
        .accessibilityIdentifier("vagas-vazio")
    }

    /// Falta o ponto base: o botão leva ao Perfil. Sem laranja: a tela não tem uma decisão a tomar, só um caminho.
    private var estadoSemPontoDeReferencia: some View {
        MensagemDaLista(titulo: TextosDoProfissional.Lista.semPontoDeReferenciaTitulo,
                        mensagem: TextosDoProfissional.Lista.semPontoDeReferenciaMensagem) {
            NavigationLink(value: RotaDoProfissional.meuPerfil) {
                Text(verbatim: TextosDoProfissional.Lista.definirPontoBase)
            }
            .buttonStyle(EstiloDoBotaoFrila(papel: .secundario))
        }
        .accessibilityIdentifier("vagas-sem-referencia")
    }

    private var estadoSemConexao: some View {
        MensagemDaLista(titulo: TextosDoProfissional.Lista.semConexaoTitulo,
                        mensagem: TextosDoProfissional.Lista.semConexaoMensagem,
                        identificadorDoTitulo: "vagas-sem-conexao") {
            if !dynamicTypeSize.isAccessibilitySize {
                tentarDeNovo
            }
        }
    }

    private var estadoErro: some View {
        MensagemDaLista(titulo: TextosDoProfissional.Lista.erroMensagem,
                        mensagem: TextosDoProfissional.Lista.erroApoio,
                        identificadorDoTitulo: "vagas-erro") {
            tentarDeNovo
        }
    }

    private var estadoPerfilIncompativel: some View {
        AvisoFrila(verbatim: TextosDoProfissional.Lista.perfilIncompativel, tom: .alerta)
            .padding(.horizontal, FrilaEspaco.grupo)
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

/// Mensagem de estado da lista (sem conexão, erro, sem ponto base): o fato em corpo, a dica em apoio e, abaixo,
/// o botão da saída. Sem ícone e sem cor de problema; é o desenho do `EstadoVazio`, mas deixa o identificador do
/// título e do botão com a tela, que os testes procuram por eles.
private struct MensagemDaLista<Acao: View>: View {
    let titulo: String
    let mensagem: String
    var identificadorDoTitulo: String?
    @ViewBuilder let acao: () -> Acao
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: FrilaEspaco.item) {
                Text(verbatim: titulo)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityIdentifier(identificadorDoTitulo ?? "mensagem-da-lista")
                Text(verbatim: mensagem)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            // Largura do rótulo; com texto grande, a largura toda, para o rótulo quebrar em vez de vazar.
            acao()
                .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: false)
                .padding(.top, FrilaEspaco.bloco)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, FrilaEspaco.respiro)
        .padding(.horizontal, FrilaEspaco.grupo)
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

/// Folha de um filtro: o título e as opções numa lista de escolha única, com o check em tinta na marcada.
/// Tocar aplica na hora e fecha a folha.
private struct FolhaDeFiltro: View {
    let titulo: String
    let opcoes: [OpcaoDeFiltro]
    let fechar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
            Text(verbatim: titulo)
                .font(FrilaTipo.tituloDaTela)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, FrilaEspaco.grupo)
                .padding(.top, FrilaEspaco.grupo)
                .accessibilityAddTraits(.isHeader)
            ScrollView {
                FrilaGrupoDeLinhas(linhasComIcone: false) {
                    ForEach(opcoes) { opcao in
                        FrilaLinhaDeOpcao(titulo: opcao.titulo, remate: .marcada(opcao.marcada)) {
                            opcao.aoTocar()
                            fechar()
                        }
                        .sensoryFeedback(.selection, trigger: opcao.marcada)
                        .accessibilityIdentifier("opcao-filtro-\(opcao.id)")
                    }
                }
                .padding(.horizontal, FrilaEspaco.grupo)
                .padding(.bottom, FrilaEspaco.grupo)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FrilaCor.fundo)
        .accessibilityIdentifier("folha-filtro")
    }
}
