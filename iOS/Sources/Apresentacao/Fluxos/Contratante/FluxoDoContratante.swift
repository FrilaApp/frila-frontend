import FrilaDominio
import Observation
import SwiftUI

public enum AbaDoContratante: Hashable, Sendable {
    case vagas
    case conta
}

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
    /// As casas de que a conta é membro, como o servidor as devolveu na última leitura (`meus_estabelecimentos`).
    public private(set) var casas: [EstabelecimentoDaConta] = []
    /// A casa que a conta escolheu em "Trocar de casa". Só vive na memória deste modelo, que é da sessão: sair da conta, a sessão
    /// vencer ou entrar com outra conta tira o fluxo da tela (`destinoAtual = nil`) e o modelo vai junto, então a escolha volta a
    /// `nil`. Toda leitura confere se a conta ainda é membro dela; se não é, vale a primeira casa.
    public private(set) var escolhidaID: UUID?
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

    /// `preferida` é a casa que a pessoa acabou de abrir (aceitou um convite, por exemplo); sem ela vale a escolha anterior e, sem
    /// esta, a primeira casa na ordem do servidor.
    public func carregar(preferindo preferida: UUID? = nil) async {
        guard !carregando else { return }
        carregando = true
        estado = .carregando
        defer { carregando = false }
        do {
            let lidas = try await meusEstabelecimentos()
            casas = lidas
            if let casa = Self.casa(entre: lidas, preferida: preferida ?? escolhidaID) {
                escolhidaID = casa.id
                estado = .vagas(casa)
            } else {
                escolhidaID = nil
                estado = .cadastro(try await minhaConta())
            }
        } catch is CancellationError {
            // A saída da tela cancela o carregamento, sem apresentar uma falha de rede.
        } catch {
            casas = []
            let erro = error as? ErroDaApi ?? ErroDaApi(codigo: .desconhecido)
            estado = erro.codigo == .semRede ? .offline : .erro(mensagem: MensagemDoErroAPI.texto(erro))
        }
    }

    /// Troca de casa: só diz de qual delas o app fala agora. Não vai ao servidor; a casa tem de estar na última lista lida.
    public func escolher(_ id: UUID) {
        guard let casa = casas.first(where: { $0.id == id }) else { return }
        escolhidaID = id
        estado = .vagas(casa)
    }

    /// Relê a lista de casas sem trocar a tela (depois de aceitar um convite, a conta pode ter uma casa a mais). Quem estava no
    /// cadastro passa para Minhas vagas assim que tem uma casa; se a casa em uso deixou de ser da conta, a leitura inteira recomeça.
    public func atualizarCasas() async {
        let leitura = meusEstabelecimentos
        guard let lidas = try? await PrazoDaAbertura.esperar(.seconds(20), { try await leitura() }) else { return }
        casas = lidas
        switch estado {
        case let .vagas(atual) where !lidas.contains(where: { $0.id == atual.id }):
            await carregar()
        case .cadastro, .erro, .offline:
            if let casa = Self.casa(entre: lidas, preferida: escolhidaID) {
                escolhidaID = casa.id
                estado = .vagas(casa)
            }
        default:
            break
        }
    }

    private static func casa(entre casas: [EstabelecimentoDaConta], preferida: UUID?) -> EstabelecimentoDaConta? {
        casas.first(where: { $0.id == preferida }) ?? casas.first
    }
}

/// Entrada do contratante: primeiro estabelecimento da API ou cadastro com o responsável da conta,
/// organizados em abas nativas com Minhas vagas e Conta (LOG-007).
public struct FluxoDoContratante: View {
    @State private var aba: AbaDoContratante = .vagas
    @State private var mostrarConfirmacaoDeSaida = false
    private let api: any ApiCliente
    private let fila: (any FilaDeAcoes)?
    private let sair: () -> Void
    private let roteador: RoteadorDoContratante?
    @State private var model: FluxoDoContratanteViewModel
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
        TabView(selection: $aba) {
            conteudoPrincipal
                .tint(FrilaCor.primaria)
                .tabItem {
                    Label(String(localized: "Minhas vagas", bundle: bundleApresentacao), systemImage: "briefcase")
                }
                .tag(AbaDoContratante.vagas)

            NavigationStack {
                TelaPerfilEstabelecimento(api: api, casaEscolhida: model.escolhidaID, entradasDaCasa: entradasDaCasa, sair: sair)
            }
            .tint(FrilaCor.primaria)
            .tabItem {
                Label(String(localized: "Conta", bundle: bundleApresentacao), systemImage: "person.crop.circle")
            }
            .tag(AbaDoContratante.conta)
        }
        // Barra de abas do desenho do Fabrício: o ícone da aba ativa vai na cor de ação. Cada aba devolve a tinta ao
        // seu conteúdo (`.tint(FrilaCor.primaria)` acima), para link e controle nativo não virarem texto laranja.
        .tint(FrilaCor.acao)
        .sheet(isPresented: $mostrarConfirmacaoDeSaida) { confirmacaoDeSaida }
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
        .onChange(of: roteador?.avisosAbertos) {
            if roteador?.avisosAbertos != nil {
                aba = .vagas
            }
        }
    }

    @ViewBuilder
    private var conteudoPrincipal: some View {
        conteudo
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FrilaCor.fundo.ignoresSafeArea())
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
                sair: sair
            )
            // Trocar de casa recria Minhas vagas, a publicação e a busca: nada de uma casa fica na tela da outra.
            .id(estabelecimento.id)
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

    /// As linhas da equipe da casa, do convite e da troca de casa, no topo da Conta.
    private func entradasDaCasa(_ casa: EstabelecimentoDaConta?) -> AnyView {
        AnyView(
            EntradasDaCasaNaConta(
                api: api,
                casa: casa,
                casas: model.casas,
                aoEscolherCasa: { id in
                    publicando = false
                    model.escolher(id)
                },
                aoAtualizarCasas: { Task { await model.atualizarCasas() } },
                aoAbrirCasa: { id in
                    publicando = false
                    Task {
                        await model.carregar(preferindo: id)
                        aba = .vagas
                    }
                }
            )
        )
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
    /// O que a busca vazia leva para a publicação ("Publicar para todos"); `nil` na publicação de sempre.
    @State private var rascunhoDaBusca: RascunhoDeVagaDaBusca?
    /// A guarda da busca mora aqui, acima de `TelaMinhasVagas`: publicar uma vaga troca a lista pela publicação e tira a
    /// tela da hierarquia. Com um envio em curso ou incerto, a busca (a trava, o trabalho e as chaves) volta com a lista
    /// (DINHEIRO: sem ela, a busca recomeçaria limpa e a folha nova abriria uma 2ª vaga).
    @State private var guardaDaBusca: GuardaDaBuscaDeProfissionais
    @Binding private var publicando: Bool
    /// A escala de evento toma o lugar da lista, como a publicação de uma vaga.
    @State private var escalando = false
    /// Guarda a escala que saiu sem resposta conhecida (com a chave) enquanto a pessoa cancela e reabre a tela.
    @State private var guardaDaEscala = GuardaDaEscala()
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
        let estabelecimentoID = estabelecimento.id
        _guardaDaBusca = State(initialValue: GuardaDaBuscaDeProfissionais {
            BuscaDeProfissionaisViewModel(api: api, estabelecimentoID: estabelecimentoID)
        })
    }

    var body: some View {
        Group {
            if escalando {
                DestinoDePublicarEscala(
                    api: api, estabelecimentoID: model.estabelecimentoID, guarda: guardaDaEscala,
                    aoConcluir: { escalando = false }, aoCancelar: { escalando = false }
                )
            } else if publicando, let fila {
                DestinoDePublicarVaga(
                    api: api, fila: fila, modelo: publicacao, rascunhoDaBusca: rascunhoDaBusca, sair: sair ?? {},
                    cancelar: { publicando = false; rascunhoDaBusca = nil },
                    aoPublicar: {
                        // A lista volta e é relida, com a vaga nova. A vaga publicada é também o
                        // momento de explicar a notificação a quem contrata (#8).
                        guard publicando else { return }
                        publicando = false
                        rascunhoDaBusca = nil
                        Task { await permissaoDePush?.oferecerAposPublicar() }
                    }
                )
                .toolbar(.hidden, for: .tabBar)
            } else {
                // Sem o banco local não há fila para a publicação: a entrada não aparece.
                TelaMinhasVagas(
                    viewModel: model,
                    api: api,
                    fila: fila,
                    roteador: roteador,
                    publicarVaga: fila == nil ? nil : { rascunhoDaBusca = nil; publicando = true },
                    publicarEscala: { escalando = true },
                    // Sem o banco local não há fila para publicar: a busca vazia não oferece "Publicar para todos".
                    publicarParaTodosDaBusca: fila == nil ? nil : { rascunho in
                        rascunhoDaBusca = rascunho
                        publicando = true
                    },
                    guardaDaBusca: guardaDaBusca,
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
