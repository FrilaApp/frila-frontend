import FrilaApresentacao
import FrilaDados
import FrilaDominio
import FrilaInfraestrutura
import OSLog
import SwiftData
import SwiftUI

@main
struct FrilaApp: App {
    private static let logger = Logger(subsystem: "com.frila.org.app", category: "ambiente")
    private let inicializacao: Inicializacao
    private let versao: String
    private let armazenamento: ArmazenamentoSwiftData?

    init() {
        RelatorioDeFalhas.iniciarSeConfigurado()
        let versao = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        self.versao = versao
        let armazenamento: ArmazenamentoSwiftData?
        do {
            let container = try PersistenciaFrila.criarContainer()
            armazenamento = ArmazenamentoSwiftData(modelContainer: container)
        } catch {
            Logger(subsystem: "com.frila.org.app", category: "cache")
                .error("cache_indisponivel tipo=\(String(reflecting: type(of: error)), privacy: .public)")
            armazenamento = nil
        }
        self.armazenamento = armazenamento

        do throws(ErroDeConfiguracao) {
            let ambiente = try ConfiguracaoAmbiente()
            Self.logger.notice("inicio \(ambiente.resumoParaLog, privacy: .public) versao=\(versao, privacy: .public)")
            inicializacao = .pronta(Self.cliente(para: ambiente.selecao))
        } catch {
            Self.logger.error("inicio configuracao_invalida \(error.description, privacy: .public)")
            inicializacao = .configuracaoInvalida(error)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch inicializacao {
            case let .pronta(api):
                PortaoDeAtualizacao(viewModel: AtualizacaoObrigatoriaViewModel(api: api, versaoAtual: versao)) {
                    EntradaDoApp(api: api, armazenamento: armazenamento)
                }
            case let .configuracaoInvalida(erro):
                TelaDeConfiguracaoInvalida(erro: erro)
            }
        }
    }

    private static func cliente(para selecao: SelecaoDeAPI) -> any ApiCliente {
        switch selecao {
        case .emMemoria:
            ApiClienteEmMemoria.pelosArgumentos()
        case let .supabase(url, chavePublicavel):
            SupabaseApiCliente(url: url, chavePublicavel: chavePublicavel, telemetria: TelemetriaCrashlytics())
        }
    }
}

private enum Inicializacao {
    case pronta(any ApiCliente)
    case configuracaoInvalida(ErroDeConfiguracao)
}

/// Decide o que o app abre. Com o dublê (esquema Local), ou com sessão guardada no Dev e no Prod, abre
/// a lista de vagas do profissional (#104). Sem sessão, fica a tela de antes: a entrada por código é de
/// outro cartão. Quando a sessão é encerrada (401 ou saída), reavalia.
/// Limite: `possuiSessao()` pode precisar da rede para renovar; offline com sessão guardada, cai na
/// tela de antes até a próxima abertura.
private struct EntradaDoApp: View {
    let api: any ApiCliente
    let armazenamento: ArmazenamentoSwiftData?
    private let repositorioTurnos: any TurnoRepositorio
    @Environment(\.scenePhase) private var fase
    @State private var roteador = RoteadorDoProfissional()
    @State private var destinoAtual: DestinoDaConta?
    @State private var carregandoDestino: Bool = true
    @State private var erroAoAvaliar: String?
    #if DEBUG
    @State private var mostrandoCatalogo = false
    @State private var rotaInicialAplicada = false
    #endif

    init(api: any ApiCliente, armazenamento: ArmazenamentoSwiftData?) {
        self.api = api
        self.armazenamento = armazenamento
        if let armazenamento {
            self.repositorioTurnos = TurnosComCache(buscar: { try await api.meusTurnos() }, cache: armazenamento)
        } else {
            self.repositorioTurnos = api
        }
    }

    var body: some View {
        Group {
            #if DEBUG
            // Entrada isolada para o UI test do cadastro; a entrada por código fará a ligação de produto.
            if ProcessInfo.processInfo.arguments.contains("-FRILA_ABRIR_MINHAS_VAGAS") {
                let estabelecimento = EstabelecimentoDaConta(
                    id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
                    nome: "Bistrô Ipê",
                    papel: .administrador
                )
                TelaMinhasVagas(
                    viewModel: MinhasVagasViewModel(api: api, estabelecimento: estabelecimento),
                    api: api
                )
            } else if ProcessInfo.processInfo.arguments.contains("-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO") {
                let apiCadastro = ProcessInfo.processInfo.arguments.contains("-FRILA_CADASTRO_UI_TEST")
                    ? ApiClienteEmMemoria(cenario: .primeiroAcesso) : api
                if let armazenamento {
                    TelaCadastroEstabelecimento(api: apiCadastro, fila: armazenamento, responsavelNome: "Conta de teste", responsavelTelefone: "(61) 99999-0000")
                } else {
                    EstadoCarregando()
                }
            } else if ProcessInfo.processInfo.arguments.contains("-FRILA_ABRIR_CATALOGO") {
                catalogo
            } else {
                fluxoOuTelaSemSessao
            }
            #else
            fluxoOuTelaSemSessao
            #endif
        }
        .task { await avaliarSessao() }
        // Sem ampliar o observador (que só avisa encerramento): ao voltar a ficar ativo, a entrada
        // confere a sessão de novo. Cobre quem entrou pela seção de validação (Debug) e saiu do app.
        .onChange(of: fase) { _, nova in
            if nova == .active, destinoAtual == nil { Task { await avaliarSessao() } }
        }
        .task {
            guard let observador = api as? any ObservadorDeSessao else { return }
            for await _ in observador.encerramentos() {
                roteador.voltarParaLista()
                destinoAtual = nil
                await avaliarSessao()
            }
        }
        .task { await acompanharOffline() }
    }

    /// Cache e fila offline (#111): a fila sai quando a conexão volta, e a sessão encerrada apaga o
    /// que este aparelho guardou da conta. Sem o banco local, o app funciona só com rede.
    private func acompanharOffline() async {
        guard let armazenamento else { return }
        let reenvio = ReenvioAoReconectar(
            monitor: MonitorDeConexaoDoSistema(),
            sincronizador: SincronizadorAcoes(fila: armazenamento, api: api)
        )
        let saida = SaidaDaConta(api: api, armazenamento: armazenamento)
        let observador = api as? any ObservadorDeSessao
        await withTaskGroup(of: Void.self) { grupo in
            grupo.addTask { await reenvio.acompanhar() }
            if let observador {
                grupo.addTask { await saida.acompanharEncerramentos(de: observador) }
            }
        }
    }

    @ViewBuilder
    private var fluxoOuTelaSemSessao: some View {
        #if DEBUG
        if deveAbrirEntrada, destinoAtual == nil {
            FluxoDeEntrada(api: api) { destino in
                aplicarDestinoManual(destino)
            }
        } else {
            conteudoPrincipal
        }
        #else
        conteudoPrincipal
        #endif
    }

    @ViewBuilder
    private var conteudoPrincipal: some View {
        if carregandoDestino {
            EstadoCarregando()
        } else if let erroAoAvaliar {
            VStack(spacing: FrilaEspaco.medio) {
                AvisoFrila(verbatim: erroAoAvaliar, tom: .erro)
                BotaoSecundario("Tentar novamente") {
                    Task { await avaliarSessao() }
                }
            }
            .padding(FrilaEspaco.medio)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FrilaCor.fundo.ignoresSafeArea())
        } else if let destinoAtual {
            switch destinoAtual {
            case .profissional:
                fluxoProfissionalView
            case .funcoesEHorarios:
                TelaFuncoesEHorariosProvisoria()
            case .contratante:
                TelaInicioContratanteProvisoria()
            case let .cadastro(email):
                FluxoDeEntrada(api: api, rotaInicial: .cadastro(email: email ?? "")) { destino in
                    aplicarDestinoManual(destino)
                }
            }
        } else {
            FluxoDeEntrada(api: api) { destino in
                aplicarDestinoManual(destino)
            }
        }
    }

    private func aplicarDestinoManual(_ destino: DestinoAposEntrada) {
        switch destino {
        case .profissional:
            DestinoGuardado.salvar(.profissional)
            destinoAtual = .profissional
        case .funcoesEHorarios:
            DestinoGuardado.salvar(.funcoesEHorarios)
            destinoAtual = .funcoesEHorarios
        case .contratante:
            DestinoGuardado.salvar(.contratante)
            destinoAtual = .contratante
        }
    }

    @ViewBuilder
    private var fluxoProfissionalView: some View {
        #if DEBUG
        FluxoDoProfissional(api: api, roteador: roteador, repositorioTurnos: repositorioTurnos) {
            Button("Catálogo") { mostrandoCatalogo = true }
                .accessibilityHint("Abre o catálogo de componentes, só em Debug")
        }
        .sheet(isPresented: $mostrandoCatalogo) { catalogo }
        .task {
            // Roteador de destino com vaga_id simulado (#105 C3): a mesma entrada que o push do tipo
            // vaga vai usar (S2 #8). Abre o detalhe; nunca candidata sozinho.
            guard !rotaInicialAplicada, let vagaID = Self.vagaIDDosArgumentos() else { return }
            rotaInicialAplicada = true
            roteador.abrirVaga(id: vagaID)
        }
        #else
        FluxoDoProfissional(api: api, roteador: roteador, repositorioTurnos: repositorioTurnos)
        #endif
    }

    #if DEBUG
    private var deveAbrirEntrada: Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-FRILA_ENTRADA") { return true }
        if let indice = args.firstIndex(of: "-FRILA_SCENARIO"), args.indices.contains(indice + 1) {
            let cenario = args[indice + 1]
            return ["primeiro-acesso", "entrada", "codigo-errado", "codigo-expirado", "menor-de-idade"].contains(cenario)
        }
        return false
    }

    /// `-FRILA_VAGA_ID <uuid>`: só existe em Debug, e a leitura também fica dentro do bloco.
    private static func vagaIDDosArgumentos() -> UUID? {
        let argumentos = ProcessInfo.processInfo.arguments
        guard let indice = argumentos.firstIndex(of: "-FRILA_VAGA_ID"), argumentos.indices.contains(indice + 1) else { return nil }
        return UUID(uuidString: argumentos[indice + 1])
    }

    // A simulação de conflito chama `candidatar`: só roda contra o dublê, nunca contra um Supabase de
    // verdade, para não criar candidatura real em nenhum ambiente.
    private var catalogo: some View {
        CatalogoDesignSystem(api: api, permitirSimulacaoDeConflito: api is ApiClienteEmMemoria)
    }
    #endif

    private func avaliarSessao() async {
        #if DEBUG
        if deveAbrirEntrada {
            carregandoDestino = false
            return
        }
        #endif

        carregandoDestino = true
        erroAoAvaliar = nil
        let possuiSessao = await api.possuiSessao()
        guard possuiSessao else {
            destinoAtual = nil
            carregandoDestino = false
            return
        }

        do {
            destinoAtual = try await DestinoDaConta.avaliarComRecuperacaoOffline(api: api)
            carregandoDestino = false
        } catch let erroApi as ErroDaApi {
            erroAoAvaliar = MensagemDoErroAPI.texto(erroApi)
            carregandoDestino = false
        } catch {
            erroAoAvaliar = String(localized: "Não foi possível concluir esta ação. Tente novamente.", bundle: bundleApresentacao)
            carregandoDestino = false
        }
    }
}

private struct TelaInicialDaFundacao: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "briefcase.fill").font(.largeTitle)
            Text("Frila").font(.title.bold())
        }
        .accessibilityElement(children: .combine)
    }
}

/// Dev e Prod sem Supabase param aqui, com o motivo, em vez de abrir com dados simulados.
private struct TelaDeConfiguracaoInvalida: View {
    let erro: ErroDeConfiguracao

    var body: some View {
        ContentUnavailableView {
            Label("Configuração incompleta", systemImage: "exclamationmark.triangle.fill")
        } description: {
            Text(verbatim: erro.description)
        }
        .accessibilityIdentifier("configuracao-invalida")
    }
}
