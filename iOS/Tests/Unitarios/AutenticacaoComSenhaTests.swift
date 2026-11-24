import Foundation
import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

@Suite("Autenticação com senha")
struct AutenticacaoComSenhaTests {

    // MARK: - EntradaComSenhaViewModel

    @Test("Entrada com senha válida resolve destino de profissional e limpa a senha da memória da view model")
    @MainActor
    func entradaComSenhaProfissional() async {
        let api = ApiClienteEmMemoria(cenario: .sucesso, sessaoAtivaInicial: false)
        let vm = EntradaComSenhaViewModel(api: api, emailInicial: "  Prof@Exemplo.Test ")
        vm.senha = "SenhaSintetica#2026"

        let destino = await vm.entrar()

        #expect(destino == .destino(.profissional))
        #expect(vm.erro == nil)
        #expect(vm.carregando == false)
        #expect(vm.senha.isEmpty)
        #expect(await api.chamadasAEntrarComSenha == 1)
        #expect(await api.possuiSessao() == true)
    }

    @Test("Entrada com senha válida resolve destino de contratante")
    @MainActor
    func entradaComSenhaContratante() async {
        let api = ApiClienteEmMemoria(cenario: .contratante, sessaoAtivaInicial: false)
        let vm = EntradaComSenhaViewModel(api: api, emailInicial: "casa@exemplo.test")
        vm.senha = "SenhaSintetica#2026"

        let destino = await vm.entrar()

        #expect(destino == .destino(.contratante))
        #expect(vm.erro == nil)
    }

    @Test("Entrada com senha em conta sem cadastro na API encaminha para cadastro")
    @MainActor
    func entradaComSenhaPrimeiroAcesso() async {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso, sessaoAtivaInicial: false)
        let vm = EntradaComSenhaViewModel(api: api, emailInicial: "novo@exemplo.test")
        vm.senha = "SenhaSintetica#2026"

        let destino = await vm.entrar()

        #expect(destino == .cadastro(email: "novo@exemplo.test"))
    }

    @Test("Entrada com senha em conta suspensa devolve destino contaSuspensa")
    @MainActor
    func entradaComSenhaContaSuspensa() async {
        let api = ApiClienteEmMemoria(cenario: .contaSuspensa, sessaoAtivaInicial: false)
        let vm = EntradaComSenhaViewModel(api: api, emailInicial: "suspenso@exemplo.test")
        vm.senha = "SenhaSintetica#2026"

        let destino = await vm.entrar()

        guard case .destino(.contaSuspensa) = destino else {
            Issue.record("Esperava destino .contaSuspensa, recebeu \(String(describing: destino))")
            return
        }
    }

    @Test("Entrada com senha recusa credenciais incorretas sem abrir sessão")
    @MainActor
    func entradaComSenhaIncorreta() async {
        let api = ApiClienteEmMemoria(cenario: .senhaErrada, sessaoAtivaInicial: false)
        let vm = EntradaComSenhaViewModel(api: api, emailInicial: "prof@exemplo.test")
        vm.senha = "SenhaIncorreta#1"

        let destino = await vm.entrar()

        #expect(destino == nil)
        #expect(vm.erro != nil)
        #expect(await api.possuiSessao() == false)
    }

    @Test("Entrada com senha valida e-mail, senha vazia e conta de demonstração localmente")
    @MainActor
    func validacoesLocaisEntradaComSenha() async {
        let api = ApiClienteEmMemoria(cenario: .sucesso, sessaoAtivaInicial: false)
        let vm = EntradaComSenhaViewModel(api: api, emailInicial: "invalido")
        vm.senha = "SenhaSintetica#2026"

        #expect(await vm.entrar() == nil)
        #expect(vm.erro != nil)
        #expect(await api.chamadasAEntrarComSenha == 0)

        vm.email = "prof@exemplo.test"
        vm.senha = ""
        #expect(await vm.entrar() == nil)
        #expect(vm.erro != nil)
        #expect(await api.chamadasAEntrarComSenha == 0)

        vm.email = "revisao-profissional@frilabr.com"
        vm.senha = "SenhaSintetica#2026"
        #expect(await vm.entrar() == nil)
        #expect(vm.erro != nil)
        #expect(await api.chamadasAEntrarComSenha == 0)
    }

    @Test("Entrada com senha mapeia falta de rede e limite excedido")
    @MainActor
    func errosDeRedeELimiteEntradaComSenha() async {
        let apiSemRede = ApiClienteEmMemoria(cenario: .semRede, sessaoAtivaInicial: false)
        let vmSemRede = EntradaComSenhaViewModel(api: apiSemRede, emailInicial: "prof@exemplo.test")
        vmSemRede.senha = "SenhaSintetica#2026"
        #expect(await vmSemRede.entrar() == nil)
        #expect(vmSemRede.erro == MensagemDoErroAPI.texto(ErroDaApi(codigo: .semRede)))

        let apiLimite = ApiComErroDeSenha(erro: ErroDaApi(codigo: .limiteExcedido, codigoOriginal: "over_request_rate_limit"))
        let vmLimite = EntradaComSenhaViewModel(api: apiLimite, emailInicial: "prof@exemplo.test")
        vmLimite.senha = "SenhaSintetica#2026"
        #expect(await vmLimite.entrar() == nil)
        #expect(vmLimite.erro == MensagemDoErroAPI.texto(ErroDaApi(codigo: .limiteExcedido)))
    }

    @Test("Tentativa cancelada ou atrasada não sobrescreve erro nem entrega destino obsoleto")
    @MainActor
    func tentativaCanceladaNaoInvadeEstado() async {
        let api = ApiSenhaLentaControlada()
        let vm = EntradaComSenhaViewModel(api: api, emailInicial: "prof@exemplo.test")
        vm.senha = "SenhaSintetica#2026"

        let tarefa = Task { @MainActor in
            await vm.entrar()
        }
        await api.esperarInicioDaChamada()

        vm.cancelarTentativaAtual()
        tarefa.cancel()
        await api.concluirCom(erro: ErroDaApi(codigo: .naoAutenticado, codigoOriginal: "invalid_credentials"))

        let resultado = await tarefa.value
        #expect(resultado == nil)
        #expect(vm.erro == nil)
        #expect(vm.carregando == false)
    }

    // MARK: - DefinirSenhaViewModel

    @Test("Definir senha em sessão autenticada salva com sucesso e limpa campos")
    @MainActor
    func definirSenhaSucesso() async {
        let api = ApiClienteEmMemoria(cenario: .sucesso, sessaoAtivaInicial: true)
        let vm = DefinirSenhaViewModel(api: api)
        vm.senha = "NovaSenha#2026"
        vm.confirmacao = "NovaSenha#2026"

        let salvou = await vm.salvar()

        #expect(salvou == true)
        #expect(vm.concluido == true)
        #expect(vm.erro == nil)
        #expect(vm.senha.isEmpty)
        #expect(vm.confirmacao.isEmpty)
        #expect(await api.senhasDefinidas == 1)
    }

    @Test("Definir senha valida tamanho mínimo e confirmação antes de chamar a API")
    @MainActor
    func definirSenhaValidacaoLocal() async {
        let api = ApiClienteEmMemoria(cenario: .sucesso, sessaoAtivaInicial: true)
        let vm = DefinirSenhaViewModel(api: api)

        vm.senha = "curta"
        vm.confirmacao = "curta"
        #expect(await vm.salvar() == false)
        #expect(vm.erro != nil)
        #expect(await api.senhasDefinidas == 0)

        vm.senha = "NovaSenha#2026"
        vm.confirmacao = "OutraSenha#2026"
        #expect(await vm.salvar() == false)
        #expect(vm.erro != nil)
        #expect(await api.senhasDefinidas == 0)
    }

    @Test("Definir senha trata weak_password, same_password e reauthentication_needed")
    @MainActor
    func definirSenhaErrosDoServidor() async {
        let apiFraca = ApiClienteEmMemoria(cenario: .senhaFraca, sessaoAtivaInicial: true)
        let vmFraca = DefinirSenhaViewModel(api: apiFraca)
        vmFraca.senha = "12345678"
        vmFraca.confirmacao = "12345678"
        #expect(await vmFraca.salvar() == false)
        #expect(vmFraca.erro?.contains("forte") == true)

        let apiReauth = ApiClienteEmMemoria(cenario: .reautenticacaoNecessaria, sessaoAtivaInicial: true)
        let vmReauth = DefinirSenhaViewModel(api: apiReauth)
        vmReauth.senha = "NovaSenha#2026"
        vmReauth.confirmacao = "NovaSenha#2026"
        #expect(await vmReauth.salvar() == false)
        #expect(vmReauth.erro?.contains("código") == true)
        #expect(await apiReauth.possuiSessao() == true)

        let apiIgual = ApiComErroDeSenha(erro: ErroDaApi(codigo: .campoInvalido, codigoOriginal: "same_password", detalhes: "senha"))
        let vmIgual = DefinirSenhaViewModel(api: apiIgual)
        vmIgual.senha = "MesmaSenha#2026"
        vmIgual.confirmacao = "MesmaSenha#2026"
        #expect(await vmIgual.salvar() == false)
        #expect(vmIgual.erro?.contains("diferente") == true)
    }

    @Test("Recuperação via OTP valida sessão existente e permite definir nova senha na mesma conta")
    @MainActor
    func recuperacaoViaOtpEDefinirSenha() async {
        let api = ApiClienteEmMemoria(cenario: .sucesso, sessaoAtivaInicial: false)
        let recuperacaoVM = RecuperacaoSenhaViewModel(api: api, emailInicial: "prof@exemplo.test")
        #expect(await recuperacaoVM.solicitarRecuperacao() == .avancarParaCodigo(email: "prof@exemplo.test"))
        #expect(await api.chamadasASolicitarRecuperacao == 1)

        let codigoVM = CodigoViewModel(api: api, email: "prof@exemplo.test", modo: .recuperacao)
        codigoVM.codigo = "123456"
        let destino = await codigoVM.confirmarCodigo()
        #expect(destino == .destino(.profissional))
        #expect(await api.possuiSessao() == true)

        let senhaVM = DefinirSenhaViewModel(api: api)
        senhaVM.senha = "SenhaRecuperada#2026"
        senhaVM.confirmacao = "SenhaRecuperada#2026"
        #expect(await senhaVM.salvar() == true)
        #expect(await api.senhasDefinidas == 1)
    }

    // MARK: - RecuperacaoSenhaViewModel (recovery-only)

    @Test("Recuperação apresenta estado neutro para identidade inexistente/social-only sem avançar nem criar conta")
    @MainActor
    func recuperacaoIdentidadeInexistenteMostraEstadoNeutro() async {
        let api = ApiClienteEmMemoria(cenario: .identidadeInexistenteNaRecuperacao, sessaoAtivaInicial: false)
        let vm = RecuperacaoSenhaViewModel(api: api, emailInicial: "naoexiste@exemplo.test")

        let resultado = await vm.solicitarRecuperacao()

        #expect(resultado == .estadoNeutro)
        #expect(vm.mensagemNeutra != nil)
        #expect(vm.erro == nil)
        #expect(await api.possuiSessao() == false)
        #expect(await api.chamadasASolicitarRecuperacao == 1)
    }

    @Test("Recuperação não esconde 429 nem falta de rede e não usa fallback de demonstração")
    @MainActor
    func recuperacaoPreserva429RedeEBloqueiaDemo() async {
        let apiDemo = ApiClienteEmMemoria(cenario: .sucesso, sessaoAtivaInicial: false)
        let vmDemo = RecuperacaoSenhaViewModel(api: apiDemo, emailInicial: "revisao-profissional@frilabr.com")
        #expect(await vmDemo.solicitarRecuperacao() == nil)
        #expect(vmDemo.erro != nil)
        #expect(vmDemo.mensagemNeutra == nil)
        #expect(await apiDemo.chamadasASolicitarRecuperacao == 0)

        let apiSemRede = ApiClienteEmMemoria(cenario: .semRede, sessaoAtivaInicial: false)
        let vmSemRede = RecuperacaoSenhaViewModel(api: apiSemRede, emailInicial: "prof@exemplo.test")
        #expect(await vmSemRede.solicitarRecuperacao() == nil)
        #expect(vmSemRede.erro == MensagemDoErroAPI.texto(ErroDaApi(codigo: .semRede)))
        #expect(vmSemRede.mensagemNeutra == nil)

        let api429 = ApiComErroDeSenha(erro: ErroDaApi(codigo: .limiteExcedido, codigoOriginal: "over_email_send_rate_limit"))
        let vm429 = RecuperacaoSenhaViewModel(api: api429, emailInicial: "prof@exemplo.test")
        #expect(await vm429.solicitarRecuperacao() == nil)
        #expect(vm429.erro == MensagemDoErroAPI.texto(ErroDaApi(codigo: .limiteExcedido)))
        #expect(vm429.mensagemNeutra == nil)
    }

    @Test("Retorno tardio ou cancelado na recuperação não muta estado nem entrega avanço obsoleto")
    @MainActor
    func recuperacaoRetornoTardioNaoInvadeEstado() async {
        let api = ApiSenhaLentaControlada()
        let vm = RecuperacaoSenhaViewModel(api: api, emailInicial: "prof@exemplo.test")

        let tarefa = Task { @MainActor in
            await vm.solicitarRecuperacao()
        }
        await api.esperarInicioDaChamada()

        vm.cancelarTentativaAtual()
        tarefa.cancel()
        await api.concluirComSucesso()

        let resultado = await tarefa.value
        #expect(resultado == nil)
        #expect(vm.erro == nil)
        #expect(vm.mensagemNeutra == nil)
        #expect(vm.carregando == false)
    }

    // MARK: - SupabaseApiCliente (HTTP stub + FilaDeSessao)

    @Test("Recuperação envia create_user:false no envio e no reenvio, preservando OTP de entrada com create_user:true")
    @MainActor
    func supabaseRecuperacaoEnviaCreateUserFalseNoEnvioEReenvio() async throws {
        let roteiro = RoteiroDeSenha()
        let (cliente, _) = Self.criarClienteSupabase(roteiro: roteiro)

        // 1. Entrada/cadastro por OTP preserva create_user: true
        let entradaVM = EntradaViewModel(api: cliente, emailInicial: "novo@exemplo.test")
        #expect(await entradaVM.solicitarCodigo() == true)
        #expect(roteiro.corposDoOTP.last?["create_user"] as? Bool == true)

        // 2. Envio de recuperação envia create_user: false
        let recuperacaoVM = RecuperacaoSenhaViewModel(api: cliente, emailInicial: "prof@exemplo.test")
        #expect(await recuperacaoVM.solicitarRecuperacao() == .avancarParaCodigo(email: "prof@exemplo.test"))
        #expect(roteiro.corposDoOTP.last?["create_user"] as? Bool == false)

        // 3. Reenvio na tela de código em modo .recuperacao também envia create_user: false
        let codigoVM = CodigoViewModel(api: cliente, email: "prof@exemplo.test", modo: .recuperacao)
        codigoVM.segundosRestantes = 0
        await codigoVM.reenviarCodigo()
        #expect(roteiro.corposDoOTP.count == 3)
        #expect(roteiro.corposDoOTP.last?["create_user"] as? Bool == false)

        // 4. Quando GoTrue recusa criação (422 otp_disabled), RecuperacaoSenhaViewModel mostra estado neutro sem avançar
        roteiro.respostaOTP = .http(422, #"{"error_code":"otp_disabled","msg":"Signups not allowed for otp"}"#)
        let vmInexistente = RecuperacaoSenhaViewModel(api: cliente, emailInicial: "socialonly@exemplo.test")
        #expect(await vmInexistente.solicitarRecuperacao() == .estadoNeutro)
        #expect(vmInexistente.mensagemNeutra != nil)
        #expect(vmInexistente.erro == nil)
        #expect(cliente.haSessaoGuardada == false)

        // 5. 429 no GoTrue não é escondido pelo estado neutro
        roteiro.respostaOTP = .http(429, #"{"error_code":"over_email_send_rate_limit","msg":"Rate limit exceeded"}"#)
        let vm429 = RecuperacaoSenhaViewModel(api: cliente, emailInicial: "prof@exemplo.test")
        #expect(await vm429.solicitarRecuperacao() == nil)
        #expect(vm429.erro == MensagemDoErroAPI.texto(ErroDaApi(codigo: .limiteExcedido)))
        #expect(vm429.mensagemNeutra == nil)
    }

    @Test("SupabaseApiCliente.entrarComSenha usa grant_type=password, guarda sessão e mapeia invalid_credentials")
    func supabaseEntrarComSenhaEInvalidCredentials() async throws {
        let roteiro = RoteiroDeSenha()
        let (cliente, _) = Self.criarClienteSupabase(roteiro: roteiro)

        // 1. Credenciais inválidas (HTTP 400 invalid_credentials) não abrem sessão
        roteiro.respostaToken = .http(400, #"{"error_code":"invalid_credentials","msg":"Invalid login credentials"}"#)
        do {
            try await cliente.entrarComSenha(email: "prof@exemplo.test", senha: "errada")
            Issue.record("Esperava erro de credenciais inválidas")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .naoAutenticado)
            #expect(erro.codigoOriginal == "invalid_credentials")
        }
        #expect(cliente.haSessaoGuardada == false)

        // 2. Credenciais válidas chamam /auth/v1/token?grant_type=password e gravam a sessão
        roteiro.respostaToken = .http(200, RoteiroDeSenha.sessao("token-senha-1"))
        try await cliente.entrarComSenha(email: "prof@exemplo.test", senha: "SenhaValida#2026")
        #expect(cliente.haSessaoGuardada == true)
        #expect(roteiro.queriesDeToken.contains("grant_type=password"))
    }

    @Test("SupabaseApiCliente.definirSenha atualiza a sessão atual (mesmo auth.uid) e preserva sessão em reauthentication_needed")
    func supabaseDefinirSenhaPreservaSessao() async throws {
        let roteiro = RoteiroDeSenha()
        let (cliente, _) = Self.criarClienteSupabase(roteiro: roteiro)

        try await cliente.verificarCodigo(email: "prof@exemplo.test", codigo: "123456")
        #expect(cliente.haSessaoGuardada == true)

        // 1. reauthentication_needed (401) NÃO encerra a sessão
        roteiro.respostaUpdateUser = .http(401, #"{"error_code":"reauthentication_needed","msg":"Password update requires reauthentication"}"#)
        do {
            try await cliente.definirSenha("NovaSenha#2026")
            Issue.record("Esperava erro reauthentication_needed")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .naoAutenticado)
            #expect(erro.codigoOriginal == "reauthentication_needed")
        }
        #expect(cliente.haSessaoGuardada == true)

        // 2. Sucesso em PUT /auth/v1/user usa o Bearer da sessão atual
        roteiro.respostaUpdateUser = .http(200, RoteiroDeSenha.usuarioJSON)
        try await cliente.definirSenha("NovaSenha#2026")
        #expect(roteiro.autorizacoesDoUpdateUser.last == "Bearer token-otp-1")
        #expect(cliente.haSessaoGuardada == true)
    }

    @Test("401 atrasado de uma sessão antiga não derruba a sessão nova criada por entrarComSenha")
    func erro401AntigoNaoDerrubaNovaSessaoComSenha() async throws {
        let roteiro = RoteiroDeSenha()
        let (cliente, _) = Self.criarClienteSupabase(roteiro: roteiro)

        // Sessão A via OTP
        try await cliente.verificarCodigo(email: "prof@exemplo.test", codigo: "123456")
        #expect(cliente.haSessaoGuardada == true)

        // Segura a RPC iniciada sob a sessão A
        roteiro.segurarRPCs()
        let tarefaRpcAntiga = Task {
            try? await cliente.minhaConta()
        }
        await roteiro.esperarChegadaDeRPC()

        // Nova entrada via senha cria Sessão B
        roteiro.respostaToken = .http(200, RoteiroDeSenha.sessao("token-senha-nova"))
        try await cliente.entrarComSenha(email: "prof@exemplo.test", senha: "SenhaValida#2026")

        // Agora a RPC da sessão A volta com 401/nao_autenticado
        roteiro.liberarRPCs(com: .http(401, #"{"code":"nao_autenticado","message":"nao_autenticado","details":null,"hint":null}"#))
        _ = await tarefaRpcAntiga.value

        // A sessão B precisa continuar intacta!
        #expect(cliente.haSessaoGuardada == true)
        #expect(roteiro.logouts == 0)
    }

    private static func criarClienteSupabase(roteiro: RoteiroDeSenha) -> (SupabaseApiCliente, ArmazenamentoDeSessaoEmMemoria) {
        let host = "senha-\(UUID().uuidString.lowercased()).frila.test"
        StubDeAuthSenha.registrar(roteiro, host: host)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubDeAuthSenha.self]
        let sessaoHTTP = URLSession(configuration: config)
        let armazenamento = ArmazenamentoDeSessaoEmMemoria()
        let cliente = SupabaseApiCliente(
            url: URL(string: "https://\(host)")!,
            chavePublicavel: "chave-sintetica-teste",
            telemetria: TelemetryNula(),
            sessaoHTTP: sessaoHTTP,
            armazenamentoDaSessao: armazenamento
        )
        return (cliente, armazenamento)
    }
}

// MARK: - Dublês de suporte

private final class ApiComErroDeSenha: ApiClienteEncaminhador, @unchecked Sendable {
    private let erro: ErroDaApi
    init(erro: ErroDaApi) {
        self.erro = erro
        super.init(base: ApiClienteEmMemoria(cenario: .sucesso, sessaoAtivaInicial: true))
    }

    override func entrarComSenha(email: String, senha: String) async throws {
        throw erro
    }

    override func definirSenha(_ novaSenha: String) async throws {
        throw erro
    }

    override func solicitarCodigoDeRecuperacao(email: String) async throws {
        throw erro
    }
}

private final class ApiSenhaLentaControlada: ApiClienteEncaminhador, @unchecked Sendable {
    private let iniciou: AsyncStream<Void>
    private let avisarInicio: AsyncStream<Void>.Continuation
    private let trava = NSLock()
    private var continuacao: CheckedContinuation<Void, Error>?

    init() {
        (iniciou, avisarInicio) = AsyncStream<Void>.makeStream()
        super.init(base: ApiClienteEmMemoria(cenario: .sucesso, sessaoAtivaInicial: false))
    }

    override func entrarComSenha(email: String, senha: String) async throws {
        try await withCheckedThrowingContinuation { cont in
            trava.withLock { continuacao = cont }
            avisarInicio.yield()
        }
    }

    override func solicitarCodigoDeRecuperacao(email: String) async throws {
        try await withCheckedThrowingContinuation { cont in
            trava.withLock { continuacao = cont }
            avisarInicio.yield()
        }
    }

    func esperarInicioDaChamada() async {
        for await _ in iniciou { return }
    }

    func concluirCom(erro: Error) async {
        let cont = trava.withLock { () -> CheckedContinuation<Void, Error>? in
            defer { continuacao = nil }
            return continuacao
        }
        cont?.resume(throwing: erro)
    }

    func concluirComSucesso() async {
        let cont = trava.withLock { () -> CheckedContinuation<Void, Error>? in
            defer { continuacao = nil }
            return continuacao
        }
        cont?.resume()
    }
}

private final class RoteiroDeSenha: @unchecked Sendable {
    enum Resposta: Sendable {
        case http(Int, String)
    }

    private let trava = NSLock()
    private var _respostaOTP: Resposta = .http(200, "{}")
    private var _respostaToken: Resposta = .http(200, RoteiroDeSenha.sessao("token-senha-1"))
    private var _respostaUpdateUser: Resposta = .http(200, RoteiroDeSenha.usuarioJSON)
    private var _corposDoOTP: [[String: Any]] = []
    private var _queriesDeToken: [String] = []
    private var _autorizacoesDoUpdateUser: [String] = []
    private var _logouts = 0
    private var _segurarRPC = false
    private var retidas: [URLProtocol] = []
    private let chegadasRPC: AsyncStream<Void>
    private let avisarChegadaRPC: AsyncStream<Void>.Continuation

    init() {
        (chegadasRPC, avisarChegadaRPC) = AsyncStream<Void>.makeStream()
    }

    var respostaOTP: Resposta {
        get { trava.withLock { _respostaOTP } }
        set { trava.withLock { _respostaOTP = newValue } }
    }

    var respostaToken: Resposta {
        get { trava.withLock { _respostaToken } }
        set { trava.withLock { _respostaToken = newValue } }
    }

    var respostaUpdateUser: Resposta {
        get { trava.withLock { _respostaUpdateUser } }
        set { trava.withLock { _respostaUpdateUser = newValue } }
    }

    var corposDoOTP: [[String: Any]] { trava.withLock { _corposDoOTP } }
    func registrarCorpoDoOTP(_ dados: Data?) {
        guard let dados,
              let json = try? JSONSerialization.jsonObject(with: dados) as? [String: Any] else { return }
        trava.withLock { _corposDoOTP.append(json) }
    }

    var queriesDeToken: [String] { trava.withLock { _queriesDeToken } }
    func registrarQueryDeToken(_ q: String?) { trava.withLock { _queriesDeToken.append(q ?? "") } }

    var autorizacoesDoUpdateUser: [String] { trava.withLock { _autorizacoesDoUpdateUser } }
    func registrarAutorizacaoDoUpdateUser(_ valor: String?) { trava.withLock { _autorizacoesDoUpdateUser.append(valor ?? "") } }

    var logouts: Int { trava.withLock { _logouts } }
    func contarLogout() { trava.withLock { _logouts += 1 } }

    func segurarRPCs() { trava.withLock { _segurarRPC = true } }

    func reter(_ protocolo: URLProtocol) -> Bool {
        let reteve = trava.withLock { () -> Bool in
            guard _segurarRPC else { return false }
            retidas.append(protocolo)
            return true
        }
        if reteve { avisarChegadaRPC.yield() }
        return reteve
    }

    func esperarChegadaDeRPC() async {
        for await _ in chegadasRPC { return }
    }

    func liberarRPCs(com resposta: Resposta) {
        let protocolos = trava.withLock { () -> [URLProtocol] in
            let todos = retidas
            retidas = []
            _segurarRPC = false
            return todos
        }
        for protocolo in protocolos { StubDeAuthSenha.responder(protocolo, com: resposta) }
    }

    static let usuarioJSON = #"{"id":"8f1d6c2e-0000-4000-8000-000000000001","aud":"authenticated","app_metadata":{},"user_metadata":{},"created_at":"2026-09-27T00:00:00Z","updated_at":"2026-09-27T00:00:00Z"}"#

    static func sessao(_ token: String) -> String {
        let expiraEm = Int(Date().timeIntervalSince1970) + 3600
        return #"{"access_token":"\#(token)","token_type":"bearer","expires_in":3600,"expires_at":\#(expiraEm),"refresh_token":"r-\#(token)","user":\#(usuarioJSON)}"#
    }
}

private final class StubDeAuthSenha: URLProtocol {
    private static let trava = NSLock()
    nonisolated(unsafe) private static var roteiros: [String: RoteiroDeSenha] = [:]

    static func registrar(_ roteiro: RoteiroDeSenha, host: String) {
        trava.withLock { roteiros[host] = roteiro }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host,
              let roteiro = Self.trava.withLock({ Self.roteiros[host] }) else {
            Self.responder(self, com: .http(500, "{}"))
            return
        }
        switch url.path {
        case "/auth/v1/otp":
            roteiro.registrarCorpoDoOTP(Self.lerCorpo(request))
            Self.responder(self, com: roteiro.respostaOTP)
        case "/auth/v1/verify":
            Self.responder(self, com: .http(200, RoteiroDeSenha.sessao("token-otp-1")))
        case "/auth/v1/token":
            roteiro.registrarQueryDeToken(url.query)
            Self.responder(self, com: roteiro.respostaToken)
        case "/auth/v1/user":
            roteiro.registrarAutorizacaoDoUpdateUser(request.value(forHTTPHeaderField: "Authorization"))
            Self.responder(self, com: roteiro.respostaUpdateUser)
        case "/auth/v1/logout":
            roteiro.contarLogout()
            Self.responder(self, com: .http(204, ""))
        case let caminho where caminho.hasPrefix("/rest/v1/rpc/"):
            if !roteiro.reter(self) { Self.responder(self, com: .http(200, "{}")) }
        default:
            Self.responder(self, com: .http(500, "{}"))
        }
    }

    override func stopLoading() {}

    private static func lerCorpo(_ request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var dados = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let lidos = stream.read(&buffer, maxLength: buffer.count)
            if lidos <= 0 { break }
            dados.append(buffer, count: lidos)
        }
        return dados.isEmpty ? nil : dados
    }

    static func responder(_ protocolo: URLProtocol, com resposta: RoteiroDeSenha.Resposta) {
        switch resposta {
        case let .http(status, corpo):
            let http = HTTPURLResponse(
                url: protocolo.request.url!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            protocolo.client?.urlProtocol(protocolo, didReceive: http, cacheStoragePolicy: .notAllowed)
            protocolo.client?.urlProtocol(protocolo, didLoad: Data(corpo.utf8))
            protocolo.client?.urlProtocolDidFinishLoading(protocolo)
        }
    }
}
