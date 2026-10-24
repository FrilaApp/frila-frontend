import FrilaDominio
import SwiftUI

/// Equipe de confiança (#24): lista Hi-Fi com divisórias e remoção com confirmação.
public struct TelaEquipeDeConfianca: View {
    @State private var viewModel: EquipeDeConfiancaViewModel
    @State private var aRemover: PerfilPublico?

    public init(viewModel: EquipeDeConfiancaViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public init(api: any ApiCliente, estabelecimentoID: UUID, cache: CacheEquipeDeConfianca = .compartilhado) {
        self.init(viewModel: EquipeDeConfiancaViewModel(estabelecimentoID: estabelecimentoID, api: api, cache: cache))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                Text(verbatim: TextosEquipeDeConfianca.explicacao)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("equipe-explicacao")

                if let aviso = viewModel.aviso {
                    AvisoFrila(verbatim: aviso, tom: .informativo)
                        .accessibilityIdentifier("aviso-equipe")
                }
                if let erro = viewModel.mensagemErro {
                    AvisoFrila(verbatim: erro, tom: .erro)
                        .accessibilityIdentifier("erro-equipe")
                }

                conteudo
            }
            .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosEquipeDeConfianca.titulo))
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)

        .task { await viewModel.carregar() }
        .refreshable { await viewModel.carregar() }
        .accessibilityIdentifier("tela-equipe-de-confianca")
        .alert(
            Text(verbatim: TextosEquipeDeConfianca.confirmarRemocao),
            isPresented: Binding(get: { aRemover != nil }, set: { if !$0 { aRemover = nil } }),
            presenting: aRemover
        ) { perfil in
            Button(role: .cancel) { aRemover = nil } label: { Text(verbatim: TextosEquipeDeConfianca.cancelar) }
            Button(role: .destructive) { Task { await viewModel.remover(perfil) } } label: { Text(verbatim: TextosEquipeDeConfianca.remover) }
                .accessibilityIdentifier("confirmar-remocao")
        } message: { perfil in
            Text(verbatim: TextosEquipeDeConfianca.efeitoRemocao(perfil.nome))
        }
    }

    @ViewBuilder
    private var conteudo: some View {
        switch viewModel.estado {
        case .carregando:
            EstadoCarregando()
        case .vazio:
            EstadoVazio(verbatim: TextosEquipeDeConfianca.vazioTitulo, mensagem: TextosEquipeDeConfianca.vazioMensagem)
                .accessibilityIdentifier("equipe-vazia")
        case .semRede:
            EstadoErro(verbatim: TextosEquipeDeConfianca.semRede) { Task { await viewModel.carregar() } }
                .accessibilityIdentifier("equipe-sem-rede")
        case .erro:
            EstadoErro(verbatim: TextosEquipeDeConfianca.erroCarregar) { Task { await viewModel.carregar() } }
                .accessibilityIdentifier("equipe-erro")
        case let .conteudo(membros):
            VStack(spacing: 0) {
                ForEach(membros) { perfil in
                    linha(perfil)
                    Divider().overlay(FrilaCor.divisoria)
                }
            }
        }
    }

    private func linha(_ perfil: PerfilPublico) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: perfil.nome)
                .font(FrilaTipo.tituloDoCartao.weight(.bold))
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)
            if !perfil.funcoes.isEmpty {
                Text(verbatim: perfil.funcoes.joined(separator: ", "))
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
            SeloReputacao(perfil.reputacao)
            BotaoSecundario(verbatim: TextosEquipeDeConfianca.remover) { aRemover = perfil }
                .disabled(viewModel.removendo != nil)
                .accessibilityLabel(Text(verbatim: "\(TextosEquipeDeConfianca.remover) \(perfil.nome)"))
                .accessibilityIdentifier("remover-da-equipe-\(perfil.id)")
            if viewModel.removendo == perfil.id { ProgressView() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, FrilaEspaco.medio)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("membro-da-equipe-\(perfil.id)")
    }
}

/// "Incluir na equipe" ao lado das ações sobre um profissional que cumpriu turno na casa (#24). Quem
/// usa só mostra o botão quando a presença do turno foi verificada; a regra vale no servidor.
struct BotaoIncluirNaEquipe: View {
    @State private var model: IncluirNaEquipeViewModel
    private let identificador: String

    init(
        perfil: PerfilPublico,
        estabelecimentoID: UUID,
        api: any ApiCliente,
        cache: CacheEquipeDeConfianca = .compartilhado,
        identificador: String = "incluir-na-equipe"
    ) {
        let membro = MembroDaEquipe(estabelecimentoID: estabelecimentoID, profissionalID: perfil.id)
        _model = State(initialValue: IncluirNaEquipeViewModel(membro: membro, api: api, cache: cache))
        self.identificador = identificador
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            if model.situacao == .naEquipe {
                Label {
                    Text(verbatim: TextosEquipeDeConfianca.naEquipe)
                } icon: {
                    Image(systemName: "checkmark.seal")
                }
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.sucesso)
                .padding(.horizontal, FrilaEspaco.compacto)
                .padding(.vertical, FrilaEspaco.pequeno)
                .background(FrilaCor.sucesso.opacity(0.1), in: Capsule())
                .overlay(Capsule().strokeBorder(FrilaCor.sucesso.opacity(0.3), lineWidth: 1))
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .accessibilityIdentifier("na-equipe-\(identificador)")
            } else {
                Button { Task { await model.incluir() } } label: {
                    Label {
                        Text(verbatim: TextosEquipeDeConfianca.incluir)
                    } icon: {
                        Image(systemName: "person.badge.plus")
                    }
                    .font(FrilaTipo.botaoPadrao)
                    .foregroundStyle(FrilaCor.texto)
                    .padding(.horizontal, FrilaEspaco.medio)
                    .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
                    .overlay(Capsule().strokeBorder(FrilaCor.borda, lineWidth: 1))
                    .contentShape(Capsule())
                }
                .buttonStyle(.tatil)
                .disabled(model.incluindo)
                .accessibilityIdentifier(identificador)
                if model.incluindo { ProgressView() }
            }
            if let erro = model.mensagemErro {
                AvisoFrila(verbatim: erro, tom: .erro)
                    .accessibilityIdentifier("erro-\(identificador)")
            }
        }
        .task { await model.carregar() }
    }
}
