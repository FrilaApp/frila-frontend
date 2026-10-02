@testable import FrilaDados
import Foundation
import FrilaDominio
import Testing

/// Os ids das fixtures: o turno, a posição, a vaga e o profissional são os mesmos de `turnos.json`
/// e de `painel.json`.
private enum IDs {
    static let turno = UUID(uuidString: "60000000-0000-0000-0000-000000000001")!
    static let posicao = UUID(uuidString: "50000000-0000-0000-0000-000000000001")!
    static let posicaoNova = UUID(uuidString: "50000000-0000-0000-0000-000000000003")!
    static let vaga = UUID(uuidString: "40000000-0000-0000-0000-000000000001")!
    static let profissional = UUID(uuidString: "80000000-0000-0000-0000-000000000001")!
    static let chave = UUID(uuidString: "90000000-0000-0000-0000-000000000002")!
    static let denuncia = UUID(uuidString: "a0000000-0000-0000-0000-000000000001")!
    static let contestacao = UUID(uuidString: "a0000000-0000-0000-0000-000000000002")!
}

/// O que cada fixture de resposta vira no domínio. Os testes de DTO e os de HTTP esperam o mesmo.
private enum Esperado {
    static func instante(_ texto: String) throws -> Date { try #require(ContratoAPI.instante(texto)) }

    static func confirmacao() throws -> ResultadoRegistro {
        ResultadoRegistro(
            turnoID: IDs.turno, tipo: .manual, verificacao: .verificado,
            registradoEm: try instante("2026-10-09T20:58:04Z"), distanciaMetros: nil
        )
    }

    static let reabertura = ResultadoCancelamento(posicaoID: IDs.posicao, falta: true, reaberta: true, novaPosicaoID: IDs.posicaoNova)
    static let cancelamento = ResultadoCancelamento(posicaoID: IDs.posicao, falta: false, reaberta: false, novaPosicaoID: nil)
    static let vagaCancelada = VagaCancelada(vagaID: IDs.vaga, estado: .cancelada, posicoesCanceladas: 2)
    static let alvo = Alvo(tipo: .profissional, id: IDs.profissional)

    static func protocolo() throws -> Protocolo {
        Protocolo(
            ocorrenciaID: IDs.denuncia, tipo: .denuncia,
            criadaEm: try instante("2026-10-10T01:20:00Z"), prazoRespostaAte: try DataCivil("2026-10-16")
        )
    }

    static func bloqueio() throws -> Bloqueio {
        Bloqueio(alvo: alvo, criadoEm: try instante("2026-10-10T01:21:30Z"))
    }

    static func contaSuspensa() throws -> SituacaoDaConta {
        SituacaoDaConta(
            estado: .suspensa,
            suspensao: Suspensao(
                motivo: "Denúncia grave confirmada pela Equipe Frila",
                desde: try instante("2026-10-12T14:00:00Z"),
                contestacao: Protocolo(
                    ocorrenciaID: IDs.contestacao, tipo: .contestacao,
                    criadaEm: try instante("2026-10-12T18:30:00Z"), prazoRespostaAte: try DataCivil("2026-10-19")
                )
            )
        )
    }

    static let denuncia = Denuncia(
        alvo: alvo, turnoID: IDs.turno, motivo: .riscoSeguranca,
        relato: "Chegou alterado e ameaçou a equipe da cozinha.", chave: IDs.chave
    )
    static let motivoDaPosicao = "Imprevisto de saúde"
    static let motivoDaVaga = "O evento foi adiado"
    static let relatoDaContestacao = "Não estive nesse turno; houve engano de pessoa."
}

@Suite("Contrato 0.2.27: as RPCs da Sprint 2")
struct ContratoDaSprint2Tests {
    @Test("Confirmar check-in manual e reabrir por atraso mandam só o id (#19)")
    func requisicoesDoTurnoDoContratante() throws {
        #expect(try ContratoTests.objeto(ContratoAPI.ID("turno_id", IDs.turno)) == ContratoTests.fixture("requisicao-confirmar-checkin-manual"))
        #expect(try ContratoTests.objeto(ContratoAPI.ID("posicao_id", IDs.posicao)) == ContratoTests.fixture("requisicao-reabrir-por-atraso"))
    }

    @Test("A confirmação devolve o check-in manual verificado, sem distância (#19)")
    func respostaDaConfirmacao() throws {
        let registro = try FixturesDoContrato.carregar("resultado-confirmacao-manual", como: ContratoAPI.ResultadoRegistroDTO.self).dominio()
        #expect(registro == (try Esperado.confirmacao()))
    }

    @Test("A reabertura por atraso conta falta e traz a posição nova; o cancelamento sem reabertura não traz (#19, #20)")
    func respostasDeCancelamento() throws {
        let reabertura = try FixturesDoContrato.carregar("resultado-reabertura", como: ContratoAPI.ResultadoCancelamentoDTO.self).dominio()
        #expect(reabertura == Esperado.reabertura)
        let cancelamento = try FixturesDoContrato.carregar("resultado-cancelamento", como: ContratoAPI.ResultadoCancelamentoDTO.self).dominio()
        #expect(cancelamento == Esperado.cancelamento)
    }

    @Test("Cancelar posição e cancelar vaga mandam o id e o motivo (#20)")
    func requisicoesDeCancelamento() throws {
        let posicao = ContratoAPI.CancelarPosicao(posicaoID: IDs.posicao, motivo: Esperado.motivoDaPosicao)
        #expect(try ContratoTests.objeto(posicao) == ContratoTests.fixture("requisicao-cancelar-posicao"))
        let vaga = ContratoAPI.CancelarVaga(vagaID: IDs.vaga, motivo: Esperado.motivoDaVaga)
        #expect(try ContratoTests.objeto(vaga) == ContratoTests.fixture("requisicao-cancelar-vaga"))

        let cancelada = try FixturesDoContrato.carregar("vaga-cancelada", como: ContratoAPI.VagaCanceladaDTO.self).dominio()
        #expect(cancelada == Esperado.vagaCancelada)
    }

    @Test("Denunciar e bloquear mandam o par alvo_tipo + alvo_id do perfil público (#39)")
    func denunciarEBloquear() throws {
        #expect(try ContratoTests.objeto(ContratoAPI.Denunciar(Esperado.denuncia)) == ContratoTests.fixture("requisicao-denunciar"))
        #expect(try ContratoTests.objeto(ContratoAPI.Bloquear(Esperado.alvo)) == ContratoTests.fixture("requisicao-bloquear"))

        let protocolo = try FixturesDoContrato.carregar("protocolo", como: ContratoAPI.ProtocoloDTO.self).dominio()
        #expect(protocolo == (try Esperado.protocolo()))
        let bloqueio = try FixturesDoContrato.carregar("bloqueio", como: ContratoAPI.BloqueioDTO.self).dominio()
        #expect(bloqueio == (try Esperado.bloqueio()))
    }

    @Test("O alvo sai do perfil público que está na tela, sem id de conta (#39)")
    func alvoDoPerfilPublico() throws {
        let perfil = try FixturesDoContrato.carregar("perfil-publico", como: ContratoAPI.PerfilPublicoDTO.self).dominio()
        #expect(Alvo(perfil) == Alvo(tipo: perfil.tipo, id: perfil.id))
        #expect(Alvo(perfil) == Esperado.alvo)
    }

    @Test("Denúncia sem turno não manda turno_id (#39)")
    func denunciaSemTurno() throws {
        let denuncia = Denuncia(alvo: Esperado.alvo, motivo: .outro, relato: "Documento que não é dele.", chave: IDs.chave)
        let corpo = try ContratoTests.objeto(ContratoAPI.Denunciar(denuncia))
        #expect(corpo["turno_id"] == nil)
        #expect(corpo["motivo"] as? String == "outro")
        #expect((corpo.allKeys as? [String])?.sorted() == ["alvo_id", "alvo_tipo", "chave", "motivo", "relato"])
    }

    @Test("Os motivos de denúncia são os do contrato", arguments: [
        (MotivoDenuncia.assedio, "assedio"), (.discriminacao, "discriminacao"), (.riscoSeguranca, "risco_seguranca"), (.outro, "outro"),
    ])
    func motivosDeDenuncia(motivo: MotivoDenuncia, noContrato: String) {
        #expect(motivo.rawValue == noContrato)
        #expect(MotivoDenuncia.allCases.count == 4)
    }

    @Test("A situação da conta chega ativa sem suspensão, e suspensa com motivo, data e contestação (#41)")
    func situacaoDaConta() throws {
        let ativa = try FixturesDoContrato.carregar("situacao-da-conta", como: ContratoAPI.SituacaoDaContaDTO.self).dominio()
        #expect(ativa == SituacaoDaConta(estado: .ativa, suspensao: nil))
        let suspensa = try FixturesDoContrato.carregar("situacao-da-conta-suspensa", como: ContratoAPI.SituacaoDaContaDTO.self).dominio()
        #expect(suspensa == (try Esperado.contaSuspensa()))
    }

    @Test("Contestar a suspensão manda só o relato (#41)")
    func contestarSuspensao() throws {
        let corpo = ContratoAPI.ContestarSuspensao(relato: Esperado.relatoDaContestacao)
        #expect(try ContratoTests.objeto(corpo) == ContratoTests.fixture("requisicao-contestar-suspensao"))
    }

    @Test("Prazo de resposta fora do calendário vira erro de conversão, nunca queda do app")
    func prazoInvalido() throws {
        let protocolo = Data(#"{"ocorrencia_id":"a0000000-0000-0000-0000-000000000001","tipo":"denuncia","criada_em":"2026-10-10T01:20:00Z","prazo_resposta_ate":"2026-02-30"}"#.utf8)
        #expect(throws: ErroDeConversao(campo: "prazo_resposta_ate")) {
            try ContratoAPI.decodificador().decode(ContratoAPI.ProtocoloDTO.self, from: protocolo).dominio()
        }
    }
}

// MARK: - Pela rede

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

/// Responde a cada RPC da Sprint 2 com a fixture do contrato e guarda o corpo recebido por rota.
/// Qualquer outra rota recebe um 500 sem envelope.
private final class BackendDaSprint2: URLProtocol {
    static let fixtures: [String: String] = [
        "confirmar_checkin_manual": "resultado-confirmacao-manual",
        "reabrir_por_atraso": "resultado-reabertura",
        "cancelar_posicao": "resultado-cancelamento",
        "cancelar_vaga": "vaga-cancelada",
        "denunciar": "protocolo",
        "bloquear": "bloqueio",
        "situacao_da_conta": "situacao-da-conta-suspensa",
        "contestar_suspensao": "protocolo",
    ]

    private static let trava = NSLock()
    nonisolated(unsafe) private static var corpos: [String: Data] = [:]

    /// O último corpo que chegou à rota, como objeto JSON.
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

/// Recusa cada RPC da Sprint 2 com um erro que o contrato ou o backend descreve para ela.
private final class RecusasDaSprint2: URLProtocol {
    static let recusas: [String: (status: Int, codigo: String, detalhes: String?)] = [
        "confirmar_checkin_manual": (409, "checkin_ja_confirmado", nil),
        "reabrir_por_atraso": (422, "reabertura_antes_da_tolerancia", nil),
        "cancelar_posicao": (409, "posicao_nao_cancelavel", nil),
        "cancelar_vaga": (422, "perfil_incompativel", nil),
        "denunciar": (422, "campo_invalido", "relato"),
        "bloquear": (404, "nao_encontrado", nil),
        "situacao_da_conta": (401, "nao_autenticado", nil),
        "contestar_suspensao": (409, "contestacao_ja_aberta", nil),
    ]

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let rota = request.url?.lastPathComponent ?? ""
        guard let recusa = Self.recusas[rota],
              let corpo = try? JSONEncoder().encode(EnvelopeErroAPI(code: recusa.codigo, message: recusa.codigo, details: recusa.detalhes, hint: nil)) else {
            return responder(self, status: 500, corpo: Data("{}".utf8))
        }
        responder(self, status: recusa.status, corpo: corpo)
    }

    override func stopLoading() {}
}

/// Respostas que o contrato não promete assim, mas que o cliente precisa atravessar sem cair: valor
/// de enum que o app não conhece, e a recusa com `details` que só o backend documenta.
private final class CasosDeBordaDaSprint2: URLProtocol {
    static let respostas: [String: (status: Int, corpo: String)] = [
        "denunciar": (200, #"{"ocorrencia_id":"a0000000-0000-0000-0000-000000000001","tipo":"elogio","criada_em":"2026-10-10T01:20:00Z","prazo_resposta_ate":"2026-10-16"}"#),
        "situacao_da_conta": (200, #"{"estado":"banida","suspensao":null}"#),
        "reabrir_por_atraso": (409, #"{"code":"posicao_nao_cancelavel","message":"posicao_nao_cancelavel","details":"checkin_registrado","hint":null}"#),
    ]

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let resposta = Self.respostas[request.url?.lastPathComponent ?? ""] else {
            return responder(self, status: 500, corpo: Data("{}".utf8))
        }
        responder(self, status: resposta.status, corpo: Data(resposta.corpo.utf8))
    }

    override func stopLoading() {}
}

@Suite("Cliente Supabase: as RPCs da Sprint 2 contra respostas HTTP do contrato")
struct SupabaseDaSprint2Tests {
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

    @Test("confirmar_checkin_manual manda o turno e lê o registro verificado (#19)")
    func confirmarCheckinManual() async throws {
        let registro = try await cliente(BackendDaSprint2.self).confirmarCheckinManual(turnoID: IDs.turno)
        #expect(registro == (try Esperado.confirmacao()))
        #expect(try BackendDaSprint2.recebido(em: "confirmar_checkin_manual") == ContratoTests.fixture("requisicao-confirmar-checkin-manual"))
    }

    @Test("reabrir_por_atraso manda a posição e lê a falta e a posição nova (#19)")
    func reabrirPorAtraso() async throws {
        let resultado = try await cliente(BackendDaSprint2.self).reabrirPorAtraso(posicaoID: IDs.posicao)
        #expect(resultado == Esperado.reabertura)
        #expect(try BackendDaSprint2.recebido(em: "reabrir_por_atraso") == ContratoTests.fixture("requisicao-reabrir-por-atraso"))
    }

    @Test("cancelar_posicao manda a posição e o motivo (#20)")
    func cancelarPosicao() async throws {
        let resultado = try await cliente(BackendDaSprint2.self).cancelarPosicao(id: IDs.posicao, motivo: Esperado.motivoDaPosicao)
        #expect(resultado == Esperado.cancelamento)
        #expect(try BackendDaSprint2.recebido(em: "cancelar_posicao") == ContratoTests.fixture("requisicao-cancelar-posicao"))
    }

    @Test("cancelar_vaga manda a vaga e o motivo, e lê quantas posições caíram (#20)")
    func cancelarVaga() async throws {
        let resultado = try await cliente(BackendDaSprint2.self).cancelarVaga(id: IDs.vaga, motivo: Esperado.motivoDaVaga)
        #expect(resultado == Esperado.vagaCancelada)
        #expect(try BackendDaSprint2.recebido(em: "cancelar_vaga") == ContratoTests.fixture("requisicao-cancelar-vaga"))
    }

    @Test("denunciar manda o alvo, o turno, o motivo, o relato e a chave, e lê o protocolo (#39)")
    func denunciar() async throws {
        let protocolo = try await cliente(BackendDaSprint2.self).denunciar(Esperado.denuncia)
        #expect(protocolo == (try Esperado.protocolo()))
        #expect(try BackendDaSprint2.recebido(em: "denunciar") == ContratoTests.fixture("requisicao-denunciar"))
    }

    @Test("bloquear manda o alvo e lê o bloqueio com o mesmo par (#39)")
    func bloquear() async throws {
        let bloqueio = try await cliente(BackendDaSprint2.self).bloquear(Esperado.alvo)
        #expect(bloqueio == (try Esperado.bloqueio()))
        #expect(try BackendDaSprint2.recebido(em: "bloquear") == ContratoTests.fixture("requisicao-bloquear"))
    }

    @Test("situacao_da_conta vai sem parâmetros e lê a suspensão com a contestação (#41)")
    func situacaoDaConta() async throws {
        let situacao = try await cliente(BackendDaSprint2.self).situacaoDaConta()
        #expect(situacao == (try Esperado.contaSuspensa()))
        #expect(try BackendDaSprint2.recebido(em: "situacao_da_conta") == [:])
    }

    @Test("contestar_suspensao manda o relato e lê o protocolo (#41)")
    func contestarSuspensao() async throws {
        let protocolo = try await cliente(BackendDaSprint2.self).contestarSuspensao(relato: Esperado.relatoDaContestacao)
        #expect(protocolo.ocorrenciaID == IDs.denuncia)
        #expect(try BackendDaSprint2.recebido(em: "contestar_suspensao") == ContratoTests.fixture("requisicao-contestar-suspensao"))
    }

    @Test("Tipo de protocolo ou estado de conta que o app não conhece vira resposta_invalida, nunca queda")
    func enumDesconhecido() async throws {
        let api = try cliente(CasosDeBordaDaSprint2.self)
        await #expect(throws: ErroDaApi(codigo: .respostaInvalida)) { _ = try await api.denunciar(Esperado.denuncia) }
        await #expect(throws: ErroDaApi(codigo: .respostaInvalida)) { _ = try await api.situacaoDaConta() }
    }

    @Test("reabrir_por_atraso com check-in feito chega como posicao_nao_cancelavel, com checkin_registrado no detalhe")
    func reabrirComCheckinFeito() async throws {
        let api = try cliente(CasosDeBordaDaSprint2.self)
        await #expect(throws: ErroDaApi(codigo: .posicaoNaoCancelavel, detalhes: "checkin_registrado")) {
            _ = try await api.reabrirPorAtraso(posicaoID: IDs.posicao)
        }
    }

    @Test("A recusa de cada RPC chega tipada, com o código e o detalhe do envelope", arguments: [
        ("confirmar_checkin_manual", CodigoErroAPI.checkinJaConfirmado), ("reabrir_por_atraso", .reaberturaAntesDaTolerancia),
        ("cancelar_posicao", .posicaoNaoCancelavel), ("cancelar_vaga", .perfilIncompativel), ("denunciar", .campoInvalido),
        ("bloquear", .naoEncontrado), ("situacao_da_conta", .naoAutenticado), ("contestar_suspensao", .contestacaoJaAberta),
    ])
    func recusas(rota: String, esperado: CodigoErroAPI) async throws {
        let api = try cliente(RecusasDaSprint2.self)
        let erro = await #expect(throws: ErroDaApi.self) {
            switch rota {
            case "confirmar_checkin_manual": _ = try await api.confirmarCheckinManual(turnoID: IDs.turno)
            case "reabrir_por_atraso": _ = try await api.reabrirPorAtraso(posicaoID: IDs.posicao)
            case "cancelar_posicao": _ = try await api.cancelarPosicao(id: IDs.posicao, motivo: Esperado.motivoDaPosicao)
            case "cancelar_vaga": _ = try await api.cancelarVaga(id: IDs.vaga, motivo: Esperado.motivoDaVaga)
            case "denunciar": _ = try await api.denunciar(Esperado.denuncia)
            case "bloquear": _ = try await api.bloquear(Esperado.alvo)
            case "situacao_da_conta": _ = try await api.situacaoDaConta()
            case "contestar_suspensao": _ = try await api.contestarSuspensao(relato: Esperado.relatoDaContestacao)
            default: Issue.record("rota sem chamada: \(rota)")
            }
        }
        #expect(erro?.codigo == esperado)
        #expect(erro?.codigoOriginal == RecusasDaSprint2.recusas[rota]?.codigo)
        #expect(erro?.detalhes == RecusasDaSprint2.recusas[rota]?.detalhes)
    }
}
