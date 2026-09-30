// BAIXA FIDELIDADE DESCARTÁVEL: não é design final (substitui por ora #15/#172).

import FrilaDominio
import Observation
import SwiftUI

/// Destinos do fluxo de quem procura turno.
public enum RotaDoProfissional: Hashable, Sendable {
    case detalhe(vagaID: UUID)
    case resultado(vaga: Vaga, resultado: ResultadoDaCandidatura)
}

/// Pilha de navegação do fluxo. É a entrada que a notificação do tipo vaga (S2 #8) vai usar:
/// `abrirVaga` empilha o detalhe, nunca candidata sozinho.
@MainActor @Observable
public final class RoteadorDoProfissional {
    public var caminho: [RotaDoProfissional] = []
    /// Sobrevive à saída do detalhe enquanto `candidatar` ainda está em voo. O roteador, e não a
    /// view que iniciou a chamada, decide o destino do resultado definitivo.
    var candidaturaEmAndamento: CandidaturaViewModel?

    public init() {}

    public func abrirVaga(id: UUID) {
        caminho = [.detalhe(vagaID: id)]
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

/// Lista de vagas -> detalhe (#104) -> candidatura e resultado (#105).
public struct FluxoDoProfissional<Barra: View>: View {
    private let api: any ApiCliente
    @Bindable private var roteador: RoteadorDoProfissional
    @State private var feed: FeedVagasViewModel
    private let barra: () -> Barra

    public init(api: any ApiCliente, roteador: RoteadorDoProfissional, relogio: any Relogio = RelogioDoSistema(),
                @ViewBuilder barra: @escaping () -> Barra) {
        self.api = api
        self.roteador = roteador
        _feed = State(initialValue: FeedVagasViewModel(api: api, relogio: relogio))
        self.barra = barra
    }

    public var body: some View {
        NavigationStack(path: $roteador.caminho) {
            TelaVagas(viewModel: feed) { roteador.caminho.append(.detalhe(vagaID: $0)) }
                .toolbar { ToolbarItem(placement: .topBarTrailing) { barra() } }
                .navigationDestination(for: RotaDoProfissional.self) { rota in
                    switch rota {
                    case let .detalhe(vagaID):
                        DestinoDoDetalhe(vagaID: vagaID, api: api, candidatar: roteador.candidatar)
                    case let .resultado(vaga, resultado):
                        TelaResultadoDaCandidatura(vaga: vaga, resultado: resultado, voltarParaLista: voltarParaLista)
                    }
                }
        }
    }
}

extension FluxoDoProfissional {
    /// "Vaga preenchida" e os outros resultados voltam para a lista (#105 C4), que é atualizada.
    private func voltarParaLista() {
        roteador.voltarParaLista()
        let feed = feed
        Task { await feed.atualizar() }
    }
}

extension FluxoDoProfissional where Barra == EmptyView {
    public init(api: any ApiCliente, roteador: RoteadorDoProfissional, relogio: any Relogio = RelogioDoSistema()) {
        self.init(api: api, roteador: roteador, relogio: relogio) { EmptyView() }
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
