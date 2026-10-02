// BAIXA FIDELIDADE DESCARTÁVEL: não é design final. As telas de destino do push seguem o low-fi do
// profissional (#15) até a alta fidelidade chegar.

import FrilaDominio
import SwiftUI

/// Por que a vaga de um aviso não dá mais para pegar. O contrato manda decidir pelo que o servidor
/// diz, e nunca pelo relógio do aparelho: só há candidatura com `publicada` e posição aberta.
public enum IndisponibilidadeDaVaga: Equatable, Sendable {
    case preenchida
    /// Cancelada, encerrada ou com o início já passado.
    case encerrada
    /// `404`: a vaga não existe mais ou não está visível para esta conta.
    case naoEncontrada

    public init?(_ estado: EstadoDoDetalhe) {
        switch estado {
        case let .carregado(vaga) where vaga.estado == .publicada && vaga.posicoesAbertas > 0:
            return nil
        case let .carregado(vaga):
            self = vaga.estado == .preenchida ? .preenchida : .encerrada
        case .naoEncontrada:
            self = .naoEncontrada
        case .carregando, .falha:
            return nil
        }
    }
}

/// O que a vaga indisponível de um aviso mostra a quem tocou: o turno da conta nela, ou a
/// explicação de por que não dá mais para pegá-la.
enum BuscaDaVagaDoAviso: Equatable {
    case pendente
    case achou(Turno)
    /// Sem turno na vaga. `candidatura` é o estado da candidatura da conta nela, se houver: é o
    /// que diz a quem foi recusado, ou esperava quando a seleção fechou, o que aconteceu (#10).
    case semTurno(candidatura: EstadoCandidatura?)

    /// A decisão, com o que foi lido; `nil` é leitura que falhou. A candidatura vem antes do
    /// turno: a recusada e a expirada não têm turno, e assim um turno antigo da conta na mesma
    /// vaga (o cancelado continua em `meus_turnos`) não toma o lugar da explicação. Sem conseguir
    /// ler os turnos, vale o que o servidor disse da vaga.
    static func decidir(vagaID: UUID, candidaturas: [Candidatura]?, turnos: [Turno]?) -> BuscaDaVagaDoAviso {
        let candidatura = candidaturas?.first { $0.vaga.id == vagaID }?.estado
        if candidatura == .recusada || candidatura == .expirada { return .semTurno(candidatura: candidatura) }
        guard let meu = turnos?.first(where: { $0.vaga.id == vagaID }) else { return .semTurno(candidatura: candidatura) }
        return .achou(meu)
    }

    static func procurar(vagaID: UUID, api: any ApiCliente, repositorio: any TurnoRepositorio) async -> BuscaDaVagaDoAviso {
        let candidaturas = try? await api.minhasCandidaturas()
        let turnos = try? await repositorio.ler().turnos
        return decidir(vagaID: vagaID, candidaturas: candidaturas, turnos: turnos)
    }
}

/// A vaga de um aviso (#8). Se ainda dá para pegar, é o detalhe de sempre. Se não dá, é a tela de
/// vaga indisponível, a não ser que a vaga já seja de quem tocou: aí o destino é o turno dela.
struct DestinoDaVagaDoAviso<Conteudo: View>: View {
    @State private var detalhe: DetalheVagaViewModel
    @State private var busca = BuscaDaVagaDoAviso.pendente
    private let api: any ApiCliente
    private let repositorio: any TurnoRepositorio
    private let candidatar: (CandidaturaViewModel) async -> Void
    private let voltarParaLista: () -> Void
    private let turno: (Turno) -> Conteudo

    init(
        vagaID: UUID,
        api: any ApiCliente,
        repositorio: any TurnoRepositorio,
        candidatar: @escaping (CandidaturaViewModel) async -> Void,
        voltarParaLista: @escaping () -> Void,
        @ViewBuilder turno: @escaping (Turno) -> Conteudo
    ) {
        _detalhe = State(initialValue: DetalheVagaViewModel(vagaID: vagaID, api: api))
        self.api = api
        self.repositorio = repositorio
        self.candidatar = candidatar
        self.voltarParaLista = voltarParaLista
        self.turno = turno
    }

    var body: some View {
        if let motivo = IndisponibilidadeDaVaga(detalhe.estado) {
            switch busca {
            case .pendente:
                EstadoCarregando()
                    .task { busca = await BuscaDaVagaDoAviso.procurar(vagaID: detalhe.vagaID, api: api, repositorio: repositorio) }
            case let .achou(meuTurno):
                turno(meuTurno)
            case let .semTurno(candidatura):
                TelaVagaIndisponivel(
                    motivo: motivo, candidatura: candidatura, modo: vaga?.modo, vagaCancelada: vaga?.estado == .cancelada,
                    voltarParaLista: voltarParaLista
                )
            }
        } else {
            TelaDetalheVaga(viewModel: detalhe) { vaga in
                AreaDeCandidatura(vaga: vaga, api: api, candidatar: candidatar)
            }
        }
    }

    private var vaga: Vaga? {
        if case let .carregado(vaga) = detalhe.estado { return vaga }
        return nil
    }
}

/// A tela própria da vaga que não dá mais para pegar (RN10): diz o que aconteceu e leva de volta à
/// lista. Os textos são os mesmos do resultado da candidatura.
struct TelaVagaIndisponivel: View {
    private typealias Textos = TextosDoProfissional.Candidatura
    private typealias TextosDaSelecao = TextosDaCandidaturaEmSelecao
    let motivo: IndisponibilidadeDaVaga
    /// O estado da candidatura da conta nesta vaga, quando há uma: a recusada e a expirada têm
    /// explicação própria (avisos `candidatura_recusada` e `selecao_encerrada`).
    var candidatura: EstadoCandidatura?
    var modo: ModoPreenchimento?
    /// A casa cancelou a vaga. `IndisponibilidadeDaVaga` junta a cancelada e a encerrada; para
    /// quem tinha candidatura nela, a tela diz qual das duas foi.
    var vagaCancelada = false
    let voltarParaLista: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    Text(verbatim: titulo).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    Text(verbatim: mensagem).font(.body).foregroundStyle(FrilaCor.textoSecundario)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("vaga-indisponivel")

                BotaoSecundario(verbatim: Textos.voltarParaLista, acao: voltarParaLista)
                    .accessibilityIdentifier("voltar-para-lista")
            }
            .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosDoProfissional.Detalhe.titulo))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { AccessibilityNotification.Announcement(titulo).post() }
    }

    private var textos: (titulo: String, mensagem: String) {
        Self.textos(motivo: motivo, candidatura: candidatura, modo: modo, vagaCancelada: vagaCancelada)
    }
    private var titulo: String { textos.titulo }
    private var mensagem: String { textos.mensagem }

    /// O que a tela diz. A candidatura recusada ou expirada da conta explica mais do que o estado
    /// da vaga; sem ela, vale o estado que o servidor devolveu.
    static func textos(
        motivo: IndisponibilidadeDaVaga, candidatura: EstadoCandidatura?, modo: ModoPreenchimento?, vagaCancelada: Bool = false
    ) -> (titulo: String, mensagem: String) {
        switch (candidatura, motivo) {
        case (.recusada, _): (TextosDaSelecao.recusadaTitulo, TextosDaSelecao.recusadaMensagem)
        // A candidatura que esperava também expira quando a casa cancela a vaga: aí a seleção não
        // "foi encerrada", e a tela diz o que houve.
        case (.expirada, _) where vagaCancelada: (TextosDaSelecao.canceladaTitulo, TextosDaSelecao.canceladaMensagem)
        case (.expirada, _): (TextosDaSelecao.expiradaTitulo, TextosDaSelecao.expiradaMensagem)
        // "Quem aceita primeiro" é da urgência: na seleção, quem preenche a vaga é a escolha da casa.
        case (_, .preenchida):
            (Textos.preenchidaTitulo, modo == .selecao ? TextosDaSelecao.preenchidaEmSelecao : Textos.preenchidaMensagem)
        case (_, .encerrada): (Textos.encerradaTitulo, Textos.encerradaMensagem)
        case (_, .naoEncontrada): (Textos.encerradaTitulo, Textos.naoEncontrada)
        }
    }
}

/// O que a procura do turno de um aviso deu.
enum BuscaDoTurnoDoAviso: Equatable {
    case carregando
    case achou(Turno)
    case naoEncontrado
    case semConexao
    case falha

    /// Falha de leitura não vira "não encontrado": sem ler, não dá para dizer que o turno não é da conta.
    static func procurar(_ turnoID: UUID, em repositorio: any TurnoRepositorio) async -> BuscaDoTurnoDoAviso {
        do {
            guard let meu = try await repositorio.ler().turnos.first(where: { $0.id == turnoID }) else { return .naoEncontrado }
            return .achou(meu)
        } catch let erro as ErroDaApi where erro.codigo == .semRede {
            return .semConexao
        } catch {
            return .falha
        }
    }
}

/// O turno de um aviso (#8). O aviso só traz o id, então o turno é procurado entre os da conta que
/// está no aparelho: o de outra conta nunca aparece, porque não vem na leitura.
struct DestinoDoTurnoDoAviso<Conteudo: View>: View {
    @State private var estado = BuscaDoTurnoDoAviso.carregando
    private let turnoID: UUID
    private let repositorio: any TurnoRepositorio
    private let verMeusTurnos: () -> Void
    private let turno: (Turno) -> Conteudo

    init(
        turnoID: UUID,
        repositorio: any TurnoRepositorio,
        verMeusTurnos: @escaping () -> Void,
        @ViewBuilder turno: @escaping (Turno) -> Conteudo
    ) {
        self.turnoID = turnoID
        self.repositorio = repositorio
        self.verMeusTurnos = verMeusTurnos
        self.turno = turno
    }

    var body: some View {
        switch estado {
        case let .achou(meuTurno):
            turno(meuTurno)
        default:
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.medio) { semTurno }
                    .padding(FrilaEspaco.medio)
            }
            .background(FrilaCor.fundo)
            .navigationTitle(Text(verbatim: TextosDoProfissional.Turnos.tituloMeuTurno))
            .navigationBarTitleDisplayMode(.inline)
            .task { await carregar() }
        }
    }

    @ViewBuilder
    private var semTurno: some View {
        switch estado {
        case .carregando, .achou:
            EstadoCarregando()
        case .naoEncontrado:
            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                Text(verbatim: TextosDoPush.Turno.naoEncontradoTitulo).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                Text(verbatim: TextosDoPush.Turno.naoEncontradoMensagem).font(.body).foregroundStyle(FrilaCor.textoSecundario)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("turno-do-aviso-nao-encontrado")
            BotaoSecundario(verbatim: TextosDoPush.Turno.verMeusTurnos, acao: verMeusTurnos)
                .accessibilityIdentifier("ver-meus-turnos")
        case .semConexao:
            AvisoFrila(verbatim: TextosDoProfissional.Lista.semConexaoMensagem, tom: .alerta)
            BotaoSecundario("Tentar novamente") { Task { await carregar() } }
        case .falha:
            EstadoErro(verbatim: TextosDoPush.Turno.falha) { Task { await carregar() } }
        }
    }

    private func carregar() async {
        estado = .carregando
        estado = await BuscaDoTurnoDoAviso.procurar(turnoID, em: repositorio)
    }
}
