@testable import FrilaApresentacao
@testable import FrilaDados
import Foundation
import FrilaDominio
import Testing

private let casaID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!

/// O código com que a leitura foi recusada, ou nada se ela respondeu.
private func recusa(_ api: ApiClienteEmMemoria, id: UUID) async -> CodigoErroAPI? {
    do {
        _ = try await api.meuEstabelecimento(id: id)
        return nil
    } catch {
        return (error as? ErroDaApi)?.codigo ?? .desconhecido
    }
}

@Suite("meu_estabelecimento no dublê em memória, como o backend responde (contrato 0.2.29)")
struct MeuEstabelecimentoEmMemoriaTests {
    @Test("Quem é membro recebe o cadastro da casa, com o endereço, a região e o ponto, sem documento")
    func membro() async throws {
        let casa = try await ApiClienteEmMemoria(cenario: .contratante).meuEstabelecimento(id: casaID)

        #expect(casa == (try FixturesDoContrato.carregar("meu-estabelecimento", como: ContratoAPI.MeuEstabelecimentoDTO.self).dominio()))
        #expect(casa.endereco == "CLS 405, Asa Sul, Brasília - DF")
        #expect(casa.regiaoAdministrativa == "Plano Piloto")
        #expect(casa.documento.isEmpty)
    }

    @Test("A casa de outra conta e o id que não existe respondem sem_permissao, iguais")
    func naoMembro() async throws {
        #expect(await recusa(ApiClienteEmMemoria(cenario: .contratante), id: UUID()) == .semPermissao)
        #expect(await recusa(ApiClienteEmMemoria(cenario: .contratanteSemEstabelecimento), id: casaID) == .semPermissao)
    }

    @Test("Sem rede, a leitura falha como falta de rede")
    func semRede() async throws {
        #expect(await recusa(ApiClienteEmMemoria(cenario: .semRede), id: casaID) == .semRede)
    }

    @Test("A casa recém-cadastrada pode ser lida de novo, com o endereço e sem o documento")
    func depoisDoCadastro() async throws {
        let api = ApiClienteEmMemoria(cenario: .contratanteSemEstabelecimento)
        let cadastrada = try await api.cadastrarEstabelecimento(CadastroEstabelecimento(
            nome: "Café de teste", documento: "12345678901", tipo: .foodService, endereco: "Brasília, DF",
            regiaoAdministrativa: "Plano Piloto", ponto: try Coordenada(latitude: -15.78, longitude: -47.93)
        ))

        let lida = try await api.meuEstabelecimento(id: cadastrada.id)
        #expect(lida.id == cadastrada.id)
        #expect(lida.nome == cadastrada.nome)
        #expect(lida.tipo == cadastrada.tipo)
        #expect(lida.endereco == cadastrada.endereco)
        #expect(lida.regiaoAdministrativa == cadastrada.regiaoAdministrativa)
        #expect(lida.ponto == cadastrada.ponto)
        #expect(lida.papel == cadastrada.papel)
        #expect(lida.documento.isEmpty)
    }
}

@Suite("Contrato de meu_estabelecimento (0.2.29)")
struct ContratoDeMeuEstabelecimentoTests {
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

    @Test("Chama /rpc/meu_estabelecimento com o estabelecimento_id e lê o MeuEstabelecimento do contrato")
    func leitura() async throws {
        let casa = try await cliente(BackendDoEstabelecimento.self).meuEstabelecimento(id: casaID)

        #expect(casa == (try FixturesDoContrato.carregar("meu-estabelecimento", como: ContratoAPI.MeuEstabelecimentoDTO.self).dominio()))
        #expect(casa.documento.isEmpty)
        let corpo = try BackendDoEstabelecimento.recebido()
        #expect(corpo == ["estabelecimento_id": casaID.uuidString] as NSDictionary)
    }

    @Test("O 403 de quem não é membro chega tipado como sem_permissao")
    func recusa() async throws {
        do {
            _ = try await cliente(RecusaDoEstabelecimento.self).meuEstabelecimento(id: casaID)
            Issue.record("a leitura devia ter sido recusada")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .semPermissao)
        }
    }

    @Test("Resposta 404 do servidor atual (RPC inexistente) chega como erro da API e não trava")
    func rpcInexistente() async throws {
        do {
            _ = try await cliente(ServidorSemRpc.self).meuEstabelecimento(id: casaID)
            Issue.record("a leitura devia ter falhado com 404")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .desconhecido)
            #expect(MensagemDoErroAPI.texto(erro) == "Não foi possível concluir esta ação. Tente novamente.")
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

private final class BackendDoEstabelecimento: URLProtocol {
    private static let trava = NSLock()
    nonisolated(unsafe) private static var corpo: Data?

    static func recebido() throws -> NSDictionary {
        let dados = try #require(trava.withLock { corpo })
        return try #require(JSONSerialization.jsonObject(with: dados) as? NSDictionary)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard request.url?.lastPathComponent == "meu_estabelecimento",
              let resposta = try? FixturesDoContrato.dados("meu-estabelecimento") else {
            return responder(self, status: 500, corpo: Data("{}".utf8))
        }
        if let corpo = corpoEnviado(em: request) { Self.trava.withLock { Self.corpo = corpo } }
        responder(self, status: 200, corpo: resposta)
    }

    override func stopLoading() {}
}

private final class ServidorSemRpc: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let envelope = EnvelopeErroAPI(
            code: "PGRST202",
            message: "Could not find the function meu_estabelecimento in the schema cache",
            details: nil,
            hint: nil
        )
        responder(self, status: 404, corpo: (try? JSONEncoder().encode(envelope)) ?? Data())
    }

    override func stopLoading() {}
}

private final class RecusaDoEstabelecimento: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let envelope = EnvelopeErroAPI(code: "sem_permissao", message: "sem_permissao", details: nil, hint: nil)
        responder(self, status: 403, corpo: (try? JSONEncoder().encode(envelope)) ?? Data())
    }

    override func stopLoading() {}
}

// MARK: - A publicação a partir de Minhas vagas

private actor Chamadas {
    private(set) var total = 0
    func mais() { total += 1 }
}

@MainActor
@Suite("Publicar vaga a partir de Minhas vagas: o cadastro da casa e o telefone do responsável")
struct PublicacaoDaCasaViewModelTests {
    @Test("Lê o cadastro da casa e o telefone da conta, e fica pronta para o formulário")
    func pronta() async throws {
        let api = ApiClienteEmMemoria(cenario: .contratante)
        let modelo = PublicacaoDaCasaViewModel(api: api, estabelecimentoID: casaID)
        #expect(modelo.estado == .carregando)

        await modelo.carregar()

        let casa = try await api.meuEstabelecimento(id: casaID)
        let conta = try await api.minhaConta()
        #expect(modelo.estado == .pronta(casa, telefoneResponsavel: conta.telefone))
    }

    @Test("Sem rede mostra a falha de rede, e tentar de novo com rede abre a publicação")
    func semRedeETentarDeNovo() async throws {
        let comRede = ApiClienteEmMemoria(cenario: .contratante)
        let semRede = Trava(true)
        let modelo = PublicacaoDaCasaViewModel(
            estabelecimentoID: casaID,
            estabelecimento: { id in
                if semRede.valor { throw ErroDaApi(codigo: .semRede) }
                return try await comRede.meuEstabelecimento(id: id)
            },
            minhaConta: { try await comRede.minhaConta() }
        )

        await modelo.carregar()
        #expect(modelo.estado == .erro(mensagem: MensagemDoErroAPI.texto(ErroDaApi(codigo: .semRede))))

        semRede.valor = false
        await modelo.carregar()
        guard case .pronta = modelo.estado else {
            Issue.record("a segunda tentativa devia abrir a publicação")
            return
        }
    }

    @Test("Quem não é membro da casa vê a recusa, e não o formulário")
    func naoMembro() async {
        let modelo = PublicacaoDaCasaViewModel(api: ApiClienteEmMemoria(cenario: .contratanteSemEstabelecimento), estabelecimentoID: casaID)

        await modelo.carregar()

        #expect(modelo.estado == .erro(mensagem: MensagemDoErroAPI.texto(ErroDaApi(codigo: .semPermissao))))
    }

    @Test("O cadastro lido fica guardado: abrir a publicação de novo não volta à rede")
    func naoReleDepoisDePronta() async throws {
        let api = ApiClienteEmMemoria(cenario: .contratante)
        let chamadas = Chamadas()
        let modelo = PublicacaoDaCasaViewModel(
            estabelecimentoID: casaID,
            estabelecimento: { id in
                await chamadas.mais()
                return try await api.meuEstabelecimento(id: id)
            },
            minhaConta: { try await api.minhaConta() }
        )

        await modelo.carregar()
        await modelo.carregar()

        #expect(await chamadas.total == 1)
    }

    @Test("Quando a RPC não existe no servidor (404), mostra mensagem padrão sem travar a tela")
    func rpcInexistente() async {
        let modelo = PublicacaoDaCasaViewModel(
            estabelecimentoID: casaID,
            estabelecimento: { _ in throw ErroDaApi(codigo: .desconhecido, codigoOriginal: "PGRST202") },
            minhaConta: { try await ApiClienteEmMemoria(cenario: .contratante).minhaConta() }
        )

        await modelo.carregar()

        #expect(modelo.estado == .erro(mensagem: MensagemDoErroAPI.texto(ErroDaApi(codigo: .desconhecido))))
    }
}

private final class Trava: @unchecked Sendable {
    private let trava = NSLock()
    private var guardado: Bool
    init(_ valor: Bool) { guardado = valor }
    var valor: Bool {
        get { trava.withLock { guardado } }
        set { trava.withLock { guardado = newValue } }
    }
}
