import FrilaDominio
import SwiftUI
#if DEBUG
import Observation
#endif

/// Tela do turno, nos quadros "TurnoHoje", "TurnoProximo" e "MeuTurno" do MidFi do Fabrício: cartão
/// de dados do turno, seção de chegada, "Como chegar" e avaliação em cartões brancos sobre o fundo cinza.
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
                    AvisoFrila(verbatim: TextosDaFila.texto(recusa), tom: .informativo)
                        .accessibilityIdentifier("aviso-acao-recusada-\(recusa.tipo.rawValue)")
                    BotaoSecundario("Fechar") { Task { await viewModel.fecharAvisoDaFila(id: recusa.id) } }
                        .accessibilityIdentifier("fechar-aviso-acao-recusada-\(recusa.tipo.rawValue)")
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
                        SecaoDePresenca(viewModel: presenca, turno: viewModel)
                    } else if viewModel.podeAvisarACaminho || viewModel.aCaminhoEm != nil {
                        cartaoACaminhoSemPresenca
                    }
                    cartaoComoChegar
                }
                if viewModel.podeAvaliar {
                    cartaoAvaliacao
                } else if let liberacao = viewModel.liberacaoDaAvaliacao {
                    AvisoFrila(verbatim: TextosDoProfissional.Avaliacao.liberaAs(formatador.hora(liberacao)), tom: .informativo)
                        .accessibilityIdentifier("aviso-avaliacao-libera")
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
        .task { await medirAbertura(.meuTurno, carregar: viewModel.carregar, pronto: detalheNaTela) }
        .task { await viewModel.aguardarLiberacaoDaAvaliacao() }
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

    /// Fim da medição de abertura (#73): a carga da API encerrada (responsável local e observações
    /// da vaga), com o "Como chegar" completo na tela.
    private var detalheNaTela: @MainActor @Sendable () -> Bool {
        let viewModel = viewModel
        return { viewModel.detalheCarregado }
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
                dados: ContextoSuporteTurno(turno: viewModel.turno),
                api: viewModel.api
            )
        } label: {
            Text(verbatim: TextosDoSuporte.botaoAjudaTurno)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.textoSecundario)
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
                    .font(FrilaTipo.nota)
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
            .font(FrilaTipo.tituloGrande)
            .foregroundStyle(FrilaCor.texto)
            .padding(.horizontal, FrilaEspaco.minimo)
            .accessibilityIdentifier("estado-do-turno")
            .accessibilityAddTraits(.isHeader)
    }

    private var cartaoTurno: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: viewModel.turno.contraparte.nome)
                    .font(FrilaTipo.resumo)
                    .textCase(.uppercase)
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityLabel(Text(verbatim: viewModel.turno.contraparte.nome))
                Text(verbatim: viewModel.turno.vaga.funcao)
                    .font(FrilaTipo.tituloDoDetalhe)
                    .foregroundStyle(FrilaCor.texto)
            }

            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                    Text(verbatim: formatador.intervalo(viewModel.turno.vaga.periodo)).font(FrilaTipo.meta)
                    FrilaPriceTag(texto: formatador.dinheiro(viewModel.turno.valorAcordado),
                                  leitura: formatador.dinheiroFalado(viewModel.turno.valorAcordado), tamanho: 18)
                }

                VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                    // Com o turno em andamento, o endereço mora no "Como chegar"; cancelado, não há
                    // esse cartão e o endereço, com o atalho do mapa, fica aqui.
                    if !viewModel.permiteAcoesDoTurno {
                        enderecoEMapa
                    }
                    quemRecebe
                }
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, FrilaEspaco.pequeno)
            .overlay(alignment: .top) { fio }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .contain)
    }

    private var fio: some View {
        Rectangle().fill(FrilaCor.divisoria).frame(height: 1).accessibilityHidden(true)
    }

    private var enderecoDoTurno: some View {
        Text(verbatim: viewModel.turno.vaga.local)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("endereco-do-turno")
    }

    private var enderecoEMapa: some View {
        HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.minimo) {
            enderecoDoTurno
            if let urlMapas = viewModel.urlMapas {
                Link(destination: urlMapas) {
                    Image(systemName: "map")
                        .foregroundStyle(FrilaCor.texto)
                        .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("atalho-mapas")
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(Text(verbatim: TextosDoProfissional.Turnos.verNoMapas))
                .accessibilityHint(String(localized: "Abre o endereço no Apple Maps", bundle: bundleApresentacao))
            }
        }
    }

    private var quemRecebe: some View {
        Text(verbatim: "\(TextosDoProfissional.Turnos.quemRecebe): \(viewModel.quemRecebeExibicao)")
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("quem-recebe-no-turno")
    }

    private var cartaoCancelamento: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoProfissional.Turnos.cancelamentoTitulo)
                .font(FrilaTipo.secao)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)
            if let causa = viewModel.causaDoCancelamento {
                Text(verbatim: causa)
                    .font(FrilaTipo.corpo)
            }
            if let falta = viewModel.faltaNoCancelamento {
                Text(verbatim: falta)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cancelamento-do-turno")
    }

    private var cartaoACaminhoSemPresenca: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoProfissional.Presenca.titulo)
                .font(FrilaTipo.secao)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)

            if let data = viewModel.aCaminhoEm {
                Label {
                    Text(verbatim: TextosDoProfissional.Turnos.avisouACaminho(formatador.hora(data)))
                } icon: {
                    Image(systemName: "figure.walk")
                }
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("a-caminho-situacao")
            }
            if let erro = viewModel.mensagemErroACaminho {
                AvisoFrila(verbatim: erro, tom: .erro).accessibilityIdentifier("a-caminho-erro")
                if viewModel.podeTentarAvisarDeNovo {
                    Button {
                        Task { await viewModel.avisarACaminho() }
                    } label: {
                        Text(verbatim: TextosDoProfissional.Turnos.tentarDeNovo)
                            .font(FrilaTipo.botao)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, FrilaEspaco.grande)
                            .padding(.vertical, FrilaEspaco.pequeno)
                            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
                            .foregroundStyle(FrilaCor.texto)
                            .background(FrilaCor.superficie, in: Capsule())
                            .overlay(Capsule().strokeBorder(FrilaCor.divisoria, lineWidth: 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.tatil)
                    .accessibilityLabel(Text(verbatim: TextosDoProfissional.Turnos.tentarDeNovo))
                    .accessibilityIdentifier("tentar-a-caminho-de-novo")
                }
            }
            if viewModel.podeExibirBotaoACaminho {
                Button {
                    Task { await viewModel.avisarACaminho() }
                } label: {
                    Text(verbatim: TextosDoProfissional.Turnos.botaoEstouACaminho)
                        .font(FrilaTipo.botao)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, FrilaEspaco.grande)
                        .padding(.vertical, FrilaEspaco.pequeno)
                        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
                        .foregroundStyle(FrilaCor.texto)
                        .background(FrilaCor.superficie, in: Capsule())
                        .overlay(Capsule().strokeBorder(FrilaCor.divisoria, lineWidth: 1))
                        .contentShape(Capsule())
                }
                .buttonStyle(.tatil)
                .disabled(viewModel.avisandoACaminho)
                .accessibilityLabel(Text(verbatim: TextosDoProfissional.Turnos.botaoEstouACaminho))
                .accessibilityIdentifier("botao-a-caminho")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("presenca-do-turno")
    }

    /// "Como chegar" no lugar do cartão de contato: o endereço da vaga, o atalho para o mapa e, quando
    /// a casa escreveu, as observações (entrada, ponto de referência). Só dados que a vaga já tem.
    private var cartaoComoChegar: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoProfissional.Turnos.comoChegar)
                .font(FrilaTipo.secao)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)

            enderecoDoTurno
                .font(FrilaTipo.chip)
                .foregroundStyle(FrilaCor.texto)

            if let observacoes = viewModel.observacoesDaVaga {
                VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                    Text(verbatim: TextosDoProfissional.Detalhe.observacoes)
                        .font(FrilaTipo.nota.weight(.semibold))
                        .foregroundStyle(FrilaCor.textoSecundario)
                    Text(verbatim: observacoes)
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("observacoes-do-turno")
            }

            if let urlMapas = viewModel.urlMapas {
                // O alvo fica no rótulo, dentro do link: fora dele, só o texto recebia o toque.
                Link(destination: urlMapas) {
                    HStack(spacing: FrilaEspaco.pequeno) {
                        Image(systemName: "map")
                            .accessibilityHidden(true)
                        Text(verbatim: TextosDoProfissional.Detalhe.abrirNoMapa)
                            .font(FrilaTipo.botaoPadrao)
                    }
                    .foregroundStyle(FrilaCor.texto)
                    .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
                    .overlay(Capsule().strokeBorder(FrilaCor.borda, lineWidth: 1))
                    .contentShape(Capsule())
                }
                #if DEBUG
                .modifier(CapturaDeAberturaDeURLParaTeste())
                #endif
                .accessibilityIdentifier("botao-abrir-no-mapa")
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(String(localized: "Abre o endereço no Apple Maps", bundle: bundleApresentacao))
            }

            Text(verbatim: TextosDoProfissional.Turnos.lembretes)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("como-chegar-do-turno")
    }

    private var cartaoAvaliacao: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoProfissional.Avaliacao.cartaoTitulo)
                .font(FrilaTipo.secao)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)

            if viewModel.jaAvaliado {
                if let resposta = viewModel.respostaAvaliacao {
                    Text(verbatim: TextosDoProfissional.Avaliacao.statusResposta(resposta))
                        .font(FrilaTipo.chip)
                        .accessibilityIdentifier("texto-status-avaliacao")
                } else {
                    Text(verbatim: TextosDoProfissional.Avaliacao.statusAvaliado)
                        .font(FrilaTipo.chip)
                        .accessibilityIdentifier("texto-status-avaliacao")
                }

                NavigationLink {
                    if let avaliacao = viewModel.criarAvaliacaoViewModel() {
                        TelaAvaliacao(viewModel: avaliacao)
                    }
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                            .accessibilityHidden(true)
                        Text(verbatim: TextosDoProfissional.Avaliacao.botaoVerAvaliacao)
                    }
                    .font(FrilaTipo.meta.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
                    .frame(minHeight: FrilaMetrica.alvoMinimo)
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("botao-ver-avaliacao")
            } else {
                Text(verbatim: TextosDoProfissional.Avaliacao.cartaoChamada)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)

                NavigationLink {
                    if let avaliacao = viewModel.criarAvaliacaoViewModel() {
                        TelaAvaliacao(viewModel: avaliacao)
                    }
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                            .accessibilityHidden(true)
                        Text(verbatim: TextosDoProfissional.Avaliacao.botaoAvaliar)
                    }
                    .font(FrilaTipo.meta.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
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
