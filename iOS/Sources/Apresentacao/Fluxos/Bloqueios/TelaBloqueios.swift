import FrilaDominio
import SwiftUI

/// Tela "Pessoas e locais bloqueados" (decisão A8 da PO, RF26, contrato v0.2.51).
/// Lista quem o usuário bloqueou e permite desfazer o bloqueio com confirmação.
public struct TelaBloqueios: View {
    @State private var viewModel: BloqueiosViewModel
    @State private var itemADesbloquear: ItemBloqueio?

    public init(viewModel: BloqueiosViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public init(api: any ApiCliente, bloqueiosDaSessao: BloqueiosDaSessao? = nil) {
        self.init(viewModel: BloqueiosViewModel(api: api, bloqueiosDaSessao: bloqueiosDaSessao))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                Text(verbatim: TextosBloqueios.explicacao)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("bloqueios-explicacao")

                if let aviso = viewModel.aviso {
                    AvisoFrila(verbatim: aviso, tom: .alerta)
                        .accessibilityIdentifier("aviso-bloqueios")
                }
                if let erro = viewModel.mensagemErro {
                    AvisoFrila(verbatim: erro, tom: .erro)
                        .accessibilityIdentifier("erro-bloqueios")
                }

                conteudo
            }
            .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosBloqueios.titulo))
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await viewModel.carregar() }
        .refreshable { await viewModel.carregar() }
        .accessibilityIdentifier("tela-bloqueios")
        .alert(
            Text(verbatim: TextosBloqueios.confirmarDesbloqueio),
            isPresented: Binding(get: { itemADesbloquear != nil }, set: { if !$0 { itemADesbloquear = nil } }),
            presenting: itemADesbloquear
        ) { item in
            Button(role: .cancel) { itemADesbloquear = nil } label: {
                Text(verbatim: TextosBloqueios.cancelar)
            }
            Button {
                Task { await viewModel.desbloquear(item) }
            } label: {
                Text(verbatim: TextosBloqueios.desbloquear)
            }
            .accessibilityIdentifier("confirmar-desbloqueio")
        } message: { item in
            Text(verbatim: TextosBloqueios.efeitoDesbloqueio(item.nome))
        }
    }

    @ViewBuilder
    private var conteudo: some View {
        switch viewModel.estado {
        case .carregando:
            EstadoCarregando()
        case .vazio:
            EstadoVazio(verbatim: TextosBloqueios.vazioTitulo, mensagem: TextosBloqueios.vazioMensagem)
                .accessibilityIdentifier("bloqueios-vazio")
        case let .erro(mensagem):
            EstadoErro(verbatim: mensagem) { Task { await viewModel.carregar() } }
                .accessibilityIdentifier("bloqueios-erro")
        case let .offline(itens):
            lista(itens)
        case let .conteudo(itens):
            lista(itens)
        }
    }

    private func lista(_ itens: [ItemBloqueio]) -> some View {
        VStack(spacing: 0) {
            ForEach(itens) { item in
                linha(item)
                Divider().overlay(FrilaCor.divisoria)
            }
        }
    }

    private func linha(_ item: ItemBloqueio) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: item.nome)
                .font(FrilaTipo.tituloDoCartao.weight(.bold))
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)

            Text(verbatim: item.alvo.tipo == .estabelecimento ? TextosBloqueios.tipoEstabelecimento : TextosBloqueios.tipoProfissional)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)

            BotaoSecundario(verbatim: TextosBloqueios.desbloquear) {
                itemADesbloquear = item
            }
            .disabled(viewModel.desbloqueandoID != nil)
            .accessibilityLabel(Text(verbatim: "\(TextosBloqueios.desbloquear) \(item.nome)"))
            .accessibilityIdentifier("desbloquear-\(item.id)")

            if viewModel.desbloqueandoID == item.id {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, FrilaEspaco.medio)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("item-bloqueio-\(item.id)")
    }
}
