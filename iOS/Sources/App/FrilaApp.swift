import FrilaApresentacao
import FrilaDados
import FrilaDominio
import FrilaInfraestrutura
#if DEBUG
import MapKit
import UserNotifications
#endif
import OSLog
import SwiftData
import SwiftUI

@main
struct FrilaApp: App {
    private static let logger = Logger(subsystem: "com.frila.org.app", category: "ambiente")
    /// O sistema entrega o token do APNs e as notificações ao delegate, que é dono dos roteadores (#8).
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegado
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
            let api = try Self.cliente(para: ambiente)
            let aparelho = Self.aparelhoDePush(para: api)
            inicializacao = .pronta(Dependencias(
                api: api, localizacao: Self.leitorDeLocalizacao(para: api), aparelho: aparelho,
                permissao: Self.permissaoDePush(para: api), canal: Self.canalDePush(para: api, aparelho: aparelho)
            ))
        } catch {
            Self.logger.error("inicio configuracao_invalida \(error.description, privacy: .public)")
            inicializacao = .configuracaoInvalida(error)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch inicializacao {
            case let .pronta(dependencias):
                PortaoDeAtualizacao(viewModel: AtualizacaoObrigatoriaViewModel(api: dependencias.api, versaoAtual: versao)) {
                    EntradaDoApp(dependencias, armazenamento: armazenamento, navegacao: delegado.navegacao)
                }
            case let .configuracaoInvalida(erro):
                TelaDeConfiguracaoInvalida(erro: erro)
            }
        }
    }

    private static func cliente(para ambiente: ConfiguracaoAmbiente) throws(ErroDeConfiguracao) -> any ApiCliente {
        switch ambiente.selecao {
        case .emMemoria:
            #if DEBUG
            return ApiClienteEmMemoria.pelosArgumentos()
            #else
            // O dublê e os argumentos de lançamento ficam fora do Release (#96), que nunca abre com
            // dados simulados.
            throw ErroDeConfiguracao(ambiente: ambiente.ambiente, motivo: .simuladoForaDoLocal)
            #endif
        case let .supabase(url, chavePublicavel):
            return SupabaseApiCliente(url: url, chavePublicavel: chavePublicavel, telemetria: TelemetriaCrashlytics())
        }
    }

    /// Um leitor para o app inteiro. Só o dublê em memória (esquema Local) aceita o GPS simulado de
    /// `-FRILA_LOCALIZACAO`; com Supabase é sempre o CoreLocation.
    private static func leitorDeLocalizacao(para api: any ApiCliente) -> any LeitorDeLocalizacao {
        #if DEBUG
        if api is ApiClienteEmMemoria, let simulado = LeitorDeLocalizacaoSimulado.pelosArgumentos() {
            return simulado
        }
        #endif
        return LeitorDeLocalizacaoDoSistema()
    }

    /// Um por app: o token de push e a conta a que o aparelho está entregue (#162), no Keychain. O
    /// dublê em memória (esquema Local) guarda num item separado: o vínculo precisa sobreviver ao
    /// app fechado, que é quando o toque numa notificação o abre.
    private static func aparelhoDePush(para api: any ApiCliente) -> AparelhoDePush {
        let armazenamento = api is ApiClienteEmMemoria
            ? ArmazenamentoDoAparelhoNoKeychain(servico: "com.frila.org.app.push.local") : ArmazenamentoDoAparelhoNoKeychain()
        return AparelhoDePush(api: api, armazenamento: armazenamento)
    }

    /// O token chega pelo FCM. No esquema Local não há Firebase: o dublê recebe um token simulado, e
    /// o registro, o vínculo e o destino do toque rodam como rodariam com o servidor.
    private static func canalDePush(para api: any ApiCliente, aparelho: AparelhoDePush) -> any CanalDePush {
        CanalDePushDoAparelho(tokenSimulado: api is ApiClienteEmMemoria ? "token-simulado-do-esquema-local" : nil) { token in
            await aparelho.receber(token: token)
        }
    }

    /// A permissão de notificação é a do sistema. Só o dublê em memória (esquema Local) a simula,
    /// e concedida, para o pedido de verdade não entrar nos testes de interface: lá,
    /// `-FRILA_PERMISSAO_PUSH <nao-pedida|negada|sistema>` escolhe outro estado, e
    /// `-FRILA_PERMISSAO_PUSH_RESPOSTA negada` faz a pessoa recusar o pedido.
    private static func permissaoDePush(para api: any ApiCliente) -> any PermissaoDePush {
        #if DEBUG
        if api is ApiClienteEmMemoria {
            let argumentos = ProcessInfo.processInfo.arguments
            func valor(_ nome: String) -> String? {
                guard let indice = argumentos.firstIndex(of: nome), argumentos.indices.contains(indice + 1) else { return nil }
                return argumentos[indice + 1]
            }
            let pedido = valor("-FRILA_PERMISSAO_PUSH")
            if pedido == "sistema" { return PermissaoDePushDoSistema() }
            return PermissaoDePushSimulada(
                estado: pedido.flatMap(EstadoDaPermissaoDePush.init(rawValue:)) ?? .concedida,
                resposta: valor("-FRILA_PERMISSAO_PUSH_RESPOSTA").flatMap(EstadoDaPermissaoDePush.init(rawValue:)) ?? .concedida
            )
        }
        #endif
        return PermissaoDePushDoSistema()
    }
}

private enum Inicializacao {
    case pronta(Dependencias)
    case configuracaoInvalida(ErroDeConfiguracao)
}

/// O que o app monta uma vez, na abertura, quando a configuração do ambiente é válida.
private struct Dependencias {
    let api: any ApiCliente
    let localizacao: any LeitorDeLocalizacao
    let aparelho: AparelhoDePush
    let permissao: any PermissaoDePush
    let canal: any CanalDePush
}

/// Decide o que o app abre. Com o dublê (esquema Local), ou com sessão guardada no Dev e no Prod, abre
/// a lista de vagas do profissional (#104). Sem sessão, fica a tela de antes: a entrada por código é de
/// outro cartão. Quando a sessão é encerrada (401 ou saída), reavalia.
/// Limite: `possuiSessao()` pode precisar da rede para renovar; offline com sessão guardada, cai na
/// tela de antes até a próxima abertura.
private struct EntradaDoApp: View {
    let api: any ApiCliente
    let armazenamento: ArmazenamentoSwiftData?
    let localizacao: any LeitorDeLocalizacao
    let aparelho: AparelhoDePush
    let canal: any CanalDePush
    private let repositorioTurnos: any TurnoRepositorio
    @Environment(\.scenePhase) private var fase
    @State private var roteador: RoteadorDoProfissional
    @State private var roteadorDoContratante: RoteadorDoContratante
    /// O ponto único do toque num push (#8): confere a conta e manda para um dos dois roteadores acima.
    @State private var roteadorDePush: RoteadorDePush
    /// A permissão de notificação, a tela de explicação e o aviso fixo de quem está sem ela (#8).
    @State private var permissaoDePush: PermissaoDePushModelo
    @State private var contaID: UUID?
    @State private var destinoAtual: DestinoDaConta?
    @State private var carregandoDestino: Bool = true
    @State private var erroAoAvaliar: String?
    #if DEBUG
    @State private var mostrandoCatalogo = false
    @State private var rotaInicialAplicada = false
    #endif

    init(_ dependencias: Dependencias, armazenamento: ArmazenamentoSwiftData?, navegacao: NavegacaoDoApp) {
        let api = dependencias.api
        let localizacao = dependencias.localizacao
        self.api = api
        aparelho = dependencias.aparelho
        canal = dependencias.canal
        _permissaoDePush = State(initialValue: PermissaoDePushModelo(permissao: dependencias.permissao, abrirAjustes: {
            guard let ajustes = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
            UIApplication.shared.open(ajustes)
        }))
        _roteador = State(initialValue: navegacao.profissional)
        _roteadorDoContratante = State(initialValue: navegacao.contratante)
        _roteadorDePush = State(initialValue: navegacao.push)
        #if DEBUG
        // Reproduz a instalação anterior ao cache de sessão, somente com o dublê Local.
        let armazenamento: ArmazenamentoSwiftData? = if api is ApiClienteEmMemoria,
            ProcessInfo.processInfo.arguments.contains("-FRILA_CACHE_VAZIO_UI_TEST") {
            try? ArmazenamentoSwiftData(modelContainer: PersistenciaFrila.criarContainer(emMemoria: true))
        } else if api is ApiClienteEmMemoria,
                  ProcessInfo.processInfo.arguments.contains("-FRILA_SEM_CACHE_UI_TEST") {
            nil
        } else {
            armazenamento
        }
        #endif
        self.armazenamento = armazenamento
        self.localizacao = localizacao
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
            if api is ApiClienteEmMemoria, ProcessInfo.processInfo.arguments.contains("-FRILA_ABRIR_AVALIACAO_UI_TEST") {
                DestinoDaAvaliacaoParaTeste(api: api)
            } else if ProcessInfo.processInfo.arguments.contains("-FRILA_ABRIR_MINHAS_VAGAS") {
                let estabelecimento = EstabelecimentoDaConta(
                    id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
                    nome: "Bistrô Ipê",
                    papel: .administrador
                )
                TelaMinhasVagas(
                    viewModel: MinhasVagasViewModel(api: api, estabelecimento: estabelecimento),
                    api: api,
                    roteador: roteadorDoContratante
                )
                .task { aplicarAvisoDosArgumentos() }
            } else if ProcessInfo.processInfo.arguments.contains("-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO") {
                let apiCadastro = ProcessInfo.processInfo.arguments.contains("-FRILA_CADASTRO_UI_TEST")
                    ? ApiClienteEmMemoria(cenario: .primeiroAcesso) : api
                if let armazenamento {
                    TelaCadastroEstabelecimento(api: apiCadastro, fila: armazenamento, responsavelNome: "Conta de teste", responsavelTelefone: "(61) 99999-0000", sair: acaoDeSair)
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
        .environment(permissaoDePush)
        .sheet(isPresented: $permissaoDePush.explicacaoVisivel) {
            TelaExplicacaoDoPush(modelo: permissaoDePush, perfil: destinoAtual == .contratante ? .contratante : .profissional)
        }
        .task { await avaliarSessao() }
        .task { await permissaoDePush.atualizar() }
        // O token de push passa a ser da conta que está no aparelho, a cada abertura com sessão e a
        // cada entrada (#162). Sem token, ainda não há o que registrar. O roteador do push fica
        // sabendo de quem é o aparelho antes do registro, com o vínculo guardado, para o toque que
        // abriu o app não esperar a rede, e de novo depois, com o vínculo que o servidor confirmou.
        // Só fica registrado quem tem a permissão: sem ela, o token sai do servidor (contrato de
        // `registrar_dispositivo`), e volta quando a permissão vier.
        .task(id: ContaNaTela(contaID: contaID, destino: destinoAtual, permissao: permissaoDePush.estado)) {
            guard let contaID, let permissao = permissaoDePush.estado else { return }
            await informarContaAoPush(contaID)
            if permissao == .concedida {
                // Quem entra depois de uma saída só volta a receber do sistema quando o servidor
                // confirma o token para ela: a ordem está em `AparelhoDePush.ligar`.
                await aparelho.ligar(para: contaID, canal: canal)
            } else {
                await aparelho.suspender()
            }
            await informarContaAoPush(contaID)
            #if DEBUG
            if !Task.isCancelled { aplicarPushDosArgumentos() }
            #endif
            await descartarAvisosDeAntesDoVinculo()
        }
        // O token do FCM chega depois da entrada, e o registro dele termina fora da tarefa acima: o
        // roteador do push fica sabendo do vínculo novo por aqui.
        .task {
            for await _ in await aparelho.mudancasDoVinculo() {
                if let contaID { await informarContaAoPush(contaID) }
                Task { await descartarAvisosDeAntesDoVinculo() }
            }
        }
        // Suspensão e reativação não têm tela própria no payload: a conta é reavaliada, e é a
        // situação dela que decide o que abre.
        .onChange(of: roteadorDePush.reavaliacoesDaConta) {
            Task { await avaliarSessao() }
        }
        // Sem ampliar o observador (que só avisa encerramento): ao voltar a ficar ativo, a entrada
        // confere a sessão de novo. Cobre quem entrou pela seção de validação (Debug) e saiu do app.
        .onChange(of: fase) { _, nova in
            if nova == .active, destinoAtual == nil { Task { await avaliarSessao() } }
            // A pessoa pode ter mudado a permissão de notificação nos Ajustes.
            if nova == .active { Task { await permissaoDePush.atualizar() } }
        }
        .task {
            guard let observador = api as? any ObservadorDeSessao else { return }
            for await _ in observador.encerramentos() {
                UserDefaultsArmazenamentoAvaliacoes().limpar()
                await aparelho.desvincular()
                await canal.suspenderEntrega()
                await canal.limparEntregues()
                roteadorDePush.semSessao()
                contaID = nil
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
            sincronizador: SincronizadorAcoes(fila: armazenamento, api: api, avaliacaoJaRegistrada: { acao in
                guard let turnoID = acao.turnoID, let contaID = acao.contaID else { return }
                UserDefaultsArmazenamentoAvaliacoes().registrarSemResposta(para: turnoID, contaID: contaID)
            })
        )
        let saida = SaidaDaConta(api: api, armazenamento: armazenamento, aparelho: aparelho, canal: canal,
                                limparAvaliacoes: { UserDefaultsArmazenamentoAvaliacoes().limpar() })
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
                let contaDoCadastro = contaID
                CriacaoDoPerfilProfissional(api: api, sair: acaoDeSair) {
                    // Uma resposta atrasada não reabre Vagas depois de sair ou trocar de conta.
                    guard destinoAtual == .funcoesEHorarios, contaID == contaDoCadastro else { return }
                    aplicarDestinoIdentificado(.profissional)
                }
            case .contratante:
                fluxoContratanteView
            case let .cadastro(email):
                FluxoDeEntrada(api: api, rotaInicial: .cadastro(email: email ?? "")) { destino in
                    aplicarDestinoManual(destino)
                }
            case let .contaSuspensa(situacao):
                TelaContaSuspensa(
                    viewModel: ContaSuspensaViewModel(
                        situacao: situacao,
                        api: api,
                        aoReativar: {
                            Task { await avaliarSessao() }
                        },
                        sair: acaoDeSair
                    ),
                    api: api
                )
            }
        } else {
            FluxoDeEntrada(api: api) { destino in
                aplicarDestinoManual(destino)
            }
        }
    }

    /// Diz ao roteador do push quem está no aparelho. A tarefa cancelada, ou de uma conta que já
    /// não é a da tela, não informa nada.
    private func informarContaAoPush(_ contaID: UUID) async {
        let vinculo = await aparelho.vinculo()
        // Sem destino, a conta ainda está sendo avaliada: informar agora decidiria um toque pendente
        // sem saber o fluxo dela.
        guard !Task.isCancelled, contaID == self.contaID, let destinoAtual else { return }
        let fluxo: FluxoDaConta = switch destinoAtual {
        case .profissional: .profissional
        case .contratante: .contratante
        // A conta suspensa não tem fluxo: só os avisos da conta (suspensão e reativação) a reavaliam.
        case .funcoesEHorarios, .cadastro, .contaSuspensa: .nenhum
        }
        roteadorDePush.contaAtiva(ContaNoAparelho(contaID: contaID, fluxo: fluxo, vinculo: vinculo))
    }

    /// O que foi entregue antes de o aparelho ser da conta que está na tela não é dela: sai da
    /// central. Na troca de conta o vínculo só vale depois da carência, e o que chegar nela sai
    /// quando ela acaba.
    private func descartarAvisosDeAntesDoVinculo() async {
        guard !Task.isCancelled, let desde = await aparelho.vinculo()?.desde else { return }
        await canal.descartarEntregues(antesDe: desde)
        let espera = desde.timeIntervalSinceNow
        guard espera > 0, (try? await Task.sleep(for: .seconds(espera))) != nil else { return }
        if await aparelho.vinculo()?.desde == desde { await canal.descartarEntregues(antesDe: desde) }
    }

    private func aplicarDestinoManual(_ destino: DestinoAposEntrada) {
        // Uma nova autenticação nunca herda o ID da conta anterior, nem mesmo sem rede.
        contaID = nil
        destinoAtual = nil
        carregandoDestino = true
        Task {
            do {
                contaID = try await IdentidadeDaAvaliacao.obter(api: api, cache: armazenamento, permitirCache: false)
                roteador.voltarParaLista()
                aplicarDestinoIdentificado(destino)
            } catch {
                erroAoAvaliar = MensagemDoErroAPI.texto(error as? ErroDaApi ?? ErroDaApi(codigo: .semRede))
            }
            carregandoDestino = false
        }
    }

    private func aplicarDestinoIdentificado(_ destino: DestinoAposEntrada) {
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
        case let .contaSuspensa(situacao):
            destinoAtual = .contaSuspensa(situacao)
        }
    }

    @ViewBuilder
    private var fluxoContratanteView: some View {
        #if DEBUG
        FluxoDoContratante(api: api, fila: armazenamento, roteador: roteadorDoContratante, sair: acaoDeSair)
            // Aviso da casa simulado: a mesma entrada que o push vai usar (S2 #8). Abre a vaga ou o
            // turno; nunca confirma presença nem reabre vaga sozinho.
            .task { aplicarAvisoDosArgumentos() }
        #else
        FluxoDoContratante(api: api, fila: armazenamento, roteador: roteadorDoContratante, sair: acaoDeSair)
        #endif
    }

    @ViewBuilder
    private var fluxoProfissionalView: some View {
        #if DEBUG
        FluxoDoProfissional(api: api, contaID: contaID, roteador: roteador, repositorioTurnos: repositorioTurnos, localizacao: localizacao, fila: armazenamento, sair: acaoDeSair) {
            Button("Catálogo") { mostrandoCatalogo = true }
                .accessibilityHint("Abre o catálogo de componentes, só em Debug")
        }
        .id(contaID)
        .sheet(isPresented: $mostrandoCatalogo) { catalogo }
        .task {
            // Roteador de destino com vaga_id simulado (#105 C3): a mesma entrada que o push do tipo
            // vaga vai usar (S2 #8). Abre o detalhe; nunca candidata sozinho.
            guard !rotaInicialAplicada else { return }
            if api is ApiClienteEmMemoria, let turnoID = Self.turnoIDDosArgumentos() {
                rotaInicialAplicada = true
                roteador.abrirAvaliacao(turnoID: turnoID)
                return
            }
            guard let vagaID = Self.vagaIDDosArgumentos() else { return }
            rotaInicialAplicada = true
            roteador.abrirVaga(id: vagaID)
        }
        #else
        FluxoDoProfissional(api: api, contaID: contaID, roteador: roteador, repositorioTurnos: repositorioTurnos, localizacao: localizacao, fila: armazenamento, sair: acaoDeSair)
            .id(contaID)
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

    /// `-FRILA_AVISO <tipo> -FRILA_AVISO_ID <uuid>`: abre o destino de um aviso da casa, como o toque
    /// no push (#8) vai abrir. O id é o `vaga_id` em `vaga_vazia` e o `turno_id` nos outros tipos.
    private func aplicarAvisoDosArgumentos() {
        let argumentos = ProcessInfo.processInfo.arguments
        guard !rotaInicialAplicada,
              let tipo = argumentos.firstIndex(of: "-FRILA_AVISO"), argumentos.indices.contains(tipo + 1),
              let id = argumentos.firstIndex(of: "-FRILA_AVISO_ID"), argumentos.indices.contains(id + 1),
              let aviso = AvisoDoContratante(
                  tipo: argumentos[tipo + 1],
                  payload: ["vaga_id": argumentos[id + 1], "turno_id": argumentos[id + 1]]
              ) else { return }
        rotaInicialAplicada = true
        roteadorDoContratante.abrir(aviso)
    }

    /// `-FRILA_PUSH <tipo> -FRILA_PUSH_ID <uuid>`: o toque num push, pelo caminho inteiro do #8, só
    /// contra o dublê. O id vai como `vaga_id` e como `turno_id`, e o roteador usa o que o tipo pede.
    /// Com `-FRILA_PUSH_DE_ANTES`, o aviso chegou antes de o aparelho ser da conta e não abre nada.
    /// Com `-FRILA_PUSH_NOTIFICACAO_EM <segundos>`, o payload vai numa notificação local: quem a
    /// mostra e entrega o toque é o sistema, pelo `AppDelegate`, com o app aberto, em segundo plano
    /// ou fechado, como no push de verdade. Precisa da permissão do sistema (`-FRILA_PERMISSAO_PUSH sistema`).
    private func aplicarPushDosArgumentos() {
        let argumentos = ProcessInfo.processInfo.arguments
        guard api is ApiClienteEmMemoria, !rotaInicialAplicada,
              let tipo = argumentos.firstIndex(of: "-FRILA_PUSH"), argumentos.indices.contains(tipo + 1) else { return }
        var payload = ["tipo": argumentos[tipo + 1]]
        if let id = argumentos.firstIndex(of: "-FRILA_PUSH_ID"), argumentos.indices.contains(id + 1) {
            payload["vaga_id"] = argumentos[id + 1]
            payload["turno_id"] = argumentos[id + 1]
        }
        if let espera = argumentos.firstIndex(of: "-FRILA_PUSH_NOTIFICACAO_EM"), argumentos.indices.contains(espera + 1),
           let segundos = TimeInterval(argumentos[espera + 1]), segundos > 0 {
            // Sem a permissão o sistema recusa a notificação: espera a pessoa conceder.
            guard permissaoDePush.estado == .concedida else { return }
            rotaInicialAplicada = true
            let conteudo = UNMutableNotificationContent()
            conteudo.title = "Frila"
            conteudo.body = "Aviso simulado: \(argumentos[tipo + 1])"
            conteudo.userInfo = payload
            UNUserNotificationCenter.current().add(UNNotificationRequest(
                identifier: UUID().uuidString, content: conteudo,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: segundos, repeats: false)
            ))
            return
        }
        rotaInicialAplicada = true
        let entregueEm: Date = argumentos.contains("-FRILA_PUSH_DE_ANTES") ? .distantPast : .now
        roteadorDePush.tocar(payload: payload, entregueEm: entregueEm)
    }

    private static func turnoIDDosArgumentos() -> UUID? {
        let argumentos = ProcessInfo.processInfo.arguments
        guard let indice = argumentos.firstIndex(of: "-FRILA_AVALIACAO_TURNO_ID"), argumentos.indices.contains(indice + 1) else { return nil }
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
            roteadorDePush.semSessao()
            contaID = nil
            destinoAtual = nil
            carregandoDestino = false
            return
        }

        do {
            let destino = try await DestinoDaConta.avaliarComRecuperacaoOffline(api: api)
            if destino.tipoGuardavel != nil {
                do {
                    contaID = try await IdentidadeDaAvaliacao.obter(api: api, cache: armazenamento)
                } catch let erro as ErroDaApi where erro.codigo == .semRede {
                    // O destino guardado continua disponível sem identidade. Só a avaliação depende dela.
                    contaID = nil
                }
            } else {
                contaID = nil
            }
            destinoAtual = destino
            carregandoDestino = false
        } catch let erroApi as ErroDaApi {
            erroAoAvaliar = MensagemDoErroAPI.texto(erroApi)
            carregandoDestino = false
        } catch {
            erroAoAvaliar = String(localized: "Não foi possível concluir esta ação. Tente novamente.", bundle: bundleApresentacao)
            carregandoDestino = false
        }
    }

    private var acaoDeSair: () -> Void {
        { Task { await sairDaConta() } }
    }

    @MainActor
    private func sairDaConta() async {
        roteadorDePush.semSessao()
        contaID = nil
        destinoAtual = nil
        // A saída suspende a entrega do sistema neste aparelho, antes e depois de falar com o
        // servidor, e tira da central o que a conta recebeu, para quem pegar o aparelho depois (RN15).
        await SaidaDaConta(api: api, armazenamento: armazenamento, aparelho: aparelho, canal: canal,
                                limparAvaliacoes: { UserDefaultsArmazenamentoAvaliacoes().limpar() }).sair()
        roteador.voltarParaLista()
        destinoAtual = nil
        await avaliarSessao()
    }
}

/// A conta, o fluxo e a permissão de notificação: quando um deles muda, o registro do aparelho e o
/// roteador do push são atualizados.
private struct ContaNaTela: Equatable {
    let contaID: UUID?
    let destino: DestinoDaConta?
    let permissao: EstadoDaPermissaoDePush?
}

/// O cadastro mantém seu modelo enquanto há erro e usa a mesma saída dos demais fluxos.
private struct CriacaoDoPerfilProfissional: View {
    @State private var viewModel: PerfilProfissionalViewModel
    let sair: () -> Void
    let aoConcluir: () -> Void

    init(api: any ApiCliente, sair: @escaping () -> Void, aoConcluir: @escaping () -> Void) {
        self.sair = sair
        self.aoConcluir = aoConcluir
        #if DEBUG
        if api is ApiClienteEmMemoria,
           ProcessInfo.processInfo.arguments.contains("-FRILA_BUSCA_PERFIL_UI_TEST") {
            // Só a busca externa é simulada: cadastro, seleção e envio usam o fluxo de produto.
            _viewModel = State(initialValue: PerfilProfissionalViewModel(api: api, buscarPontoBase: { _ in
                let item = MKMapItem(placemark: MKPlacemark(coordinate:
                    CLLocationCoordinate2D(latitude: -15.8267, longitude: -47.9218)))
                item.name = "Guará II"
                return [item]
            }))
            return
        }
        #endif
        _viewModel = State(initialValue: PerfilProfissionalViewModel(api: api, modo: .criacao))
    }

    var body: some View {
        NavigationStack {
            TelaPerfilProfissional(viewModel: viewModel, aoSalvar: aoConcluir)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: sair) {
                            Text("Sair", bundle: bundleApresentacao)
                        }
                        .accessibilityIdentifier("criacao-perfil-sair")
                    }
                }
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

#if DEBUG
/// Usa a tela de produto e um armazenamento isolado, apenas contra o dublê Local.
private struct DestinoDaAvaliacaoParaTeste: View {
    @State private var viewModel: AvaliacaoTurnoViewModel

    init(api: any ApiCliente) {
        let contaID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let turnoID = UUID(uuidString: "22000000-0000-0000-0000-000000000001")!
        let armazenamento = ArmazenamentoAvaliacoesEmMemoria()
        if ProcessInfo.processInfo.arguments.contains("-FRILA_AVALIACAO_SALVA_UI_TEST") {
            armazenamento.salvar(resposta: false, para: turnoID, contaID: contaID)
        }
        _viewModel = State(initialValue: AvaliacaoTurnoViewModel(turnoID: turnoID, contaID: contaID,
                                                              api: api, armazenamento: armazenamento))
    }

    var body: some View {
        NavigationStack { TelaAvaliacao(viewModel: viewModel) }
    }
}
#endif
