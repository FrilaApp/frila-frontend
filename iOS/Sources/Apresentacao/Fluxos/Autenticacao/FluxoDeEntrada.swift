import FrilaDominio
import SwiftUI

public enum RotaEntrada: Hashable, Sendable {
    case entrada
    case codigo(email: String)
    case senha(email: String)
    case recuperacao(email: String)
    case codigoDeRecuperacao(email: String)
    case definirSenhaAposRecuperacao
    case cadastro(email: String)
}

public struct FluxoDeEntrada: View {
    private let api: any ApiCliente
    private let relogio: any Relogio
    private let verificadorDeIdade: any VerificadorDeIdade
    private let aoConcluir: (DestinoAposEntrada) -> Void

    @State private var rotaAtual: RotaEntrada = .senha(email: "")
    @State private var entradaVM: EntradaViewModel
    @State private var codigoVM: CodigoViewModel?
    @State private var entradaComSenhaVM: EntradaComSenhaViewModel?
    @State private var recuperacaoVM: RecuperacaoSenhaViewModel?
    @State private var destinoAposDefinirSenha: DestinoCodigo?
    @State private var cadastroVM: CadastroViewModel?

    public init(
        api: any ApiCliente,
        relogio: any Relogio = RelogioDoSistema(),
        verificadorDeIdade: any VerificadorDeIdade = VerificadorDeIdadeIndisponivel(),
        rotaInicial: RotaEntrada = .senha(email: ""),
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
        } else if ProcessInfo.processInfo.arguments.contains("-FRILA_ABRIR_CADASTRO") {
            let emailTeste = "novo@frila.app"
            _rotaAtual = State(initialValue: .cadastro(email: emailTeste))
            _cadastroVM = State(initialValue: CadastroViewModel(api: api, email: emailTeste, relogio: relogio, verificadorDeIdade: verificadorDeIdade))
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
                TelaEntrada(
                    viewModel: entradaVM,
                    aoAvancarParaCodigo: { email in
                        codigoVM = CodigoViewModel(api: api, email: email)
                        rotaAtual = .codigo(email: email)
                    },
                    aoEntrarComSenha: { email in
                        entradaComSenhaVM = EntradaComSenhaViewModel(api: api, emailInicial: email)
                        rotaAtual = .senha(email: email)
                    }
                )
            case let .codigo(email):
                if let codigoVM {
                    TelaCodigo(
                        viewModel: codigoVM,
                        aoVoltar: { rotaAtual = .entrada },
                        aoConcluir: { destino in
                            if DemonstracaoContas.ehEmailDeDemonstracao(email) {
                                encaminharDestino(destino)
                            } else {
                                destinoAposDefinirSenha = destino
                                rotaAtual = .definirSenhaAposRecuperacao
                            }
                        }
                    )
                } else {
                    EstadoCarregando()
                        .onAppear {
                            codigoVM = CodigoViewModel(api: api, email: email)
                        }
                }
            case let .senha(email):
                if let entradaComSenhaVM {
                    TelaEntradaComSenha(
                        viewModel: entradaComSenhaVM,
                        aoCriarConta: { emailAtual in
                            entradaVM.email = emailAtual
                            rotaAtual = .entrada
                        },
                        aoEsqueciSenha: { emailAtual in
                            recuperacaoVM = RecuperacaoSenhaViewModel(api: api, emailInicial: emailAtual)
                            rotaAtual = .recuperacao(email: emailAtual)
                        },
                        aoConcluir: encaminharDestino
                    )
                } else {
                    EstadoCarregando()
                        .onAppear {
                            entradaComSenhaVM = EntradaComSenhaViewModel(api: api, emailInicial: email)
                        }
                }
            case let .recuperacao(email):
                if let recuperacaoVM {
                    TelaRecuperacaoSenha(
                        viewModel: recuperacaoVM,
                        aoVoltar: { emailAtual in
                            entradaComSenhaVM = EntradaComSenhaViewModel(api: api, emailInicial: emailAtual)
                            rotaAtual = .senha(email: emailAtual)
                        },
                        aoAvancarParaCodigo: { emailAtual in
                            codigoVM = CodigoViewModel(api: api, email: emailAtual, modo: .recuperacao)
                            rotaAtual = .codigoDeRecuperacao(email: emailAtual)
                        }
                    )
                } else {
                    EstadoCarregando()
                        .onAppear {
                            recuperacaoVM = RecuperacaoSenhaViewModel(api: api, emailInicial: email)
                        }
                }
            case let .codigoDeRecuperacao(email):
                if let codigoVM {
                    TelaCodigo(
                        viewModel: codigoVM,
                        aoVoltar: {
                            recuperacaoVM = RecuperacaoSenhaViewModel(api: api, emailInicial: email)
                            rotaAtual = .recuperacao(email: email)
                        },
                        aoConcluir: { destino in
                            // Recuperação de senha nunca encaminha para criação de cadastro novo.
                            if case .cadastro = destino {
                                destinoAposDefinirSenha = nil
                                rotaAtual = .senha(email: email)
                                return
                            }
                            destinoAposDefinirSenha = destino
                            rotaAtual = .definirSenhaAposRecuperacao
                        }
                    )
                } else {
                    EstadoCarregando()
                        .onAppear {
                            codigoVM = CodigoViewModel(api: api, email: email, modo: .recuperacao)
                        }
                }
            case .definirSenhaAposRecuperacao:
                NavigationStack {
                    TelaDefinirSenha(api: api, permitirPular: false) {
                        if let destino = destinoAposDefinirSenha {
                            destinoAposDefinirSenha = nil
                            encaminharDestino(destino)
                        } else {
                            rotaAtual = .senha(email: "")
                        }
                    }
                }
            case let .cadastro(email):
                if let cadastroVM {
                    TelaCadastro(
                        viewModel: cadastroVM,
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

    private func encaminharDestino(_ destino: DestinoCodigo) {
        switch destino {
        case let .cadastro(email):
            cadastroVM = CadastroViewModel(api: api, email: email, relogio: relogio, verificadorDeIdade: verificadorDeIdade)
            rotaAtual = .cadastro(email: email)
        case let .destino(destinoFinal):
            aoConcluir(destinoFinal)
        }
    }
}
