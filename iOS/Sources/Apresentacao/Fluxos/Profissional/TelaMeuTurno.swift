import FrilaDominio
import SwiftUI
#if DEBUG
import Observation
#endif

/// Tela do turno da pele nova (T4, T8 e estados): "Seu turno é hoje", card de status
/// com a linha de etapas, avisos da presença, "Como chegar" com miniatura do mapa,
/// "Orientações da casa", botão primário flutuante (Estou a caminho / MARCAR PRESENÇA)
/// e ações discretas ao final da rolagem.
public struct TelaMeuTurno: View {
    @Bindable private var viewModel: MeuTurnoViewModel
    @State private var cancelamento: CancelamentoViewModel?
    @State private var suporteModel: SuporteTurnoViewModel?
    @Environment(BloqueiosDaSessao.self) private var bloqueiosDaSessao: BloqueiosDaSessao?
    @State private var bloqueiosLocais = BloqueiosDaSessao()
    private var bloqueios: BloqueiosDaSessao { bloqueiosDaSessao ?? bloqueiosLocais }
    private let formatador = FormatadorFrila()

    private var calendario: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = FormatadorFrila.fuso
        cal.locale = FormatadorFrila.locale
        return cal
    }

    public init(viewModel: MeuTurnoViewModel) {
        self.viewModel = viewModel
    }

    private var ehHoje: Bool {
        calendario.isDate(viewModel.turno.vaga.periodo.inicio, inSameDayAs: Date())
    }

    private var horarioComecou: Bool {
        Date() >= viewModel.turno.vaga.periodo.inicio
    }

    private var estaACaminho: Bool {
        viewModel.aCaminhoEm != nil || viewModel.avisandoACaminho
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                cabecalho
                cardDeStatus

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
                    // Avisos e botão no fluxo
                    if !viewModel.temCheckin {
                        if estaACaminho {
                            // T8 no fluxo
                            VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                                Text("Toque ao chegar. A localização é lida só neste toque.", bundle: bundleApresentacao)
                                    .font(FrilaTipo.meta)
                                    .foregroundStyle(FrilaCor.texto)
                                Text("Sem sinal de internet? A casa pode marcar sua presença no painel dela.", bundle: bundleApresentacao)
                                    .font(FrilaTipo.meta)
                                    .foregroundStyle(FrilaCor.textoSecundario)
                            }
                            .padding(.top, FrilaEspaco.minimo)
                        } else {
                            // T4 no fluxo
                            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                                Text("A localização é lida só neste toque.", bundle: bundleApresentacao)
                                    .font(FrilaTipo.meta)
                                    .foregroundStyle(FrilaCor.textoSecundario)
                                BotaoSecundario("Marcar presença") {
                                    Task { await viewModel.presenca?.iniciar(.checkin) }
                                }
                                .accessibilityIdentifier("fazer-checkin")
                            }
                            .padding(.top, FrilaEspaco.minimo)
                        }

                        SecaoComoChegar(
                            endereco: viewModel.turno.vaga.local,
                            distanciaTexto: viewModel.turno.vaga.regiaoAdministrativa.isEmpty ? nil : viewModel.turno.vaga.regiaoAdministrativa,
                            urlMapas: viewModel.urlMapas
                        )
                        .accessibilityIdentifier("como-chegar-do-turno")
                    }

                    SecaoOrientaçõesDaCasa(
                        observacoes: viewModel.observacoesDaVaga,
                        quemRecebe: viewModel.responsavelLocal ?? viewModel.quemRecebeExibicao,
                        traje: nil
                    )

                    if let presenca = viewModel.presenca {
                        SecaoDePresenca(viewModel: presenca, turno: viewModel)
                    }
                }

                if viewModel.podeAvaliar {
                    cartaoAvaliacao
                } else if let liberacao = viewModel.liberacaoDaAvaliacao {
                    AvisoFrila(verbatim: TextosDoProfissional.Avaliacao.liberaAs(formatador.hora(liberacao)), tom: .informativo)
                        .accessibilityIdentifier("aviso-avaliacao-libera")
                }

                AcoesDiscretasDoTurno(
                    podeCancelar: viewModel.podeCancelar,
                    horarioComecou: horarioComecou,
                    aoCancelar: { cancelamento = viewModel.criarCancelamentoViewModel() },
                    aoPedirSuporte: {
                        suporteModel = SuporteTurnoViewModel(
                            dados: ContextoSuporteTurno(turno: viewModel.turno),
                            api: viewModel.api
                        )
                    },
                    aoDenunciar: {
                        suporteModel = SuporteTurnoViewModel(
                            dados: ContextoSuporteTurno(turno: viewModel.turno),
                            api: viewModel.api
                        )
                    }
                )

                rodapeSeguranca
            }
            .padding(FrilaEspaco.medio)
            // Padding extra no fim para não ficar coberto pelo botão flutuante
            .padding(.bottom, botaoFlutuanteExiste ? 80 : 0)
        }
        .background(FrilaCor.fundo)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            botaoFlutuante
        }
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

    private var botaoFlutuanteExiste: Bool {
        if viewModel.cancelado || viewModel.temCheckin { return false }
        if estaACaminho { return true }
        return ehHoje && viewModel.podeExibirBotaoACaminho
    }

    // MARK: - Botão Flutuante

    @ViewBuilder
    private var botaoFlutuante: some View {
        if !viewModel.cancelado && !viewModel.temCheckin {
            if estaACaminho {
                // T8: Botão flutuante "MARCAR PRESENÇA" (64 pt) com mensagens de erro ou conferência
                VStack(spacing: FrilaEspaco.minimo) {
                    if viewModel.presenca?.ocupado == true {
                        Text("Conferindo se a presença foi marcada.", bundle: bundleApresentacao)
                            .font(FrilaTipo.meta)
                            .foregroundStyle(FrilaCor.texto)
                            .accessibilityIdentifier("mensagem-presenca")
                    } else if case let .semGPS(_, motivo) = viewModel.presenca?.etapa {
                        switch motivo {
                        case .longe:
                            Text(String(format: String(localized: "A presença não foi marcada. A localização lida está a mais de 50 m do %@. Aproxime-se do local e tente de novo.", bundle: bundleApresentacao), viewModel.turno.contraparte.nome))
                                .font(FrilaTipo.meta)
                                .foregroundStyle(FrilaCor.texto)
                                .accessibilityIdentifier("mensagem-presenca")
                        case .permissaoNegada, .localizacaoAproximada:
                            VStack(spacing: FrilaEspaco.fio) {
                                Text("A presença não foi marcada. O Frila não tem acesso à sua localização. Permita em Ajustes e toque de novo.", bundle: bundleApresentacao)
                                    .font(FrilaTipo.meta)
                                    .foregroundStyle(FrilaCor.texto)
                                    .accessibilityIdentifier("mensagem-presenca")
                                if let ajustes = URL(string: UIApplication.openSettingsURLString) {
                                    Link(destination: ajustes) {
                                        Text("Abrir Ajustes", bundle: bundleApresentacao)
                                            .font(FrilaTipo.meta.weight(.semibold))
                                            .underline()
                                            .foregroundStyle(FrilaCor.texto)
                                    }
                                    .accessibilityIdentifier("abrir-ajustes")
                                }
                            }
                        case .semSinal:
                            Text("A presença não foi marcada. Sem sinal de internet, nada saiu do seu celular. Toque de novo quando o sinal voltar.", bundle: bundleApresentacao)
                                .font(FrilaTipo.meta)
                                .foregroundStyle(FrilaCor.texto)
                                .accessibilityIdentifier("mensagem-presenca")
                        default:
                            if let erro = viewModel.presenca?.mensagemDeErro {
                                Text(verbatim: erro)
                                    .font(FrilaTipo.meta)
                                    .foregroundStyle(FrilaCor.texto)
                                    .accessibilityIdentifier("mensagem-presenca")
                            }
                        }
                    }

                    Button {
                        Task { await viewModel.presenca?.iniciar(.checkin) }
                    } label: {
                        Text("MARCAR PRESENÇA", bundle: bundleApresentacao)
                            .font(FrilaTipo.botaoPrimario)
                            .foregroundStyle(FrilaCor.sobreAcao)
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(viewModel.presenca?.ocupado == true ? FrilaCor.controle : FrilaCor.acao, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.tatil)
                    .disabled(viewModel.presenca?.ocupado == true)
                    .accessibilityIdentifier("fazer-checkin")
                }
                .padding(.horizontal, FrilaEspaco.medio)
                .padding(.bottom, FrilaEspaco.pequeno)
                .background(FrilaCor.fundo.opacity(0.95))
            } else if ehHoje && viewModel.podeExibirBotaoACaminho {
                // T4: Botão flutuante "Estou a caminho" (48 pt)
                BotaoPrimario("Estou a caminho", carregando: viewModel.avisandoACaminho) {
                    Task { await viewModel.avisarACaminho() }
                }
                .padding(.horizontal, FrilaEspaco.medio)
                .padding(.bottom, FrilaEspaco.pequeno)
                .background(FrilaCor.fundo.opacity(0.95))
                .accessibilityIdentifier("botao-a-caminho")
            }
        }
    }

    // MARK: - Cabeçalho

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
            if ehHoje {
                Text("Seu turno é hoje", bundle: bundleApresentacao)
                    .font(FrilaTipo.tituloDaTela)
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("estado-do-turno")

                if horarioComecou {
                    Text(String(format: String(localized: "O horário começou às %@.", bundle: bundleApresentacao), formatadorHora(viewModel.turno.vaga.periodo.inicio)))
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .accessibilityIdentifier("apoio-horario-comecou")
                }
            } else {
                Text(String(format: String(localized: "Seu turno é %@", bundle: bundleApresentacao), formatadorDataCurta(viewModel.turno.vaga.periodo.inicio)))
                    .font(FrilaTipo.tituloDaTela)
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("estado-do-turno")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Card de Status

    private var cardDeStatus: some View {
        let casa = viewModel.turno.contraparte.nome
        let dataTexto = ehHoje ? String(localized: "Hoje", bundle: bundleApresentacao) : formatadorDataCurta(viewModel.turno.vaga.periodo.inicio)
        let horarioTexto = formatadorIntervalo(viewModel.turno.vaga.periodo)

        if viewModel.temCheckin {
            return CardDeStatusDoTurno(
                seloTexto: "Presença marcada",
                seloEstilo: .andamento,
                casaNome: casa,
                apoioTexto: String(format: String(localized: "Você chegou ao %@.", bundle: bundleApresentacao), casa),
                dataTexto: dataTexto,
                horarioTexto: horarioTexto,
                etapaAtual: .presenca,
                etapasFeitas: [.confirmado, .aCaminho, .presenca]
            )
        } else if estaACaminho {
            return CardDeStatusDoTurno(
                seloTexto: "A caminho",
                seloEstilo: .andamento,
                casaNome: casa,
                dataTexto: dataTexto,
                horarioTexto: horarioTexto,
                etapaAtual: .aCaminho,
                etapasFeitas: [.confirmado]
            )
        } else if viewModel.turno.estado == .cumprida {
            return CardDeStatusDoTurno(
                seloTexto: "Concluído",
                seloEstilo: .contorno,
                casaNome: casa,
                dataTexto: dataTexto,
                horarioTexto: horarioTexto,
                etapaAtual: .concluido,
                etapasFeitas: [.confirmado, .aCaminho, .presenca, .concluido]
            )
        } else {
            return CardDeStatusDoTurno(
                seloTexto: "Confirmado",
                seloEstilo: .destaque,
                seloIcone: "checkmark",
                casaNome: casa,
                dataTexto: dataTexto,
                horarioTexto: horarioTexto,
                etapaAtual: .confirmado,
                etapasFeitas: []
            )
        }
    }

    // MARK: - Apoio

    private var detalheNaTela: @MainActor @Sendable () -> Bool {
        let viewModel = viewModel
        return { viewModel.detalheCarregado }
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

    private var cartaoCancelamento: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoProfissional.Turnos.cancelamentoTitulo)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)
            if let causa = viewModel.causaDoCancelamento {
                Text(verbatim: causa).font(FrilaTipo.meta)
            }
            if let falta = viewModel.faltaNoCancelamento {
                Text(verbatim: falta)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cancelamento-do-turno")
    }

    private var cartaoAvaliacao: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoProfissional.Avaliacao.cartaoTitulo)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)

            if viewModel.jaAvaliado {
                if let resposta = viewModel.respostaAvaliacao {
                    Text(verbatim: TextosDoProfissional.Avaliacao.statusResposta(resposta))
                        .font(FrilaTipo.meta)
                        .accessibilityIdentifier("texto-status-avaliacao")
                } else {
                    Text(verbatim: TextosDoProfissional.Avaliacao.statusAvaliado)
                        .font(FrilaTipo.meta)
                        .accessibilityIdentifier("texto-status-avaliacao")
                }

                NavigationLink {
                    if let avaliacao = viewModel.criarAvaliacaoViewModel() {
                        TelaAvaliacao(viewModel: avaliacao)
                    }
                } label: {
                    HStack {
                        Image(systemName: "star.fill").accessibilityHidden(true)
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
                        Image(systemName: "star.fill").accessibilityHidden(true)
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

    private func formatadorHora(_ data: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = FormatadorFrila.locale
        formatter.timeZone = FormatadorFrila.fuso
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: data)
    }

    private func formatadorDataCurta(_ data: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = FormatadorFrila.locale
        formatter.timeZone = FormatadorFrila.fuso
        formatter.dateFormat = "EEE dd/MM"
        let raw = formatter.string(from: data).replacingOccurrences(of: ".", with: "")
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    private func formatadorIntervalo(_ periodo: Periodo) -> String {
        let f = DateFormatter()
        f.locale = FormatadorFrila.locale
        f.timeZone = FormatadorFrila.fuso
        f.dateFormat = "HH:mm"
        return "\(f.string(from: periodo.inicio)) às \(f.string(from: periodo.fim))"
    }
}
