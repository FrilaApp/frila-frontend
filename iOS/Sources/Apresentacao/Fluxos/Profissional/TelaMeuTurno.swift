import FrilaDominio
import SwiftUI
#if DEBUG
import Observation
#endif

/// Detalhe do turno do profissional (T4 e T8 do protótipo, numa view só, com o estado do turno): o título, o card de
/// status com o selo e a linha de etapas, o aviso e o botão da presença, "Como chegar", a avaliação e, no fim, as
/// ações de risco e de suporte em ação discreta. O nome da tela ("Meu turno") fica na barra, e o estado vai no título.
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
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                cabecalho
                cartaoTurno
                avisosDaFila
                if let desfecho = viewModel.desfechoDoCancelamento {
                    AvisoFrila(verbatim: TextosDoCancelamento.desfecho(.posicao(desfecho), lado: .profissional), tom: .informativo)
                        .accessibilityIdentifier("desfecho-do-cancelamento-no-turno")
                }
                if viewModel.cancelamentoNaFila {
                    AvisoFrila(verbatim: TextosDoCancelamento.naFila, tom: .alerta)
                        .accessibilityIdentifier("cancelamento-na-fila")
                }
                if viewModel.cancelamento != nil {
                    blocoCancelamento
                }
                if viewModel.permiteAcoesDoTurno {
                    if let presenca = viewModel.presenca {
                        SecaoDePresenca(viewModel: presenca, turno: viewModel)
                    } else if viewModel.podeAvisarACaminho || viewModel.aCaminhoEm != nil {
                        blocoACaminhoSemPresenca
                    }
                    blocoComoChegar
                }
                if viewModel.podeAvaliar {
                    blocoAvaliacao
                } else if let liberacao = viewModel.liberacaoDaAvaliacao {
                    AvisoFrila(verbatim: TextosDoProfissional.Avaliacao.liberaAs(formatador.hora(liberacao)), tom: .informativo)
                        .accessibilityIdentifier("aviso-avaliacao-libera")
                }
                acoesDoFim
            }
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.top, FrilaEspaco.item)
            .padding(.bottom, FrilaEspaco.grupo)
        }
        // A leitura roda numa Task solta: o gesto de puxar cancela o código do `refreshable`, e o `try?` do `reler()` engoliria o cancelamento.
        .refreshable { await Task { await viewModel.atualizar() }.value }
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

    // MARK: - Etapa do turno

    private var houveACaminho: Bool { viewModel.aCaminhoEm != nil }
    private var houvePresenca: Bool { viewModel.temCheckin }
    private var houveSaida: Bool {
        if let presenca = viewModel.presenca {
            return presenca.checkout != .naoFeito || viewModel.turno.checkout != nil
        }
        return viewModel.turno.checkout != nil
    }

    private var etapaAtual: EtapaDoTurno {
        EtapaDoTurno.atual(aCaminho: houveACaminho, presenca: houvePresenca, concluido: houveSaida)
    }

    // MARK: - Ações de suporte e segurança (#21, #39)

    /// No fim da tela, longe do botão primário e uma por linha: cancelar, pedir ajuda, denunciar e bloquear.
    /// 24 do bloco de cima mais 8 daqui dão os 32 pt do desenho.
    private var acoesDoFim: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            if viewModel.podeCancelar {
                botaoCancelar
            }
            botaoSuporte
            rodapeSeguranca
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, FrilaEspaco.item)
    }

    private var botaoSuporte: some View {
        Button {
            suporteModel = SuporteTurnoViewModel(
                dados: ContextoSuporteTurno(turno: viewModel.turno),
                api: viewModel.api
            )
        } label: {
            Text(verbatim: TextosDoSuporte.botaoAjudaTurno)
        }
        .buttonStyle(.frilaAcaoDiscreta)
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

    // MARK: - Título e card de status

    private var cabecalho: some View {
        Text(verbatim: viewModel.cancelado ? TextosDoProfissional.Turnos.canceladoTitulo
             : viewModel.naoVerificado ? TextosDoProfissional.Turnos.naoVerificadoTitulo
             : TextosDoProfissional.Turnos.confirmadoTitulo)
            .font(FrilaTipo.tituloDaTela)
            .foregroundStyle(FrilaCor.texto)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("estado-do-turno")
            .accessibilityAddTraits(.isHeader)
    }

    /// O card de status do turno (DESIGN.md, "Card de status do turno"): o selo da etapa, a casa, a função, quando e
    /// quem recebe, a linha de etapas e o valor. O endereço fica em "Como chegar"; cancelado, não há esse bloco e o
    /// endereço, com o atalho do mapa, fica aqui.
    private var cartaoTurno: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
            seloDoTurno
            VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
                Text(verbatim: viewModel.turno.contraparte.nome)
                    .font(FrilaTipo.nome)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: viewModel.turno.vaga.funcao)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                FrilaLinhaDeDado(icone: "clock") { Text(verbatim: formatador.intervalo(viewModel.turno.vaga.periodo)) }
                if !viewModel.permiteAcoesDoTurno {
                    FrilaLinhaDeDado(icone: "mappin") { enderecoEMapa }
                }
                FrilaLinhaDeDado(icone: "person") { quemRecebe }
            }
            if viewModel.permiteAcoesDoTurno {
                LinhaDeEtapas(
                    feitas: EtapaDoTurno.feitas(aCaminho: houveACaminho, presenca: houvePresenca, concluido: houveSaida),
                    atual: etapaAtual
                )
            }
            Rectangle()
                .fill(FrilaCor.divisoria)
                .frame(height: 1)
                .accessibilityHidden(true)
            FrilaPriceTag(texto: formatador.dinheiro(viewModel.turno.valorAcordado),
                          leitura: formatador.dinheiroFalado(viewModel.turno.valorAcordado), tamanho: 28)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var seloDoTurno: some View {
        if viewModel.cancelado {
            SeloDeStatus(verbatim: TextosDoProfissional.Turnos.canceladoTitulo, estilo: .encerrado)
        } else if viewModel.naoVerificado {
            SeloDeStatus(verbatim: TextosDoProfissional.Turnos.naoVerificadoTitulo, estilo: .contorno)
        } else {
            let dados = etapaAtual.selo
            SeloDeStatus(verbatim: dados.titulo, estilo: dados.estilo, icone: dados.icone)
        }
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
                        .frame(minWidth: FrilaMetrica.alvo, minHeight: FrilaMetrica.alvo)
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

    // MARK: - Avisos

    /// O que a fila do aparelho recusou: o aviso e, logo abaixo, o "Fechar".
    @ViewBuilder
    private var avisosDaFila: some View {
        ForEach(viewModel.recusasDaFila) { recusa in
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                AvisoFrila(verbatim: TextosDaFila.texto(recusa), tom: .informativo)
                    .accessibilityIdentifier("aviso-acao-recusada-\(recusa.tipo.rawValue)")
                BotaoSecundario("Fechar") { Task { await viewModel.fecharAvisoDaFila(id: recusa.id) } }
                    .accessibilityIdentifier("fechar-aviso-acao-recusada-\(recusa.tipo.rawValue)")
            }
        }
    }

    private var blocoCancelamento: some View {
        BlocoComRotuloDeGrupo(TextosDoProfissional.Turnos.cancelamentoTitulo) {
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                if let causa = viewModel.causaDoCancelamento {
                    Text(verbatim: causa)
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let falta = viewModel.faltaNoCancelamento {
                    Text(verbatim: falta)
                        .font(FrilaTipo.apoio)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartaoFrila()
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("cancelamento-do-turno")
        }
    }

    /// O aviso "a caminho" quando não há leitor de localização (as prévias): o mesmo bloco da presença, sem o check-in.
    private var blocoACaminhoSemPresenca: some View {
        BlocoComRotuloDeGrupo(TextosDoProfissional.Presenca.titulo) {
            VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                if let data = viewModel.aCaminhoEm {
                    FrilaLinhaDeDado(icone: "figure.walk") {
                        Text(verbatim: TextosDoProfissional.Turnos.avisouACaminho(formatador.hora(data)))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("a-caminho-situacao")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cartaoFrila()
                }
                VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                    if let erro = viewModel.mensagemErroACaminho {
                        MensagemJuntoAoBotao(verbatim: erro).accessibilityLabel(Text(verbatim: AvisoFrila.rotuloAcessibilidade(texto: erro, tom: .erro))).accessibilityIdentifier("a-caminho-erro")
                    }
                    if viewModel.podeTentarAvisarDeNovo {
                        BotaoPrimario(verbatim: TextosDoProfissional.Turnos.tentarDeNovo, carregando: viewModel.avisandoACaminho) {
                            Task { await viewModel.avisarACaminho() }
                        }
                        .accessibilityIdentifier("tentar-a-caminho-de-novo")
                    }
                    if viewModel.podeExibirBotaoACaminho {
                        BotaoPrimario(verbatim: TextosDoProfissional.Turnos.botaoEstouACaminho, carregando: viewModel.avisandoACaminho) {
                            Task { await viewModel.avisarACaminho() }
                        }
                        .accessibilityIdentifier("botao-a-caminho")
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("presenca-do-turno")
    }

    /// "Como chegar" no lugar do cartão de contato: o endereço da vaga, o atalho para o mapa e, quando
    /// a casa escreveu, as observações (entrada, ponto de referência). Só dados que a vaga já tem.
    private var blocoComoChegar: some View {
        BlocoComRotuloDeGrupo(TextosDoProfissional.Turnos.comoChegar) {
            VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                enderecoDoTurno
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)

                if let observacoes = viewModel.observacoesDaVaga {
                    VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
                        Text(verbatim: TextosDoProfissional.Detalhe.observacoes)
                            .font(FrilaTipo.rotuloDeGrupo)
                            .foregroundStyle(FrilaCor.textoSecundario)
                        Text(verbatim: observacoes)
                            .font(FrilaTipo.corpo)
                            .foregroundStyle(FrilaCor.texto)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("observacoes-do-turno")
                }

                if let urlMapas = viewModel.urlMapas {
                    // O alvo fica no rótulo, dentro do link: fora dele, só o texto recebia o toque.
                    Link(destination: urlMapas) {
                        HStack(spacing: FrilaEspaco.item) {
                            Image(systemName: "map")
                                .accessibilityHidden(true)
                            Text(verbatim: TextosDoProfissional.Detalhe.abrirNoMapa)
                        }
                        .font(FrilaTipo.rotuloSecundario)
                        .foregroundStyle(FrilaCor.texto)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, FrilaEspaco.bloco)
                        .padding(.vertical, FrilaEspaco.item)
                        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
                        .background(FrilaCor.superficie, in: FrilaForma.capsulaQueCresce())
                        .overlay(FrilaForma.capsulaQueCresce().strokeBorder(FrilaCor.borda, lineWidth: 1))
                        .contentShape(FrilaForma.capsulaQueCresce())
                    }
                    #if DEBUG
                    .modifier(CapturaDeAberturaDeURLParaTeste())
                    #endif
                    .accessibilityIdentifier("botao-abrir-no-mapa")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint(String(localized: "Abre o endereço no Apple Maps", bundle: bundleApresentacao))
                }

                Text(verbatim: TextosDoProfissional.Turnos.lembretes)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartaoFrila()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("como-chegar-do-turno")
        }
    }

    /// A avaliação do turno: a chamada e o botão secundário (sem laranja: a tela de leitura não decide nada).
    private var blocoAvaliacao: some View {
        BlocoComRotuloDeGrupo(TextosDoProfissional.Avaliacao.cartaoTitulo) {
            VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                if viewModel.jaAvaliado {
                    Text(verbatim: viewModel.respostaAvaliacao.map { TextosDoProfissional.Avaliacao.statusResposta($0) }
                         ?? TextosDoProfissional.Avaliacao.statusAvaliado)
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("texto-status-avaliacao")

                    NavigationLink {
                        if let avaliacao = viewModel.criarAvaliacaoViewModel() {
                            TelaAvaliacao(viewModel: avaliacao)
                        }
                    } label: {
                        Text(verbatim: TextosDoProfissional.Avaliacao.botaoVerAvaliacao)
                    }
                    .buttonStyle(EstiloDoBotaoFrila(papel: .secundario))
                    .accessibilityIdentifier("botao-ver-avaliacao")
                } else {
                    Text(verbatim: TextosDoProfissional.Avaliacao.cartaoChamada)
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)

                    NavigationLink {
                        if let avaliacao = viewModel.criarAvaliacaoViewModel() {
                            TelaAvaliacao(viewModel: avaliacao)
                        }
                    } label: {
                        Text(verbatim: TextosDoProfissional.Avaliacao.botaoAvaliar)
                    }
                    .buttonStyle(EstiloDoBotaoFrila(papel: .secundario))
                    .accessibilityIdentifier("botao-abrir-avaliacao")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartaoFrila()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("cartao-avaliacao-turno")
        }
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
