// BAIXA FIDELIDADE DESCARTÁVEL: não é design final. Segue o protótipo low-fi "Vagas no DF" e
// substitui por ora a alta fidelidade do profissional (#15) e os padrões de estado (#172).

import FrilaDominio
import SwiftUI

/// Lista de vagas abertas do DF (#104). Tocar num cartão empilha o detalhe.
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
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                AvisoDePermissaoDePush(perfil: .profissional)
                filtros
                conteudo
            }
            .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosDoProfissional.Lista.titulo))
        .refreshable { await medirAbertura(.listaDeVagas, carregar: viewModel.atualizar, pronto: listaNaTela) }
        .task { if viewModel.estado == .ociosa { await medirAbertura(.listaDeVagas, carregar: viewModel.carregar, pronto: listaNaTela) } }
        .accessibilityIdentifier("tela-vagas")
        // Nos tamanhos de acessibilidade o aviso de sem conexão empurrava o Tentar novamente para baixo
        // da barra de abas flutuante: o botão fica preso ao rodapé, acima dela, e o aviso rola. Fica
        // depois do identificador da tela, que senão passaria para o botão.
        .safeAreaInset(edge: .bottom) {
            if dynamicTypeSize.isAccessibilitySize, viewModel.estado == .falha(.semConexao) {
                tentarDeNovo
                    .padding(FrilaEspaco.medio)
                    .background(FrilaCor.fundo)
            }
        }
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
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FrilaEspaco.pequeno) {
                        filtroFuncao
                        filtroData
                        filtroDistancia
                    }
                }
            }
        }
    }

    private var filtroFuncao: some View {
        Menu {
            Button { selecionar { await $0.selecionar(funcao: nil) } } label: { Text(verbatim: TextosDoProfissional.Lista.qualquerFuncao) }
            ForEach(viewModel.funcoes) { funcao in
                Button { selecionar { await $0.selecionar(funcao: funcao.id) } } label: { Text(verbatim: funcao.nome) }
            }
        } label: {
            PilulaDeFiltro(titulo: nomeDaFuncao, ativo: viewModel.funcaoID != nil)
        }
        .accessibilityIdentifier("filtro-funcao")
    }

    private var filtroData: some View {
        Menu {
            ForEach(FiltroDeData.allCases, id: \.self) { opcao in
                Button { selecionar { await $0.selecionar(data: opcao) } } label: { Text(verbatim: Self.titulo(opcao)) }
            }
        } label: {
            PilulaDeFiltro(titulo: Self.titulo(viewModel.data), ativo: viewModel.data != .qualquer)
        }
        .accessibilityIdentifier("filtro-data")
    }

    private var filtroDistancia: some View {
        Menu {
            ForEach(FiltroDeDistancia.opcoes, id: \.self) { opcao in
                Button { selecionar { await $0.selecionar(distancia: opcao) } } label: { Text(verbatim: Self.titulo(opcao)) }
            }
        } label: {
            PilulaDeFiltro(titulo: Self.titulo(viewModel.distancia), ativo: viewModel.distancia != .qualquer)
        }
        .accessibilityIdentifier("filtro-distancia")
    }

    @ViewBuilder
    private var conteudo: some View {
        switch viewModel.estado {
        case .ociosa, .carregando:
            EstadoCarregando()
        case let .carregada(vagas) where vagas.isEmpty:
            EstadoVazio(verbatim: TextosDoProfissional.Lista.vazioTitulo,
                        mensagem: TextosDoProfissional.Lista.vazioMensagem)
                .accessibilityIdentifier("vagas-vazio")
        case let .carregada(vagas):
            LazyVStack(spacing: FrilaEspaco.medio) {
                ForEach(vagas) { vaga in
                    Button { abrir(vaga.id) } label: { CartaoVaga(vaga) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("vaga-\(vaga.id.uuidString)")
                        .accessibilityHint(Text("Abre o detalhe da vaga", bundle: bundleApresentacao))
                        .task { if vaga.id == vagas.last?.id { await viewModel.carregarMais() } }
                }
            }
        case .falha(.semConexao):
            VStack(spacing: FrilaEspaco.medio) {
                AvisoFrila(verbatim: TextosDoProfissional.Lista.semConexaoMensagem, tom: .alerta)
                if !dynamicTypeSize.isAccessibilitySize { tentarDeNovo }
            }
            .accessibilityIdentifier("vagas-sem-conexao")
        case .falha(.semPontoDeReferencia):
            EstadoErro(verbatim: TextosDoProfissional.Lista.semPontoDeReferencia) { Task { await viewModel.carregar() } }
                .accessibilityIdentifier("vagas-sem-referencia")
        case .falha(.perfilIncompativel):
            AvisoFrila(verbatim: TextosDoProfissional.Lista.perfilIncompativel, tom: .alerta)
                .accessibilityIdentifier("vagas-perfil-incompativel")
        case .falha(.erro):
            EstadoErro(verbatim: TextosDoProfissional.Lista.erroMensagem) { Task { await viewModel.carregar() } }
                .accessibilityIdentifier("vagas-erro")
        }
    }

    private var tentarDeNovo: some View {
        BotaoSecundario("Tentar novamente") { Task { await viewModel.carregar() } }
            .accessibilityIdentifier("vagas-tentar-de-novo")
    }

    private var nomeDaFuncao: String {
        viewModel.funcoes.first { $0.id == viewModel.funcaoID }?.nome ?? TextosDoProfissional.Lista.qualquerFuncao
    }

    private func selecionar(_ acao: @escaping @MainActor (FeedVagasViewModel) async -> Void) {
        let viewModel = viewModel
        Task { await acao(viewModel) }
    }

    static func titulo(_ data: FiltroDeData) -> String {
        switch data {
        case .qualquer: TextosDoProfissional.Lista.qualquerData
        case .hoje: TextosDoProfissional.Lista.hoje
        case .amanha: TextosDoProfissional.Lista.amanha
        }
    }

    static func titulo(_ distancia: FiltroDeDistancia) -> String {
        switch distancia {
        case .qualquer: TextosDoProfissional.Lista.qualquerDistancia
        case let .ate(km): TextosDoProfissional.Lista.ateKm(km)
        }
    }
}

/// Pílula de filtro que abre um menu. O estado ativo não depende só de cor: ganha um ícone.
private struct PilulaDeFiltro: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let titulo: String
    let ativo: Bool

    var body: some View {
        HStack(spacing: FrilaEspaco.minimo) {
            if ativo { Image(systemName: "checkmark").accessibilityHidden(true) }
            Text(verbatim: titulo)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            Image(systemName: "chevron.down").font(.caption).accessibilityHidden(true)
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, FrilaEspaco.medio)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? FrilaEspaco.pequeno : 0)
        .frame(minHeight: FrilaMetrica.alvoMinimo)
        .background(ativo ? FrilaCor.primaria.opacity(0.12) : FrilaCor.superficie, in: Capsule())
        .overlay(Capsule().stroke(ativo ? FrilaCor.primaria : FrilaCor.textoSecundario, lineWidth: 1))
        .foregroundStyle(FrilaCor.texto)
        .accessibilityElement(children: .combine)
        .accessibilityValue(ativo ? String(localized: "filtro ativo", bundle: bundleApresentacao) : "")
    }
}
