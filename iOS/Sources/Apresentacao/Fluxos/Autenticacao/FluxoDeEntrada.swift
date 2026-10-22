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
    private let verificadorDeIdade: any VerificadorDeIdade
    private let aoConcluir: (DestinoAposEntrada) -> Void

    @State private var rotaAtual: RotaEntrada = .entrada
    @State private var entradaVM: EntradaViewModel
    @State private var codigoVM: CodigoViewModel?
    @State private var cadastroVM: CadastroViewModel?

    public init(
        api: any ApiCliente,
        relogio: any Relogio = RelogioDoSistema(),
        verificadorDeIdade: any VerificadorDeIdade = VerificadorDeIdadeIndisponivel(),
        rotaInicial: RotaEntrada = .entrada,
        aoConcluir: @escaping (DestinoAposEntrada) -> Void
    ) {
        self.api = api
        self.relogio = relogio
        self.verificadorDeIdade = verificadorDeIdade
        self.aoConcluir = aoConcluir
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-FRILA_ABRIR_CODIGO") {
            let emailTeste = "teste@frila.app"
            _rotaAtual = State(initialValue: .codigo(email: emailTeste))
            _codigoVM = State(initialValue: CodigoViewModel(api: api, email: emailTeste))
        } else {
            _rotaAtual = State(initialValue: rotaInicial)
        }
        #else
        _rotaAtual = State(initialValue: rotaInicial)
        #endif
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
                                cadastroVM = CadastroViewModel(api: api, email: email, relogio: relogio, verificadorDeIdade: verificadorDeIdade)
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
                            cadastroVM = CadastroViewModel(api: api, email: email, relogio: relogio, verificadorDeIdade: verificadorDeIdade)
                        }
                }
            }
        }
    }
}
