import FrilaDominio
import SwiftUI

public enum RotaEntrada: Hashable, Sendable {
    case entrada
    case codigo(email: String)
    case cadastro(email: String)
}

public struct FluxoDeEntrada: View {
    private let api: any ApiCliente
    private let relogio: any Relogio
    private let aoConcluir: (DestinoAposEntrada) -> Void

    @State private var rotaAtual: RotaEntrada = .entrada
    @State private var entradaVM: EntradaViewModel
    @State private var codigoVM: CodigoViewModel?
    @State private var cadastroVM: CadastroViewModel?

    public init(
        api: any ApiCliente,
        relogio: any Relogio = RelogioDoSistema(),
        rotaInicial: RotaEntrada = .entrada,
        aoConcluir: @escaping (DestinoAposEntrada) -> Void
    ) {
        self.api = api
        self.relogio = relogio
        self.aoConcluir = aoConcluir
        _rotaAtual = State(initialValue: rotaInicial)
        _entradaVM = State(initialValue: EntradaViewModel(api: api))
    }

    public var body: some View {
        Group {
            switch rotaAtual {
            case .entrada:
                TelaEntrada(viewModel: entradaVM) { email in
                    codigoVM = CodigoViewModel(api: api, email: email)
                    rotaAtual = .codigo(email: email)
                }
            case let .codigo(email):
                if let codigoVM {
                    TelaCodigo(
                        viewModel: codigoVM,
                        aoVoltar: { rotaAtual = .entrada },
                        aoConcluir: { destino in
                            switch destino {
                            case let .cadastro(email):
                                cadastroVM = CadastroViewModel(api: api, email: email, relogio: relogio)
                                rotaAtual = .cadastro(email: email)
                            case let .destino(destinoFinal):
                                aoConcluir(destinoFinal)
                            }
                        }
                    )
                } else {
                    EstadoCarregando()
                        .onAppear {
                            codigoVM = CodigoViewModel(api: api, email: email)
                        }
                }
            case let .cadastro(email):
                if let cadastroVM {
                    TelaCadastro(
                        viewModel: cadastroVM,
                        aoVoltar: { rotaAtual = .codigo(email: email) },
                        aoConcluir: { destino in
                            aoConcluir(destino)
                        }
                    )
                } else {
                    EstadoCarregando()
                        .onAppear {
                            cadastroVM = CadastroViewModel(api: api, email: email, relogio: relogio)
                        }
                }
            }
        }
    }
}
