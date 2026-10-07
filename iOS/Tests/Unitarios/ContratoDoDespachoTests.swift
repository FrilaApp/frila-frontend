@testable import FrilaDados
import Foundation
import FrilaDominio
import Testing

/// Os ids das fixtures: a função e o profissional são os de `perfil-profissional.json`, e a casa é
/// a de `meus-estabelecimentos.json`.
private enum IDs {
    static let funcao = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    static let casa = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    static let revisao = UUID(uuidString: "a0000000-0000-0000-0000-000000000003")!
}

private enum Esperado {
    static func criterios() throws -> CriteriosDeNotificacao {
        CriteriosDeNotificacao(
            funcoes: [Funcao(id: IDs.funcao, nome: "Garçom", categoria: "Salão")],
            disponibilidades: [
                JanelaDeDisponibilidade(diaDaSemana: 5, inicio: try HoraDoDia("18:00"), fim: try HoraDoDia("02:00")),
                JanelaDeDisponibilidade(diaDaSemana: 6, inicio: try HoraDoDia("18:00"), fim: try HoraDoDia("02:00")),
            ],
            distanciaMaximaKm: 15,
            equipesDeConfianca: [EquipeDeConfiancaDoProfissional(estabelecimentoID: IDs.casa, nome: "Bistrô Ipê")],
            notificacoesNoMaximoACadaMin: 30
        )
    }

    static func protocolo() throws -> Protocolo {
        Protocolo(
            ocorrenciaID: IDs.revisao, tipo: .revisaoDespacho,
            criadaEm: try #require(ContratoAPI.instante("2026-10-10T02:05:00Z")), prazoRespostaAte: try DataCivil("2026-10-16")
        )
    }

    static let relato = "Tenho a função e os horários cadastrados e não recebi as vagas de sexta."
}

@Suite("Contrato 0.2.36: critérios de notificação e revisão do despacho (#18)")
struct ContratoDoDespachoTests {
    @Test("A fixture dos critérios vira função, grade, distância, equipes e teto")
    func criterios() throws {
        let criterios = try FixturesDoContrato.carregar("criterios-de-notificacao", como: ContratoAPI.CriteriosDeNotificacaoDTO.self).dominio()
        #expect(criterios == (try Esperado.criterios()))
        #expect(!criterios.semCriterios)
    }

    @Test("Pedir a revisão manda só o relato")
    func requisicao() throws {
        let corpo = ContratoAPI.PedirRevisaoDespacho(relato: Esperado.relato)
        #expect(try ContratoTests.objeto(corpo) == ContratoTests.fixture("requisicao-pedir-revisao-despacho"))
    }

    @Test("O protocolo da revisão chega com o tipo revisao_despacho e o prazo")
    func protocolo() throws {
        let protocolo = try FixturesDoContrato.carregar("protocolo-revisao-despacho", como: ContratoAPI.ProtocoloDTO.self).dominio()
        #expect(protocolo == (try Esperado.protocolo()))
    }

    @Test("Dia da semana fora de 0 a 6 na grade é erro de conversão, nunca queda")
    func janelaInvalida() throws {
        let dados = Data(#"{"funcoes":[],"disponibilidades":[{"dia_semana":7,"hora_inicio":"18:00","hora_fim":"02:00"}],"distancia_maxima_km":15,"equipes_de_confianca":[],"notificacoes_no_maximo_a_cada_min":30}"#.utf8)
        #expect(throws: ErroDeConversao(campo: "dia_semana")) {
            try ContratoAPI.decodificador().decode(ContratoAPI.CriteriosDeNotificacaoDTO.self, from: dados).dominio()
        }
    }

    @Test("Sem função, grade nem equipe, os critérios estão vazios")
    func semCriterios() {
        let vazio = CriteriosDeNotificacao(funcoes: [], disponibilidades: [], distanciaMaximaKm: 15, equipesDeConfianca: [], notificacoesNoMaximoACadaMin: 30)
        #expect(vazio.semCriterios)
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

/// Responde às duas RPCs com a fixture do contrato e guarda o corpo recebido por rota.
private final class BackendDoDespacho: URLProtocol {
    static let fixtures: [String: String] = [
        "criterios_de_notificacao": "criterios-de-notificacao",
        "pedir_revisao_despacho": "protocolo-revisao-despacho",
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
private final class RecusasDoDespacho: URLProtocol {
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

@Suite("Cliente Supabase: critérios e revisão do despacho contra respostas HTTP do contrato (#18)")
struct SupabaseDoDespachoTests {
    @Test("criterios_de_notificacao vai sem parâmetros e lê os critérios")
    func criterios() async throws {
        let criterios = try await cliente(BackendDoDespacho.self).criteriosDeNotificacao()
        #expect(criterios == (try Esperado.criterios()))
        #expect(try BackendDoDespacho.recebido(em: "criterios_de_notificacao") == [:])
    }

    @Test("pedir_revisao_despacho manda o relato e lê o protocolo")
    func pedirRevisao() async throws {
        let protocolo = try await cliente(BackendDoDespacho.self).pedirRevisaoDespacho(relato: Esperado.relato)
        #expect(protocolo == (try Esperado.protocolo()))
        #expect(try BackendDoDespacho.recebido(em: "pedir_revisao_despacho") == ContratoTests.fixture("requisicao-pedir-revisao-despacho"))
    }
}

/// Em série: as recusas passam por um estado compartilhado do `URLProtocol`.
@Suite("Cliente Supabase: as recusas que o contrato lista para as duas RPCs (#18)", .serialized)
struct RecusasDoDespachoTests {
    @Test("A recusa de criterios_de_notificacao chega tipada, com o detalhe", arguments: [
        (401, "nao_autenticado", nil, CodigoErroAPI.naoAutenticado),
        (403, "sem_permissao", "conta_suspensa", .semPermissao),
        (404, "nao_encontrado", nil, .naoEncontrado),
        (422, "perfil_incompativel", nil, .perfilIncompativel),
    ] as [(Int, String, String?, CodigoErroAPI)])
    func criterios(status: Int, codigo: String, detalhes: String?, esperado: CodigoErroAPI) async throws {
        RecusasDoDespacho.definir((status, codigo, detalhes))
        let api = try cliente(RecusasDoDespacho.self)
        let erro = await #expect(throws: ErroDaApi.self) { _ = try await api.criteriosDeNotificacao() }
        #expect(erro?.codigo == esperado)
        #expect(erro?.codigoOriginal == codigo)
        #expect(erro?.detalhes == detalhes)
    }

    @Test("A recusa de pedir_revisao_despacho chega tipada: campo, conta suspensa, contestação existente e limite", arguments: [
        (401, "nao_autenticado", nil, CodigoErroAPI.naoAutenticado),
        (403, "sem_permissao", "conta_suspensa", .semPermissao),
        (409, "contestacao_ja_aberta", nil, .contestacaoJaAberta),
        (422, "campo_obrigatorio", "relato", .campoObrigatorio),
        (422, "campo_invalido", "relato", .campoInvalido),
        (429, "limite_excedido", nil, .limiteExcedido),
    ] as [(Int, String, String?, CodigoErroAPI)])
    func pedirRevisao(status: Int, codigo: String, detalhes: String?, esperado: CodigoErroAPI) async throws {
        RecusasDoDespacho.definir((status, codigo, detalhes))
        let api = try cliente(RecusasDoDespacho.self)
        let erro = await #expect(throws: ErroDaApi.self) { _ = try await api.pedirRevisaoDespacho(relato: Esperado.relato) }
        #expect(erro?.codigo == esperado)
        #expect(erro?.codigoOriginal == codigo)
        #expect(erro?.detalhes == detalhes)
    }
}
