@testable import FrilaDados
import Foundation
import FrilaDominio
import FrilaInfraestrutura
import Testing

private enum Tokens {
    /// O mesmo das fixtures `requisicao-registrar-dispositivo` e `requisicao-remover-dispositivo`.
    static let aparelho = "token-fcm-de-exemplo-0001"
    static let novo = "token-fcm-de-exemplo-0002"
}

private let outraConta = UUID(uuidString: "10000000-0000-0000-0000-0000000000ff")!

// MARK: - Dublê em memória

@Suite("Dispositivo no dublê em memória, como o backend responde (#162)")
struct DispositivoEmMemoriaTests {
    private let agora = Date(timeIntervalSince1970: 1_790_000_000)

    @Test("Registrar devolve a plataforma e a data, e o token passa a ser da conta")
    func registra() async throws {
        let api = ApiClienteEmMemoria(relogio: RelogioFixo(agora: agora))
        let dispositivo = try await api.registrarDispositivo(tokenFCM: Tokens.aparelho)

        let contaID = try await api.minhaConta().id
        #expect(dispositivo == Dispositivo(plataforma: .ios, atualizadoEm: agora))
        #expect(await api.donoDoDispositivo(tokenFCM: Tokens.aparelho) == contaID)
    }

    @Test("Token em branco é campo obrigatório, e com menos de 20 caracteres, campo inválido", arguments: [
        ("   ", CodigoErroAPI.campoObrigatorio),
        ("curto-demais", CodigoErroAPI.campoInvalido),
    ])
    func recusaToken(token: String, codigo: CodigoErroAPI) async throws {
        let api = ApiClienteEmMemoria()
        do {
            _ = try await api.registrarDispositivo(tokenFCM: token)
            Issue.record("o registro devia ter sido recusado")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == codigo)
            #expect(erro.detalhes == "token_fcm")
        }
    }

    @Test("Sem conta, registrar e remover são 401")
    func semConta() async throws {
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        await #expect(throws: ErroDaApi(codigo: .naoAutenticado)) { _ = try await api.registrarDispositivo(tokenFCM: Tokens.aparelho) }
        await #expect(throws: ErroDaApi(codigo: .naoAutenticado)) { try await api.removerDispositivo(tokenFCM: Tokens.aparelho) }
    }

    @Test("Sem rede, registrar e remover falham como falta de rede")
    func semRede() async throws {
        let api = ApiClienteEmMemoria(cenario: .semRede)
        await #expect(throws: ErroDaApi(codigo: .semRede)) { _ = try await api.registrarDispositivo(tokenFCM: Tokens.aparelho) }
        await #expect(throws: ErroDaApi(codigo: .semRede)) { try await api.removerDispositivo(tokenFCM: Tokens.aparelho) }
    }

    @Test("O token que era de outra conta passa para quem registrou: troca de conta no mesmo iPhone")
    func trocaDeDono() async throws {
        let api = ApiClienteEmMemoria()
        await api.registrarDispositivo(tokenFCM: Tokens.aparelho, deOutraConta: outraConta)

        _ = try await api.registrarDispositivo(tokenFCM: Tokens.aparelho)

        let contaID = try await api.minhaConta().id
        #expect(await api.donoDoDispositivo(tokenFCM: Tokens.aparelho) == contaID)
    }

    @Test("Remover só tira o token da própria conta, e repetir ou mandar token curto não é erro")
    func remove() async throws {
        let api = ApiClienteEmMemoria()
        await api.registrarDispositivo(tokenFCM: Tokens.novo, deOutraConta: outraConta)
        _ = try await api.registrarDispositivo(tokenFCM: Tokens.aparelho)

        try await api.removerDispositivo(tokenFCM: Tokens.novo)
        try await api.removerDispositivo(tokenFCM: Tokens.aparelho)
        try await api.removerDispositivo(tokenFCM: Tokens.aparelho)
        try await api.removerDispositivo(tokenFCM: "curto")

        #expect(await api.donoDoDispositivo(tokenFCM: Tokens.novo) == outraConta)
        #expect(await api.donoDoDispositivo(tokenFCM: Tokens.aparelho) == nil)
    }
}

// MARK: - Contrato

@Suite("Contrato do dispositivo: registrar_dispositivo e remover_dispositivo")
struct ContratoDoDispositivoTests {
    @Test("Os corpos e a resposta batem com as fixtures do contrato")
    func fixtures() throws {
        #expect(try ContratoTests.objeto(ContratoAPI.RegistrarDispositivo(tokenFCM: Tokens.aparelho)) == ContratoTests.fixture("requisicao-registrar-dispositivo"))
        #expect(try ContratoTests.objeto(ContratoAPI.RemoverDispositivo(tokenFCM: Tokens.aparelho)) == ContratoTests.fixture("requisicao-remover-dispositivo"))

        let dispositivo = try FixturesDoContrato.carregar("dispositivo", como: ContratoAPI.DispositivoDTO.self).dominio()
        let atualizadoEm = try #require(ContratoAPI.instante("2026-10-10T01:22:00Z"))
        #expect(dispositivo == Dispositivo(plataforma: .ios, atualizadoEm: atualizadoEm))
    }

    private func cliente(_ protocolo: URLProtocol.Type) throws -> SupabaseApiCliente {
        let configuracao = URLSessionConfiguration.ephemeral
        configuracao.protocolClasses = [protocolo]
        return SupabaseApiCliente(
            url: try #require(URL(string: "https://frila-teste.supabase.co")),
            chavePublicavel: "sb_publishable_teste",
            telemetria: TelemetryNula(),
            sessaoHTTP: URLSession(configuration: configuracao)
        )
    }

    @Test("registrar_dispositivo manda o token e a plataforma ios, e lê o dispositivo")
    func registrar() async throws {
        let dispositivo = try await cliente(BackendDoDispositivo.self).registrarDispositivo(tokenFCM: Tokens.aparelho)

        #expect(dispositivo.plataforma == .ios)
        #expect(try BackendDoDispositivo.recebido(em: "registrar_dispositivo") == ContratoTests.fixture("requisicao-registrar-dispositivo"))
    }

    @Test("remover_dispositivo manda o token e aceita removido falso, que não é erro")
    func remover() async throws {
        try await cliente(BackendDoDispositivo.self).removerDispositivo(tokenFCM: Tokens.aparelho)

        #expect(try BackendDoDispositivo.recebido(em: "remover_dispositivo") == ContratoTests.fixture("requisicao-remover-dispositivo"))
    }

    @Test("O 422 do token curto chega tipado, com o campo no detalhe (contrato 0.2.26)")
    func recusa() async throws {
        do {
            _ = try await cliente(RecusaDoDispositivo.self).registrarDispositivo(tokenFCM: "curto")
            Issue.record("o registro devia ter sido recusado")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .campoInvalido)
            #expect(erro.detalhes == "token_fcm")
        }
    }
}

/// A URLSession entrega o corpo ao URLProtocol como stream, e não em `httpBody`.
private func corpoEnviado(em request: URLRequest) -> Data? {
    if let corpo = request.httpBody { return corpo }
    guard let stream = request.httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }
    var dados = Data()
    var buffer = [UInt8](repeating: 0, count: 4_096)
    while stream.hasBytesAvailable {
        let lidos = stream.read(&buffer, maxLength: buffer.count)
        guard lidos > 0 else { break }
        dados.append(buffer, count: lidos)
    }
    return dados
}

private func responder(_ protocolo: URLProtocol, status: Int, corpo: Data) {
    guard let url = protocolo.request.url else { return }
    let resposta = HTTPURLResponse(
        url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"]
    )!
    protocolo.client?.urlProtocol(protocolo, didReceive: resposta, cacheStoragePolicy: .notAllowed)
    protocolo.client?.urlProtocol(protocolo, didLoad: corpo)
    protocolo.client?.urlProtocolDidFinishLoading(protocolo)
}

/// Responde às duas RPCs do dispositivo como o contrato descreve e guarda o corpo recebido por rota.
private final class BackendDoDispositivo: URLProtocol {
    private static let trava = NSLock()
    nonisolated(unsafe) private static var corpos: [String: Data] = [:]

    static func recebido(em rota: String) throws -> NSDictionary {
        let dados = try #require(trava.withLock { corpos[rota] })
        return try #require(JSONSerialization.jsonObject(with: dados) as? NSDictionary)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let rota = request.url?.lastPathComponent ?? ""
        let resposta: Data? = switch rota {
        case "registrar_dispositivo": try? FixturesDoContrato.dados("dispositivo")
        case "remover_dispositivo": Data(#"{"removido":false}"#.utf8)
        default: nil
        }
        guard request.httpMethod == "POST", let resposta else {
            return responder(self, status: 500, corpo: Data("{}".utf8))
        }
        if let corpo = corpoEnviado(em: request) { Self.trava.withLock { Self.corpos[rota] = corpo } }
        responder(self, status: 200, corpo: resposta)
    }

    override func stopLoading() {}
}

private final class RecusaDoDispositivo: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let envelope = EnvelopeErroAPI(code: "campo_invalido", message: "campo_invalido", details: "token_fcm", hint: nil)
        guard let corpo = try? JSONEncoder().encode(envelope) else {
            return responder(self, status: 500, corpo: Data("{}".utf8))
        }
        responder(self, status: 422, corpo: corpo)
    }

    override func stopLoading() {}
}

// MARK: - Ciclo de vida do token

/// Segura uma chamada até o teste liberar, para pôr outra operação na fila atrás dela.
private actor Portao {
    private var aberto = false
    private var esperando: [CheckedContinuation<Void, Never>] = []
    private var chegou: [CheckedContinuation<Void, Never>] = []
    private var chegadas = 0

    func passar() async {
        chegadas += 1
        chegou.forEach { $0.resume() }
        chegou = []
        if aberto { return }
        await withCheckedContinuation { esperando.append($0) }
    }

    /// Volta quando alguém já está parado no portão.
    func alguemChegou() async {
        if chegadas > 0 { return }
        await withCheckedContinuation { chegou.append($0) }
    }

    func abrir() {
        aberto = true
        esperando.forEach { $0.resume() }
        esperando = []
    }
}

/// O dublê do contrato, anotando a ordem do que chega ao servidor e podendo cortar a rede.
private final class ApiDoAparelho: ApiClienteEncaminhador, @unchecked Sendable {
    private let trava = NSLock()
    private var _chamadas: [String] = []
    private var _semRede = false
    private var _portao: Portao?

    var chamadas: [String] { trava.withLock { _chamadas } }
    var semRede: Bool {
        get { trava.withLock { _semRede } }
        set { trava.withLock { _semRede = newValue } }
    }
    /// Com portão, `registrarDispositivo` só responde depois de ele abrir.
    var portao: Portao? {
        get { trava.withLock { _portao } }
        set { trava.withLock { _portao = newValue } }
    }

    private func anotar(_ chamada: String) { trava.withLock { _chamadas.append(chamada) } }
    private func exigirRede() throws { if semRede { throw ErroDaApi(codigo: .semRede) } }

    override func registrarDispositivo(tokenFCM: String) async throws -> Dispositivo {
        anotar("registrar \(tokenFCM)")
        await portao?.passar()
        try exigirRede()
        return try await base.registrarDispositivo(tokenFCM: tokenFCM)
    }

    override func removerDispositivo(tokenFCM: String) async throws {
        anotar("remover \(tokenFCM)")
        try exigirRede()
        try await base.removerDispositivo(tokenFCM: tokenFCM)
    }

    /// Como o cliente real: tira o aparelho antes de encerrar a sessão, e sem rede a remoção falha
    /// em silêncio. Não chama o `sair` do dublê, que limpa o destino guardado, global: os testes
    /// que dependem dele rodam em paralelo com estes.
    override func sair(tokenFCM: String?) async {
        anotar("sair \(tokenFCM ?? "sem token")")
        if let tokenFCM, !semRede { try? await base.removerDispositivo(tokenFCM: tokenFCM) }
    }
}

private final class RelogioAjustavel: Relogio, @unchecked Sendable {
    private let trava = NSLock()
    private var instante: Date
    init(_ instante: Date) { self.instante = instante }
    var agora: Date { trava.withLock { instante } }
    func avancar(_ segundos: TimeInterval) { trava.withLock { instante = instante.addingTimeInterval(segundos) } }
}

private struct ObservadorDeUmEncerramento: ObservadorDeSessao {
    func encerramentos() -> AsyncStream<Void> {
        AsyncStream { continuacao in
            continuacao.yield()
            continuacao.finish()
        }
    }
}

@Suite("Ciclo de vida do token de push neste aparelho (#162)")
struct AparelhoDePushTests {
    private let api = ApiDoAparelho()
    private let guardado = ArmazenamentoDoAparelhoEmMemoria()
    private let relogio = RelogioAjustavel(Date(timeIntervalSince1970: 1_790_000_000))

    private func aparelho() -> AparelhoDePush {
        AparelhoDePush(api: api, armazenamento: guardado, relogio: relogio)
    }

    /// O destino guardado é global (`UserDefaults.standard`): estes testes não o limpam, para não
    /// atropelar os que dependem dele e rodam em paralelo.
    private func saida(_ aparelho: AparelhoDePush) -> SaidaDaConta {
        SaidaDaConta(api: api, armazenamento: nil, aparelho: aparelho, limparDestino: {})
    }

    private func conta() async throws -> UUID { try await api.minhaConta().id }
    private func dono(_ token: String) async -> UUID? { await api.base.donoDoDispositivo(tokenFCM: token) }

    @Test("Sem token do FCM não há o que registrar, e nada vai ao servidor")
    func semToken() async throws {
        let registro = await aparelho().registrar(para: try await conta())

        #expect(registro == .semToken)
        #expect(api.chamadas.isEmpty)
        #expect(guardado.ler() == nil)
    }

    @Test("O token que chega antes da entrada fica guardado, e a entrada o registra para a conta")
    func tokenAntesDaEntrada() async throws {
        let aparelho = aparelho()
        let contaID = try await conta()

        #expect(await aparelho.receber(token: Tokens.aparelho) == .semConta)
        #expect(api.chamadas.isEmpty)

        let vinculo = VinculoDoAparelho(contaID: contaID, desde: relogio.agora)
        #expect(await aparelho.registrar(para: contaID) == .registrado(vinculo))
        #expect(await dono(Tokens.aparelho) == contaID)
        #expect(await aparelho.vinculo() == vinculo)
        #expect(guardado.ler() == AparelhoGuardado(token: Tokens.aparelho, vinculo: vinculo))
    }

    @Test("O token que chega depois da entrada é registrado na hora para quem entrou")
    func tokenDepoisDaEntrada() async throws {
        let aparelho = aparelho()
        let contaID = try await conta()
        #expect(await aparelho.registrar(para: contaID) == .semToken)

        let registro = await aparelho.receber(token: Tokens.aparelho)

        #expect(registro == .registrado(VinculoDoAparelho(contaID: contaID, desde: relogio.agora)))
        #expect(await dono(Tokens.aparelho) == contaID)
    }

    @Test("A cada abertura o registro é reenviado, e o aparelho continua da conta desde a primeira vez")
    func reabertura() async throws {
        let contaID = try await conta()
        let desde = relogio.agora
        let primeira = aparelho()
        await primeira.receber(token: Tokens.aparelho)
        await primeira.registrar(para: contaID)

        // Outra abertura do app: instância nova, o mesmo guardado, e o FCM entrega o mesmo token.
        relogio.avancar(86_400)
        let segunda = aparelho()
        #expect(await segunda.vinculo() == VinculoDoAparelho(contaID: contaID, desde: desde))
        #expect(await segunda.registrar(para: contaID) == .registrado(VinculoDoAparelho(contaID: contaID, desde: desde)))
        #expect(await segunda.receber(token: Tokens.aparelho) == .registrado(VinculoDoAparelho(contaID: contaID, desde: desde)))

        #expect(api.chamadas == ["registrar \(Tokens.aparelho)", "registrar \(Tokens.aparelho)"])
    }

    @Test("Sair da conta manda o token guardado, e não nil: o aparelho sai do servidor antes de a sessão acabar")
    func saida() async throws {
        let aparelho = aparelho()
        await aparelho.receber(token: Tokens.aparelho)
        await aparelho.registrar(para: try await conta())

        await saida(aparelho).sair()

        #expect(api.chamadas.last == "sair \(Tokens.aparelho)")
        #expect(await dono(Tokens.aparelho) == nil)
        #expect(await aparelho.vinculo() == nil)
        // O token é do aparelho: fica guardado para a próxima conta que entrar.
        #expect(guardado.ler() == AparelhoGuardado(token: Tokens.aparelho, vinculo: nil))
    }

    @Test("Troca de conta no mesmo iPhone: quem entra vira a dona do token, com um vínculo que começa na entrada")
    func trocaDeConta() async throws {
        // A conta anterior saiu sem rede: o servidor ainda acha que o aparelho é dela.
        let antes = relogio.agora
        await api.base.registrarDispositivo(tokenFCM: Tokens.aparelho, deOutraConta: outraConta)
        guardado.guardar(AparelhoGuardado(token: Tokens.aparelho, vinculo: nil))
        relogio.avancar(600)

        let aparelho = aparelho()
        let contaID = try await conta()
        let registro = await aparelho.registrar(para: contaID)

        #expect(registro == .registrado(VinculoDoAparelho(contaID: contaID, desde: antes.addingTimeInterval(600))))
        #expect(await dono(Tokens.aparelho) == contaID)
    }

    @Test("O vínculo guardado de outra conta nunca é herdado: o da conta que entra começa do zero")
    func vinculoDeOutraConta() async throws {
        let antigo = VinculoDoAparelho(contaID: outraConta, desde: relogio.agora)
        guardado.guardar(AparelhoGuardado(token: Tokens.aparelho, vinculo: antigo))
        relogio.avancar(60)
        let aparelho = aparelho()
        let contaID = try await conta()

        api.semRede = true
        #expect(await aparelho.registrar(para: contaID) == .falhou(ErroDaApi(codigo: .semRede)))
        // Sem a confirmação do servidor, o aparelho ainda não é de quem entrou.
        #expect(await aparelho.vinculo() == antigo)

        api.semRede = false
        #expect(await aparelho.registrar(para: contaID) == .registrado(VinculoDoAparelho(contaID: contaID, desde: relogio.agora)))
    }

    @Test("Sair sem rede não segura a saída: o aparelho deixa de ser da conta aqui, e a próxima entrada toma o token")
    func saidaSemRede() async throws {
        let aparelho = aparelho()
        let contaID = try await conta()
        await aparelho.receber(token: Tokens.aparelho)
        await aparelho.registrar(para: contaID)

        api.semRede = true
        await saida(aparelho).sair()

        #expect(api.chamadas.last == "sair \(Tokens.aparelho)")
        #expect(await aparelho.vinculo() == nil)
        // Limite conhecido: sem rede, o servidor continua com o token até outra conta entrar.
        #expect(await dono(Tokens.aparelho) == contaID)
    }

    @Test("Token trocado pelo FCM com alguém dentro: o antigo sai, o novo entra e o vínculo continua")
    func tokenTrocado() async throws {
        let aparelho = aparelho()
        let contaID = try await conta()
        let desde = relogio.agora
        await aparelho.receber(token: Tokens.aparelho)
        await aparelho.registrar(para: contaID)
        relogio.avancar(3_600)

        let registro = await aparelho.receber(token: Tokens.novo)

        #expect(registro == .registrado(VinculoDoAparelho(contaID: contaID, desde: desde)))
        #expect(api.chamadas.suffix(2) == ["remover \(Tokens.aparelho)", "registrar \(Tokens.novo)"])
        #expect(await dono(Tokens.aparelho) == nil)
        #expect(await dono(Tokens.novo) == contaID)
        #expect(guardado.ler()?.token == Tokens.novo)
    }

    @Test("Token trocado sem ninguém dentro só é guardado")
    func tokenTrocadoSemConta() async throws {
        guardado.guardar(AparelhoGuardado(token: Tokens.aparelho, vinculo: nil))

        #expect(await aparelho().receber(token: Tokens.novo) == .semConta)
        #expect(api.chamadas.isEmpty)
        #expect(guardado.ler() == AparelhoGuardado(token: Tokens.novo, vinculo: nil))
    }

    @Test("Sessão encerrada sem a pessoa pedir desfaz o vínculo sem chamar o servidor, que já não aceitaria")
    func encerramento() async throws {
        let aparelho = aparelho()
        await aparelho.receber(token: Tokens.aparelho)
        await aparelho.registrar(para: try await conta())
        let antes = api.chamadas

        await saida(aparelho).acompanharEncerramentos(de: ObservadorDeUmEncerramento())

        #expect(await aparelho.vinculo() == nil)
        #expect(api.chamadas == antes)
        // Depois do encerramento, um token novo não é registrado para a conta que caiu.
        #expect(await aparelho.receber(token: Tokens.novo) == .semConta)
    }

    @Test("Excluir a conta desfaz o vínculo do aparelho, e a exclusão recusada não desfaz")
    func exclusao() async throws {
        struct Porta: ExclusaoDeContaPorta {
            let erro: ErroDaApi?
            func excluirConta() async throws -> ExclusaoDeConta {
                if let erro { throw erro }
                return ExclusaoDeConta(perfilRemovidoEm: .now, dadosApagadosAte: try DataCivil("2026-10-17"), turnosCancelados: 0)
            }
        }
        let aparelho = aparelho()
        let contaID = try await conta()
        await aparelho.receber(token: Tokens.aparelho)
        await aparelho.registrar(para: contaID)
        let vinculo = await aparelho.vinculo()

        await #expect(throws: ErroDaApi(codigo: .administradorUnico)) {
            try await saida(aparelho).excluir(porta: Porta(erro: ErroDaApi(codigo: .administradorUnico)))
        }
        #expect(await aparelho.vinculo() == vinculo)

        // No servidor, é a própria exclusão que apaga os aparelhos da conta
        // (frila-backend, `20260929160000_excluir_conta_autor.sql`).
        try await saida(aparelho).excluir(porta: Porta(erro: nil))
        #expect(await aparelho.vinculo() == nil)
        #expect(await aparelho.receber(token: Tokens.novo) == .semConta)
    }

    @Test("Saída pedida com um registro em voo espera o registro e só então tira o token: ele não fica com quem saiu")
    func saidaComRegistroEmVoo() async throws {
        let aparelho = aparelho()
        let contaID = try await conta()
        await aparelho.receber(token: Tokens.aparelho)
        let portao = Portao()
        api.portao = portao

        async let registro = aparelho.registrar(para: contaID)
        await portao.alguemChegou()
        async let saida: Void = saida(aparelho).sair()
        await portao.abrir()
        _ = await (registro, saida)

        #expect(api.chamadas == ["registrar \(Tokens.aparelho)", "sair \(Tokens.aparelho)"])
        #expect(await dono(Tokens.aparelho) == nil)
        #expect(await aparelho.vinculo() == nil)
    }
}

@Suite("O guardado do aparelho no Keychain")
struct ArmazenamentoDoAparelhoNoKeychainTests {
    @Test("Guarda e lê o token e o vínculo, e a segunda gravação substitui a primeira")
    func idaEVolta() throws {
        let servico = "com.frila.org.app.push.teste.\(UUID().uuidString)"
        let armazenamento = ArmazenamentoDoAparelhoNoKeychain(servico: servico)
        defer { try? ArmazenamentoKeychain(servico: servico).remover(conta: "aparelho") }
        #expect(armazenamento.ler() == nil)

        armazenamento.guardar(AparelhoGuardado(token: Tokens.aparelho, vinculo: nil))
        let vinculo = VinculoDoAparelho(contaID: outraConta, desde: Date(timeIntervalSince1970: 1_790_000_000))
        armazenamento.guardar(AparelhoGuardado(token: Tokens.novo, vinculo: vinculo))

        #expect(armazenamento.ler() == AparelhoGuardado(token: Tokens.novo, vinculo: vinculo))
    }
}
