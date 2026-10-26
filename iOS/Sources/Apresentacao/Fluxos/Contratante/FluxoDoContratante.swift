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

/// Entrada do contratante: primeiro estabelecimento da API ou cadastro com o responsável da conta. A barra de cima
/// e o fundo agrupado seguem o quadro "Main" do MidFi do Fabrício.
public struct FluxoDoContratante: View {
    @State private var mostrarConfirmacaoDeSaida = false
    private let api: any ApiCliente
    private let fila: (any FilaDeAcoes)?
    private let sair: () -> Void
    private let roteador: RoteadorDoContratante?
    @State private var model: FluxoDoContratanteViewModel
    @State private var mostrandoPerfilEstabelecimento = false
    @State private var mostrandoExclusaoDeConta = false
    @State private var publicando = ProcessInfo.processInfo.arguments.contains("-FRILA_ABRIR_PUBLICAR")

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
        conteudoDaTela
            .sheet(isPresented: $mostrarConfirmacaoDeSaida) { confirmacaoDeSaida }
    }

    @ViewBuilder
    private var conteudoDaTela: some View {
        VStack(spacing: 0) {
            if case .cadastro = model.estado {
                // Toolbar nativo dentro de TelaCadastroEstabelecimento
            } else if case .vagas = model.estado {
                // Toolbar nativo dentro de TelaMinhasVagas
            } else {
                HStack {
                    Spacer()
                    Button(action: solicitarSaida) { Text("Sair", bundle: bundleApresentacao).font(FrilaTipo.meta) }
                        .foregroundStyle(FrilaCor.texto)
                        .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                        .accessibilityIdentifier("sair-fluxo-contratante")
                }
                .padding(.horizontal, FrilaEspaco.medio)
            }
            conteudo.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
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
                        Button {
                            mostrandoPerfilEstabelecimento = false
                        } label: {
                            Label(String(localized: "Fechar", bundle: bundleApresentacao), systemImage: "xmark")
                                .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                                .contentShape(Rectangle())
                        }
                        .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                        .accessibilityShowsLargeContentViewer()
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
                        .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                        .accessibilityShowsLargeContentViewer()
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
            TelaCadastroEstabelecimento(api: api, fila: fila, responsavelNome: conta.nome,
                                       responsavelTelefone: conta.telefone, sair: sair,
                                       excluirConta: { mostrandoExclusaoDeConta = true },
                                       aoPublicarPrimeiraVaga: { Task { await model.carregar() } })
        case let .vagas(estabelecimento):
            DestinoDasVagasDoContratante(
                api: api,
                fila: fila,
                estabelecimento: estabelecimento,
                roteador: roteador,
                publicando: $publicando,
                sair: sair,
                abrirPerfil: { mostrandoPerfilEstabelecimento = true }
            )
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

    private var solicitarSaida: () -> Void {
        { mostrarConfirmacaoDeSaida = true }
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
                .padding(FrilaEspaco.medio)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: FrilaEspaco.pequeno) {
                BotaoSecundario(verbatim: String(localized: "Cancelar", bundle: bundleApresentacao)) {
                    mostrarConfirmacaoDeSaida = false
                }
                .accessibilityIdentifier("botao-cancelar-saida-dialogo")
                Button(role: .destructive) {
                    mostrarConfirmacaoDeSaida = false
                    sair()
                } label: {
                    Text("Sair", bundle: bundleApresentacao)
                        .font(FrilaTipo.botao)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, FrilaEspaco.pequeno)
                        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(FrilaCor.sobrePrimaria)
                .background(FrilaCor.perigo, in: Capsule())
                .accessibilityIdentifier("botao-confirmar-saida-dialogo")
            }
            .padding(FrilaEspaco.medio)
            .background(FrilaCor.fundo)
        }
        .background(FrilaCor.fundo)
        .presentationDetents([.large])
        .presentationCornerRadius(FrilaRaio.folha)
        .presentationDragIndicator(.visible)
    }
}

/// Minhas vagas e, a partir dela, a publicação de uma vaga nova. A publicação toma o lugar da
/// lista, como no primeiro acesso, e não uma folha por cima dela: assim a explicação da
/// notificação, que é uma folha da raiz do app, pode aparecer depois de publicar (#8).
private struct DestinoDasVagasDoContratante: View {
    private let api: any ApiCliente
    private let fila: (any FilaDeAcoes)?
    private let roteador: RoteadorDoContratante?
    private let sair: (() -> Void)?
    private let abrirPerfil: (() -> Void)?
    @State private var model: MinhasVagasViewModel
    @State private var publicacao: PublicacaoDaCasaViewModel
    @Binding private var publicando: Bool
    @Environment(PermissaoDePushModelo.self) private var permissaoDePush: PermissaoDePushModelo?

    init(
        api: any ApiCliente,
        fila: (any FilaDeAcoes)?,
        estabelecimento: EstabelecimentoDaConta,
        roteador: RoteadorDoContratante?,
        publicando: Binding<Bool>,
        sair: (() -> Void)? = nil,
        abrirPerfil: (() -> Void)? = nil
    ) {
        self.api = api
        self.fila = fila
        self.roteador = roteador
        self.sair = sair
        self.abrirPerfil = abrirPerfil
        _publicando = publicando
        _model = State(initialValue: MinhasVagasViewModel(api: api, estabelecimento: estabelecimento))
        _publicacao = State(initialValue: PublicacaoDaCasaViewModel(api: api, estabelecimentoID: estabelecimento.id))
    }

    var body: some View {
        Group {
            if publicando, let fila {
                DestinoDePublicarVaga(
                    api: api, fila: fila, modelo: publicacao, sair: sair ?? {},
                    cancelar: { publicando = false },
                    aoPublicar: {
                        // A lista volta e é relida, com a vaga nova. A vaga publicada é também o
                        // momento de explicar a notificação a quem contrata (#8).
                        guard publicando else { return }
                        publicando = false
                        Task { await permissaoDePush?.oferecer() }
                    }
                )
            } else {
                // Sem o banco local não há fila para a publicação: a entrada não aparece.
                TelaMinhasVagas(
                    viewModel: model,
                    api: api,
                    fila: fila,
                    roteador: roteador,
                    publicarVaga: fila == nil ? nil : { publicando = true },
                    sair: sair,
                    abrirPerfil: abrirPerfil
                )
            }
        }
        #if DEBUG
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-FRILA_ABRIR_PUBLICAR"), fila != nil {
                publicando = true
            }
        }
        #endif
    }
}
