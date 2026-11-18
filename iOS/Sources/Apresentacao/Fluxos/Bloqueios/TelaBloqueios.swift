import FrilaDominio
import SwiftUI

/// Tela "Pessoas e locais bloqueados" (decisão A8 da PO, RF26, contrato v0.2.51).
/// Lista quem o usuário bloqueou e permite desfazer o bloqueio com confirmação.
/// Desenho do sistema do Fabrício (extrapolado: a tela não está no protótipo): tela de leitura, sem laranja; a lista
/// num grupo de linhas e "Desbloquear" em link, porque desfazer o bloqueio leva a uma confirmação nativa.
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
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                Text(verbatim: TextosBloqueios.explicacao)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
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
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.vertical, FrilaEspaco.bloco)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        FrilaGrupoDeLinhas(linhasComIcone: false) {
            ForEach(itens) { item in
                linha(item)
            }
        }
    }

    private func linha(_ item: ItemBloqueio) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
            Text(verbatim: item.nome)
                .font(FrilaTipo.nome)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(verbatim: item.alvo.tipo == .estabelecimento ? TextosBloqueios.tipoEstabelecimento : TextosBloqueios.tipoProfissional)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)

            // Link: abre a confirmação nativa que explica o que volta a acontecer. Enquanto um desbloqueio roda, os
            // outros ficam desligados, sem indicador girando.
            Button { itemADesbloquear = item } label: { Text(verbatim: TextosBloqueios.desbloquear) }
                .buttonStyle(.frilaLink)
                .disabled(viewModel.desbloqueandoID != nil)
                .accessibilityLabel(Text(verbatim: "\(TextosBloqueios.desbloquear) \(item.nome)"))
                .accessibilityIdentifier("desbloquear-\(item.id)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, FrilaMedidaDeLinha.margem)
        .padding(.vertical, FrilaEspaco.item)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("item-bloqueio-\(item.id)")
    }
}
