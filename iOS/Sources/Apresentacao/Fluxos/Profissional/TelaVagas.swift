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
                    if filtradas.count == 1 {
                        Text("1 vaga até \(5) km do seu ponto base", bundle: bundleApresentacao)
                            .font(FrilaTipo.nota)
                            .foregroundStyle(FrilaCor.textoSecundario)
                    } else {
                        Text("\(filtradas.count) vagas até \(5) km do seu ponto base", bundle: bundleApresentacao)
                            .font(FrilaTipo.nota)
                            .foregroundStyle(FrilaCor.textoSecundario)
                    }
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
                    filtroAberto = .todos
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

    @ViewBuilder
    private func folhaDeFiltro(_ filtro: FiltroDoFeed) -> some View {
        switch filtro {
        case .todos:
            FolhaDeFiltrosT2b(viewModel: viewModel) { filtroAberto = nil }
                .presentationDetents([.fraction(0.85), .large])
                .presentationDragIndicator(.visible)
        case .funcao:
            let titulo = TextosDoProfissional.Lista.filtroFuncao
            let opcoes = [OpcaoDeFiltro(id: "qualquer", titulo: TextosDoProfissional.Lista.qualquerFuncao, marcada: viewModel.funcaoID == nil) {
                selecionar { await $0.selecionar(funcao: nil) }
            }] + viewModel.funcoes.map { funcao in
                OpcaoDeFiltro(id: funcao.id.uuidString, titulo: funcao.nome, marcada: viewModel.funcaoID == funcao.id) {
                    selecionar { await $0.selecionar(funcao: funcao.id) }
                }
            }
            FolhaDeFiltro(titulo: titulo, opcoes: opcoes) { filtroAberto = nil }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        case .data:
            let titulo = TextosDoProfissional.Lista.filtroData
            let opcoes = FiltroDeData.allCases.map { opcao in
                OpcaoDeFiltro(id: "\(opcao)", titulo: Self.tituloMenu(opcao), marcada: viewModel.data == opcao) {
                    selecionar { await $0.selecionar(data: opcao) }
                }
            }
            FolhaDeFiltro(titulo: titulo, opcoes: opcoes) { filtroAberto = nil }
                .presentationDetents([.height(CGFloat(opcoes.count) * 52 + 96)])
                .presentationDragIndicator(.visible)
        case .distancia:
            let titulo = TextosDoProfissional.Lista.filtroDistancia
            let opcoes = FiltroDeDistancia.opcoes.map { opcao in
                OpcaoDeFiltro(id: "\(opcao)", titulo: Self.tituloMenu(opcao), marcada: viewModel.distancia == opcao) {
                    selecionar { await $0.selecionar(distancia: opcao) }
                }
            }
            FolhaDeFiltro(titulo: titulo, opcoes: opcoes) { filtroAberto = nil }
                .presentationDetents([.height(CGFloat(opcoes.count) * 52 + 96)])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var conteudo: some View {
        switch viewModel.estado {
        case .ociosa, .carregando:
            estadoCarregando
        case let .carregada(vagas):
            let filtradas = filtrarPorBusca(vagas)
            if filtradas.isEmpty {
                if !textoBusca.isEmpty {
                    estadoBuscaSemResultado
                } else {
                    estadoSemVagas
                }
            } else {
                VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
                    Text(verbatim: TextosDoProfissional.Lista.contagem(total: filtradas.count, haMais: viewModel.haMaisPaginas))
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .padding(.horizontal, FrilaEspaco.medio)

                    LazyVStack(spacing: FrilaEspaco.medio) {
                        ForEach(Array(filtradas.enumerated()), id: \.element.id) { index, vaga in
                            CartaoVagaT2(vaga: vaga, destaque: index == 0 && vaga.modo == .urgencia) {
                                abrir(vaga.id)
                            }
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .accessibilityIdentifier("vaga-\(vaga.id.uuidString)")
                            .accessibilityHint(Text("Abre o detalhe da vaga", bundle: bundleApresentacao))
                            .task { await viewModel.registrarVagaVista(id: vaga.id) }
                            .task { if vaga.id == filtradas.last?.id { await viewModel.carregarMais() } }
                        }
                    }
                    .padding(.horizontal, FrilaEspaco.medio)
                }
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

    private var estadoBuscaSemResultado: some View {
        VStack(spacing: FrilaEspaco.pequeno) {
            Text("Nenhuma vaga com “\(textoBusca)” até \(5) km nestes filtros.", bundle: bundleApresentacao)
                .font(FrilaTipo.tituloDeEstado)
                .foregroundStyle(FrilaCor.texto)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("vagas-busca-sem-resultado")

            Text("Tente outra busca ou mude os filtros.", bundle: bundleApresentacao)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, FrilaEspaco.enorme)
        .padding(.horizontal, FrilaEspaco.grande)
    }

    private var estadoSemVagas: some View {
        VStack(spacing: FrilaEspaco.medio) {
            ZStack {
                RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous)
                    .strokeBorder(FrilaCor.borda, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .frame(width: 96, height: 96)

                Image(systemName: "magnifyingglass")
                    .font(FrilaTipo.secao)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
            .accessibilityHidden(true)

            VStack(spacing: FrilaEspaco.pequeno) {
                let nomeFuncao = rotuloFuncao
                let periodoOuData = rotuloData
                Text("Nenhuma vaga de \(nomeFuncao) até \(5) km neste \(periodoOuData).", bundle: bundleApresentacao)
                    .font(FrilaTipo.tituloDeEstado)
                    .foregroundStyle(FrilaCor.texto)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            BotaoSecundario("Ver vagas à noite") {
                selecionar {
                    await $0.selecionar(data: .hoje)
                }
            }
            .padding(.top, FrilaEspaco.pequeno)
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
                    .foregroundStyle(FrilaCor.sobreAcao)
                    .background(FrilaCor.acao, in: RoundedRectangle(cornerRadius: FrilaRaio.interno, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: FrilaRaio.interno, style: .continuous))
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
    case todos, funcao, data, distancia
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

// MARK: - T2b Folha Geral de Filtros

private struct FolhaDeFiltrosT2b: View {
    @Bindable var viewModel: FeedVagasViewModel
    let fechar: () -> Void
    @State private var abrindoCatalogo = false
    @State private var raioKm: Double = 5
    @State private var periodoSelecionado: String? = "Noite"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Filtros", bundle: bundleApresentacao)
                            .font(FrilaTipo.tituloDaTela)
                            .foregroundStyle(FrilaCor.texto)
                            .accessibilityAddTraits(.isHeader)

                        Text("\(3) vagas com estes filtros.", bundle: bundleApresentacao)
                            .font(FrilaTipo.nota)
                            .foregroundStyle(FrilaCor.textoSecundario)
                    }

                    // Seção Funções
                    VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
                        HStack {
                            Text("Funções", bundle: bundleApresentacao)
                                .font(FrilaTipo.corpo.weight(.semibold))
                                .foregroundStyle(FrilaCor.texto)

                            Spacer()

                            Button {
                                abrindoCatalogo = true
                            } label: {
                                Text("Ver catálogo", bundle: bundleApresentacao)
                                    .font(FrilaTipo.nota.weight(.medium))
                                    .foregroundStyle(FrilaCor.texto)
                            }
                            .buttonStyle(.plain)
                        }

                        let funcoesDestaque = ["Bartender", "Garçom", "Cozinheiro", "Cumim"]
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: FrilaEspaco.pequeno) {
                                ForEach(funcoesDestaque, id: \.self) { nome in
                                    let marcada = viewModel.funcoes.first(where: { $0.id == viewModel.funcaoID })?.nome == nome
                                    Button {
                                        if marcada {
                                            Task { await viewModel.selecionar(funcao: nil) }
                                        } else if let f = viewModel.funcoes.first(where: { $0.nome == nome }) {
                                            Task { await viewModel.selecionar(funcao: f.id) }
                                        }
                                    } label: {
                                        Text(verbatim: nome)
                                            .font(marcada ? FrilaTipo.corpo.weight(.semibold) : FrilaTipo.corpo)
                                            .padding(.horizontal, FrilaEspaco.medio)
                                            .frame(height: 36)
                                            .foregroundStyle(FrilaCor.texto)
                                            .background(marcada ? FrilaCor.superficieDoCampo : FrilaCor.superficie, in: Capsule())
                                            .overlay(Capsule().strokeBorder(marcada ? FrilaCor.texto : FrilaCor.borda, lineWidth: marcada ? 1.5 : 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Seção Raio
                    VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
                        HStack {
                            Text("Raio", bundle: bundleApresentacao)
                                .font(FrilaTipo.corpo.weight(.semibold))
                                .foregroundStyle(FrilaCor.texto)
                            Spacer()
                            Text("Até \(Int(raioKm)) km", bundle: bundleApresentacao)
                                .font(FrilaTipo.nota)
                                .foregroundStyle(FrilaCor.textoSecundario)
                        }

                        Slider(value: $raioKm, in: 1...10, step: 1)
                            .tint(FrilaCor.texto)
                            .onChange(of: raioKm) { _, novo in
                                Task { await viewModel.selecionar(distancia: .ate(km: Int(novo))) }
                            }
                    }

                    // Seção Datas
                    VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
                        Text("Datas", bundle: bundleApresentacao)
                            .font(FrilaTipo.corpo.weight(.semibold))
                            .foregroundStyle(FrilaCor.texto)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: FrilaEspaco.pequeno) {
                                Button {
                                    Task { await viewModel.selecionar(data: .qualquer) }
                                } label: {
                                    Text("Qualquer data", bundle: bundleApresentacao)
                                        .font(viewModel.data == .qualquer ? FrilaTipo.corpo.weight(.semibold) : FrilaTipo.corpo)
                                        .padding(.horizontal, FrilaEspaco.medio)
                                        .frame(height: 36)
                                        .foregroundStyle(FrilaCor.texto)
                                        .background(viewModel.data == .qualquer ? FrilaCor.superficieDoCampo : FrilaCor.superficie, in: Capsule())
                                        .overlay(Capsule().strokeBorder(viewModel.data == .qualquer ? FrilaCor.texto : FrilaCor.borda, lineWidth: viewModel.data == .qualquer ? 1.5 : 1))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    Task { await viewModel.selecionar(data: .hoje) }
                                } label: {
                                    Text("Hoje", bundle: bundleApresentacao)
                                        .font(viewModel.data == .hoje ? FrilaTipo.corpo.weight(.semibold) : FrilaTipo.corpo)
                                        .padding(.horizontal, FrilaEspaco.medio)
                                        .frame(height: 36)
                                        .foregroundStyle(FrilaCor.texto)
                                        .background(viewModel.data == .hoje ? FrilaCor.superficieDoCampo : FrilaCor.superficie, in: Capsule())
                                        .overlay(Capsule().strokeBorder(viewModel.data == .hoje ? FrilaCor.texto : FrilaCor.borda, lineWidth: viewModel.data == .hoje ? 1.5 : 1))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    Task { await viewModel.selecionar(data: .amanha) }
                                } label: {
                                    Text("Amanhã", bundle: bundleApresentacao)
                                        .font(viewModel.data == .amanha ? FrilaTipo.corpo.weight(.semibold) : FrilaTipo.corpo)
                                        .padding(.horizontal, FrilaEspaco.medio)
                                        .frame(height: 36)
                                        .foregroundStyle(FrilaCor.texto)
                                        .background(viewModel.data == .amanha ? FrilaCor.superficieDoCampo : FrilaCor.superficie, in: Capsule())
                                        .overlay(Capsule().strokeBorder(viewModel.data == .amanha ? FrilaCor.texto : FrilaCor.borda, lineWidth: viewModel.data == .amanha ? 1.5 : 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Seção Períodos
                    VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
                        Text("Períodos", bundle: bundleApresentacao)
                            .font(FrilaTipo.corpo.weight(.semibold))
                            .foregroundStyle(FrilaCor.texto)

                        let periodos = ["Manhã", "Tarde", "Noite", "Madrugada"]
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: FrilaEspaco.pequeno) {
                                ForEach(periodos, id: \.self) { p in
                                    let ativo = periodoSelecionado == p
                                    Button {
                                        periodoSelecionado = ativo ? nil : p
                                    } label: {
                                        Text(verbatim: p)
                                            .font(ativo ? FrilaTipo.corpo.weight(.semibold) : FrilaTipo.corpo)
                                            .padding(.horizontal, FrilaEspaco.medio)
                                            .frame(height: 36)
                                            .foregroundStyle(FrilaCor.texto)
                                            .background(ativo ? FrilaCor.superficieDoCampo : FrilaCor.superficie, in: Capsule())
                                            .overlay(Capsule().strokeBorder(ativo ? FrilaCor.texto : FrilaCor.borda, lineWidth: ativo ? 1.5 : 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, FrilaEspaco.grande)
                .padding(.top, FrilaEspaco.medio)
                .padding(.bottom, FrilaEspaco.enorme)
            }
            .background(FrilaCor.fundo)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        fechar()
                    } label: {
                        Text("Concluir", bundle: bundleApresentacao)
                            .font(FrilaTipo.corpo.weight(.semibold))
                            .foregroundStyle(FrilaCor.texto)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("filtros-concluir")
                }
            }
            .sheet(isPresented: $abrindoCatalogo) {
                TelaEscolherFuncoes(
                    funcoes: viewModel.funcoes,
                    selecionadas: viewModel.funcaoID.map { [$0] } ?? [],
                    alternar: { id in
                        Task {
                            if viewModel.funcaoID == id {
                                await viewModel.selecionar(funcao: nil)
                            } else {
                                await viewModel.selecionar(funcao: id)
                            }
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Cartão da Vaga T2

private struct CartaoVagaT2: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let vaga: VagaNaLista
    let destaque: Bool
    let agora: Date
    let aoTocar: () -> Void
    private let formatador = FormatadorFrila()

    init(vaga: VagaNaLista, destaque: Bool = false, agora: Date = .now, aoTocar: @escaping () -> Void) {
        self.vaga = vaga
        self.destaque = destaque
        self.agora = agora
        self.aoTocar = aoTocar
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(verbatim: vaga.estabelecimento.nome)
                        .font(FrilaTipo.resumo)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: FrilaEspaco.minimo)

                    let modo = FormatoDataVaga.modoEfetivo(
                        modo: vaga.modo,
                        posicoesAbertas: vaga.posicoesAbertas,
                        inicio: vaga.periodo.inicio,
                        agora: agora
                    )
                    if modo == .urgencia {
                        SeloDeStatus("Urgente", estilo: .urgencia)
                    } else {
                        SeloDeStatus("Por seleção", estilo: .contorno)
                    }
                }

                let reputacao = vaga.estabelecimento.reputacao
                if reputacao.semHistorico {
                    Text("Ainda sem avaliações.", bundle: bundleApresentacao)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                } else {
                    let pct = Int((Double(reputacao.positivas) / Double(max(1, reputacao.total))) * 100)
                    Text(verbatim: String(format: String(localized: "%lld%% trabalhariam aqui de novo", bundle: bundleApresentacao), pct))
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }
            }

            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                linhaDado(icone: "briefcase") {
                    Text(verbatim: vaga.funcao.nome)
                }
                linhaDado(icone: "calendar") {
                    Text(verbatim: FormatoDataVaga.cartao(vaga.periodo, agora: agora))
                }
                linhaDado(icone: "mappin") {
                    HStack(spacing: 4) {
                        Text(verbatim: formatador.distancia(vaga.distanciaKm))
                        Text("do seu ponto base", bundle: bundleApresentacao)
                    }
                }
            }

            Rectangle()
                .fill(FrilaCor.borda)
                .frame(height: 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.minimo) {
                    Text(verbatim: formatador.dinheiro(vaga.valor))
                        .font(FrilaTipo.fonteValor(tamanho: 28))
                        .foregroundStyle(FrilaCor.texto)
                }

                inclusosView
            }

            if destaque {
                BotaoPrimario("Ver detalhes da vaga", acao: aoTocar)
            } else {
                BotaoSecundario("Ver detalhes da vaga", acao: aoTocar)
            }
        }
        .padding(.horizontal, FrilaEspaco.medio)
        .padding(.bottom, FrilaEspaco.medio)
        .padding(.top, destaque ? 32 : FrilaEspaco.medio)
        .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous)
                .strokeBorder(FrilaCor.borda, lineWidth: 1)
        )
        .modifier(ModificadorDestaque(ativo: destaque))
        .contentShape(Rectangle())
        .onTapGesture {
            aoTocar()
        }
    }

    @ViewBuilder
    private var inclusosView: some View {
        switch (vaga.inclusos.refeicao, vaga.inclusos.transporte) {
        case (true, true):
            Text("Incluso: jantar e transporte de volta", bundle: bundleApresentacao)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
        case (true, false):
            Text("Incluso: jantar", bundle: bundleApresentacao)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
        case (false, true):
            Text("Incluso: transporte de volta", bundle: bundleApresentacao)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
        case (false, false):
            EmptyView()
        }
    }

    private func linhaDado<Conteudo: View>(icone: String, @ViewBuilder conteudo: () -> Conteudo) -> some View {
        HStack(spacing: FrilaEspaco.pequeno) {
            Image(systemName: icone)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)

            conteudo()
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ModificadorDestaque: ViewModifier {
    let ativo: Bool

    func body(content: Content) -> some View {
        if ativo {
            content.elevacaoFrila(.suave)
        } else {
            content
        }
    }
}
