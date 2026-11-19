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

    // Selos e etapas do cartão de status do turno (R6). Os selos nomeiam o estado; as etapas, o caminho.
    static let etapaConfirmado = String(localized: "Confirmado", bundle: bundleApresentacao)
    static let etapaACaminho = String(localized: "A caminho", bundle: bundleApresentacao)
    static let etapaPresenca = String(localized: "Presença", bundle: bundleApresentacao)
    static let etapaConcluido = String(localized: "Concluído", bundle: bundleApresentacao)
    static let seloPresencaAConfirmar = String(localized: "Presença a confirmar", bundle: bundleApresentacao)
    static let seloPresencaVerificada = String(localized: "Presença verificada", bundle: bundleApresentacao)
    static let seloNaoVerificada = String(localized: "Presença não verificada", bundle: bundleApresentacao)
    static let seloCancelada = String(localized: "Cancelada", bundle: bundleApresentacao)

    static func detalheDoCheckin(em hora: String, tipo: TipoRegistro?) -> String {
        switch tipo {
        case .geolocalizado:
            String(format: checkinNoLocal, hora)
        case .manual:
            String(format: checkinManual, hora)
        case .codigo, .none:
            // Presença verificada pelo código: a casa vê "Check-in às HH:MM" (desenho do check-in por código,
            // seção 6). O texto próprio espera o desenho.
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

/// O selo e a etapa do cartão de status do turno, a partir da chegada do profissional.
private struct SituacaoDoTurnoDaCasa {
    let selo: String
    let estilo: SeloDeStatus.Estilo
    let icone: String?
    /// A etapa atual da linha (0 a 3: Confirmado, A caminho, Presença, Concluído). `nil` quando não há caminho a mostrar.
    let etapa: Int?

    init(_ chegada: ChegadaDoProfissional) {
        switch chegada {
        case .aguardando:
            self.init(TextosDoAcompanhamento.etapaConfirmado, .destaque, "checkmark", 0)
        case .aCaminho:
            self.init(TextosDoAcompanhamento.etapaACaminho, .andamento, nil, 1)
        case .manualPendente:
            self.init(TextosDoAcompanhamento.seloPresencaAConfirmar, .contorno, nil, 2)
        case .emAtraso:
            self.init(TextosDoAcompanhamento.atrasos, .contorno, nil, 0)
        case .verificada:
            self.init(TextosDoAcompanhamento.seloPresencaVerificada, .andamento, "checkmark", 2)
        case .naoVerificada:
            self.init(TextosDoAcompanhamento.seloNaoVerificada, .encerrado, nil, nil)
        case .cancelada:
            self.init(TextosDoAcompanhamento.seloCancelada, .encerrado, nil, nil)
        }
    }

    private init(_ selo: String, _ estilo: SeloDeStatus.Estilo, _ icone: String?, _ etapa: Int?) {
        self.selo = selo
        self.estilo = estilo
        self.icone = icone
        self.etapa = etapa
    }
}

/// A linha de etapas do turno (DESIGN.md do protótipo): Confirmado, A caminho, Presença, Concluído. Marcador de 12 pt por
/// etapa, ligado ao seguinte por um traço de 2 pt: em tinta até a etapa atual, em `divisoria` dali em diante. As etapas
/// futuras são contorno. A atual leva o rótulo em 600 e em tinta. Em texto grande, vira uma lista, para o rótulo não cortar.
private struct LinhaDeEtapasDoTurnoDaCasa: View {
    let atual: Int
    @Environment(\.dynamicTypeSize) private var tamanhoDoTexto
    private let rotulos = [TextosDoAcompanhamento.etapaConfirmado, TextosDoAcompanhamento.etapaACaminho,
                           TextosDoAcompanhamento.etapaPresenca, TextosDoAcompanhamento.etapaConcluido]

    var body: some View {
        Group {
            if tamanhoDoTexto >= .xLarge { emLista } else { emLinha }
        }
        .accessibilityElement(children: .contain)
    }

    private var emLinha: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(rotulos.indices, id: \.self) { indice in
                VStack(spacing: FrilaEspaco.item) {
                    HStack(spacing: 0) {
                        trecho(existe: indice > 0, feito: indice <= atual)
                        marcador(indice)
                        trecho(existe: indice < rotulos.count - 1, feito: indice + 1 <= atual)
                    }
                    rotulo(indice).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(indice == atual ? .isSelected : [])
            }
        }
    }

    private var emLista: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            ForEach(rotulos.indices, id: \.self) { indice in
                HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.item) {
                    marcador(indice)
                    rotulo(indice)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(indice == atual ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func marcador(_ indice: Int) -> some View {
        Group {
            if indice <= atual {
                Circle().fill(FrilaCor.texto)
            } else {
                Circle().strokeBorder(FrilaCor.bordaDoCampo, lineWidth: 2)
            }
        }
        .frame(width: 12, height: 12)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func trecho(existe: Bool, feito: Bool) -> some View {
        if existe {
            Rectangle().fill(feito ? FrilaCor.texto : FrilaCor.divisoria).frame(height: 2).frame(maxWidth: .infinity)
        } else {
            Color.clear.frame(height: 2).frame(maxWidth: .infinity)
        }
    }

    private func rotulo(_ indice: Int) -> some View {
        Text(verbatim: rotulos[indice])
            .font(indice == atual ? FrilaTipo.legenda.weight(.semibold) : FrilaTipo.legenda)
            .foregroundStyle(indice == atual ? FrilaCor.texto : FrilaCor.textoSecundario)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// O turno visto por quem opera a casa, no quadro "TurnoContratante" do MidFi do Fabrício: a chegada do
/// profissional, a confirmação do check-in manual e a reabertura por atraso. Recebe o turno pelo id,
/// que é o que o aviso do push traz.
///
/// Desenho (R6): o lado da casa não foi desenhado pelo Fabrício. A tela segue o detalhe do turno do profissional (T4 e
/// T8 do protótipo): título, cartão de status com selo e linha de etapas, o bloco de chegada, a ação principal ancorada
/// embaixo (um botão laranja só, "Confirmar presença") e as ações de risco e de suporte no fim, discretas.
struct TelaTurnoDoContratante: View {
    @State private var chamadaHabilitada = false
    /// O código de chegada (0.2.68): só existe com a chave `checkin_por_codigo` ligada; sem ela, a tela é a de hoje.
    @State private var codigoDaCasa: CodigoDaCasaViewModel?
    @State private var mostrarConfirmacaoDeSaida = false
    let viewModel: AcompanhamentoViewModel
    let turnoID: UUID
    let api: (any ApiCliente)?
    let sair: (() -> Void)?
    @State private var cancelamento: CancelamentoViewModel?
    @State private var suporteModel: SuporteTurnoViewModel?
    @Environment(BloqueiosDaSessao.self) private var bloqueiosDaSessao: BloqueiosDaSessao?
    @State private var bloqueiosLocais = BloqueiosDaSessao()
    private var bloqueios: BloqueiosDaSessao { bloqueiosDaSessao ?? bloqueiosLocais }
    private let formatador = FormatadorFrila()

    init(viewModel: AcompanhamentoViewModel, turnoID: UUID, api: (any ApiCliente)? = nil, sair: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.turnoID = turnoID
        self.api = api ?? viewModel.api
        self.sair = sair
    }

    var body: some View {
        conteudoDaTela
            .sheet(isPresented: $mostrarConfirmacaoDeSaida) { confirmacaoDeSaida }
    }

    @ViewBuilder
    private var conteudoDaTela: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                if let turno = viewModel.turno(turnoID: turnoID) {
                    conteudo(turno)
                } else if viewModel.falhouAoCarregar {
                    // Sem leitura que tenha dado certo, não dá para dizer que o turno não existe.
                    VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                        AvisoFrila(verbatim: TextosDoAcompanhamento.falhaAoCarregar, tom: .erro)
                        BotaoSecundario("Tentar novamente") { Task { await viewModel.carregar() } }
                            .accessibilityIdentifier("tentar-de-novo-turno")
                    }
                } else if viewModel.painel == nil {
                    EstadoCarregando()
                } else {
                    AvisoFrila(verbatim: TextosDoAcompanhamento.naoEncontrado, tom: .informativo)
                        .accessibilityIdentifier("turno-contratante-nao-encontrado")
                }
            }
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.top, FrilaEspaco.item)
            .padding(.bottom, FrilaEspaco.grupo)
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
        // Sem título na barra: o título da tela é conteúdo nosso (DESIGN.md, "Estrutura"); a barra só leva o voltar.
        .navigationBarTitleDisplayMode(.inline)
        // O identificador da tela vem antes do rodapé: depois dele, cobriria o botão ancorado e apagaria o dele.
        .accessibilityIdentifier("turno-do-contratante")
        .rodapeAncoradoSe(viewModel.turno(turnoID: turnoID).map(confirmarPresencaNoRodape) ?? false) { rodapeDaAcao }
        .task { if viewModel.painel == nil || viewModel.contaID == nil { await viewModel.carregar() } }
        .task(id: viewModel.turno(turnoID: turnoID)?.vaga.periodo.fim) {
            if let turno = viewModel.turno(turnoID: turnoID) { await viewModel.aguardarLiberacaoDaAvaliacao(turno) }
        }
        .refreshable { await viewModel.carregar() }
        // O `.task` acima só carrega sem painel: com o painel de Minhas vagas, quem relê ao abrir o
        // turno é a atualização automática, com o intervalo mínimo.
        .atualizacaoAutomatica(.turnoDoContratante, aoAparecer: .sempre) {
            await viewModel.atualizarEmSilencio(para: turnoID)
        }
        .onReceive(NotificationCenter.default.publisher(for: .filaDeAcoesAtualizada)) { _ in
            Task { await viewModel.carregarDaFila(para: turnoID) }
        }
        .sheet(item: $cancelamento) { folha in
            FolhaDeCancelamento(viewModel: folha) { cancelamento = nil }
        }
        .sheet(item: $suporteModel) { model in
            FolhaSuporteTurno(viewModel: model)
        }
        .task {
            guard let api else { return }
            let recursos = (try? await PrazoDaAbertura.esperar(.seconds(15)) {
                try await api.configuracaoDoApp()
            })?.recursos
            chamadaHabilitada = recursos?.chamadaDireta == true
            if recursos?.checkinPorCodigo == true, codigoDaCasa == nil {
                codigoDaCasa = CodigoDaCasaViewModel(turnoID: turnoID, api: api, aoConfirmar: {
                    Task { await viewModel.atualizarEmSilencio(para: turnoID) }
                })
            }
        }
    }

    // MARK: - Conteúdo

    @ViewBuilder private func conteudo(_ turno: TurnoAcompanhado) -> some View {
        Text(verbatim: TextosDoAcompanhamento.titulo)
            .font(FrilaTipo.tituloDaTela)
            .foregroundStyle(FrilaCor.texto)
            // Em texto grande "Acompanhar" é mais largo que a tela: encolhe um pouco em vez de partir a palavra ao meio.
            .minimumScaleFactor(0.6)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)

        cartaoDeStatus(turno)

        // O modelo é o da lista inteira: aqui só as recusas deste turno.
        let recusas = viewModel.recusasDaFila.filter { $0.turnoID == turnoID }
        if !recusas.isEmpty {
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                ForEach(recusas) { recusa in
                    AvisoFrila(verbatim: TextosDaFila.texto(recusa), tom: .informativo)
                        .accessibilityIdentifier("aviso-acao-recusada-\(recusa.tipo.rawValue)")
                    BotaoSecundario("Fechar") { Task { await viewModel.fecharAvisoDaFila(id: recusa.id) } }
                        .accessibilityIdentifier("fechar-aviso-acao-recusada-\(recusa.tipo.rawValue)")
                }
            }
        }

        AvisosDoAcompanhamento(viewModel: viewModel, vagaID: turno.vaga.id, posicaoID: turno.posicao.id,
                               mostrarFalha: !confirmarPresencaNoRodape(turno))

        grupoDeChegada(turno)

        cartaoAvaliacao(turno)

        equipeDoProfissional(turno)

        acoesDeRiscoESuporte(turno)
    }

    /// O cartão de status do turno: o selo do estado, o nome de quem vem, os dados do turno e a linha de etapas.
    private func cartaoDeStatus(_ turno: TurnoAcompanhado) -> some View {
        let situacao = SituacaoDoTurnoDaCasa(viewModel.chegada(turno))
        return VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                SeloDeStatus(verbatim: situacao.selo, estilo: situacao.estilo, icone: situacao.icone)
                Text(verbatim: TextosDoAcompanhamento.nome(turno))
                    .font(FrilaTipo.nome)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                FrilaLinhaDeDado(icone: "briefcase") { Text(verbatim: turno.vaga.funcao) }
                FrilaLinhaDeDado(icone: "calendar") { Text(verbatim: formatador.data(turno.vaga.periodo.inicio)) }
                FrilaLinhaDeDado(icone: "clock") {
                    Text(verbatim: FormatoDeHorarioDoTurno().horario(inicio: turno.vaga.periodo.inicio, fim: turno.vaga.periodo.fim))
                }
                FrilaLinhaDeDado(icone: "mappin.and.ellipse") { Text(verbatim: turno.vaga.local) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            if let etapa = situacao.etapa {
                LinhaDeEtapasDoTurnoDaCasa(atual: etapa)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
    }

    /// "Chegada": o que se sabe da chegada de quem foi confirmado e, quando o check-in manual espera a casa, o código.
    private func grupoDeChegada(_ turno: TurnoAcompanhado) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text(verbatim: TextosDoAcompanhamento.chegada)
                .font(FrilaTipo.rotuloDeGrupo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                chegada(turno)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartaoFrila()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("chegada-do-turno")
            if viewModel.chegada(turno) == .manualPendente, let codigoDaCasa {
                CartaoDoCodigoDaCasa(viewModel: codigoDaCasa)
                    .padding(.top, FrilaEspaco.item)
            }
        }
    }

    @ViewBuilder private func chegada(_ turno: TurnoAcompanhado) -> some View {
        switch viewModel.chegada(turno) {
        case .aguardando:
            Text(verbatim: TextosDoAcompanhamento.aguardando)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.textoSecundario)
        case let .aCaminho(desde):
            Text(verbatim: String(format: TextosDoAcompanhamento.aCaminho, formatador.hora(desde)))
                .font(FrilaTipo.rotuloSecundario)
                .foregroundStyle(FrilaCor.texto)
        case .manualPendente:
            Text(verbatim: TextosDoAcompanhamento.manualPendente)
                .font(FrilaTipo.rotuloSecundario)
                .foregroundStyle(FrilaCor.texto)
            Text(verbatim: TextosDoAcompanhamento.explicacaoDaConfirmacao)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
            if let checkinEm = turno.posicao.checkinEm {
                FrilaLinhaDeDado(icone: "clock") {
                    Text(verbatim: TextosDoAcompanhamento.detalheDoCheckin(em: formatador.hora(checkinEm), tipo: turno.posicao.checkinTipo ?? .manual))
                        .accessibilityIdentifier("detalhe-checkin-\(turnoID)")
                }
            }
        case .emAtraso:
            Text(verbatim: TextosDoAcompanhamento.emAtraso)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
            if viewModel.podeReabrir(turno) {
                BotaoSecundario(verbatim: TextosDoAcompanhamento.reabrirVaga) { viewModel.pedirReabertura(turno) }
                    .disabled(viewModel.emAndamento.contains(turno.id))
                    .accessibilityIdentifier("reabrir-vaga-\(turno.id)")
                    .padding(.top, FrilaEspaco.item)
            }
        case .verificada:
            HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.item) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityHidden(true)
                Text(verbatim: TextosDoAcompanhamento.verificada)
            }
            .font(FrilaTipo.rotuloSecundario)
            .foregroundStyle(FrilaCor.texto)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("presenca-verificada-\(turnoID)")
            if let checkinEm = turno.posicao.checkinEm {
                FrilaLinhaDeDado(icone: "clock") {
                    Text(verbatim: TextosDoAcompanhamento.detalheDoCheckin(em: formatador.hora(checkinEm), tipo: turno.posicao.checkinTipo))
                        .accessibilityIdentifier("detalhe-checkin-\(turnoID)")
                }
            }
            if let confirmadoEm = turno.posicao.checkinConfirmadoEm {
                FrilaLinhaDeDado(icone: "checkmark") {
                    Text(verbatim: String(format: TextosDoAcompanhamento.checkinConfirmado, formatador.hora(confirmadoEm)))
                        .accessibilityIdentifier("detalhe-confirmacao-\(turnoID)")
                }
            }
        case .naoVerificada:
            Text(verbatim: TextosDoAcompanhamento.naoVerificada)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.textoSecundario)
        case .cancelada:
            // O bloco inteiro usa o id do turno: `turno.id` é o da posição, outro valor.
            Text(verbatim: TextosDoAcompanhamento.cancelada)
                .font(FrilaTipo.rotuloSecundario)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityIdentifier("posicao-cancelada-\(turnoID)")
            if let cancelamento = turno.posicao.cancelamento {
                VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
                    Text(verbatim: TextosDoAcompanhamento.textoDaCausa(cancelamento.causa))
                        .font(FrilaTipo.corpo)
                        .accessibilityIdentifier("cancelamento-causa-\(turnoID)")
                    Text(verbatim: TextosDoAcompanhamento.textoDaFalta(cancelamento.falta))
                        .font(FrilaTipo.apoio)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .accessibilityIdentifier("cancelamento-falta-\(turnoID)")
                    if let motivo = cancelamento.motivo, !motivo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(verbatim: String(format: TextosDoAcompanhamento.motivoCancelamento, motivo))
                            .font(FrilaTipo.apoio)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .accessibilityIdentifier("cancelamento-motivo-\(turnoID)")
                    }
                    Text(verbatim: String(format: TextosDoAcompanhamento.canceladaEm, formatador.dataEHora(cancelamento.canceladaEm)))
                        .font(FrilaTipo.apoio)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .accessibilityIdentifier("cancelamento-data-\(turnoID)")
                }
            }
        }
    }

    // MARK: - Ação principal ancorada

    /// "Confirmar presença" é a ação principal da tela quando o check-in manual espera a casa.
    private func confirmarPresencaNoRodape(_ turno: TurnoAcompanhado) -> Bool {
        viewModel.chegada(turno) == .manualPendente && viewModel.podeConfirmar(turno)
    }

    @ViewBuilder private var rodapeDaAcao: some View {
        if let turno = viewModel.turno(turnoID: turnoID) {
            // O erro da ação fica logo acima do botão que a disparou (D-DS-13).
            if let falha = viewModel.falha {
                MensagemJuntoAoBotao(verbatim: TextosDoAcompanhamento.falha(falha, desatualizado: viewModel.falhouAoCarregar))
                    .accessibilityIdentifier("falha-do-acompanhamento")
            }
            BotaoPrimario(verbatim: TextosDoAcompanhamento.confirmarPresenca, carregando: viewModel.emAndamento.contains(turno.id)) {
                Task { await viewModel.confirmarPresenca(turno) }
            }
            .accessibilityIdentifier("confirmar-presenca-\(turnoID)")
        }
    }

    // MARK: - Avaliação (#22)

    @ViewBuilder
    private func cartaoAvaliacao(_ turno: TurnoAcompanhado) -> some View {
        if viewModel.podeAvaliar(turno) {
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                Text(verbatim: TextosDoProfissional.Avaliacao.cartaoTitulo)
                    .font(FrilaTipo.rotuloDeGrupo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                    if viewModel.jaAvaliado(turno) {
                        if let resposta = viewModel.respostaAvaliacao(turno) {
                            Text(verbatim: TextosDoProfissional.Avaliacao.statusResposta(resposta))
                                .font(FrilaTipo.corpo)
                                .foregroundStyle(FrilaCor.texto)
                                .accessibilityIdentifier("texto-status-avaliacao")
                        } else {
                            Text(verbatim: TextosDoProfissional.Avaliacao.statusAvaliado)
                                .font(FrilaTipo.corpo)
                                .foregroundStyle(FrilaCor.texto)
                                .accessibilityIdentifier("texto-status-avaliacao")
                        }

                        NavigationLink {
                            DestinoAvaliacaoDoContratante(viewModel: viewModel, turno: turno, api: api)
                        } label: {
                            Text(verbatim: TextosDoProfissional.Avaliacao.botaoVerAvaliacao)
                        }
                        .buttonStyle(EstiloDoBotaoFrila(papel: .secundario))
                        .accessibilityIdentifier("botao-ver-avaliacao")
                    } else {
                        Text(verbatim: TextosDoProfissional.Avaliacao.cartaoChamada)
                            .font(FrilaTipo.corpo)
                            .foregroundStyle(FrilaCor.texto)

                        NavigationLink {
                            DestinoAvaliacaoDoContratante(viewModel: viewModel, turno: turno, api: api)
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
        } else if let liberacao = viewModel.liberacaoDaAvaliacao(turno) {
            AvisoFrila(verbatim: TextosDoProfissional.Avaliacao.liberaAs(formatador.hora(liberacao)), tom: .informativo)
                .accessibilityIdentifier("aviso-avaliacao-libera")
        }
    }

    // MARK: - Equipe e nova chamada (#24)

    @ViewBuilder
    private func equipeDoProfissional(_ turno: TurnoAcompanhado) -> some View {
        if let profissional = turno.posicao.profissional,
           let api = viewModel.api ?? api,
           // Só com a presença verificada: é a condição de `incluir_na_equipe` (UC11). O servidor confere de novo;
           // aqui é só para não oferecer o que ele vai recusar. D-14: não oferecer incluir na equipe nem chamar
           // de novo profissional bloqueado.
           !bloqueios.contem(profissional),
           turno.posicao.verificacao == .verificado,
           let estabelecimentoID = viewModel.painel?.estabelecimentoID {
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                if chamadaHabilitada, viewModel.podeAvaliar(turno) {
                    BotaoChamarDeNovo(api: api, profissionalID: profissional.id,
                        estabelecimentoID: estabelecimentoID, vagaAnterior: turno.vaga)
                }
                BotaoIncluirNaEquipe(
                    perfil: profissional, estabelecimentoID: estabelecimentoID, api: api,
                    cache: .compartilhado,
                    identificador: "incluir-na-equipe-\(turno.posicao.id)"
                )
                .id(profissional.id)
            }
        }
    }

    // MARK: - Ações de risco e de suporte (#21, #39)

    /// No fim da tela, discretas e uma por linha (DESIGN.md, "Ações de risco ou suporte ficam no fim").
    private func acoesDeRiscoESuporte(_ turno: TurnoAcompanhado) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.podeCancelar(turno) {
                Button { cancelamento = viewModel.criarCancelamento(de: turno) } label: {
                    Text(verbatim: TextosDoCancelamento.tituloPosicao)
                }
                .buttonStyle(.frilaAcaoDiscreta)
                .accessibilityIdentifier("cancelar-posicao-\(turno.posicao.id)")
            }
            Button {
                suporteModel = SuporteTurnoViewModel(
                    dados: ContextoSuporteTurno(turnoAcompanhado: turno),
                    api: api
                )
            } label: {
                Text(verbatim: TextosDoSuporte.botaoAjudaTurno)
            }
            .buttonStyle(.frilaAcaoDiscreta)
            .accessibilityIdentifier("botao-ajuda-turno")
            .accessibilityHint(Text(verbatim: TextosDoSuporte.dicaAjudaTurno))
            segurancaDoProfissional(turno)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // 24 do espaçamento da tela + 8 = os 32 acima das ações discretas.
        .padding(.top, FrilaEspaco.item)
    }

    @ViewBuilder
    private func segurancaDoProfissional(_ turno: TurnoAcompanhado) -> some View {
        if let profissional = turno.posicao.profissional,
           let api = viewModel.api ?? api {
            VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
                if bloqueios.contem(profissional) {
                    Text(verbatim: TextosDaSeguranca.voceBloqueouProfissional)
                        .font(FrilaTipo.apoio)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .accessibilityIdentifier("etiqueta-bloqueio-\(turno.posicao.id)")
                }
                AcoesDeSeguranca(
                    perfil: profissional,
                    turnoID: turno.posicao.turnoID,
                    api: api,
                    bloqueios: bloqueios,
                    identificadorDenunciar: "denunciar-\(turno.posicao.id)",
                    identificadorBloquear: "bloquear-\(turno.posicao.id)"
                )
                // O @State do modelo nasce no init: identidade pelo alvo, para a posição reatribuída
                // não denunciar nem bloquear o profissional anterior.
                .id(profissional.id)
            }
        }
    }

    /// Mesmo padrão da exclusão de conta: título rolável e ações fixas, Cancelar primeiro.
    private var confirmacaoDeSaida: some View {
        ScrollView {
            Text("Sair da conta?", bundle: bundleApresentacao)
                .font(FrilaTipo.tituloDeEstado)
                .foregroundStyle(FrilaCor.texto)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(FrilaEspaco.grupo)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: FrilaEspaco.item) {
                BotaoSecundario(verbatim: String(localized: "Cancelar", bundle: bundleApresentacao)) {
                    mostrarConfirmacaoDeSaida = false
                }
                .accessibilityIdentifier("botao-cancelar-saida-dialogo")
                // Sem vermelho (D-DS-13): a consequência vem escrita; o botão é o secundário.
                BotaoSecundario(verbatim: String(localized: "Sair", bundle: bundleApresentacao)) {
                    mostrarConfirmacaoDeSaida = false
                    sair?()
                }
                .accessibilityIdentifier("botao-confirmar-saida-dialogo")
            }
            .padding(FrilaEspaco.grupo)
            .background(FrilaCor.fundo)
        }
        .background(FrilaCor.fundo)
        .presentationDetents([.large])
        .presentationCornerRadius(FrilaRaio.folha)
        .presentationDragIndicator(.visible)
    }
}

/// O que aconteceu na última confirmação, reabertura ou cancelamento, para a tela do turno e para Minhas vagas.
/// O resultado só aparece na tela de onde a ação saiu: `vagaID` e `posicaoID` são o alvo da tela (sem eles, a
/// lista de Minhas vagas mostra o último de qualquer vaga). `mostrarFalha` é falso quando a tela já leva a falha
/// junto ao botão que a causou.
struct AvisosDoAcompanhamento: View {
    let viewModel: AcompanhamentoViewModel
    var vagaID: UUID?
    var posicaoID: UUID?
    var mostrarFalha = true

    var body: some View {
        let resultado = viewModel.resultadoParaAviso(vaga: vagaID, posicao: posicaoID)
        let falha = mostrarFalha ? viewModel.falha : nil
        // A leitura falhou com um painel já na tela: o que aparece pode estar velho.
        let desatualizado = viewModel.falhouAoCarregar && viewModel.painel != nil
        if resultado != nil || falha != nil || desatualizado {
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                if let resultado {
                    AvisoFrila(verbatim: TextosDoAcompanhamento.resultado(resultado), tom: .informativo)
                        .accessibilityIdentifier("resultado-do-acompanhamento")
                }
                if let falha {
                    AvisoFrila(verbatim: TextosDoAcompanhamento.falha(falha, desatualizado: viewModel.falhouAoCarregar), tom: .erro)
                        .accessibilityIdentifier("falha-do-acompanhamento")
                }
                if desatualizado {
                    AvisoFrila(verbatim: TextosDoAcompanhamento.desatualizado, tom: .alerta)
                        .accessibilityIdentifier("acompanhamento-desatualizado")
                    BotaoSecundario("Tentar novamente") { Task { await viewModel.carregar() } }
                        .accessibilityIdentifier("atualizar-acompanhamento")
                }
            }
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
/// Cada pendência é o cartão de status sem etapas, com botão (DESIGN.md do protótipo, T7, "Precisa de você"): quem,
/// a função, o dia e o horário em linhas separadas (D-24), o fato em corpo e um botão secundário; o botão laranja
/// da tela é de quem a monta.
struct PendenciasDoContratante: View {
    let viewModel: AcompanhamentoViewModel
    let abrir: (UUID) -> Void
    private let formatador = FormatadorFrila()

    init(viewModel: AcompanhamentoViewModel, abrir: @escaping (UUID) -> Void) {
        self.viewModel = viewModel
        self.abrir = abrir
    }

    var body: some View {
        let pendentes = viewModel.pendentes
        let atrasos = viewModel.emAtraso
        AvisosDoAcompanhamento(viewModel: viewModel)
        if !pendentes.isEmpty {
            secao(TextosDoAcompanhamento.presencasAConfirmar, id: "presencas-a-confirmar") {
                ForEach(pendentes) { turno in
                    cartao(turno, detalhe: TextosDoAcompanhamento.explicacaoDaConfirmacao) {
                        if viewModel.podeConfirmar(turno) {
                            BotaoSecundario(verbatim: TextosDoAcompanhamento.confirmarPresenca) {
                                Task { await viewModel.confirmarPresenca(turno) }
                            }
                            .disabled(viewModel.emAndamento.contains(turno.id))
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
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text(verbatim: titulo)
                .font(FrilaTipo.rotuloDeGrupo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                conteudo()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(id)
    }

    private func cartao(_ turno: TurnoAcompanhado, detalhe: String, @ViewBuilder acao: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                    Text(verbatim: TextosDoAcompanhamento.nome(turno))
                        .font(FrilaTipo.nome)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)
                    FrilaLinhaDeDado(icone: "briefcase") { Text(verbatim: turno.vaga.funcao) }
                    FrilaLinhaDeDado(icone: "calendar") { Text(verbatim: formatador.data(turno.vaga.periodo.inicio)) }
                    FrilaLinhaDeDado(icone: "clock") {
                        Text(verbatim: FormatoDeHorarioDoTurno().horario(inicio: turno.vaga.periodo.inicio, fim: turno.vaga.periodo.fim))
                    }
                }
                .accessibilityElement(children: .combine)
                Text(verbatim: detalhe)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                acao()
                if let turnoID = turno.posicao.turnoID {
                    Button { abrir(turnoID) } label: { Text(verbatim: TextosDoAcompanhamento.acompanharTurno) }
                        .buttonStyle(.frilaLink)
                        .accessibilityIdentifier("acompanhar-turno-\(turnoID)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .contain)
    }
}

/// Destino da avaliação do contratante. Se o view model ainda não puder ser criado (ex.: falha ao ler a conta),
/// exibe tela com botão de tentar novamente em vez de uma tela vazia.
public struct DestinoAvaliacaoDoContratante: View {
    let viewModel: AcompanhamentoViewModel
    let turno: TurnoAcompanhado
    let api: (any ApiCliente)?

    public init(viewModel: AcompanhamentoViewModel, turno: TurnoAcompanhado, api: (any ApiCliente)? = nil) {
        self.viewModel = viewModel
        self.turno = turno
        self.api = api
    }

    public var body: some View {
        if let avaliacao = viewModel.criarAvaliacaoViewModel(para: turno, api: api) {
            TelaAvaliacao(viewModel: avaliacao)
        } else {
            VStack(spacing: FrilaEspaco.bloco) {
                EstadoErro(verbatim: TextosDoProfissional.Avaliacao.erroSemRede) {
                    Task {
                        await viewModel.carregarIdentidadeEEAvaliacoes()
                        if viewModel.contaID == nil {
                            await viewModel.carregar()
                        }
                    }
                }
                .disabled(viewModel.carregando)
            }
            .padding(FrilaEspaco.grupo)
            .background(FrilaCor.fundo.ignoresSafeArea())
            .navigationTitle(TextosDoProfissional.Avaliacao.titulo)
            .accessibilityIdentifier("avaliacao-sem-conexao")
            .task {
                if viewModel.contaID == nil {
                    await viewModel.carregarIdentidadeEEAvaliacoes()
                }
            }
        }
    }
}
