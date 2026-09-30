import Foundation
import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

/// O que o stub responde para um host de teste. Cada teste usa um host próprio, então os roteiros
/// não se misturam mesmo com testes em paralelo.
final class Roteiro: @unchecked Sendable {
    enum Resposta: Sendable {
        case http(Int, String)
        case semRede
    }

    private let trava = NSLock()
    private var _tokenDoVerify = "token-a"
    private var _falhaNoProximoVerify: Resposta?
    private var _rpc: Resposta = .http(200, "{}")
    private var _funcao: Resposta = .http(404, #"{"code":"nao_encontrado","message":"nao_encontrado","details":null,"hint":null}"#)
    private var _logout: Resposta = .http(204, "")
    private var _otp: Resposta = .http(200, "{}")
    private var _tabela: Resposta = .http(200, "[]")
    private var _logouts = 0
    private var _segurarRPC = false
    private var retidas: [URLProtocol] = []
    private let chegadas: AsyncStream<Void>
    private let avisarChegada: AsyncStream<Void>.Continuation

    init() {
        (chegadas, avisarChegada) = AsyncStream<Void>.makeStream()
    }

    var tokenDoVerify: String {
        get { trava.withLock { _tokenDoVerify } }
        set { trava.withLock { _tokenDoVerify = newValue } }
    }
    /// A próxima chamada a /verify recebe esta resposta; as seguintes voltam ao normal.
    func falharNoProximoVerify(com resposta: Resposta) { trava.withLock { _falhaNoProximoVerify = resposta } }
    func consumirFalhaDoVerify() -> Resposta? {
        trava.withLock { defer { _falhaNoProximoVerify = nil }; return _falhaNoProximoVerify }
    }

    var rpc: Resposta {
        get { trava.withLock { _rpc } }
        set { trava.withLock { _rpc = newValue } }
    }
    var funcao: Resposta {
        get { trava.withLock { _funcao } }
        set { trava.withLock { _funcao = newValue } }
    }
    var logout: Resposta {
        get { trava.withLock { _logout } }
        set { trava.withLock { _logout = newValue } }
    }
    var otp: Resposta {
        get { trava.withLock { _otp } }
        set { trava.withLock { _otp = newValue } }
    }
    /// Leitura direta de tabela pelo PostgREST (`/rest/v1/<tabela>`), fora das RPCs.
    var tabela: Resposta {
        get { trava.withLock { _tabela } }
        set { trava.withLock { _tabela = newValue } }
    }
    var logouts: Int { trava.withLock { _logouts } }
    func contarLogout() { trava.withLock { _logouts += 1 } }

    /// A partir daqui, cada RPC fica parada no stub até `liberar`.
    func segurarRPCs() { trava.withLock { _segurarRPC = true } }

    /// Devolve true se a RPC ficou retida.
    func reter(_ protocolo: URLProtocol) -> Bool {
        let reteve = trava.withLock { () -> Bool in
            guard _segurarRPC else { return false }
            retidas.append(protocolo)
            return true
        }
        if reteve { avisarChegada.yield() }
        return reteve
    }

    /// Espera `quantas` RPCs chegarem ao stub, sem sleep.
    func esperarChegadas(_ quantas: Int) async {
        var restantes = quantas
        for await _ in chegadas {
            restantes -= 1
            if restantes == 0 { return }
        }
    }

    func liberar(com resposta: Resposta) {
        let protocolos = trava.withLock { () -> [URLProtocol] in
            let todos = retidas
            retidas = []
            _segurarRPC = false
            return todos
        }
        for protocolo in protocolos { StubDeAuth.responder(protocolo, com: resposta) }
    }

    static func sessao(_ token: String) -> String {
        let expiraEm = Int(Date().timeIntervalSince1970) + 3600
        return #"{"access_token":"\#(token)","token_type":"bearer","expires_in":3600,"expires_at":\#(expiraEm),"refresh_token":"r-\#(token)","user":{"id":"8f1d6c2e-0000-4000-8000-000000000001","aud":"authenticated","app_metadata":{},"user_metadata":{},"created_at":"2026-09-27T00:00:00Z","updated_at":"2026-09-27T00:00:00Z"}}"#
    }
}

private final class StubDeAuth: URLProtocol {
    private static let trava = NSLock()
    nonisolated(unsafe) private static var roteiros: [String: Roteiro] = [:]

    static func registrar(_ roteiro: Roteiro, host: String) {
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
        case "/auth/v1/verify":
            Self.responder(self, com: roteiro.consumirFalhaDoVerify() ?? .http(200, Roteiro.sessao(roteiro.tokenDoVerify)))
        case "/auth/v1/otp":
            Self.responder(self, com: roteiro.otp)
        case "/auth/v1/logout":
            roteiro.contarLogout()
            Self.responder(self, com: roteiro.logout)
        case let caminho where caminho.hasPrefix("/rest/v1/rpc/"):
            if !roteiro.reter(self) { Self.responder(self, com: roteiro.rpc) }
        case let caminho where caminho.hasPrefix("/functions/v1/"):
            Self.responder(self, com: roteiro.funcao)
        case let caminho where caminho.hasPrefix("/rest/v1/"):
            Self.responder(self, com: roteiro.tabela)
        default:
            Self.responder(self, com: .http(500, "{}"))
        }
    }

    override func stopLoading() {}

    static func responder(_ protocolo: URLProtocol, com resposta: Roteiro.Resposta) {
        switch resposta {
        case .semRede:
            protocolo.client?.urlProtocol(protocolo, didFailWithError: URLError(.notConnectedToInternet))
        case let .http(status, corpo):
            let url = protocolo.request.url!
            let http = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
            protocolo.client?.urlProtocol(protocolo, didReceive: http, cacheStoragePolicy: .notAllowed)
            protocolo.client?.urlProtocol(protocolo, didLoad: Data(corpo.utf8))
            protocolo.client?.urlProtocolDidFinishLoading(protocolo)
        }
    }
}

private func envelope(_ codigo: String) -> String {
    #"{"code":"\#(codigo)","message":"\#(codigo)","details":null,"hint":null}"#
}

private func clienteDeTeste(
    _ roteiro: Roteiro,
    armazenamento: ArmazenamentoDeSessaoEmMemoria = ArmazenamentoDeSessaoEmMemoria()
) throws -> SupabaseApiCliente {
    let host = "t\(UUID().uuidString.prefix(8).lowercased()).supabase.co"
    StubDeAuth.registrar(roteiro, host: host)
    let configuracao = URLSessionConfiguration.ephemeral
    configuracao.protocolClasses = [StubDeAuth.self]
    return SupabaseApiCliente(
        url: try #require(URL(string: "https://\(host)")),
        chavePublicavel: "sb_publishable_teste",
        telemetria: TelemetryNula(),
        sessaoHTTP: URLSession(configuration: configuracao),
        armazenamentoDaSessao: armazenamento
    )
}

// O limite faz uma regressão de autoespera na fila falhar, em vez de travar a CI.
@Suite("Sessão encerrada por 401 (contrato 0.2.18)", .timeLimit(.minutes(1)))
struct EncerramentoDeSessaoTests {
    @Test("401 com nao_autenticado ou PGRST301 encerra a sessão e a tela recebe o erro original",
          arguments: ["nao_autenticado", "PGRST301"])
    func quatroZeroUmComprovadoEncerra(codigo: String) async throws {
        let roteiro = Roteiro()
        let cliente = try clienteDeTeste(roteiro)
        try await cliente.verificarCodigo(email: "c1@example.com", codigo: "123456")
        #expect(cliente.haSessaoGuardada)

        roteiro.rpc = .http(401, envelope(codigo))
        let erro = await #expect(throws: ErroDaApi.self) { _ = try await cliente.minhaConta() }

        #expect(erro?.codigo == .naoAutenticado)
        #expect(erro?.codigoOriginal == codigo)
        #expect(!cliente.haSessaoGuardada)
        #expect(roteiro.logouts == 1)
    }

    @Test("Falha do /logout não troca o erro da tela e a sessão local sai mesmo assim",
          arguments: [Roteiro.Resposta.http(500, "{}"), .semRede])
    func logoutFalhoNaoMascaraOErro(logout: Roteiro.Resposta) async throws {
        let roteiro = Roteiro()
        roteiro.logout = logout
        let cliente = try clienteDeTeste(roteiro)
        try await cliente.verificarCodigo(email: "c1@example.com", codigo: "123456")

        roteiro.rpc = .http(401, envelope("nao_autenticado"))
        let erro = await #expect(throws: ErroDaApi.self) { _ = try await cliente.minhaConta() }

        #expect(erro?.codigoOriginal == "nao_autenticado")
        // Um encerramento efetivo: o cliente de Auth do supabase-swift 2.55.2 repete POST uma vez em
        // 500 e em erro de rede (RetryRequestInterceptor, limite 2), daí 2 requisições. Isso prova uma
        // remoção só, não uma chamada só: um signOut repetido depois da remoção sai sem requisição.
        #expect(roteiro.logouts == 2)
        #expect(!cliente.haSessaoGuardada)
    }

    @Test("Armazenamento que recusa a remoção aparece como sessão ainda guardada, não como sucesso")
    func armazenamentoQueRecusaRemover() async throws {
        let roteiro = Roteiro()
        let cliente = try clienteDeTeste(roteiro, armazenamento: ArmazenamentoDeSessaoEmMemoria(falharAoRemover: true))
        try await cliente.verificarCodigo(email: "c1@example.com", codigo: "123456")

        let resultado = await cliente.encerrarPorSessaoInvalida(sessaoUsada: "token-a")

        #expect(resultado == .sessaoContinuaGuardada)
        #expect(cliente.haSessaoGuardada)
    }

    @Test("401 de uma chamada que saiu antes de uma entrada nova não derruba a sessão nova")
    func quatroZeroUmAntigoNaoDerrubaEntradaNova() async throws {
        let roteiro = Roteiro()
        let cliente = try clienteDeTeste(roteiro)
        try await cliente.verificarCodigo(email: "c1@example.com", codigo: "123456")

        roteiro.segurarRPCs()
        let emVoo = Task { try await cliente.minhaConta() }
        await roteiro.esperarChegadas(1)

        roteiro.tokenDoVerify = "token-b"
        try await cliente.verificarCodigo(email: "c1@example.com", codigo: "654321")

        roteiro.liberar(com: .http(401, envelope("nao_autenticado")))
        await #expect(throws: ErroDaApi.self) { _ = try await emVoo.value }

        #expect(cliente.haSessaoGuardada)
        #expect(roteiro.logouts == 0)
        // A sessão guardada é a nova: encerrar pela antiga não se aplica a ela.
        #expect(await cliente.encerrarPorSessaoInvalida(sessaoUsada: "token-a") == .sessaoTrocada)
    }

    // Prova efeito único (uma remoção, um /logout); um signOut sem sessão não chega à rede.
    @Test("Dois 401 da mesma sessão geram um encerramento só")
    func doisQuatroZeroUmUmEncerramento() async throws {
        let roteiro = Roteiro()
        let cliente = try clienteDeTeste(roteiro)
        try await cliente.verificarCodigo(email: "c1@example.com", codigo: "123456")

        roteiro.segurarRPCs()
        let primeira = Task { try await cliente.minhaConta() }
        let segunda = Task { try await cliente.meuPerfilProfissional() }
        await roteiro.esperarChegadas(2)
        roteiro.liberar(com: .http(401, envelope("nao_autenticado")))

        await #expect(throws: ErroDaApi.self) { _ = try await primeira.value }
        await #expect(throws: ErroDaApi.self) { _ = try await segunda.value }
        #expect(roteiro.logouts == 1)
        #expect(!cliente.haSessaoGuardada)
    }

    @Test("Uma operação da fila que falha não trava a seguinte")
    func falhaNaFilaNaoTravaASeguinte() async throws {
        let roteiro = Roteiro()
        let cliente = try clienteDeTeste(roteiro)
        roteiro.falharNoProximoVerify(com: .http(400, #"{"code":"otp_expired","message":"Token has expired or is invalid"}"#))

        await #expect(throws: ErroDaApi.self) {
            try await cliente.verificarCodigo(email: "c1@example.com", codigo: "111111")
        }
        #expect(!cliente.haSessaoGuardada)

        try await cliente.verificarCodigo(email: "c1@example.com", codigo: "123456")
        #expect(cliente.haSessaoGuardada)
    }

    @Test("Sem sessão, um 401 não encerra nada")
    func semSessaoNenhumEncerramento() async throws {
        let roteiro = Roteiro()
        let cliente = try clienteDeTeste(roteiro)
        roteiro.rpc = .http(401, envelope("nao_autenticado"))

        await #expect(throws: ErroDaApi.self) { _ = try await cliente.minhaConta() }

        #expect(roteiro.logouts == 0)
        #expect(await cliente.encerrarPorSessaoInvalida(sessaoUsada: nil) == .semSessaoNaChamada)
    }

    @Test("42501 sozinho, 403 de privilégio, 409 e 422 mantêm a sessão",
          arguments: [(403, "42501"), (401, "42501"), (403, "sem_permissao"), (409, "posicao_ja_preenchida"), (422, "campo_invalido")])
    func errosQueNaoComprovamSessaoInvalida(status: Int, codigo: String) async throws {
        let roteiro = Roteiro()
        let cliente = try clienteDeTeste(roteiro)
        try await cliente.verificarCodigo(email: "c1@example.com", codigo: "123456")
        roteiro.rpc = .http(status, envelope(codigo))

        let erro = await #expect(throws: ErroDaApi.self) { _ = try await cliente.minhaConta() }

        #expect(erro?.codigoOriginal == codigo)
        #expect(cliente.haSessaoGuardada)
        #expect(roteiro.logouts == 0)
    }

    @Test("42501 continua aparecendo como não autenticado para a tela, sem encerrar a sessão")
    func quatroDoisCincoZeroUmMantemAMensagem() async throws {
        let roteiro = Roteiro()
        let cliente = try clienteDeTeste(roteiro)
        try await cliente.verificarCodigo(email: "c1@example.com", codigo: "123456")
        roteiro.rpc = .http(403, envelope("42501"))

        let erro = await #expect(throws: ErroDaApi.self) { _ = try await cliente.minhaConta() }

        #expect(erro?.codigo == .naoAutenticado)
        #expect(cliente.haSessaoGuardada)
    }

    @Test("Falha de rede na RPC mantém a sessão")
    func falhaDeRedeMantemASessao() async throws {
        let roteiro = Roteiro()
        let cliente = try clienteDeTeste(roteiro)
        try await cliente.verificarCodigo(email: "c1@example.com", codigo: "123456")
        roteiro.rpc = .semRede

        let erro = await #expect(throws: ErroDaApi.self) { _ = try await cliente.minhaConta() }

        #expect(erro?.codigo == .semRede)
        #expect(cliente.haSessaoGuardada)
        #expect(roteiro.logouts == 0)
    }

    @Test("401 do gateway numa Edge Function encerra a sessão usada na chamada")
    func quatroZeroUmDeFuncaoEncerra() async throws {
        let roteiro = Roteiro()
        let cliente = try clienteDeTeste(roteiro)
        try await cliente.verificarCodigo(email: "c1@example.com", codigo: "123456")
        roteiro.funcao = .http(401, #"{"code":401,"message":"Invalid JWT"}"#)

        // O `code` numérico do gateway não é o envelope do contrato; o status 401 decide.
        let erro = await #expect(throws: ErroDaApi.self) {
            try await cliente.entrarDemonstracao(email: "demo@example.com", codigo: "000000")
        }
        #expect(erro?.codigo == .naoAutenticado)

        #expect(!cliente.haSessaoGuardada)
        #expect(roteiro.logouts == 1)
    }

    @Test("O observador avisa o encerramento por 401")
    func observadorAvisaOEncerramento() async throws {
        let roteiro = Roteiro()
        let cliente = try clienteDeTeste(roteiro)
        try await cliente.verificarCodigo(email: "c1@example.com", codigo: "123456")

        let (pronto, avisarPronto) = AsyncStream<Void>.makeStream()
        let avisos = cliente.encerramentos(aoFicarPronto: { avisarPronto.yield() })
        let primeiroAviso = Task { () -> Bool in
            for await _ in avisos { return true }
            return false
        }
        for await _ in pronto { break }

        roteiro.rpc = .http(401, envelope("nao_autenticado"))
        await #expect(throws: ErroDaApi.self) { _ = try await cliente.minhaConta() }

        #expect(await primeiroAviso.value)
    }
}

/// #105 e C2 do #53: o 409 do `candidatar` atravessa o cliente real até o view model como tipo, sem
/// encerrar a sessão (o 409 não é prova de autenticação inválida).
@MainActor
@Suite("Candidatura contra respostas HTTP do contrato", .timeLimit(.minutes(1)))
struct CandidaturaHTTPTests {
    @Test("409 posicao_ja_preenchida e 409 vaga_encerrada chegam ao view model como casos distintos, com a sessão preservada",
          arguments: [("posicao_ja_preenchida", ResultadoDaCandidatura.vagaPreenchida), ("vaga_encerrada", .vagaEncerrada)])
    func conflitoTipado(codigo: String, esperado: ResultadoDaCandidatura) async throws {
        let roteiro = Roteiro()
        let cliente = try clienteDeTeste(roteiro)
        try await cliente.verificarCodigo(email: "c1@example.com", codigo: "123456")
        roteiro.rpc = .http(409, envelope(codigo))
        let duble = ApiClienteEmMemoria()
        let vaga = try await duble.detalheDaVaga(id: try #require(try await duble.vagasAbertas(.todas).first).id)

        let vm = CandidaturaViewModel(vaga: vaga, api: cliente)
        await vm.candidatar()

        #expect(vm.estado == .concluida(esperado))
        #expect(cliente.haSessaoGuardada)
        #expect(roteiro.logouts == 0)
    }
}

/// `/otp` e `/verify` falham como `AuthError`; o contrato promete `limite_excedido` e
/// `nao_autenticado`, e a tela precisa saber qual dos dois aconteceu.
@Suite("Erros da entrada e do catálogo")
struct ErrosDaEntradaTests {
    @Test("429 no envio do código vira limite_excedido")
    func limiteNoEnvio() async throws {
        let roteiro = Roteiro()
        roteiro.otp = .http(429, #"{"code":"over_email_send_rate_limit","error_code":"over_email_send_rate_limit","msg":"email rate limit exceeded"}"#)
        let cliente = try clienteDeTeste(roteiro)

        let erro = await #expect(throws: ErroDaApi.self) {
            try await cliente.solicitarCodigo(email: "c1@example.com")
        }
        #expect(erro?.codigo == .limiteExcedido)
        #expect(erro?.codigoOriginal == "over_email_send_rate_limit")
    }

    @Test("Código errado ou vencido (403 otp_expired do GoTrue) vira nao_autenticado")
    func codigoErradoNaConfirmacao() async throws {
        let roteiro = Roteiro()
        roteiro.falharNoProximoVerify(com: .http(403, #"{"code":"otp_expired","error_code":"otp_expired","msg":"Token has expired or is invalid"}"#))
        let cliente = try clienteDeTeste(roteiro)

        let erro = await #expect(throws: ErroDaApi.self) {
            try await cliente.verificarCodigo(email: "c1@example.com", codigo: "000000")
        }
        #expect(erro?.codigo == .naoAutenticado)
        #expect(!cliente.haSessaoGuardada)
    }

    @Test("401 do contrato na confirmação vira nao_autenticado")
    func quatroZeroUmNaConfirmacao() async throws {
        let roteiro = Roteiro()
        roteiro.falharNoProximoVerify(com: .http(401, #"{"code":"nao_autenticado","error_code":"nao_autenticado","msg":"nao_autenticado"}"#))
        let cliente = try clienteDeTeste(roteiro)

        let erro = await #expect(throws: ErroDaApi.self) {
            try await cliente.verificarCodigo(email: "c1@example.com", codigo: "123456")
        }
        #expect(erro?.codigo == .naoAutenticado)
    }

    @Test("E-mail recusado pelo Auth (400 validation_failed) vira campo_invalido no campo email")
    func emailInvalidoNoEnvio() async throws {
        let roteiro = Roteiro()
        roteiro.otp = .http(400, #"{"code":"validation_failed","error_code":"validation_failed","msg":"Unable to validate email address: invalid format"}"#)
        let cliente = try clienteDeTeste(roteiro)

        let erro = await #expect(throws: ErroDaApi.self) {
            try await cliente.solicitarCodigo(email: "nao-e-email")
        }
        #expect(erro?.codigo == .campoInvalido)
        #expect(erro?.detalhes == "email")
    }

    @Test("401 do gateway sem envelope guarda o status como código original")
    func quatroZeroUmSemEnvelope() {
        let erro = DecodificadorErroAPI.mapear(statusCode: 401, dados: Data(#"{"code":401,"message":"Invalid JWT"}"#.utf8))
        #expect(erro.codigo == .naoAutenticado)
        #expect(erro.codigoOriginal == "http_401")
    }

    @Test("401 na leitura do catálogo de funções encerra a sessão usada na chamada")
    func quatroZeroUmNoCatalogo() async throws {
        let roteiro = Roteiro()
        let cliente = try clienteDeTeste(roteiro)
        try await cliente.verificarCodigo(email: "c1@example.com", codigo: "123456")
        roteiro.tabela = .http(401, #"{"code":"PGRST301","message":"JWT expired","details":null,"hint":null}"#)

        let erro = await #expect(throws: ErroDaApi.self) {
            _ = try await cliente.funcoes()
        }
        #expect(erro?.codigo == .naoAutenticado)
        #expect(!cliente.haSessaoGuardada)
        #expect(roteiro.logouts == 1)
    }
}
