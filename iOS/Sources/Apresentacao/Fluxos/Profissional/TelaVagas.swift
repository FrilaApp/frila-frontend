import FrilaDominio
import SwiftUI

/// Lista de vagas abertas do DF (#104), no quadro "Vagas" do MidFi do Fabrício. Tocar num cartão empilha o detalhe.
public struct TelaVagas: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable private var viewModel: FeedVagasViewModel
    private let abrir: (UUID) -> Void

    public init(viewModel: FeedVagasViewModel, abrir: @escaping (UUID) -> Void) {
        self.viewModel = viewModel
        self.abrir = abrir
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
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
        .accessibilityIdentifier("tela-vagas")
        .modifier(BarraInferiorDeAcessibilidade(
            ativo: dynamicTypeSize.isAccessibilitySize && viewModel.estado == .falha(.semConexao),
            rodape: {
                tentarDeNovo
                    .padding(FrilaEspaco.medio)
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
                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    filtroFuncao
                    filtroData
                    filtroDistancia
                }
                .padding(.horizontal, FrilaEspaco.medio)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FrilaEspaco.pequeno) {
                        filtroFuncao
                        filtroData
                        filtroDistancia
                    }
                    .padding(.horizontal, FrilaEspaco.medio)
                }
            }
        }
    }

    private var filtroFuncao: some View {
        Menu {
            Button { selecionar { await $0.selecionar(funcao: nil) } } label: {
                Text(verbatim: TextosDoProfissional.Lista.qualquerFuncao)
            }
            ForEach(viewModel.funcoes) { funcao in
                Button { selecionar { await $0.selecionar(funcao: funcao.id) } } label: {
                    Text(verbatim: funcao.nome)
                }
            }
        } label: {
            PilulaDeFiltro(titulo: rotuloFuncao, ativo: viewModel.funcaoID != nil)
        }
        .accessibilityIdentifier("filtro-funcao")
    }

    private var filtroData: some View {
        Menu {
            ForEach(FiltroDeData.allCases, id: \.self) { opcao in
                Button { selecionar { await $0.selecionar(data: opcao) } } label: {
                    Text(verbatim: Self.tituloMenu(opcao))
                }
            }
        } label: {
            PilulaDeFiltro(titulo: rotuloData, ativo: viewModel.data != .qualquer)
        }
        .accessibilityIdentifier("filtro-data")
    }

    private var filtroDistancia: some View {
        Menu {
            ForEach(FiltroDeDistancia.opcoes, id: \.self) { opcao in
                Button { selecionar { await $0.selecionar(distancia: opcao) } } label: {
                    Text(verbatim: Self.tituloMenu(opcao))
                }
            }
        } label: {
            PilulaDeFiltro(titulo: rotuloDistancia, ativo: viewModel.distancia != .qualquer)
        }
        .accessibilityIdentifier("filtro-distancia")
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

/// Chip de filtro do MidFi que abre um menu: ativo escuro com texto claro, inativo claro com fio.
/// O estado ativo não depende só de cor: ganha um ícone. Altura visual 36 pt num alvo de 44 pt.
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
        .foregroundStyle(ativo ? FrilaCor.sobrePrimaria : FrilaCor.texto)
        .background(ativo ? FrilaCor.primaria : FrilaCor.superficie, in: Capsule())
        .overlay(Capsule().strokeBorder(ativo ? Color.clear : FrilaCor.borda, lineWidth: 1))
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
