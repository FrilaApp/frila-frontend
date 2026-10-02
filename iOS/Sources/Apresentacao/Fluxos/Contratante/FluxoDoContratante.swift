import FrilaDominio
import Observation
import SwiftUI

public enum EstadoDoFluxoContratante: Equatable, Sendable {
    case carregando
    case cadastro(Conta)
    case vagas(EstabelecimentoDaConta)
    case erro(mensagem: String)
    case offline
}

@MainActor @Observable
public final class FluxoDoContratanteViewModel {
    public private(set) var estado: EstadoDoFluxoContratante = .carregando
    private let meusEstabelecimentos: @Sendable () async throws -> [EstabelecimentoDaConta]
    private let minhaConta: @Sendable () async throws -> Conta
    private var carregando = false

    public convenience init(api: any ApiCliente) {
        self.init(meusEstabelecimentos: { try await api.meusEstabelecimentos() },
                  minhaConta: { try await api.minhaConta() })
    }

    public init(
        meusEstabelecimentos: @escaping @Sendable () async throws -> [EstabelecimentoDaConta],
        minhaConta: @escaping @Sendable () async throws -> Conta
    ) {
        self.meusEstabelecimentos = meusEstabelecimentos
        self.minhaConta = minhaConta
    }

    public func carregar() async {
        guard !carregando else { return }
        carregando = true
        estado = .carregando
        defer { carregando = false }
        do {
            if let primeiro = try await meusEstabelecimentos().first {
                estado = .vagas(primeiro)
            } else {
                estado = .cadastro(try await minhaConta())
            }
        } catch is CancellationError {
            // A saída da tela cancela o carregamento, sem apresentar uma falha de rede.
        } catch {
            let erro = error as? ErroDaApi ?? ErroDaApi(codigo: .desconhecido)
            estado = erro.codigo == .semRede ? .offline : .erro(mensagem: MensagemDoErroAPI.texto(erro))
        }
    }
}

/// Entrada do contratante: primeiro estabelecimento da API ou cadastro com o responsável da conta.
public struct FluxoDoContratante: View {
    private let api: any ApiCliente
    private let fila: (any FilaDeAcoes)?
    private let sair: () -> Void
    private let roteador: RoteadorDoContratante?
    @State private var model: FluxoDoContratanteViewModel
    @State private var mostrandoPerfilEstabelecimento = false
    @State private var mostrandoExclusaoDeConta = false

    /// O roteador é a entrada dos avisos da casa (`checkin_manual_pendente`, `atraso_15min` e
    /// `vaga_vazia`), que o push (#8) vai usar.
    public init(api: any ApiCliente, fila: (any FilaDeAcoes)?, roteador: RoteadorDoContratante? = nil, sair: @escaping () -> Void) {
        self.api = api
        self.fila = fila
        self.roteador = roteador
        self.sair = sair
        _model = State(initialValue: FluxoDoContratanteViewModel(api: api))
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if case .vagas = model.estado {
                    Button {
                        mostrandoPerfilEstabelecimento = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                    }
                    .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                    .accessibilityLabel(String(localized: "Perfil do estabelecimento", bundle: bundleApresentacao))
                    .accessibilityIdentifier("abrir-perfil-estabelecimento")
                }
                if case .cadastro = model.estado {
                    Button(role: .destructive) {
                        mostrandoExclusaoDeConta = true
                    } label: {
                        Text("Excluir conta", bundle: bundleApresentacao)
                            .foregroundStyle(FrilaCor.perigo)
                    }
                    .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                    .accessibilityIdentifier("contratante-sem-estabelecimento-excluir-conta")
                }
                Button(action: sair) { Text("Sair", bundle: bundleApresentacao) }
                    .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                    .accessibilityIdentifier("sair-fluxo-contratante")
            }
            .padding(.horizontal, FrilaEspaco.medio)
            conteudo.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $mostrandoPerfilEstabelecimento) {
            NavigationStack {
                TelaPerfilEstabelecimento(
                    api: api,
                    sair: {
                        mostrandoPerfilEstabelecimento = false
                        sair()
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(String(localized: "Fechar", bundle: bundleApresentacao)) {
                            mostrandoPerfilEstabelecimento = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $mostrandoExclusaoDeConta) {
            NavigationStack {
                TelaExclusaoDeConta(
                    viewModel: ExclusaoDeContaViewModel(
                        api: api,
                        aoConcluir: {
                            mostrandoExclusaoDeConta = false
                            sair()
                        }
                    )
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(String(localized: "Fechar", bundle: bundleApresentacao)) {
                            mostrandoExclusaoDeConta = false
                        }
                    }
                }
            }
        }
        .task { await model.carregar() }
    }

    @ViewBuilder
    private var conteudo: some View {
        switch model.estado {
        case .carregando:
            EstadoCarregando()
        case let .cadastro(conta):
            if let fila {
                TelaCadastroEstabelecimento(api: api, fila: fila, responsavelNome: conta.nome,
                                           responsavelTelefone: conta.telefone, sair: sair,
                                           aoPublicarPrimeiraVaga: { Task { await model.carregar() } })
            } else {
                erro(MensagemDoErroAPI.texto(ErroDaApi(codigo: .desconhecido)))
            }
        case let .vagas(estabelecimento):
            DestinoDasVagasDoContratante(api: api, fila: fila, estabelecimento: estabelecimento, roteador: roteador, sair: sair)
        case let .erro(mensagem):
            erro(mensagem)
        case .offline:
            // Não há estabelecimentos em cache neste fluxo. Não prometemos mostrar dados salvos.
            erro(MensagemDoErroAPI.texto(ErroDaApi(codigo: .semRede)))
        }
    }

    private func erro(_ mensagem: String) -> some View {
        EstadoErro(verbatim: mensagem) { Task { await model.carregar() } }
    }
}

/// Minhas vagas e, a partir dela, a publicação de uma vaga nova. A publicação toma o lugar da
/// lista, como no primeiro acesso, e não uma folha por cima dela: assim a explicação da
/// notificação, que é uma folha da raiz do app, pode aparecer depois de publicar (#8).
private struct DestinoDasVagasDoContratante: View {
    private let api: any ApiCliente
    private let fila: (any FilaDeAcoes)?
    private let roteador: RoteadorDoContratante?
    private let sair: () -> Void
    @State private var model: MinhasVagasViewModel
    @State private var publicacao: PublicacaoDaCasaViewModel
    @State private var publicando = false

    init(api: any ApiCliente, fila: (any FilaDeAcoes)?, estabelecimento: EstabelecimentoDaConta, roteador: RoteadorDoContratante?, sair: @escaping () -> Void) {
        self.api = api
        self.fila = fila
        self.roteador = roteador
        self.sair = sair
        _model = State(initialValue: MinhasVagasViewModel(api: api, estabelecimento: estabelecimento))
        _publicacao = State(initialValue: PublicacaoDaCasaViewModel(api: api, estabelecimentoID: estabelecimento.id))
    }

    var body: some View {
        if publicando, let fila {
            DestinoDePublicarVaga(
                api: api, fila: fila, modelo: publicacao, sair: sair,
                cancelar: { publicando = false },
                aoPublicar: {
                    // A lista volta e é relida, com a vaga nova. TelaPublicarVaga já oferece a permissão de push.
                    guard publicando else { return }
                    publicando = false
                }
            )
        } else {
            // Sem o banco local não há fila para a publicação: a entrada não aparece.
            TelaMinhasVagas(viewModel: model, api: api, fila: fila, roteador: roteador,
                            publicarVaga: fila == nil ? nil : { publicando = true })
        }
    }
}
