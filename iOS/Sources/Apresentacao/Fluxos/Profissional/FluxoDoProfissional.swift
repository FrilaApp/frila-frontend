// BAIXA FIDELIDADE DESCARTÁVEL: não é design final (substitui por ora #15/#172).

import FrilaDominio
import Observation
import SwiftUI

/// Destinos do fluxo de quem procura turno.
public enum RotaDoProfissional: Hashable, Sendable {
    case detalhe(vagaID: UUID)
}

/// Pilha de navegação do fluxo. É a entrada que a notificação do tipo vaga (S2 #8) vai usar:
/// `abrirVaga` empilha o detalhe, nunca candidata sozinho.
@MainActor @Observable
public final class RoteadorDoProfissional {
    public var caminho: [RotaDoProfissional] = []

    public init() {}

    public func abrirVaga(id: UUID) {
        caminho = [.detalhe(vagaID: id)]
    }

    public func voltarParaLista() {
        caminho = []
    }
}

/// Lista de vagas -> detalhe (#104).
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
                        DestinoDoDetalhe(vagaID: vagaID, api: api)
                    }
                }
        }
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

    init(vagaID: UUID, api: any ApiCliente) {
        _viewModel = State(initialValue: DetalheVagaViewModel(vagaID: vagaID, api: api))
    }

    var body: some View { TelaDetalheVaga(viewModel: viewModel) }
}
