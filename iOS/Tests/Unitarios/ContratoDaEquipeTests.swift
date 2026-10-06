@testable import FrilaDados
import Foundation
import FrilaDominio
import Testing

/// Os ids das fixtures: a casa de `estabelecimento.json` e o profissional de `perfil-publico.json`.
private enum IDs {
    static let casa = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    static let profissional = UUID(uuidString: "80000000-0000-0000-0000-000000000001")!
}

private enum Esperado {
    static let membro = MembroDaEquipe(estabelecimentoID: IDs.casa, profissionalID: IDs.profissional)
    static let perfil = PerfilPublico(
        id: IDs.profissional, tipo: .profissional, nome: "Ana Cunha", funcoes: ["Garçom"],
        reputacao: Reputacao(positivas: 7, total: 7, taxaComparecimento: 1.0, turnosConsiderados: 7, turnosRealizados: 7)
    )
}

@Suite("Contrato 0.2.36: equipe de confiança (#24)")
struct ContratoDaEquipeTests {
    @Test("A equipe chega como lista de perfis públicos")
    func equipe() throws {
        let equipe = try FixturesDoContrato.carregar("equipe-de-confianca", como: [ContratoAPI.PerfilPublicoDTO].self).map { $0.dominio() }
        #expect(equipe == [Esperado.perfil])
    }

    @Test("Incluir e remover mandam o par estabelecimento_id + profissional_id, e leem o mesmo par")
    func membro() throws {
        #expect(try ContratoTests.objeto(ContratoAPI.MembroDaEquipeDTO(Esperado.membro)) == ContratoTests.fixture("membro-da-equipe"))
        let lido = try FixturesDoContrato.carregar("membro-da-equipe", como: ContratoAPI.MembroDaEquipeDTO.self).dominio()
        #expect(lido == Esperado.membro)
    }
}

// MARK: - Pela rede

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

/// Responde às três RPCs com a fixture do contrato e guarda o corpo recebido por rota.
private final class BackendDaEquipe: URLProtocol {
    static let fixtures: [String: String] = [
        "equipe_de_confianca": "equipe-de-confianca",
        "incluir_na_equipe": "membro-da-equipe",
        "remover_da_equipe": "membro-da-equipe",
    ]

    private static let trava = NSLock()
    nonisolated(unsafe) private static var corpos: [String: Data] = [:]

    static func recebido(em rota: String) throws -> NSDictionary {
        let dados = try #require(trava.withLock { corpos[rota] })
        return try #require(JSONSerialization.jsonObject(with: dados) as? NSDictionary)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let prefixo = "/rest/v1/rpc/"
        guard let caminho = request.url?.path, caminho.hasPrefix(prefixo), request.httpMethod == "POST" else {
            return responder(self, status: 500, corpo: Data("{}".utf8))
        }
        let rota = String(caminho.dropFirst(prefixo.count))
        guard let fixture = Self.fixtures[rota], let resposta = try? FixturesDoContrato.dados(fixture) else {
            return responder(self, status: 500, corpo: Data("{}".utf8))
        }
        if let corpo = corpoEnviado(em: request) { Self.trava.withLock { Self.corpos[rota] = corpo } }
        responder(self, status: 200, corpo: resposta)
    }

    override func stopLoading() {}
}

/// Recusa a próxima chamada com o envelope definido pelo teste. A suíte que o usa roda em série.
private final class RecusasDaEquipe: URLProtocol {
    typealias Recusa = (status: Int, codigo: String, detalhes: String?)
    private static let trava = NSLock()
    nonisolated(unsafe) private static var recusa: Recusa = (500, "desconhecido", nil)

    static func definir(_ nova: Recusa) { trava.withLock { recusa = nova } }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let recusa = Self.trava.withLock { Self.recusa }
        guard let corpo = try? JSONEncoder().encode(EnvelopeErroAPI(code: recusa.codigo, message: recusa.codigo, details: recusa.detalhes, hint: nil)) else {
            return responder(self, status: 500, corpo: Data("{}".utf8))
        }
        responder(self, status: recusa.status, corpo: corpo)
    }

    override func stopLoading() {}
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

@Suite("Cliente Supabase: equipe de confiança contra respostas HTTP do contrato (#24)")
struct SupabaseDaEquipeTests {
    @Test("equipe_de_confianca manda o estabelecimento e lê os perfis")
    func equipe() async throws {
        let equipe = try await cliente(BackendDaEquipe.self).equipeDeConfianca(estabelecimentoID: IDs.casa)
        #expect(equipe == [Esperado.perfil])
        let corpo = try BackendDaEquipe.recebido(em: "equipe_de_confianca")
        #expect((corpo["estabelecimento_id"] as? String)?.lowercased() == IDs.casa.uuidString.lowercased())
        #expect(corpo.count == 1)
    }

    @Test("incluir_na_equipe e remover_da_equipe mandam o par e leem o par")
    func incluirERemover() async throws {
        let api = try cliente(BackendDaEquipe.self)
        #expect(try await api.incluirNaEquipe(Esperado.membro) == Esperado.membro)
        #expect(try BackendDaEquipe.recebido(em: "incluir_na_equipe") == ContratoTests.fixture("membro-da-equipe"))
        #expect(try await api.removerDaEquipe(Esperado.membro) == Esperado.membro)
        #expect(try BackendDaEquipe.recebido(em: "remover_da_equipe") == ContratoTests.fixture("membro-da-equipe"))
    }
}

/// Em série: as recusas passam por um estado compartilhado do `URLProtocol`.
@Suite("Cliente Supabase: as recusas que o contrato lista para a equipe (#24)", .serialized)
struct RecusasDaEquipeTests {
    @Test("A recusa de cada operação chega tipada, com o detalhe do envelope", arguments: [
        ("equipe_de_confianca", 401, "nao_autenticado", nil, CodigoErroAPI.naoAutenticado),
        ("equipe_de_confianca", 403, "sem_permissao", nil, .semPermissao),
        ("incluir_na_equipe", 403, "sem_permissao", "sem_turno_cumprido", .semPermissao),
        ("incluir_na_equipe", 403, "sem_permissao", "conta_suspensa", .semPermissao),
        ("incluir_na_equipe", 404, "nao_encontrado", nil, .naoEncontrado),
        ("incluir_na_equipe", 422, "perfil_incompativel", nil, .perfilIncompativel),
        ("remover_da_equipe", 403, "sem_permissao", nil, .semPermissao),
        ("remover_da_equipe", 422, "perfil_incompativel", nil, .perfilIncompativel),
    ] as [(String, Int, String, String?, CodigoErroAPI)])
    func recusas(rota: String, status: Int, codigo: String, detalhes: String?, esperado: CodigoErroAPI) async throws {
        RecusasDaEquipe.definir((status, codigo, detalhes))
        let api = try cliente(RecusasDaEquipe.self)
        let erro = await #expect(throws: ErroDaApi.self) {
            switch rota {
            case "equipe_de_confianca": _ = try await api.equipeDeConfianca(estabelecimentoID: IDs.casa)
            case "incluir_na_equipe": _ = try await api.incluirNaEquipe(Esperado.membro)
            case "remover_da_equipe": _ = try await api.removerDaEquipe(Esperado.membro)
            default: Issue.record("rota sem chamada: \(rota)")
            }
        }
        #expect(erro?.codigo == esperado)
        #expect(erro?.codigoOriginal == codigo)
        #expect(erro?.detalhes == detalhes)
    }
}
