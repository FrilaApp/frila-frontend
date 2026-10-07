@testable import FrilaDados
import Foundation
import FrilaDominio
import Testing

/// Os ids das fixtures do modo seleção. A vaga e o primeiro candidato são os de `vaga.json` e de
/// `perfil-publico.json`; a candidatura da conta é a de `candidatura-selecao.json`.
private enum IDs {
    static let vaga = UUID(uuidString: "40000000-0000-0000-0000-000000000001")!
    static let minhaCandidatura = UUID(uuidString: "6f1c2a4e-2b7d-4c5e-9a1f-3d2e1c0b9a88")!
    static let candidaturaDaAna = UUID(uuidString: "70000000-0000-0000-0000-000000000001")!
    static let posicao = UUID(uuidString: "50000000-0000-0000-0000-000000000002")!
    static let turno = UUID(uuidString: "60000000-0000-0000-0000-000000000002")!
}

/// Responde às chamadas do supabase-swift sem rede, com as fixtures do contrato. O que cada teste
/// quer ouvir vem no host da URL do cliente, e não em estado compartilhado: os testes rodam em
/// paralelo, e o `URLProtocol` é criado pelo sistema.
private final class BackendDaSelecao: URLProtocol {
    private static let trava = NSLock()
    nonisolated(unsafe) private static var corpos: [String: Data] = [:]

    /// O corpo que chegou à rota, para o host de um teste.
    static func corpo(host: String, rota: String) -> NSDictionary? {
        let dados = trava.withLock { corpos["\(host)/\(rota)"] }
        return dados.flatMap { try? JSONSerialization.jsonObject(with: $0) as? NSDictionary }
    }

    private static let respostas = [
        "candidatos_da_vaga": "candidatos",
        "escolher_candidato": "resultado-confirmacao",
        "retirar_candidatura": "candidatura-retirada",
        "minhas_candidaturas": "minhas-candidaturas",
        "candidatar": "candidatura-selecao",
    ]

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host() else { return }
        let rota = url.lastPathComponent
        if let corpo = Self.corpo(de: request) {
            Self.trava.withLock { Self.corpos["\(host)/\(rota)"] = corpo }
        }
        // `<status>-<codigo>.frila-teste.supabase.co` recusa toda RPC com esse erro do contrato;
        // qualquer outro host responde a fixture da rota, ou 500 sem envelope para a rota que o
        // teste não esperava.
        let partes = host.split(separator: ".").first.map { $0.split(separator: "-", maxSplits: 1) } ?? []
        let status: Int
        let dados: Data
        if partes.count == 2, let recusa = Int(partes[0]) {
            let codigo = partes[1].replacingOccurrences(of: "-", with: "_")
            status = recusa
            dados = Data(#"{"code":"\#(codigo)","message":"\#(codigo)","details":null,"hint":null}"#.utf8)
        } else if let fixture = Self.respostas[rota], let conteudo = try? FixturesDoContrato.dados(fixture) {
            status = 200
            dados = conteudo
        } else {
            status = 500
            dados = Data("{}".utf8)
        }
        let resposta = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: resposta, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: dados)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// A URLSession entrega o corpo ao URLProtocol como stream, e não em `httpBody`.
    private static func corpo(de request: URLRequest) -> Data? {
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
}

@Suite("Contrato 0.2.27: as RPCs do modo seleção (0.2.24)")
struct ContratoDoModoSelecaoTests {
    private static func instante(_ texto: String) throws -> Date { try #require(ContratoAPI.instante(texto)) }

    private static func cliente(host: String) throws -> SupabaseApiCliente {
        let configuracao = URLSessionConfiguration.ephemeral
        configuracao.protocolClasses = [BackendDaSelecao.self]
        return SupabaseApiCliente(
            url: try #require(URL(string: "https://\(host)")),
            chavePublicavel: "sb_publishable_teste",
            telemetria: TelemetryNula(),
            sessaoHTTP: URLSession(configuration: configuracao)
        )
    }

    // MARK: Requisições

    @Test("Escolher e retirar mandam só a candidatura, e os candidatos são pedidos pela vaga")
    func requisicoes() throws {
        #expect(try ContratoTests.objeto(ContratoAPI.ID("candidatura_id", IDs.candidaturaDaAna)) == ContratoTests.fixture("requisicao-escolher-candidato"))
        #expect(try ContratoTests.objeto(ContratoAPI.ID("candidatura_id", IDs.minhaCandidatura)) == ContratoTests.fixture("requisicao-retirar-candidatura"))
        #expect(try ContratoTests.objeto(ContratoAPI.ID("vaga_id", IDs.vaga)) == ["vaga_id": IDs.vaga.uuidString])
    }

    @Test("minhas_candidaturas manda o estado do contrato, e sem filtro não manda campo nenhum")
    func filtroDeEstado() throws {
        #expect(try ContratoTests.objeto(ContratoAPI.MinhasCandidaturasParametros(estado: nil)) == [:])
        for estado in EstadoCandidatura.allCases {
            #expect(try ContratoTests.objeto(ContratoAPI.MinhasCandidaturasParametros(estado: estado)) == ["estado": estado.rawValue])
        }
        // Os cinco estados do enum `EstadoCandidatura` do contrato, com os nomes dele.
        #expect(EstadoCandidatura.allCases.map(\.rawValue) == ["pendente", "aceita", "recusada", "retirada", "expirada"])
    }

    // MARK: Respostas

    @Test("candidatos_da_vaga traz o perfil público e a reputação com denominador, na ordem do servidor")
    func candidatos() throws {
        let candidatos = try FixturesDoContrato.carregar("candidatos", como: [ContratoAPI.CandidatoDTO].self).map { $0.dominio() }
        #expect(candidatos.map(\.profissional.nome) == ["Ana Cunha", "Bruno Tavares", "Carla Menezes", "Diego Rocha"])
        #expect(candidatos.allSatisfy { $0.profissional.tipo == .profissional })

        let ana = try #require(candidatos.first)
        #expect(ana.id == IDs.candidaturaDaAna && ana.candidaturaID == IDs.candidaturaDaAna)
        #expect(ana.profissional == (try FixturesDoContrato.carregar("perfil-publico", como: ContratoAPI.PerfilPublicoDTO.self).dominio()))
        #expect(ana.criadaEm == (try Self.instante("2026-10-06T14:02:11Z")))

        // Quem ainda não tem histórico chega com total zero e taxa nula, e não com zero por cento.
        let carla = candidatos[2]
        #expect(carla.profissional.reputacao.semHistorico && carla.profissional.reputacao.taxaComparecimento == nil)
        // O instante com fração de segundo e offset do Postgres é lido igual.
        #expect(carla.criadaEm == (try Self.instante("2026-10-06T18:05:47.310Z")))

        let bruno = candidatos[1].profissional
        #expect(bruno.funcoes == ["Garçom", "Bartender"])
        #expect(bruno.reputacao == Reputacao(positivas: 10, total: 12, taxaComparecimento: 0.9, turnosConsiderados: 20, turnosRealizados: 18))

        // `da_equipe` (0.2.38, D7): lido como vem, ausente vale `false`, e a ordem segue a de chegada.
        #expect(candidatos.map(\.daEquipe) == [false, true, false, false])
        #expect(candidatos.map(\.criadaEm) == candidatos.map(\.criadaEm).sorted())
    }

    @Test("Candidato sem da_equipe (servidor anterior à 0.2.38) é lido com false, e com o campo é lido como veio")
    func daEquipe() throws {
        let semCampo = Data(#"{"candidatura_id":"70000000-0000-0000-0000-000000000001","criada_em":"2026-10-06T14:02:11Z","profissional":{"id":"80000000-0000-0000-0000-000000000001","tipo":"profissional","nome":"Ana Cunha","funcoes":[],"reputacao":{"positivas":0,"total":0,"taxa_comparecimento":null,"turnos_considerados":0,"turnos_realizados":0}}}"#.utf8)
        let decodificador = ContratoAPI.decodificador()
        #expect(try decodificador.decode(ContratoAPI.CandidatoDTO.self, from: semCampo).dominio().daEquipe == false)
        let comCampo = Data(String(decoding: semCampo, as: UTF8.self).replacingOccurrences(of: #""criada_em""#, with: #""da_equipe":true,"criada_em""#).utf8)
        #expect(try decodificador.decode(ContratoAPI.CandidatoDTO.self, from: comCampo).dominio().daEquipe == true)
    }

    @Test("minhas_candidaturas e retirar_candidatura devolvem a candidatura com o resumo da vaga e o estado")
    func candidaturas() throws {
        let minhas = try FixturesDoContrato.carregar("minhas-candidaturas", como: [ContratoAPI.MinhaCandidaturaDTO].self).map { try $0.dominio() }
        #expect(minhas.map(\.estado) == [.pendente, .recusada])
        let pendente = try #require(minhas.first)
        #expect(pendente.id == IDs.minhaCandidatura)
        #expect(pendente.vaga.id == IDs.vaga && pendente.vaga.funcao == "Garçom" && pendente.vaga.regiaoAdministrativa == "Plano Piloto")
        #expect(pendente.vaga.valor == Dinheiro(centavos: 12000))
        #expect(pendente.criadaEm == (try Self.instante("2026-10-06T14:02:11Z")))

        let retirada = try FixturesDoContrato.carregar("candidatura-retirada", como: ContratoAPI.MinhaCandidaturaDTO.self).dominio()
        #expect(retirada == Candidatura(id: pendente.id, vaga: pendente.vaga, estado: .retirada, criadaEm: pendente.criadaEm))
        // É a mesma candidatura que `candidatar` devolveu pendente.
        #expect(try FixturesDoContrato.carregar("candidatura-selecao", como: ContratoAPI.CandidaturaDTO.self).candidaturaID == retirada.id)
    }

    @Test("escolher_candidato devolve a posição, o turno e o contato do profissional")
    func confirmacao() throws {
        let confirmacao = try FixturesDoContrato.carregar("resultado-confirmacao", como: ContratoAPI.ResultadoConfirmacaoDTO.self).dominio()
        #expect(confirmacao.posicaoID == IDs.posicao && confirmacao.turnoID == IDs.turno)
        #expect(confirmacao.contato.nome == "Ana Cunha" && confirmacao.contato.telefone == "+5561988887777")
        #expect(confirmacao.contato.visivelAte == (try Self.instante("2026-10-17T01:00:00Z")))
    }

    @Test("Resposta fora do contrato é recusada, e não lida pela metade", arguments: [
        // `ResultadoConfirmacao.estado` é a constante `confirmada`.
        ("resultado-confirmacao", "confirmada", "pendente"),
        // Estado de candidatura que o enum do contrato não tem.
        ("candidatura-retirada", "retirada", "em_analise"),
    ])
    func foraDoContrato(fixture: String, de: String, para: String) throws {
        let texto = try #require(String(data: FixturesDoContrato.dados(fixture), encoding: .utf8))
        let trocado = Data(texto.replacingOccurrences(of: "\"estado\": \"\(de)\"", with: "\"estado\": \"\(para)\"").utf8)
        #expect(trocado != (try FixturesDoContrato.dados(fixture)))
        #expect(throws: DecodingError.self) {
            if fixture == "resultado-confirmacao" {
                _ = try ContratoAPI.decodificador().decode(ContratoAPI.ResultadoConfirmacaoDTO.self, from: trocado)
            } else {
                _ = try ContratoAPI.decodificador().decode(ContratoAPI.MinhaCandidaturaDTO.self, from: trocado)
            }
        }
    }

    // MARK: Pela rede

    @Test("As quatro RPCs saem na rota e no corpo do contrato e voltam como domínio")
    func pelaRede() async throws {
        let host = "selecao.frila-teste.supabase.co"
        let cliente = try Self.cliente(host: host)

        let candidatos = try await cliente.candidatosDaVaga(id: IDs.vaga)
        #expect(candidatos.count == 4 && candidatos.first?.candidaturaID == IDs.candidaturaDaAna)
        #expect(BackendDaSelecao.corpo(host: host, rota: "candidatos_da_vaga") == ["vaga_id": IDs.vaga.uuidString])

        let confirmacao = try await cliente.escolherCandidato(candidaturaID: IDs.candidaturaDaAna)
        #expect(confirmacao.turnoID == IDs.turno && confirmacao.contato.nome == "Ana Cunha")
        #expect(BackendDaSelecao.corpo(host: host, rota: "escolher_candidato") == (try ContratoTests.fixture("requisicao-escolher-candidato")))

        let retirada = try await cliente.retirarCandidatura(id: IDs.minhaCandidatura)
        #expect(retirada.estado == .retirada && retirada.vaga.id == IDs.vaga)
        #expect(BackendDaSelecao.corpo(host: host, rota: "retirar_candidatura") == (try ContratoTests.fixture("requisicao-retirar-candidatura")))

        let pendentes = try await cliente.minhasCandidaturas(estado: .pendente)
        #expect(pendentes.map(\.estado) == [.pendente, .recusada], "o dublê de rede devolve a fixture inteira; o filtro é do servidor")
        #expect(BackendDaSelecao.corpo(host: host, rota: "minhas_candidaturas") == ["estado": "pendente"])
        _ = try await cliente.minhasCandidaturas()
        #expect(BackendDaSelecao.corpo(host: host, rota: "minhas_candidaturas") == [:])

        let candidatura = try await cliente.candidatar(vagaID: IDs.vaga)
        #expect(candidatura == ResultadoCandidatura(estado: .pendente, candidaturaID: IDs.minhaCandidatura, posicaoID: nil, turnoID: nil, contato: nil))
    }

    @Test("As recusas da escolha chegam tipadas: corrida perdida, vaga fechada, candidatura indisponível e vaga oculta", arguments: [
        ("409-posicao-ja-preenchida", CodigoErroAPI.posicaoJaPreenchida),
        ("409-vaga-encerrada", CodigoErroAPI.vagaEncerrada),
        ("409-candidatura-indisponivel", CodigoErroAPI.candidaturaIndisponivel),
        ("422-vaga-oculta", CodigoErroAPI.vagaOculta),
        ("422-inelegivel", CodigoErroAPI.inelegivel),
        ("403-sem-permissao", CodigoErroAPI.semPermissao),
    ])
    func recusasDaEscolha(host: String, codigo: CodigoErroAPI) async throws {
        let cliente = try Self.cliente(host: "\(host).frila-teste.supabase.co")
        let erro = await #expect(throws: ErroDaApi.self) { _ = try await cliente.escolherCandidato(candidaturaID: IDs.candidaturaDaAna) }
        #expect(erro?.codigo == codigo)
        #expect(erro?.codigoOriginal == codigo.rawValue)
    }

    @Test("Retirar a candidatura que já não vale e publicar seleção sem as 24 horas chegam tipados")
    func outrasRecusas() async throws {
        let indisponivel = try Self.cliente(host: "409-candidatura-indisponivel.frila-teste.supabase.co")
        await #expect(throws: ErroDaApi(codigo: .candidaturaIndisponivel)) { _ = try await indisponivel.retirarCandidatura(id: IDs.minhaCandidatura) }

        let semAntecedencia = try Self.cliente(host: "422-selecao-sem-antecedencia.frila-teste.supabase.co")
        let inicio = Date(timeIntervalSince1970: 1_791_579_600)
        let publicacao = PublicacaoVaga(
            estabelecimentoID: UUID(), funcaoID: UUID(), periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(14_400)),
            local: "CLS 405", regiaoAdministrativa: "Plano Piloto", ponto: try Coordenada(latitude: -15.8121, longitude: -47.8997),
            valor: Dinheiro(centavos: 12000), posicoes: 1,
            inclusos: Inclusos(refeicao: false, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Marina", modo: .selecao, chave: UUID()
        )
        let erro = await #expect(throws: ErroDaApi.self) { _ = try await semAntecedencia.publicarVaga(publicacao) }
        #expect(erro?.codigo == .selecaoSemAntecedencia)
        #expect(erro?.codigo.recusaDefinitivaDePublicacao == true)
        #expect(BackendDaSelecao.corpo(host: "422-selecao-sem-antecedencia.frila-teste.supabase.co", rota: "publicar_vaga")?["modo"] as? String == "selecao")
    }
}
