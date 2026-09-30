// BAIXA FIDELIDADE DESCARTÁVEL: não é design final. Segue o protótipo low-fi "Vagas no DF" e
// substitui por ora a alta fidelidade do profissional (#15) e os padrões de estado (#172).

import FrilaDominio
import SwiftUI

/// Lista de vagas abertas do DF (#104). Tocar num cartão empilha o detalhe.
public struct TelaVagas: View {
    @Bindable private var viewModel: FeedVagasViewModel
    private let abrir: (UUID) -> Void

    public init(viewModel: FeedVagasViewModel, abrir: @escaping (UUID) -> Void) {
        self.viewModel = viewModel
        self.abrir = abrir
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                filtros
                conteudo
            }
            .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(TextosDoProfissional.Lista.titulo)
        .refreshable { await viewModel.atualizar() }
        .task { if viewModel.estado == .ociosa { await viewModel.carregar() } }
        .accessibilityIdentifier("tela-vagas")
    }

    private var filtros: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FrilaEspaco.pequeno) {
                Menu {
                    Button(TextosDoProfissional.Lista.qualquerFuncao) { selecionar { await $0.selecionar(funcao: nil) } }
                    ForEach(viewModel.funcoes) { funcao in
                        Button(funcao.nome) { selecionar { await $0.selecionar(funcao: funcao.id) } }
                    }
                } label: {
                    PilulaDeFiltro(titulo: nomeDaFuncao, ativo: viewModel.funcaoID != nil)
                }
                .accessibilityIdentifier("filtro-funcao")

                Menu {
                    ForEach(FiltroDeData.allCases, id: \.self) { opcao in
                        Button(Self.titulo(opcao)) { selecionar { await $0.selecionar(data: opcao) } }
                    }
                } label: {
                    PilulaDeFiltro(titulo: Self.titulo(viewModel.data), ativo: viewModel.data != .qualquer)
                }
                .accessibilityIdentifier("filtro-data")

                Menu {
                    ForEach(FiltroDeDistancia.opcoes, id: \.self) { opcao in
                        Button(Self.titulo(opcao)) { selecionar { await $0.selecionar(distancia: opcao) } }
                    }
                } label: {
                    PilulaDeFiltro(titulo: Self.titulo(viewModel.distancia), ativo: viewModel.distancia != .qualquer)
                }
                .accessibilityIdentifier("filtro-distancia")
            }
        }
    }

    @ViewBuilder
    private var conteudo: some View {
        switch viewModel.estado {
        case .ociosa, .carregando:
            EstadoCarregando()
        case let .carregada(vagas) where vagas.isEmpty:
            EstadoVazio(LocalizedStringKey(TextosDoProfissional.Lista.vazioTitulo),
                        mensagem: LocalizedStringKey(TextosDoProfissional.Lista.vazioMensagem))
                .accessibilityIdentifier("vagas-vazio")
        case let .carregada(vagas):
            LazyVStack(spacing: FrilaEspaco.medio) {
                ForEach(vagas) { vaga in
                    Button { abrir(vaga.id) } label: { CartaoVaga(vaga) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("vaga-\(vaga.id.uuidString)")
                        .accessibilityHint("Abre o detalhe da vaga")
                        .task { if vaga.id == vagas.last?.id { await viewModel.carregarMais() } }
                }
            }
        case .falha(.semConexao):
            VStack(spacing: FrilaEspaco.medio) {
                AvisoFrila(LocalizedStringKey(TextosDoProfissional.Lista.semConexaoMensagem), tom: .alerta)
                BotaoSecundario("Tentar novamente") { Task { await viewModel.carregar() } }
            }
            .accessibilityIdentifier("vagas-sem-conexao")
        case .falha(.semPontoDeReferencia):
            EstadoErro(LocalizedStringKey(TextosDoProfissional.Lista.semPontoDeReferencia)) { Task { await viewModel.carregar() } }
                .accessibilityIdentifier("vagas-sem-referencia")
        case .falha(.perfilIncompativel):
            AvisoFrila(LocalizedStringKey(TextosDoProfissional.Lista.perfilIncompativel), tom: .alerta)
                .accessibilityIdentifier("vagas-perfil-incompativel")
        case .falha(.erro):
            EstadoErro(LocalizedStringKey(TextosDoProfissional.Lista.erroMensagem)) { Task { await viewModel.carregar() } }
                .accessibilityIdentifier("vagas-erro")
        }
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
    let titulo: String
    let ativo: Bool

    var body: some View {
        HStack(spacing: FrilaEspaco.minimo) {
            if ativo { Image(systemName: "checkmark").accessibilityHidden(true) }
            Text(titulo)
            Image(systemName: "chevron.down").font(.caption).accessibilityHidden(true)
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, FrilaEspaco.medio)
        .frame(minHeight: FrilaMetrica.alvoMinimo)
        .background(ativo ? FrilaCor.primaria.opacity(0.12) : FrilaCor.superficie, in: Capsule())
        .overlay(Capsule().stroke(ativo ? FrilaCor.primaria : FrilaCor.textoSecundario, lineWidth: 1))
        .foregroundStyle(FrilaCor.texto)
        .accessibilityElement(children: .combine)
        .accessibilityValue(ativo ? String(localized: "filtro ativo") : "")
    }
}
