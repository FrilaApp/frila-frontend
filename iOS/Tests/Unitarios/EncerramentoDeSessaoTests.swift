import Foundation
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
        case "/auth/v1/logout":
            roteiro.contarLogout()
            Self.responder(self, com: roteiro.logout)
        case let caminho where caminho.hasPrefix("/rest/v1/rpc/"):
            if !roteiro.reter(self) { Self.responder(self, com: roteiro.rpc) }
        case let caminho where caminho.hasPrefix("/functions/v1/"):
            Self.responder(self, com: roteiro.funcao)
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

        // A tela recebe um ErroDaApi; qual caso é, depende do decodificador, que esta mudança não
        // toca (hoje o `code` numérico do gateway vira respostaInvalida).
        await #expect(throws: ErroDaApi.self) {
            try await cliente.entrarDemonstracao(email: "demo@example.com", codigo: "000000")
        }

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
