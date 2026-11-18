import FrilaDominio
import SwiftUI
import UIKit

/// Check-in e check-out dentro de Meu turno (#17): o que já foi registrado, o botão do próximo registro, a explicação
/// antes do pedido de permissão e a saída manual quando o GPS não serve. É o aviso da presença e o botão do T4 e do
/// T8 do protótipo: o erro e o resultado ficam em `MensagemJuntoAoBotao`, em tinta, e o botão de check-in é o
/// primário de 64 pt com o rótulo em caixa alta.
public struct SecaoDePresenca: View {
    private typealias Textos = TextosDoProfissional.Presenca

    @Bindable private var viewModel: PresencaDoTurnoViewModel
    private var turno: MeuTurnoViewModel?
    @AccessibilityFocusState private var focoNoAviso: Bool
    @Environment(\.scenePhase) private var fase
    @State private var mostrarEntradaDoCodigo = false
    private let formatador = FormatadorFrila()

    public init(viewModel: PresencaDoTurnoViewModel, turno: MeuTurnoViewModel? = nil) {
        self.viewModel = viewModel
        self.turno = turno
    }

    public var body: some View {
        BlocoComRotuloDeGrupo(Textos.titulo) {
            VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                situacoes
                if viewModel.verificacao == .naoVerificado {
                    AvisoFrila(verbatim: Textos.naoVerificadaAviso, tom: .alerta)
                        .accessibilityIdentifier("presenca-nao-verificada")
                }
                VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                    mensagens
                    acoes
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("presenca-do-turno")
        // O que muda sem toque na região (resultado, falha do GPS) é dito pelo VoiceOver, e o foco
        // vai para o aviso que pede uma decisão.
        .onChange(of: viewModel.etapa) { _, nova in
            switch nova {
            case .explicando, .semGPS: focoNoAviso = true
            case .parada, .lendo, .enviando: break
            }
        }
        .task {
            await viewModel.carregarRecursos()
            await viewModel.atualizarPermissaoDaLocalizacao()
        }
        .sheet(isPresented: $mostrarEntradaDoCodigo) { EntradaDoCodigo(presenca: viewModel) }
        // Voltando dos Ajustes, a permissão pode ter mudado.
        .onChange(of: fase) { _, nova in
            if nova == .active { Task { await viewModel.atualizarPermissaoDaLocalizacao() } }
        }
        .onChange(of: turno?.aCaminhoEm) { _, _ in anunciar(situacaoACaminho?.texto) }
        .onChange(of: viewModel.checkin) { _, _ in anunciar(situacaoDoCheckin?.texto) }
        .onChange(of: viewModel.checkout) { _, _ in anunciar(situacaoDoCheckout?.texto) }
    }

    /// O que já foi registrado: uma linha de dado por registro, num cartão, em tinta (o estado vai no ícone e no texto).
    @ViewBuilder
    private var situacoes: some View {
        if situacaoACaminho != nil || situacaoDoCheckin != nil || situacaoDoCheckout != nil {
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                if let linha = situacaoACaminho {
                    linhaDeDado(linha).accessibilityIdentifier("a-caminho-situacao")
                }
                if let linha = situacaoDoCheckin {
                    linhaDeDado(linha).accessibilityIdentifier("checkin-situacao")
                }
                if let linha = situacaoDoCheckout {
                    linhaDeDado(linha).accessibilityIdentifier("checkout-situacao")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartaoFrila()
        }
    }

    private func linhaDeDado(_ linha: LinhaDeSituacao) -> some View {
        FrilaLinhaDeDado(icone: linha.icone) { Text(verbatim: linha.texto) }
            .accessibilityElement(children: .combine)
    }

    /// Erro da ação, logo acima do botão que a disparou (DESIGN.md, "Mensagem junto ao botão").
    @ViewBuilder
    private var mensagens: some View {
        if let erro = viewModel.mensagemDeErro {
            MensagemJuntoAoBotao(verbatim: erro).accessibilityLabel(Text(verbatim: AvisoFrila.rotuloAcessibilidade(texto: erro, tom: .erro))).accessibilityIdentifier("presenca-erro")
        }
        if let erro = turno?.mensagemErroACaminho {
            MensagemJuntoAoBotao(verbatim: erro).accessibilityLabel(Text(verbatim: AvisoFrila.rotuloAcessibilidade(texto: erro, tom: .erro))).accessibilityIdentifier("a-caminho-erro")
        }
    }

    // MARK: Ações

    /// Só um botão laranja por tela: com o botão de check-in ou de check-out na tela, "Estou a caminho" fica secundário.
    private var temPrimarioDeRegistro: Bool {
        !viewModel.checkinAntecipadoDemais && (viewModel.podeFazerCheckin || viewModel.podeFazerCheckout)
    }

    @ViewBuilder
    private var acoes: some View {
        switch viewModel.etapa {
        case .parada:
            if viewModel.pedePrecisaoAntes {
                AvisoFrila(verbatim: Textos.avisoPrecisaoDesligada, tom: .alerta)
                    .accessibilityIdentifier("aviso-precisao-desligada")
                linkParaAjustes
            }
            if turno?.podeExibirBotaoACaminho == true {
                botaoACaminho(
                    verbatim: TextosDoProfissional.Turnos.botaoEstouACaminho,
                    identificador: "botao-a-caminho",
                    avisando: turno?.avisandoACaminho == true
                )
            } else if RegrasDeTelaDaPresenca.mostraTentarDeNovoDoACaminho(
                estado: viewModel.etapa, erro: turno?.mensagemErroACaminho, podeTentar: turno?.podeTentarAvisarDeNovo == true
            ) {
                botaoACaminho(
                    verbatim: TextosDoProfissional.Turnos.tentarDeNovo,
                    identificador: "tentar-a-caminho-de-novo",
                    avisando: turno?.avisandoACaminho == true
                )
            }
            if viewModel.checkinAntecipadoDemais {
                AvisoFrila(verbatim: Textos.avisoCheckinAntecipado, tom: .informativo)
                    .accessibilityIdentifier("aviso-checkin-antecipado")
            } else if viewModel.podeFazerCheckin {
                BotaoDePresenca(titulo: Textos.fazerCheckin, altura: FrilaMetrica.alturaDoBotaoDePresenca, emCaixaAlta: true) {
                    Task { await viewModel.iniciar(.checkin) }
                }
                .accessibilityIdentifier("fazer-checkin")
            } else if viewModel.podeFazerCheckout {
                BotaoPrimario(verbatim: Textos.fazerCheckout) {
                    Task { await viewModel.iniciar(.checkout) }
                }
                .accessibilityIdentifier("fazer-checkout")
            }
            // Check-in pendente com o caminho do código aberto: ler o código da casa (0.2.68). Sem a chave, não aparece.
            if viewModel.podeLerOCodigo {
                BotaoSecundario(verbatim: TextosDoCheckinPorCodigo.Profissional.abrir) {
                    mostrarEntradaDoCodigo = true
                }
                .accessibilityIdentifier("ler-codigo-da-casa")
            }
        case .explicando:
            aviso(titulo: Textos.explicacaoTitulo, textos: [Textos.explicacao, Textos.explicacaoPrecisao], identificador: "explicacao-localizacao")
            BotaoPrimario(verbatim: Textos.continuar) {
                Task { await viewModel.continuarComPermissao() }
            }
            .accessibilityIdentifier("permitir-localizacao")
            linkAgoraNao
        case .lendo:
            progresso(Textos.lendo)
        case .enviando:
            progresso(Textos.enviando)
        case let .semGPS(registro, motivo):
            aviso(
                titulo: Textos.semGPSTitulo,
                textos: [texto(motivo), registro == .checkin ? Textos.manualExplicacao : Textos.saidaSemLocalizacaoExplicacao],
                identificador: "sem-gps"
            )
            if registro == .checkin {
                BotaoDePresenca(titulo: Textos.checkinManual, altura: FrilaMetrica.alturaDoBotaoDePresenca, emCaixaAlta: true) {
                    Task { await viewModel.registrarSemGPS() }
                }
                .accessibilityIdentifier("registro-manual")
            } else {
                BotaoPrimario(verbatim: Textos.saidaSemLocalizacao) {
                    Task { await viewModel.registrarSemGPS() }
                }
                .accessibilityIdentifier("registro-manual")
            }
            BotaoSecundario(verbatim: Textos.tentarGPS) {
                Task { await viewModel.tentarGPSDeNovo() }
            }
            .accessibilityIdentifier("tentar-gps")
            if motivo == .permissaoNegada || motivo == .localizacaoAproximada {
                linkParaAjustes
            }
            linkAgoraNao
        }
    }

    /// "Estou a caminho": o primário da tela enquanto o check-in ainda não abriu; secundário quando o botão de check-in
    /// ou de check-out já está na tela.
    @ViewBuilder
    private func botaoACaminho(verbatim titulo: String, identificador: String, avisando: Bool) -> some View {
        if temPrimarioDeRegistro {
            BotaoSecundario(verbatim: titulo) { Task { await turno?.avisarACaminho() } }
                .disabled(avisando)
                .accessibilityIdentifier(identificador)
        } else {
            BotaoPrimario(verbatim: titulo, carregando: avisando) { Task { await turno?.avisarACaminho() } }
                .accessibilityIdentifier(identificador)
        }
    }

    private var linkAgoraNao: some View {
        Button { viewModel.cancelar() } label: { Text(verbatim: Textos.agoraNao) }
            .buttonStyle(.frilaLink)
            .accessibilityIdentifier("cancelar-presenca")
    }

    @ViewBuilder
    private var linkParaAjustes: some View {
        if let ajustes = URL(string: UIApplication.openSettingsURLString) {
            Link(destination: ajustes) {
                Text(verbatim: Textos.abrirAjustes)
                    .font(FrilaTipo.corpo)
                    .underline()
                    .foregroundStyle(FrilaCor.texto)
                    .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvo, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("abrir-ajustes")
        }
    }

    private func aviso(titulo: String, textos: [String], identificador: String) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text(verbatim: titulo)
                .font(FrilaTipo.nome)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focoNoAviso)
                .accessibilityIdentifier(identificador)
            ForEach(textos, id: \.self) {
                Text(verbatim: $0)
                    .font(FrilaTipo.corpo)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(FrilaCor.texto)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Lendo a localização ou enviando: o texto em tinta junto ao botão, sem indicador girando.
    private func progresso(_ texto: String) -> some View {
        MensagemJuntoAoBotao(verbatim: texto)
            .accessibilityIdentifier("presenca-em-andamento")
    }

    // MARK: Situação

    private struct LinhaDeSituacao {
        let texto: String
        let icone: String
    }

    private var situacaoACaminho: LinhaDeSituacao? {
        guard let data = turno?.aCaminhoEm else { return nil }
        return LinhaDeSituacao(
            texto: TextosDoProfissional.Turnos.avisouACaminho(formatador.hora(data)),
            icone: "figure.walk"
        )
    }

    private var situacaoDoCheckin: LinhaDeSituacao? {
        switch viewModel.checkin {
        case .naoFeito:
            return nil
        case let .naFila(feito):
            return LinhaDeSituacao(texto: Textos.checkinNaFila(formatador.hora(feito.instante), manual: feito.manual), icone: "wifi.slash")
        case let .registrado(feito):
            let hora = formatador.hora(feito.instante)
            if viewModel.verificacao == .verificado {
                return LinhaDeSituacao(texto: Textos.checkinVerificado(hora, metros: feito.distanciaMetros), icone: "checkmark.seal.fill")
            }
            if viewModel.verificacao == .naoVerificado {
                return LinhaDeSituacao(texto: Textos.checkinNaoConfirmado(hora), icone: "xmark.seal")
            }
            if viewModel.aguardandoConfirmacao {
                return LinhaDeSituacao(texto: Textos.checkinAguardando(hora), icone: "hourglass")
            }
            return LinhaDeSituacao(texto: Textos.checkinSemVerificacao(hora), icone: "questionmark.circle")
        }
    }

    private var situacaoDoCheckout: LinhaDeSituacao? {
        switch viewModel.checkout {
        case .naoFeito:
            nil
        case let .naFila(feito):
            LinhaDeSituacao(texto: Textos.checkoutNaFila(formatador.hora(feito.instante)), icone: "wifi.slash")
        case let .registrado(feito):
            LinhaDeSituacao(texto: Textos.checkoutRegistrado(formatador.hora(feito.instante), metros: feito.distanciaMetros), icone: "checkmark.circle.fill")
        }
    }

    private func texto(_ motivo: PresencaDoTurnoViewModel.MotivoSemGPS) -> String {
        switch motivo {
        case .permissaoNegada: Textos.motivoPermissaoNegada
        case .localizacaoAproximada: Textos.motivoAproximada
        case .semSinal: Textos.motivoSemSinal
        case .imprecisa: Textos.motivoImprecisa
        case let .longe(distanciaMetros): Textos.motivoLonge(distanciaMetros)
        case .enderecoIndisponivel: Textos.motivoEnderecoIndisponivel
        }
    }

    private func anunciar(_ texto: String?) {
        guard let texto else { return }
        AccessibilityNotification.Announcement(texto).post()
    }
}

/// O botão de presença do protótipo (T8, "MARCAR PRESENÇA"): o primário de 64 pt com o rótulo em caixa alta. A caixa
/// alta é só do desenho: o nome falado e o que os testes procuram seguem o texto do catálogo. Desligado, vira o botão
/// em conferência, no lugar e com o mesmo rótulo.
private struct BotaoDePresenca: View {
    let titulo: String
    let altura: CGFloat
    let emCaixaAlta: Bool
    let acao: () -> Void
    @Environment(\.isEnabled) private var habilitado
    @Environment(\.dynamicTypeSize) private var tamanhoDoTexto

    var body: some View {
        // Com texto de acessibilidade a caixa alta alonga o botão e dificulta a leitura: fica só no tamanho comum.
        let maiusculas = emCaixaAlta && !tamanhoDoTexto.isAccessibilitySize
        Button(action: acao) {
            Text(verbatim: maiusculas ? titulo.uppercased(with: Locale(identifier: "pt_BR")) : titulo)
        }
        .buttonStyle(EstiloDoBotaoFrila(papel: .primario, emConferencia: !habilitado, alturaMinima: altura))
        .accessibilityLabel(Text(verbatim: titulo))
    }
}

/// Condições de tela da presença que valem testar sem desenhar a view.
enum RegrasDeTelaDaPresenca {
    /// O "Tentar de novo" do aviso "a caminho": com o erro na tela e o ViewModel dizendo que dá para tentar.
    static func mostraTentarDeNovoDoACaminho(estado: PresencaDoTurnoViewModel.Etapa, erro: String?, podeTentar: Bool) -> Bool {
        estado == .parada && erro != nil && podeTentar
    }
}
