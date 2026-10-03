// VISUAL PROVISÓRIO: o design de alta fidelidade do turno do contratante ainda não chegou (#19).

import FrilaDominio
import SwiftUI

enum TextosDoAcompanhamento {
    static let titulo = String(localized: "Acompanhar turno", bundle: bundleApresentacao)
    static let chegada = String(localized: "Chegada", bundle: bundleApresentacao)
    static let aguardando = String(localized: "Ainda não fez o check-in.", bundle: bundleApresentacao)
    static let aCaminho = String(localized: "Avisou que está a caminho às %@.", bundle: bundleApresentacao)
    static let manualPendente = String(localized: "Fez o check-in manual, sem confirmação pelo GPS.", bundle: bundleApresentacao)
    static let explicacaoDaConfirmacao = String(localized: "Confirme se a pessoa chegou. Sem a sua confirmação, o turno fica como não verificado.", bundle: bundleApresentacao)
    static let confirmarPresenca = String(localized: "Confirmar presença", bundle: bundleApresentacao)
    static let verificada = String(localized: "Presença verificada.", bundle: bundleApresentacao)
    static let naoVerificada = String(localized: "Presença não verificada.", bundle: bundleApresentacao)
    static let emAtraso = String(localized: "Passaram 15 minutos do início e não há check-in. Você pode esperar ou reabrir a vaga.", bundle: bundleApresentacao)
    static let reabrirVaga = String(localized: "Reabrir vaga", bundle: bundleApresentacao)
    static let reabrirPergunta = String(localized: "Reabrir a vaga?", bundle: bundleApresentacao)
    static let reabrirAviso = String(localized: "Conta como falta para %@, e a vaga volta a ser oferecida a outros profissionais.", bundle: bundleApresentacao)
    static let esperar = String(localized: "Esperar", bundle: bundleApresentacao)
    static let cancelada = String(localized: "Esta posição foi cancelada.", bundle: bundleApresentacao)
    static let presencaConfirmada = String(localized: "Presença confirmada.", bundle: bundleApresentacao)
    static let vagaReaberta = String(localized: "Vaga reaberta. A falta foi registrada, e a posição voltou a ser oferecida.", bundle: bundleApresentacao)
    static let faltaSemReabertura = String(localized: "Falta registrada. Falta menos de 1 hora para o fim do turno, e a vaga não foi reaberta.", bundle: bundleApresentacao)
    static let antesDaTolerancia = String(localized: "Ainda não passaram 15 minutos do início do turno.", bundle: bundleApresentacao)
    static let situacaoMudou = String(localized: "A situação deste turno mudou. Atualizamos a tela.", bundle: bundleApresentacao)
    static let situacaoMudouSemAtualizar = String(localized: "A situação deste turno mudou.", bundle: bundleApresentacao)
    static let desatualizado = String(localized: "Não foi possível atualizar. O que aparece aqui pode estar desatualizado.", bundle: bundleApresentacao)
    static let falhaAoCarregarVaga = String(localized: "Não foi possível carregar a vaga. Tente novamente.", bundle: bundleApresentacao)
    static let falhaAoCarregar = String(localized: "Não foi possível carregar o turno. Tente novamente.", bundle: bundleApresentacao)
    static let naoEncontrado = String(localized: "Não encontramos este turno.", bundle: bundleApresentacao)
    static let profissional = String(localized: "Profissional confirmado", bundle: bundleApresentacao)
    static let presencasAConfirmar = String(localized: "Presenças a confirmar", bundle: bundleApresentacao)
    static let atrasos = String(localized: "Em atraso", bundle: bundleApresentacao)
    static let semCheckin = String(localized: "Sem check-in 15 minutos depois do início.", bundle: bundleApresentacao)
    static let acompanharTurno = titulo
    static let vagaNaoEncontrada = String(localized: "Não encontramos esta vaga.", bundle: bundleApresentacao)
    static let periodo = String(localized: "%@ – %@", bundle: bundleApresentacao)
    static let checkinNoLocal = String(localized: "Check-in no local às %@.", bundle: bundleApresentacao)
    static let checkinManual = String(localized: "Check-in manual às %@.", bundle: bundleApresentacao)
    static let checkinGenerico = String(localized: "Check-in às %@.", bundle: bundleApresentacao)
    static let checkinConfirmado = String(localized: "Check-in confirmado às %@.", bundle: bundleApresentacao)
    static let causaProfissional = String(localized: "Cancelado pelo profissional.", bundle: bundleApresentacao)
    static let causaEstabelecimento = String(localized: "Cancelado pelo estabelecimento.", bundle: bundleApresentacao)
    static let causaReaberturaPorAtraso = String(localized: "Reabertura por atraso.", bundle: bundleApresentacao)
    static let causaNoShowSemCheckin = String(localized: "Turno encerrado sem check-in.", bundle: bundleApresentacao)
    static let causaOutro = String(localized: "Posição cancelada.", bundle: bundleApresentacao)
    static let contouFalta = String(localized: "Contou como falta para o profissional.", bundle: bundleApresentacao)
    static let naoContouFalta = String(localized: "Não contou como falta.", bundle: bundleApresentacao)
    static let motivoCancelamento = String(localized: "Motivo: %@", bundle: bundleApresentacao)
    static let canceladaEm = String(localized: "Cancelada em %@.", bundle: bundleApresentacao)

    static func detalheDoCheckin(em hora: String, tipo: TipoRegistro?) -> String {
        switch tipo {
        case .geolocalizado:
            String(format: checkinNoLocal, hora)
        case .manual:
            String(format: checkinManual, hora)
        case .none:
            String(format: checkinGenerico, hora)
        }
    }

    static func textoDaCausa(_ causa: CausaDoCancelamento) -> String {
        switch causa {
        case .profissional: causaProfissional
        case .estabelecimento: causaEstabelecimento
        case .reaberturaPorAtraso: causaReaberturaPorAtraso
        case .noShowSemCheckin: causaNoShowSemCheckin
        case .outro: causaOutro
        }
    }

    static func textoDaFalta(_ falta: Bool) -> String {
        falta ? contouFalta : naoContouFalta
    }

    static func resultado(_ resultado: ResultadoDoAcompanhamento) -> String {
        switch resultado {
        case .presencaConfirmada: presencaConfirmada
        case .vagaReaberta: vagaReaberta
        case .faltaSemReabertura: faltaSemReabertura
        case let .posicaoCancelada(reaberta): reaberta ? TextosDoCancelamento.posicaoCanceladaReaberta : TextosDoCancelamento.posicaoCanceladaDescoberta
        case .vagaCancelada: TextosDoCancelamento.vagaCancelada
        case .cancelamentoNaFila: TextosDoCancelamento.naFila
        }
    }

    /// Só diz "Atualizamos a tela" quando a releitura depois da recusa deu certo.
    static func falha(_ falha: FalhaDoAcompanhamento, desatualizado: Bool) -> String {
        switch falha {
        case .antesDaTolerancia: antesDaTolerancia
        case .situacaoMudou: desatualizado ? situacaoMudouSemAtualizar : situacaoMudou
        case let .api(erro): MensagemDoErroAPI.texto(erro)
        }
    }

    static func nome(_ turno: TurnoAcompanhado) -> String {
        turno.posicao.profissional?.nome ?? profissional
    }
}

/// O turno visto por quem opera a casa: a chegada do profissional, a confirmação do check-in manual
/// e a reabertura por atraso. Recebe o turno pelo id, que é o que o aviso do push traz.
struct TelaTurnoDoContratante: View {
    let viewModel: AcompanhamentoViewModel
    let turnoID: UUID
    let api: (any ApiCliente)?
    @State private var cancelamento: CancelamentoViewModel?
    @State private var suporteTurno: TurnoAcompanhado?
    @Environment(BloqueiosDaSessao.self) private var bloqueiosDaSessao: BloqueiosDaSessao?
    @State private var bloqueiosLocais = BloqueiosDaSessao()
    private var bloqueios: BloqueiosDaSessao { bloqueiosDaSessao ?? bloqueiosLocais }
    private let formatador = FormatadorFrila()

    init(viewModel: AcompanhamentoViewModel, turnoID: UUID, api: (any ApiCliente)? = nil) {
        self.viewModel = viewModel
        self.turnoID = turnoID
        self.api = api ?? viewModel.api
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                if let turno = viewModel.turno(turnoID: turnoID) {
                    conteudo(turno)
                } else if viewModel.falhouAoCarregar {
                    // Sem leitura que tenha dado certo, não dá para dizer que o turno não existe.
                    AvisoFrila(verbatim: TextosDoAcompanhamento.falhaAoCarregar, tom: .erro)
                    BotaoSecundario("Tentar novamente") { Task { await viewModel.carregar() } }
                        .accessibilityIdentifier("tentar-de-novo-turno")
                } else if viewModel.painel == nil {
                    EstadoCarregando()
                } else {
                    AvisoFrila(verbatim: TextosDoAcompanhamento.naoEncontrado, tom: .informativo)
                        .accessibilityIdentifier("turno-contratante-nao-encontrado")
                }
            }
            .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
        .navigationTitle(TextosDoAcompanhamento.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .task { if viewModel.painel == nil { await viewModel.carregar() } }
        .refreshable { await viewModel.carregar() }
        .sheet(item: $cancelamento) { folha in
            FolhaDeCancelamento(viewModel: folha) { cancelamento = nil }
        }
        .sheet(item: $suporteTurno) { turno in
            FolhaSuporteTurno(
                viewModel: SuporteTurnoViewModel(
                    dados: ContextoSuporteTurno(turnoAcompanhado: turno)
                )
            )
        }
        .accessibilityIdentifier("turno-do-contratante")
    }

    @ViewBuilder private func conteudo(_ turno: TurnoAcompanhado) -> some View {
        Text(verbatim: TextosDoAcompanhamento.nome(turno))
            .font(.largeTitle.bold())
            .accessibilityAddTraits(.isHeader)
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: turno.vaga.funcao).font(.headline)
            Text(verbatim: turno.vaga.local)
            Text(verbatim: String(
                format: TextosDoAcompanhamento.periodo, formatador.hora(turno.vaga.periodo.inicio), formatador.hora(turno.vaga.periodo.fim)
            ))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FrilaEspaco.medio)
        .cartaoFrila()
        .accessibilityElement(children: .combine)

        AvisosDoAcompanhamento(viewModel: viewModel)

        Text(verbatim: TextosDoAcompanhamento.chegada).font(.title2.bold()).accessibilityAddTraits(.isHeader)
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            chegada(turno)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FrilaEspaco.medio)
        .cartaoFrila()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chegada-do-turno")

        if viewModel.podeCancelar(turno) {
            BotaoDeCancelamento(titulo: TextosDoCancelamento.tituloPosicao) { cancelamento = viewModel.criarCancelamento(de: turno) }
                .accessibilityIdentifier("cancelar-posicao-\(turno.posicao.id)")
        }

        rodapeAcoes(turno)
    }

    // MARK: - Ações de suporte e segurança (#21, #39)

    @ViewBuilder
    private func rodapeAcoes(_ turno: TurnoAcompanhado) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            botaoSuporte(turno)
            rodapeSeguranca(turno)
        }
    }

    private func botaoSuporte(_ turno: TurnoAcompanhado) -> some View {
        Button {
            suporteTurno = turno
        } label: {
            Text(verbatim: TextosDoSuporte.botaoAjudaTurno)
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("botao-ajuda-turno")
        .accessibilityHint(Text(verbatim: TextosDoSuporte.dicaAjudaTurno))
    }

    @ViewBuilder
    private func rodapeSeguranca(_ turno: TurnoAcompanhado) -> some View {
        if let profissional = turno.posicao.profissional,
           let api = viewModel.api ?? api {
            AcoesDeSeguranca(
                perfil: profissional,
                turnoID: turno.posicao.turnoID,
                api: api,
                bloqueios: bloqueios,
                identificadorDenunciar: "denunciar-\(turno.posicao.id)",
                identificadorBloquear: "bloquear-\(turno.posicao.id)"
            )
        }
    }

    @ViewBuilder private func chegada(_ turno: TurnoAcompanhado) -> some View {
        switch viewModel.chegada(turno) {
        case .aguardando:
            Text(verbatim: TextosDoAcompanhamento.aguardando)
        case let .aCaminho(desde):
            Text(verbatim: String(format: TextosDoAcompanhamento.aCaminho, formatador.hora(desde)))
        case .manualPendente:
            Text(verbatim: TextosDoAcompanhamento.manualPendente).font(.headline)
            Text(verbatim: TextosDoAcompanhamento.explicacaoDaConfirmacao).foregroundStyle(FrilaCor.textoSecundario)
            if let checkinEm = turno.posicao.checkinEm {
                Text(verbatim: TextosDoAcompanhamento.detalheDoCheckin(em: formatador.hora(checkinEm), tipo: turno.posicao.checkinTipo ?? .manual))
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityIdentifier("detalhe-checkin-\(turnoID)")
            }
            if viewModel.podeConfirmar(turno) {
                BotaoPrimario(verbatim: TextosDoAcompanhamento.confirmarPresenca, carregando: viewModel.emAndamento.contains(turno.id)) {
                    Task { await viewModel.confirmarPresenca(turno) }
                }
                .accessibilityIdentifier("confirmar-presenca-\(turnoID)")
            }
        case .emAtraso:
            AvisoFrila(verbatim: TextosDoAcompanhamento.emAtraso, tom: .alerta)
            if viewModel.podeReabrir(turno) {
                BotaoSecundario(verbatim: TextosDoAcompanhamento.reabrirVaga) { viewModel.pedirReabertura(turno) }
                    .disabled(viewModel.emAndamento.contains(turno.id))
                    .accessibilityIdentifier("reabrir-vaga-\(turno.id)")
            }
        case .verificada:
            Text(verbatim: TextosDoAcompanhamento.verificada).font(.headline)
                .accessibilityIdentifier("presenca-verificada-\(turnoID)")
            if let checkinEm = turno.posicao.checkinEm {
                Text(verbatim: TextosDoAcompanhamento.detalheDoCheckin(em: formatador.hora(checkinEm), tipo: turno.posicao.checkinTipo))
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityIdentifier("detalhe-checkin-\(turnoID)")
            }
            if let confirmadoEm = turno.posicao.checkinConfirmadoEm {
                Text(verbatim: String(format: TextosDoAcompanhamento.checkinConfirmado, formatador.hora(confirmadoEm)))
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityIdentifier("detalhe-confirmacao-\(turnoID)")
            }
        case .naoVerificada:
            Text(verbatim: TextosDoAcompanhamento.naoVerificada)
        case .cancelada:
            // O bloco inteiro usa o id do turno: `turno.id` é o da posição, outro valor.
            Text(verbatim: TextosDoAcompanhamento.cancelada).font(.headline)
                .accessibilityIdentifier("posicao-cancelada-\(turnoID)")
            if let cancelamento = turno.posicao.cancelamento {
                VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                    Text(verbatim: TextosDoAcompanhamento.textoDaCausa(cancelamento.causa))
                        .accessibilityIdentifier("cancelamento-causa-\(turnoID)")
                    Text(verbatim: TextosDoAcompanhamento.textoDaFalta(cancelamento.falta))
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .accessibilityIdentifier("cancelamento-falta-\(turnoID)")
                    if let motivo = cancelamento.motivo, !motivo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(verbatim: String(format: TextosDoAcompanhamento.motivoCancelamento, motivo))
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .accessibilityIdentifier("cancelamento-motivo-\(turnoID)")
                    }
                    Text(verbatim: String(format: TextosDoAcompanhamento.canceladaEm, formatador.dataEHora(cancelamento.canceladaEm)))
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .accessibilityIdentifier("cancelamento-data-\(turnoID)")
                }
            }
        }
    }
}

/// O que aconteceu na última confirmação, reabertura ou cancelamento, para a tela do turno e para Minhas vagas.
struct AvisosDoAcompanhamento: View {
    let viewModel: AcompanhamentoViewModel

    var body: some View {
        if let resultado = viewModel.resultado {
            AvisoFrila(verbatim: TextosDoAcompanhamento.resultado(resultado), tom: .informativo)
                .accessibilityIdentifier("resultado-do-acompanhamento")
        }
        if let falha = viewModel.falha {
            AvisoFrila(verbatim: TextosDoAcompanhamento.falha(falha, desatualizado: viewModel.falhouAoCarregar), tom: .erro)
                .accessibilityIdentifier("falha-do-acompanhamento")
        }
        // A leitura falhou com um painel já na tela: o que aparece pode estar velho.
        if viewModel.falhouAoCarregar, viewModel.painel != nil {
            AvisoFrila(verbatim: TextosDoAcompanhamento.desatualizado, tom: .alerta)
                .accessibilityIdentifier("acompanhamento-desatualizado")
            BotaoSecundario("Tentar novamente") { Task { await viewModel.carregar() } }
                .accessibilityIdentifier("atualizar-acompanhamento")
        }
    }
}

/// Reabrir conta como falta para o profissional: a pergunta vem antes da chamada. Fica na pilha de
/// navegação de Minhas vagas, uma vez só, e vale também para a tela do turno.
struct ConfirmacaoDeReabertura: ViewModifier {
    let viewModel: AcompanhamentoViewModel

    func body(content: Content) -> some View {
        let turno = viewModel.reaberturaEmConfirmacao
        content.alert(
            Text(verbatim: TextosDoAcompanhamento.reabrirPergunta),
            isPresented: Binding(get: { viewModel.reaberturaEmConfirmacao != nil }, set: { if !$0 { viewModel.desistirDaReabertura() } })
        ) {
            Button(role: .destructive) {
                viewModel.confirmarReabertura()
            } label: {
                Text(verbatim: TextosDoAcompanhamento.reabrirVaga)
            }
            Button(role: .cancel) {
                viewModel.desistirDaReabertura()
            } label: {
                Text(verbatim: TextosDoAcompanhamento.esperar)
            }
        } message: {
            Text(verbatim: String(format: TextosDoAcompanhamento.reabrirAviso, turno.map(TextosDoAcompanhamento.nome) ?? TextosDoAcompanhamento.profissional))
        }
    }
}

/// O que pede uma decisão da casa agora, no topo de Minhas vagas: presenças a confirmar e atrasos.
struct PendenciasDoContratante: View {
    let viewModel: AcompanhamentoViewModel
    let abrir: (UUID) -> Void

    var body: some View {
        let pendentes = viewModel.pendentes
        let atrasos = viewModel.emAtraso
        AvisosDoAcompanhamento(viewModel: viewModel)
        if !pendentes.isEmpty {
            secao(TextosDoAcompanhamento.presencasAConfirmar, id: "presencas-a-confirmar") {
                ForEach(pendentes) { turno in
                    cartao(turno, detalhe: TextosDoAcompanhamento.explicacaoDaConfirmacao) {
                        if viewModel.podeConfirmar(turno) {
                            BotaoPrimario(verbatim: TextosDoAcompanhamento.confirmarPresenca, carregando: viewModel.emAndamento.contains(turno.id)) {
                                Task { await viewModel.confirmarPresenca(turno) }
                            }
                            .accessibilityIdentifier("confirmar-presenca-\(turno.posicao.turnoID?.uuidString ?? "")")
                        }
                    }
                }
            }
        }
        if !atrasos.isEmpty {
            secao(TextosDoAcompanhamento.atrasos, id: "turnos-em-atraso") {
                ForEach(atrasos) { turno in
                    cartao(turno, detalhe: TextosDoAcompanhamento.semCheckin) {
                        if viewModel.podeReabrir(turno) {
                            BotaoSecundario(verbatim: TextosDoAcompanhamento.reabrirVaga) { viewModel.pedirReabertura(turno) }
                                .disabled(viewModel.emAndamento.contains(turno.id))
                                .accessibilityIdentifier("reabrir-vaga-\(turno.id)")
                        }
                    }
                }
            }
        }
    }

    private func secao(_ titulo: String, id: String, @ViewBuilder conteudo: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: titulo).font(.title3.bold()).accessibilityAddTraits(.isHeader)
            conteudo()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(id)
    }

    private func cartao(_ turno: TurnoAcompanhado, detalhe: String, @ViewBuilder acao: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoAcompanhamento.nome(turno)).font(.headline)
            Text(verbatim: turno.vaga.funcao).font(.subheadline)
            Text(verbatim: detalhe).font(.subheadline).foregroundStyle(FrilaCor.textoSecundario)
            acao()
            if let turnoID = turno.posicao.turnoID {
                Button { abrir(turnoID) } label: {
                    Text(verbatim: TextosDoAcompanhamento.acompanharTurno).frame(minHeight: FrilaMetrica.alvoMinimo)
                }
                .accessibilityIdentifier("acompanhar-turno-\(turnoID)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FrilaEspaco.medio)
        .cartaoFrila()
        .accessibilityElement(children: .contain)
    }
}
