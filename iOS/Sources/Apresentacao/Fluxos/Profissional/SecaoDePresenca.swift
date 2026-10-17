import FrilaDominio
import SwiftUI
import UIKit

/// Check-in e check-out dentro de Meu turno (#17): o que já foi registrado, o botão do próximo
/// registro, a explicação antes do pedido de permissão e a saída manual quando o GPS não serve.
/// É a seção "Chegada" do quadro "TurnoHoje" do MidFi (e o aviso de falha do "AlertaAtraso"):
/// cartão com rótulo em caixa alta, linhas de estado, botão escuro e ações de apoio.
struct SecaoDePresenca: View {
    private typealias Textos = TextosDoProfissional.Presenca

    @Bindable private var viewModel: PresencaDoTurnoViewModel
    private var turno: MeuTurnoViewModel?
    @AccessibilityFocusState private var focoNoAviso: Bool
    private let formatador = FormatadorFrila()

    init(viewModel: PresencaDoTurnoViewModel, turno: MeuTurnoViewModel? = nil) {
        self.viewModel = viewModel
        self.turno = turno
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
            Text(verbatim: Textos.titulo.uppercased())
                .font(FrilaTipo.microRotulo)
                .tracking(0.8)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)

            if let aCaminho = situacaoACaminho {
                linha(aCaminho).accessibilityIdentifier("a-caminho-situacao")
            }
            if let situacao = situacaoDoCheckin {
                linha(situacao).accessibilityIdentifier("checkin-situacao")
            }
            if let situacao = situacaoDoCheckout {
                linha(situacao).accessibilityIdentifier("checkout-situacao")
            }
            if let erro = viewModel.mensagemDeErro {
                AvisoFrila(verbatim: erro, tom: .erro).accessibilityIdentifier("presenca-erro")
            }
            if let erro = turno?.mensagemErroACaminho {
                AvisoFrila(verbatim: erro, tom: .erro).accessibilityIdentifier("a-caminho-erro")
                if turno?.podeTentarAvisarDeNovo == true {
                    BotaoSecundario(verbatim: TextosDoProfissional.Turnos.tentarDeNovo) {
                        Task { await turno?.avisarACaminho() }
                    }
                    .accessibilityIdentifier("tentar-a-caminho-de-novo")
                }
            }
            acoes
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
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
        .onChange(of: turno?.aCaminhoEm) { _, _ in anunciar(situacaoACaminho?.texto) }
        .onChange(of: viewModel.checkin) { _, _ in anunciar(situacaoDoCheckin?.texto) }
        .onChange(of: viewModel.checkout) { _, _ in anunciar(situacaoDoCheckout?.texto) }
    }

    // MARK: Ações

    @ViewBuilder
    private var acoes: some View {
        switch viewModel.etapa {
        case .parada:
            if turno?.podeExibirBotaoACaminho == true {
                BotaoSecundario(verbatim: TextosDoProfissional.Turnos.botaoEstouACaminho) {
                    Task { await turno?.avisarACaminho() }
                }
                .disabled(turno?.avisandoACaminho == true)
                .accessibilityIdentifier("botao-a-caminho")
            }
            if viewModel.podeFazerCheckin {
                BotaoPrimario(verbatim: Textos.fazerCheckin) { Task { await viewModel.iniciar(.checkin) } }
                    .accessibilityIdentifier("fazer-checkin")
            } else if viewModel.podeFazerCheckout {
                BotaoPrimario(verbatim: Textos.fazerCheckout) { Task { await viewModel.iniciar(.checkout) } }
                    .accessibilityIdentifier("fazer-checkout")
            }
        case .explicando:
            aviso(titulo: Textos.explicacaoTitulo, textos: [Textos.explicacao], identificador: "explicacao-localizacao")
            BotaoPrimario(verbatim: Textos.continuar) { Task { await viewModel.continuarComPermissao() } }
                .accessibilityIdentifier("permitir-localizacao")
            BotaoSecundario(verbatim: Textos.agoraNao) { viewModel.cancelar() }
                .accessibilityIdentifier("cancelar-presenca")
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
            BotaoPrimario(verbatim: registro == .checkin ? Textos.checkinManual : Textos.saidaSemLocalizacao) {
                Task { await viewModel.registrarSemGPS() }
            }
            .accessibilityIdentifier("registro-manual")
            BotaoSecundario(verbatim: Textos.tentarGPS) { Task { await viewModel.tentarGPSDeNovo() } }
                .accessibilityIdentifier("tentar-gps")
            if motivo == .permissaoNegada || motivo == .localizacaoAproximada,
               let ajustes = URL(string: UIApplication.openSettingsURLString) {
                Link(destination: ajustes) {
                    Text(verbatim: Textos.abrirAjustes)
                        .font(FrilaTipo.meta.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)
                }
                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
                .accessibilityIdentifier("abrir-ajustes")
            }
            BotaoSecundario(verbatim: Textos.agoraNao) { viewModel.cancelar() }
                .accessibilityIdentifier("cancelar-presenca")
        }
    }

    private func aviso(titulo: String, textos: [String], identificador: String) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(verbatim: titulo)
                .font(FrilaTipo.rotuloDoCampo)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focoNoAviso)
                .accessibilityIdentifier(identificador)
            ForEach(textos, id: \.self) { Text(verbatim: $0).font(FrilaTipo.meta) }
        }
        .foregroundStyle(FrilaCor.texto)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func progresso(_ texto: String) -> some View {
        HStack(spacing: FrilaEspaco.pequeno) {
            ProgressView()
            Text(verbatim: texto).font(FrilaTipo.meta).foregroundStyle(FrilaCor.textoSecundario)
        }
        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("presenca-em-andamento")
    }

    // MARK: Situação

    private struct LinhaDeSituacao {
        let texto: String
        let icone: String
        let cor: Color
    }

    /// Ícone e texto dizem a situação; a cor só acompanha.
    private func linha(_ situacao: LinhaDeSituacao) -> some View {
        Label {
            Text(verbatim: situacao.texto)
        } icon: {
            Image(systemName: situacao.icone)
        }
        .font(FrilaTipo.meta.weight(.semibold))
        .foregroundStyle(situacao.cor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var situacaoACaminho: LinhaDeSituacao? {
        guard let data = turno?.aCaminhoEm else { return nil }
        return LinhaDeSituacao(
            texto: TextosDoProfissional.Turnos.avisouACaminho(formatador.hora(data)),
            icone: "figure.walk",
            cor: FrilaCor.texto
        )
    }

    private var situacaoDoCheckin: LinhaDeSituacao? {
        switch viewModel.checkin {
        case .naoFeito:
            return nil
        case let .naFila(feito):
            return LinhaDeSituacao(texto: Textos.checkinNaFila(formatador.hora(feito.instante), manual: feito.manual), icone: "wifi.slash", cor: FrilaCor.alerta)
        case let .registrado(feito):
            let hora = formatador.hora(feito.instante)
            if viewModel.verificacao == .verificado {
                return LinhaDeSituacao(texto: Textos.checkinVerificado(hora, metros: feito.distanciaMetros), icone: "checkmark.seal.fill", cor: FrilaCor.sucesso)
            }
            if viewModel.aguardandoConfirmacao {
                return LinhaDeSituacao(texto: Textos.checkinAguardando(hora), icone: "hourglass", cor: FrilaCor.alerta)
            }
            return LinhaDeSituacao(texto: Textos.checkinSemVerificacao(hora), icone: "questionmark.circle", cor: FrilaCor.textoSecundario)
        }
    }

    private var situacaoDoCheckout: LinhaDeSituacao? {
        switch viewModel.checkout {
        case .naoFeito:
            nil
        case let .naFila(feito):
            LinhaDeSituacao(texto: Textos.checkoutNaFila(formatador.hora(feito.instante)), icone: "wifi.slash", cor: FrilaCor.alerta)
        case let .registrado(feito):
            LinhaDeSituacao(texto: Textos.checkoutRegistrado(formatador.hora(feito.instante), metros: feito.distanciaMetros), icone: "checkmark.circle.fill", cor: FrilaCor.texto)
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
