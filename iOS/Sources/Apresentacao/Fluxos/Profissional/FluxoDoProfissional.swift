// BAIXA FIDELIDADE DESCARTÁVEL: não é design final (substitui por ora #15/#172).

import FrilaDominio
import Observation
import SwiftUI

/// Abas de navegação principal do profissional (conforme protótipo low-fi).
public enum AbaDoProfissional: Hashable, Sendable {
    case vagas
    case turnos
}

/// Destinos do fluxo de quem procura turno.
public enum RotaDoProfissional: Hashable, Sendable {
    case detalhe(vagaID: UUID)
    case resultado(vaga: Vaga, resultado: ResultadoDaCandidatura)
    case meuTurno(turno: Turno)
}

/// Pilha de navegação do fluxo. É a entrada que a notificação do tipo vaga (S2 #8) vai usar:
/// `abrirVaga` empilha o detalhe, nunca candidata sozinho.
@MainActor @Observable
public final class RoteadorDoProfissional {
    public var caminho: [RotaDoProfissional] = []
    public var aba: AbaDoProfissional = .vagas
    /// Sobrevive à saída do detalhe enquanto `candidatar` ainda está em voo. O roteador, e não a
    /// view que iniciou a chamada, decide o destino do resultado definitivo.
    var candidaturaEmAndamento: CandidaturaViewModel?

    public init() {}

    public func abrirVaga(id: UUID) {
        aba = .vagas
        caminho = [.detalhe(vagaID: id)]
    }

    public func abrirMeusTurnos() {
        aba = .turnos
    }

    public func voltarParaLista() {
        caminho = []
    }

    public func candidatar(viewModel: CandidaturaViewModel) async {
        if let candidaturaEmAndamento, candidaturaEmAndamento !== viewModel, candidaturaEmAndamento.enviando {
            viewModel.indicarOutroEnvioEmAndamento()
            return
        }
        guard !viewModel.enviando else { return }
        candidaturaEmAndamento = viewModel
        defer {
            if candidaturaEmAndamento === viewModel {
                candidaturaEmAndamento = nil
            }
        }
        await viewModel.candidatar()
        guard candidaturaEmAndamento === viewModel,
              case let .concluida(resultado) = viewModel.estado,
              resultado.abreTelaPropria else { return }
        caminho = [.resultado(vaga: viewModel.vaga, resultado: resultado)]
    }
}

/// Lista de vagas -> detalhe (#104) -> candidatura e resultado (#105), e aba Meus turnos (#109).
public struct FluxoDoProfissional<Barra: View>: View {
    private let api: any ApiCliente
    private let repositorioTurnos: any TurnoRepositorio
    private let relogio: any Relogio
    @Bindable private var roteador: RoteadorDoProfissional
    @State private var feed: FeedVagasViewModel
    @State private var turnosViewModel: MeusTurnosViewModel
    @State private var caminhoTurnos: [Turno] = []
    private let barra: () -> Barra

    public init(
        api: any ApiCliente,
        roteador: RoteadorDoProfissional,
        repositorioTurnos: (any TurnoRepositorio)? = nil,
        relogio: any Relogio = RelogioDoSistema(),
        @ViewBuilder barra: @escaping () -> Barra
    ) {
        self.api = api
        let repo = repositorioTurnos ?? api
        self.repositorioTurnos = repo
        self.relogio = relogio
        self.roteador = roteador
        _feed = State(initialValue: FeedVagasViewModel(api: api, relogio: relogio))
        _turnosViewModel = State(initialValue: MeusTurnosViewModel(repositorio: repo))
        self.barra = barra
    }

    public var body: some View {
        TabView(selection: $roteador.aba) {
            NavigationStack(path: $roteador.caminho) {
                TelaVagas(viewModel: feed) { roteador.caminho.append(.detalhe(vagaID: $0)) }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                roteador.aba = .turnos
                            } label: {
                                Label(TextosDoProfissional.Turnos.tituloMeusTurnos, systemImage: "calendar")
                            }
                            .accessibilityIdentifier("abrir-meus-turnos")
                        }
                        ToolbarItem(placement: .topBarTrailing) { barra() }
                    }
                    .navigationDestination(for: RotaDoProfissional.self) { rota in
                        switch rota {
                        case let .detalhe(vagaID):
                            DestinoDoDetalhe(vagaID: vagaID, api: api, candidatar: roteador.candidatar)
                        case let .resultado(vaga, resultado):
                            TelaResultadoDaCandidatura(vaga: vaga, resultado: resultado, voltarParaLista: voltarParaLista)
                        case let .meuTurno(turno):
                            DestinoDoMeuTurno(turno: turno, api: api, relogio: relogio)
                        }
                    }
            }
            .tabItem {
                Label(TextosDoProfissional.Lista.titulo, systemImage: "briefcase")
            }
            .tag(AbaDoProfissional.vagas)

            NavigationStack(path: $caminhoTurnos) {
                TelaMeusTurnos(viewModel: turnosViewModel) { turno in
                    caminhoTurnos.append(turno)
                }
                .navigationDestination(for: Turno.self) { turno in
                    DestinoDoMeuTurno(turno: turno, api: api, relogio: relogio)
                }
            }
            .tabItem {
                Label(TextosDoProfissional.Turnos.tituloMeusTurnos, systemImage: "calendar")
            }
            .tag(AbaDoProfissional.turnos)
        }
    }
}

extension FluxoDoProfissional {
    /// "Vaga preenchida" e os outros resultados voltam para a lista (#105 C4), que é atualizada.
    private func voltarParaLista() {
        roteador.voltarParaLista()
        let feed = feed
        let turnos = turnosViewModel
        Task {
            await feed.atualizar()
            await turnos.atualizar()
        }
    }
}

extension FluxoDoProfissional where Barra == EmptyView {
    public init(
        api: any ApiCliente,
        roteador: RoteadorDoProfissional,
        repositorioTurnos: (any TurnoRepositorio)? = nil,
        relogio: any Relogio = RelogioDoSistema()
    ) {
        self.init(api: api, roteador: roteador, repositorioTurnos: repositorioTurnos, relogio: relogio) { EmptyView() }
    }
}

/// Guarda o view model do detalhe enquanto o destino estiver na pilha.
private struct DestinoDoDetalhe: View {
    @State private var viewModel: DetalheVagaViewModel
    private let api: any ApiCliente
    private let candidatar: (CandidaturaViewModel) async -> Void

    init(vagaID: UUID, api: any ApiCliente, candidatar: @escaping (CandidaturaViewModel) async -> Void) {
        _viewModel = State(initialValue: DetalheVagaViewModel(vagaID: vagaID, api: api))
        self.api = api
        self.candidatar = candidatar
    }

    var body: some View {
        TelaDetalheVaga(viewModel: viewModel) { vaga in
            AreaDeCandidatura(vaga: vaga, api: api, candidatar: candidatar)
        }
    }
}

/// Destino do detalhe do turno (#109).
private struct DestinoDoMeuTurno: View {
    @State private var viewModel: MeuTurnoViewModel

    init(turno: Turno, api: any ApiCliente, relogio: any Relogio) {
        _viewModel = State(initialValue: MeuTurnoViewModel(turno: turno, api: api, relogio: relogio))
    }

    var body: some View {
        TelaMeuTurno(viewModel: viewModel)
    }
}
