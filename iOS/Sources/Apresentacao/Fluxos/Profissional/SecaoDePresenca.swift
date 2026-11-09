import FrilaDominio
import SwiftUI
import UIKit

/// Check-in e check-out dentro de Meu turno (T8, RF13, RN22): o que já foi registrado,
/// o botão do próximo registro, a explicação antes do pedido de permissão e a saída manual quando o GPS não serve.
public struct SecaoDePresenca: View {
    private typealias Textos = TextosDoProfissional.Presenca

    @Bindable private var viewModel: PresencaDoTurnoViewModel
    private var turno: MeuTurnoViewModel?
    @AccessibilityFocusState private var focoNoAviso: Bool
    @Environment(\.scenePhase) private var fase
    private let formatador = FormatadorFrila()

    public init(viewModel: PresencaDoTurnoViewModel, turno: MeuTurnoViewModel? = nil) {
        self.viewModel = viewModel
        self.turno = turno
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
            if let aCaminho = situacaoACaminho {
                linha(aCaminho).accessibilityIdentifier("a-caminho-situacao")
            }
            if let situacao = situacaoDoCheckin {
                linha(situacao).accessibilityIdentifier("checkin-situacao")
            }
            if let situacao = situacaoDoCheckout {
                linha(situacao).accessibilityIdentifier("checkout-situacao")
            }
            if viewModel.verificacao == .naoVerificado {
                AvisoFrila(verbatim: Textos.naoVerificadaAviso, tom: .alerta)
                    .accessibilityIdentifier("presenca-nao-verificada")
            }
            if let erro = viewModel.mensagemDeErro {
                AvisoFrila(verbatim: erro, tom: .erro).accessibilityIdentifier("presenca-erro")
            }
            if let erro = turno?.mensagemErroACaminho {
                AvisoFrila(verbatim: erro, tom: .erro).accessibilityIdentifier("a-caminho-erro")
                if turno?.podeTentarAvisarDeNovo == true {
                    botaoPresencaInativo(
                        verbatim: TextosDoProfissional.Turnos.tentarDeNovo,
                        identificador: "tentar-a-caminho-de-novo"
                    ) {
                        Task { await turno?.avisarACaminho() }
                    }
                }
            }
            acoes
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("presenca-do-turno")
        .onChange(of: viewModel.etapa) { _, nova in
            switch nova {
            case .explicando, .semGPS: focoNoAviso = true
            case .parada, .lendo, .enviando: break
            }
        }
        .task { await viewModel.atualizarPermissaoDaLocalizacao() }
        .onChange(of: fase) { _, nova in
            if nova == .active { Task { await viewModel.atualizarPermissaoDaLocalizacao() } }
        }
        .onChange(of: turno?.aCaminhoEm) { _, _ in anunciar(situacaoACaminho?.texto) }
        .onChange(of: viewModel.checkin) { _, _ in anunciar(situacaoDoCheckin?.texto) }
        .onChange(of: viewModel.checkout) { _, _ in anunciar(situacaoDoCheckout?.texto) }
    }

    // MARK: - Ações

    @ViewBuilder
    private var acoes: some View {
        switch viewModel.etapa {
        case .parada:
            if viewModel.pedePrecisaoAntes {
                AvisoFrila(verbatim: Textos.avisoPrecisaoDesligada, tom: .alerta)
                    .accessibilityIdentifier("aviso-precisao-desligada")
                linkParaAjustes
            }
            if viewModel.checkinAntecipadoDemais {
                AvisoFrila(verbatim: Textos.avisoCheckinAntecipado, tom: .informativo)
                    .accessibilityIdentifier("aviso-checkin-antecipado")
            } else if viewModel.podeFazerCheckout {
                botaoPresencaAtivo(
                    verbatim: Textos.fazerCheckout,
                    identificador: "fazer-checkout"
                ) {
                    Task { await viewModel.iniciar(.checkout) }
                }
            }
        case .explicando:
            VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
                aviso(titulo: Textos.explicacaoTitulo, textos: [Textos.explicacao, Textos.explicacaoPrecisao], identificador: "explicacao-localizacao")
                botaoPresencaAtivo(
                    verbatim: Textos.continuar,
                    identificador: "permitir-localizacao"
                ) {
                    Task { await viewModel.continuarComPermissao() }
                }
                botaoPresencaInativo(
                    verbatim: Textos.agoraNao,
                    identificador: "cancelar-presenca"
                ) {
                    viewModel.cancelar()
                }
            }
            .cartaoFrila()
        case .lendo:
            progresso(Textos.lendo)
        case .enviando:
            progresso(Textos.enviando)
        case let .semGPS(registro, motivo):
            VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
                aviso(
                    titulo: Textos.semGPSTitulo,
                    textos: [texto(motivo), registro == .checkin ? Textos.manualExplicacao : Textos.saidaSemLocalizacaoExplicacao],
                    identificador: "sem-gps"
                )
                botaoPresencaAtivo(
                    verbatim: registro == .checkin ? Textos.checkinManual : Textos.saidaSemLocalizacao,
                    identificador: "registro-manual"
                ) {
                    Task { await viewModel.registrarSemGPS() }
                }
                botaoPresencaInativo(
                    verbatim: Textos.tentarGPS,
                    identificador: "tentar-gps"
                ) {
                    Task { await viewModel.tentarGPSDeNovo() }
                }
                if motivo == .permissaoNegada || motivo == .localizacaoAproximada {
                    linkParaAjustes
                }
                botaoPresencaInativo(
                    verbatim: Textos.agoraNao,
                    identificador: "cancelar-presenca"
                ) {
                    viewModel.cancelar()
                }
            }
            .cartaoFrila()
        }
    }

    @ViewBuilder
    private var linkParaAjustes: some View {
        if let ajustes = URL(string: UIApplication.openSettingsURLString) {
            Link(destination: ajustes) {
                Text(verbatim: Textos.abrirAjustes)
                    .font(FrilaTipo.meta.weight(.semibold))
                    .underline()
                    .foregroundStyle(FrilaCor.texto)
            }
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
            .contentShape(Rectangle())
            .accessibilityIdentifier("abrir-ajustes")
        }
    }

    private func botaoPresencaAtivo(
        verbatim titulo: String,
        identificador: String,
        carregando: Bool = false,
        acao: @escaping () -> Void
    ) -> some View {
        Button(action: acao) {
            Group {
                if carregando {
                    ProgressView().tint(FrilaCor.sobreAcao)
                } else {
                    Text(verbatim: titulo)
                        .font(FrilaTipo.rotuloSecundario)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, FrilaEspaco.grande)
            .padding(.vertical, FrilaEspaco.pequeno)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
            .foregroundStyle(FrilaCor.sobreAcao)
            .background(FrilaCor.acao, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.tatil)
        .disabled(carregando)
        .accessibilityLabel(Text(verbatim: titulo))
        .accessibilityIdentifier(identificador)
    }

    private func botaoPresencaInativo(
        verbatim titulo: String,
        identificador: String,
        desabilitado: Bool = false,
        acao: @escaping () -> Void
    ) -> some View {
        Button(action: acao) {
            Text(verbatim: titulo)
                .font(FrilaTipo.rotuloSecundario)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, FrilaEspaco.grande)
                .padding(.vertical, FrilaEspaco.pequeno)
                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
                .foregroundStyle(FrilaCor.texto)
                .background(FrilaCor.superficie, in: Capsule())
                .overlay(Capsule().strokeBorder(FrilaCor.borda, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.tatil)
        .disabled(desabilitado)
        .accessibilityLabel(Text(verbatim: titulo))
        .accessibilityIdentifier(identificador)
    }

    private func aviso(titulo: String, textos: [String], identificador: String) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(verbatim: titulo)
                .font(FrilaTipo.meta.weight(.semibold))
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

    // MARK: - Situação

    private struct LinhaDeSituacao {
        let texto: String
        let icone: String
        let cor: Color
    }

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
            if viewModel.verificacao == .naoVerificado {
                return LinhaDeSituacao(texto: Textos.checkinNaoConfirmado(hora), icone: "xmark.seal", cor: FrilaCor.textoSecundario)
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
            return nil
        case let .naFila(feito):
            return LinhaDeSituacao(texto: Textos.checkoutNaFila(formatador.hora(feito.instante)), icone: "wifi.slash", cor: FrilaCor.alerta)
        case let .registrado(feito):
            return LinhaDeSituacao(texto: Textos.checkoutRegistrado(formatador.hora(feito.instante), metros: feito.distanciaMetros), icone: "checkmark.circle.fill", cor: FrilaCor.texto)
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
