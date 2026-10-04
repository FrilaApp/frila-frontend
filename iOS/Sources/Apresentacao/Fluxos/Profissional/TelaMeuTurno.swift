import FrilaDominio
import SwiftUI
#if DEBUG
import Observation
#endif

public struct TelaMeuTurno: View {
    @Bindable private var viewModel: MeuTurnoViewModel
    @State private var cancelamento: CancelamentoViewModel?
    @State private var suporteModel: SuporteTurnoViewModel?
    @Environment(BloqueiosDaSessao.self) private var bloqueiosDaSessao: BloqueiosDaSessao?
    @State private var bloqueiosLocais = BloqueiosDaSessao()
    private var bloqueios: BloqueiosDaSessao { bloqueiosDaSessao ?? bloqueiosLocais }
    private let formatador = FormatadorFrila()

    public init(viewModel: MeuTurnoViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                cabecalho
                cartaoTurno
                ForEach(viewModel.recusasDaFila) { recusa in
                    AvisoFrila(verbatim: TextosDaFila.texto(recusa.tipo), tom: .informativo)
                        .accessibilityIdentifier("aviso-acao-recusada-\(recusa.tipo.rawValue)")
                }
                if let desfecho = viewModel.desfechoDoCancelamento {
                    AvisoFrila(verbatim: TextosDoCancelamento.desfecho(.posicao(desfecho), lado: .profissional), tom: .informativo)
                        .accessibilityIdentifier("desfecho-do-cancelamento-no-turno")
                }
                if viewModel.cancelamentoNaFila {
                    AvisoFrila(verbatim: TextosDoCancelamento.naFila, tom: .alerta)
                        .accessibilityIdentifier("cancelamento-na-fila")
                }
                if viewModel.cancelamento != nil {
                    cartaoCancelamento
                }
                if viewModel.permiteAcoesDoTurno {
                    if let presenca = viewModel.presenca {
                        SecaoDePresenca(viewModel: presenca)
                    }
                    cartaoContato
                }
                if viewModel.podeAvaliar {
                    cartaoAvaliacao
                }
                if viewModel.podeCancelar {
                    botaoCancelar
                }
                rodapeAcoes
            }
            .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosDoProfissional.Turnos.tituloMeuTurno))
        .navigationBarTitleDisplayMode(.inline)
        .task { await medirAbertura(.meuTurno, carregar: viewModel.carregar, pronto: contatoNaTela) }
        .onReceive(NotificationCenter.default.publisher(for: .filaDeAcoesAtualizada)) { _ in
            Task { await viewModel.carregarRecusasDaFila() }
        }
        .sheet(item: $cancelamento) { folha in
            FolhaDeCancelamento(viewModel: folha) { cancelamento = nil }
        }
        .sheet(item: $suporteModel) { model in
            FolhaSuporteTurno(viewModel: model)
        }
        .accessibilityIdentifier("tela-meu-turno")
    }

    /// Fim da medição de abertura (#73): a carga da API encerrada (contato e responsável local), com
    /// o contato na tela.
    private var contatoNaTela: @MainActor @Sendable () -> Bool {
        let viewModel = viewModel
        return { !viewModel.carregandoContato && viewModel.contato != nil }
    }

    // MARK: - Ações de suporte e segurança (#21, #39)

    private var rodapeAcoes: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            botaoSuporte
            rodapeSeguranca
        }
    }

    private var botaoSuporte: some View {
        Button {
            suporteModel = SuporteTurnoViewModel(
                dados: ContextoSuporteTurno(turno: viewModel.turno)
            )
        } label: {
            Text(verbatim: TextosDoSuporte.botaoAjudaTurno)
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("botao-ajuda-turno")
        .accessibilityHint(Text(verbatim: TextosDoSuporte.dicaAjudaTurno))
    }

    private var rodapeSeguranca: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            if bloqueios.contem(viewModel.turno.contraparte) {
                Text(verbatim: TextosDaSeguranca.voceBloqueouEstabelecimento)
                    .font(.caption)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityIdentifier("etiqueta-bloqueio-turno")
            }
            AcoesDeSeguranca(
                perfil: viewModel.turno.contraparte,
                turnoID: viewModel.turno.id,
                api: viewModel.api,
                bloqueios: bloqueios
            )
            .id(viewModel.turno.contraparte.id)
        }
    }

    private var botaoCancelar: some View {
        BotaoDeCancelamento(titulo: TextosDoCancelamento.tituloTurno) {
            cancelamento = viewModel.criarCancelamentoViewModel()
        }
        .accessibilityIdentifier("cancelar-turno")
    }

    private var cabecalho: some View {
        Text(verbatim: viewModel.cancelado ? TextosDoProfissional.Turnos.canceladoTitulo : TextosDoProfissional.Turnos.confirmadoTitulo)
            .font(.title2.bold())
            .accessibilityIdentifier("estado-do-turno")
            .accessibilityAddTraits(.isHeader)
    }

    private var cartaoTurno: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(verbatim: "\(viewModel.turno.vaga.funcao) · \(viewModel.turno.contraparte.nome)")
                .font(.headline)
            Text(verbatim: "\(formatador.intervalo(viewModel.turno.vaga.periodo)) · \(formatador.dinheiro(viewModel.turno.valorAcordado))")
                .font(.subheadline)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: FrilaEspaco.minimo) {
                    enderecoEMapa
                    quemRecebe
                }
                .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                    enderecoEMapa
                    quemRecebe
                }
            }
            .font(.subheadline)
            .foregroundStyle(FrilaCor.textoSecundario)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .contain)
    }

    private var enderecoEMapa: some View {
        HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.minimo) {
            Text(verbatim: viewModel.turno.vaga.local)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("endereco-do-turno")
            if let urlMapas = viewModel.urlMapas {
                Link(destination: urlMapas) {
                    Image(systemName: "map")
                        .foregroundStyle(FrilaCor.primaria)
                        .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("atalho-mapas")
                .accessibilityLabel(Text(verbatim: TextosDoProfissional.Turnos.verNoMapas))
                .accessibilityHint(String(localized: "Abre o endereço no Apple Maps", bundle: bundleApresentacao))
            }
        }
    }

    private var quemRecebe: some View {
        Text(verbatim: "· \(TextosDoProfissional.Turnos.quemRecebe): \(viewModel.quemRecebeExibicao)")
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("quem-recebe-no-turno")
    }

    private var cartaoCancelamento: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoProfissional.Turnos.cancelamentoTitulo)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if let causa = viewModel.causaDoCancelamento {
                Text(verbatim: causa)
                    .font(.body)
            }
            if let falta = viewModel.faltaNoCancelamento {
                Text(verbatim: falta)
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cancelamento-do-turno")
    }

    private var cartaoContato: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoProfissional.Candidatura.contato.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)

            if viewModel.contatoExpirado {
                Text(verbatim: TextosDoProfissional.Turnos.contatoEncerrado)
                    .font(.subheadline)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityIdentifier("contato-expirado-aviso")
            } else if let contato = viewModel.contato {
                Text(verbatim: "\(contato.nome) · \(contato.telefone)")
                    .font(.body.weight(.semibold))
                    .accessibilityIdentifier("contato-telefone")

                if let urlWhatsApp = viewModel.urlWhatsApp {
                    // O alvo de 44 pt fica no rótulo, dentro do link: fora dele, só o texto recebia o toque.
                    Link(destination: urlWhatsApp) {
                        HStack {
                            Image(systemName: "message.fill")
                            Text(verbatim: TextosDoProfissional.Candidatura.abrirWhatsApp)
                        }
                        .frame(minHeight: FrilaMetrica.alvoMinimo)
                        .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("botao-whatsapp")
                    .accessibilityHint(String(localized: "Abre a conversa no WhatsApp com mensagem pré-formatada", bundle: bundleApresentacao))
                    #if DEBUG
                    .modifier(CapturaDeAberturaDeURLParaTeste())
                    #endif
                }

                Text(verbatim: TextosDoProfissional.Turnos.lembretesEVisibilidade)
                    .font(.caption)
                    .foregroundStyle(FrilaCor.textoSecundario)
            } else if viewModel.carregandoContato {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("contato-do-turno")
    }

    private var cartaoAvaliacao: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoProfissional.Avaliacao.cartaoTitulo.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)

            if viewModel.jaAvaliado {
                if let resposta = viewModel.respostaAvaliacao {
                    Text(verbatim: TextosDoProfissional.Avaliacao.statusResposta(resposta))
                        .font(.body.weight(.semibold))
                        .accessibilityIdentifier("texto-status-avaliacao")
                } else {
                    Text(verbatim: TextosDoProfissional.Avaliacao.statusAvaliado)
                        .font(.body.weight(.semibold))
                        .accessibilityIdentifier("texto-status-avaliacao")
                }

                NavigationLink {
                    if let avaliacao = viewModel.criarAvaliacaoViewModel() {
                        TelaAvaliacao(viewModel: avaliacao)
                    }
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                        Text(verbatim: TextosDoProfissional.Avaliacao.botaoVerAvaliacao)
                    }
                    .frame(minHeight: FrilaMetrica.alvoMinimo)
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("botao-ver-avaliacao")
            } else {
                Text(verbatim: TextosDoProfissional.Avaliacao.cartaoChamada)
                    .font(.subheadline)
                    .foregroundStyle(FrilaCor.textoSecundario)

                NavigationLink {
                    if let avaliacao = viewModel.criarAvaliacaoViewModel() {
                        TelaAvaliacao(viewModel: avaliacao)
                    }
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                        Text(verbatim: TextosDoProfissional.Avaliacao.botaoAvaliar)
                    }
                    .frame(minHeight: FrilaMetrica.alvoMinimo)
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("botao-abrir-avaliacao")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cartao-avaliacao-turno")
    }
}

#if DEBUG
/// Captura o destino recebido pelo sistema ao tocar no Link, sem sair do app durante o teste.
@MainActor
private protocol AbridorDeURL: AnyObject {
    var urlAberta: URL? { get }
    func abrir(_ url: URL)
}

@MainActor
@Observable
private final class AbridorDeURLParaTeste: AbridorDeURL {
    private(set) var urlAberta: URL?

    func abrir(_ url: URL) {
        urlAberta = url
    }
}

@MainActor
private struct CapturaDeAberturaDeURLParaTeste: ViewModifier {
    @State private var abridor: any AbridorDeURL = AbridorDeURLParaTeste()

    @ViewBuilder
    func body(content: Content) -> some View {
        if ProcessInfo.processInfo.arguments.contains("-FRILA_CAPTURAR_URL_UI_TEST") {
            content
                .environment(\.openURL, OpenURLAction { url in
                    abridor.abrir(url)
                    return .handled
                })
                .accessibilityValue(Text(verbatim: abridor.urlAberta?.absoluteString ?? ""))
        } else {
            content
        }
    }
}
#endif
