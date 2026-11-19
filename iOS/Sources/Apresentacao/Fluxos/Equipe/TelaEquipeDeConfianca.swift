import FrilaDominio
import SwiftUI

/// Equipe de confiança (#24): lista Hi-Fi com divisórias e remoção com confirmação.
public struct TelaEquipeDeConfianca: View {
    @State private var viewModel: EquipeDeConfiancaViewModel
    @State private var chamadaHabilitada = false
    private let api: (any ApiCliente)?
    @State private var aRemover: PerfilPublico?
    @Environment(BloqueiosDaSessao.self) private var bloqueiosDaSessao: BloqueiosDaSessao?
    @State private var bloqueiosLocais = BloqueiosDaSessao()
    private var bloqueios: BloqueiosDaSessao { bloqueiosDaSessao ?? bloqueiosLocais }

    public init(viewModel: EquipeDeConfiancaViewModel, api: (any ApiCliente)? = nil) {
        self.api = api
        _viewModel = State(initialValue: viewModel)
    }

    public init(api: any ApiCliente, estabelecimentoID: UUID, cache: CacheEquipeDeConfianca = .compartilhado) {
        self.init(viewModel: EquipeDeConfiancaViewModel(estabelecimentoID: estabelecimentoID, api: api, cache: cache), api: api)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                Text(verbatim: TextosEquipeDeConfianca.explicacao)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
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
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.top, FrilaEspaco.item)
            .padding(.bottom, FrilaEspaco.grupo)
        }
        .background(FrilaCor.fundo)
        // O título fica na barra (cromo nativo), pequeno: a lista começa logo abaixo.
        .navigationTitle(Text(verbatim: TextosEquipeDeConfianca.titulo))
        .navigationBarTitleDisplayMode(.inline)

        .task {
            if let api {
                chamadaHabilitada = (try? await PrazoDaAbertura.esperar(.seconds(15)) {
                    try await api.configuracaoDoApp()
                })?.recursos.chamadaDireta == true
            }
            await viewModel.carregar()
        }
        .refreshable { await viewModel.carregar() }
        // O `.task` acima já relê a cada aparição: aqui ficam a volta do segundo plano e o push.
        .atualizacaoAutomatica(.equipeDeConfianca, aoAparecer: .nunca, recarregar: viewModel.atualizarEmSilencio)
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
            VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                ForEach(membros) { perfil in
                    linha(perfil)
                }
            }
        }
    }

    /// Um membro da equipe num cartão: quem é, o que faz e a reputação escrita como fato (na voz de quem avalia);
    /// "Chamar de novo" é o botão secundário e "Remover" a ação discreta, no fim do cartão.
    private func linha(_ perfil: PerfilPublico) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
            VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
                Text(verbatim: perfil.nome)
                    .font(FrilaTipo.nome)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if !perfil.funcoes.isEmpty {
                    Text(verbatim: perfil.funcoes.joined(separator: ", "))
                        .font(FrilaTipo.apoio)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(verbatim: SeloReputacao.descricao(perfil.reputacao))
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                if chamadaHabilitada, let api, !bloqueios.contem(perfil) {
                    BotaoChamarDeNovo(api: api, profissionalID: perfil.id, estabelecimentoID: viewModel.estabelecimentoID)
                }
                Button { aRemover = perfil } label: { Text(verbatim: TextosEquipeDeConfianca.remover) }
                    .buttonStyle(.frilaAcaoDiscreta)
                    .disabled(viewModel.removendo != nil)
                    .accessibilityLabel(Text(verbatim: "\(TextosEquipeDeConfianca.remover) \(perfil.nome)"))
                    .accessibilityIdentifier("remover-da-equipe-\(perfil.id)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("membro-da-equipe-\(perfil.id)")
    }
}

/// "Incluir na equipe" ao lado das ações sobre um profissional que cumpriu turno na casa (#24). Quem
/// usa só mostra o botão quando a presença do turno foi verificada; a regra vale no servidor.
struct BotaoIncluirNaEquipe: View {
    let perfil: PerfilPublico
    @State private var model: IncluirNaEquipeViewModel
    private let identificador: String
    @Environment(BloqueiosDaSessao.self) private var bloqueiosDaSessao: BloqueiosDaSessao?
    @State private var bloqueiosLocais = BloqueiosDaSessao()
    private var bloqueios: BloqueiosDaSessao { bloqueiosDaSessao ?? bloqueiosLocais }

    init(
        perfil: PerfilPublico,
        estabelecimentoID: UUID,
        api: any ApiCliente,
        cache: CacheEquipeDeConfianca = .compartilhado,
        identificador: String = "incluir-na-equipe"
    ) {
        self.perfil = perfil
        let membro = MembroDaEquipe(estabelecimentoID: estabelecimentoID, profissionalID: perfil.id)
        _model = State(initialValue: IncluirNaEquipeViewModel(membro: membro, api: api, cache: cache))
        self.identificador = identificador
    }

    var body: some View {
        if !bloqueios.contem(perfil) {
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                if model.situacao == .naEquipe {
                    // Selo informa, não se toca: contorno, sem verde.
                    SeloDeStatus(verbatim: TextosEquipeDeConfianca.naEquipe, estilo: .contorno, icone: "checkmark")
                        .accessibilityIdentifier("na-equipe-\(identificador)")
                } else {
                    // O erro da ação fica logo acima do botão que a disparou.
                    if let erro = model.mensagemErro {
                        MensagemJuntoAoBotao(verbatim: erro)
                            .accessibilityIdentifier("erro-\(identificador)")
                    }
                    BotaoSecundario(verbatim: TextosEquipeDeConfianca.incluir) { Task { await model.incluir() } }
                        .disabled(model.incluindo)
                        .accessibilityIdentifier(identificador)
                }
            }
            .task { await model.carregar() }
        }
    }
}
