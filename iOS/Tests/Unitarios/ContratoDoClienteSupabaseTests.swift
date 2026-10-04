import Foundation
@testable import FrilaDados
import FrilaDominio
import Testing

/// O backend de mentira: responde cada rota com a fixture do contrato e guarda o corpo que o
/// cliente mandou. A tabela é estática porque a `URLSession` instancia o `URLProtocol` por
/// requisição; por isso a suíte é `.serialized` e cada teste a reinicia.
private final class BackendDeContrato: URLProtocol {
    struct Resposta {
        let status: Int
        let corpo: Data
        let tipo: String
        init(status: Int = 200, corpo: Data, tipo: String = "application/json") {
            self.status = status; self.corpo = corpo; self.tipo = tipo
        }
    }

    private static let trava = NSLock()
    nonisolated(unsafe) private static var rotas: [String: Resposta] = [:]
    nonisolated(unsafe) private static var recebidas: [(rota: String, corpo: Data?)] = []

    static func preparar(_ novas: [String: Resposta]) {
        trava.withLock { rotas = novas; recebidas = [] }
    }

    static var requisicoes: [(rota: String, corpo: Data?)] { trava.withLock { recebidas } }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        let corpo = Self.corpo(de: request)
        let resposta = Self.trava.withLock { () -> Resposta? in
            Self.recebidas.append((url.path, corpo))
            return Self.rotas[url.path]
        }
        let http = HTTPURLResponse(
            url: url,
            statusCode: resposta?.status ?? 500,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": resposta?.tipo ?? "application/json"]
        )!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: resposta?.corpo ?? Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

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

/// Cada chamada do `SupabaseApiCliente` contra o contrato: a rota certa, o corpo igual à fixture de
/// requisição e a resposta da fixture virando o domínio. É o que `ContratoTests` não cobre: ali o
/// DTO é decodificado direto; aqui a chamada inteira sai pela rede.
@Suite("Cliente Supabase: rota, corpo e resposta de cada RPC do contrato", .serialized)
struct ContratoDoClienteSupabaseTests {
    private static let turnoID = UUID(uuidString: "60000000-0000-0000-0000-000000000001")!
    private static let registradoEm = ContratoAPI.instante("2026-10-09T20:52:31Z")!

    private func cliente() throws -> SupabaseApiCliente {
        let configuracao = URLSessionConfiguration.ephemeral
        configuracao.protocolClasses = [BackendDeContrato.self]
        return SupabaseApiCliente(
            url: try #require(URL(string: "https://frila-teste.supabase.co")),
            chavePublicavel: "sb_publishable_teste",
            telemetria: TelemetryNula(),
            sessaoHTTP: URLSession(configuration: configuracao),
            armazenamentoDaSessao: ArmazenamentoDeSessaoEmMemoria()
        )
    }

    private func rpc(_ nome: String, _ fixture: String, status: Int = 200) throws {
        BackendDeContrato.preparar(["/rest/v1/rpc/\(nome)": .init(status: status, corpo: try FixturesDoContrato.dados(fixture))])
    }

    private func corpoEnviado(para rota: String) throws -> NSDictionary {
        let requisicao = try #require(BackendDeContrato.requisicoes.first { $0.rota == rota })
        let corpo = try #require(requisicao.corpo)
        return try #require(JSONSerialization.jsonObject(with: corpo) as? NSDictionary)
    }

    // MARK: Presença (RN08, RN09)

    @Test("fazer_checkin sem GPS manda distancia_m nulo e registrado_em, e lê o registro verificado")
    func checkinSemGPS() async throws {
        try rpc("fazer_checkin", "resultado-registro")
        let resultado = try await cliente().fazerCheckin(turnoID: Self.turnoID, distanciaMetros: nil, registradoEm: Self.registradoEm)

        #expect(try corpoEnviado(para: "/rest/v1/rpc/fazer_checkin") == (try ContratoTests.fixture("requisicao-registro-de-presenca")))
        #expect(resultado.turnoID == Self.turnoID)
        #expect(resultado.tipo == .geolocalizado)
        #expect(resultado.verificacao == .verificado)
        #expect(resultado.distanciaMetros == 38)
        #expect(resultado.registradoEm == Self.registradoEm)
    }

    @Test("fazer_checkout manda a distância medida em metros inteiros")
    func checkoutComDistancia() async throws {
        try rpc("fazer_checkout", "resultado-registro")
        _ = try await cliente().fazerCheckout(turnoID: Self.turnoID, distanciaMetros: 38, registradoEm: Self.registradoEm)

        let corpo = try corpoEnviado(para: "/rest/v1/rpc/fazer_checkout")
        #expect(corpo["turno_id"] as? String == Self.turnoID.uuidString.lowercased())
        #expect(corpo["distancia_m"] as? Int == 38)
        #expect(corpo["registrado_em"] as? String == "2026-10-09T20:52:31Z")
    }

    @Test("avisar_a_caminho manda só o turno_id e lê a_caminho_em")
    func avisarACaminho() async throws {
        try rpc("avisar_a_caminho", "resultado-a-caminho")
        let resultado = try await cliente().avisarACaminho(turnoID: Self.turnoID)

        #expect(try corpoEnviado(para: "/rest/v1/rpc/avisar_a_caminho") == (try ContratoTests.fixture("requisicao-avisar-a-caminho")))
        #expect(resultado.turnoID == Self.turnoID)
        #expect(resultado.aCaminhoEm == ContratoTests.aCaminho)
    }

    // MARK: Contato e avaliação (RN10, RN07)

    @Test("contato_do_turno manda o turno_id e lê nome, telefone, link e prazo do contato")
    func contatoDoTurno() async throws {
        try rpc("contato_do_turno", "contato")
        let contato = try await cliente().contatoDoTurno(id: Self.turnoID)
        let esperado = try ContratoTests.fixture("contato")

        #expect(try corpoEnviado(para: "/rest/v1/rpc/contato_do_turno") == ["turno_id": Self.turnoID.uuidString.lowercased()])
        #expect(contato.nome == esperado["nome"] as? String)
        #expect(contato.telefone == esperado["telefone"] as? String)
        #expect(contato.whatsappURL.absoluteString == esperado["whatsapp_url"] as? String)
        #expect(contato.visivelAte == ContratoAPI.instante(try #require(esperado["visivel_ate"] as? String)))
    }

    @Test("avaliar manda turno_id e resposta, e lê a avaliação criada")
    func avaliar() async throws {
        try rpc("avaliar", "avaliacao")
        let avaliacao = try await cliente().avaliar(turnoID: Self.turnoID, resposta: true)

        #expect(try corpoEnviado(para: "/rest/v1/rpc/avaliar") == (try ContratoTests.fixture("requisicao-avaliar")))
        #expect(avaliacao.turnoID == Self.turnoID)
        #expect(avaliacao.resposta)
        #expect(avaliacao.criadaEm == ContratoAPI.instante("2026-10-10T01:30:12.5+00:00"))
    }

    // MARK: Conta e perfil (dados pessoais)

    @Test("criar_conta manda perfil, nome, telefone E.164, nascimento e termos_versao, e lê a conta")
    func criarConta() async throws {
        try rpc("criar_conta", "usuario")
        let conta = try await cliente().criarConta(CadastroConta(
            nome: "Ana Cunha", telefone: "+5561988887777", nascimento: try DataCivil(ano: 1998, mes: 4, dia: 12),
            perfil: .profissional, versaoTermos: "2026-09-22"
        ))

        #expect(try corpoEnviado(para: "/rest/v1/rpc/criar_conta") == (try ContratoTests.fixture("requisicao-criar-conta")))
        #expect(conta.nome == "Ana Cunha")
        #expect(conta.telefone == "+5561988887777")
        #expect(conta.email == "ana.cunha@frila.app")
        #expect(conta.nascimento == (try DataCivil(ano: 1998, mes: 4, dia: 12)))
        #expect(conta.estado == .ativa)
    }

    @Test("criar_perfil_profissional manda funções, ponto_base e janelas no formato do contrato")
    func criarPerfilProfissional() async throws {
        try rpc("criar_perfil_profissional", "perfil-profissional")
        let perfil = try await cliente().criarPerfilProfissional(DadosPerfilProfissional(
            funcoes: [UUID(uuidString: "20000000-0000-0000-0000-000000000001")!],
            pontoBase: try Coordenada(latitude: -15.8267, longitude: -47.9218),
            disponibilidades: [
                JanelaDeDisponibilidade(diaDaSemana: 5, inicio: try HoraDoDia(hora: 18, minuto: 0), fim: try HoraDoDia(hora: 2, minuto: 0)),
                JanelaDeDisponibilidade(diaDaSemana: 6, inicio: try HoraDoDia(hora: 18, minuto: 0), fim: try HoraDoDia(hora: 2, minuto: 0)),
            ]
        ))

        #expect(try corpoEnviado(para: "/rest/v1/rpc/criar_perfil_profissional") == (try ContratoTests.fixture("requisicao-criar-perfil-profissional")))
        #expect(!perfil.funcoes.isEmpty)
    }

    @Test("atualizar_perfil_profissional só com funções não manda ponto_base nem disponibilidades")
    func atualizarPerfilSoComFuncoes() async throws {
        try rpc("atualizar_perfil_profissional", "perfil-profissional")
        _ = try await cliente().atualizarPerfilProfissional(AlteracaoPerfilProfissional(funcoes: [
            UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
            UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
        ]))

        #expect(try corpoEnviado(para: "/rest/v1/rpc/atualizar_perfil_profissional") == (try ContratoTests.fixture("requisicao-atualizar-perfil-profissional")))
    }

    @Test("meu_perfil_profissional, minha_conta, perfil_publico e meus_estabelecimentos leem as fixtures")
    func leiturasDePerfil() async throws {
        try rpc("meu_perfil_profissional", "perfil-profissional")
        #expect(try await cliente().meuPerfilProfissional().funcoes.isEmpty == false)

        try rpc("minha_conta", "usuario")
        #expect(try await cliente().minhaConta().id == UUID(uuidString: "10000000-0000-0000-0000-000000000001"))

        try rpc("perfil_publico", "perfil-publico")
        let id = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let publico = try await cliente().perfilPublico(id: id)
        #expect(try corpoEnviado(para: "/rest/v1/rpc/perfil_publico") == ["id": id.uuidString.lowercased()])
        #expect(!publico.nome.isEmpty)

        try rpc("meus_estabelecimentos", "meus-estabelecimentos")
        #expect(try await cliente().meusEstabelecimentos().isEmpty == false)
    }

    // MARK: Turnos, vagas e painel

    @Test("meus_turnos lê a lista do contrato com o contato dentro do prazo")
    func meusTurnos() async throws {
        try rpc("meus_turnos", "turnos")
        let turnos = try await cliente().meusTurnos()
        let esperados = try #require(JSONSerialization.jsonObject(with: FixturesDoContrato.dados("turnos")) as? [[String: Any]])

        #expect(turnos.count == esperados.count)
        #expect(turnos.map { $0.id.uuidString.lowercased() } == esperados.map { $0["id"] as? String })
    }

    @Test("vagas_abertas manda o filtro em snake_case e lê a lista; detalhe_vaga manda vaga_id e lê a vaga")
    func vagasAbertasEDetalhe() async throws {
        try rpc("vagas_abertas", "vagas-abertas")
        let funcao = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
        let vagas = try await cliente().vagasAbertas(FiltroVagas(funcaoID: funcao, distanciaMaximaKm: 15, limite: 20, deslocamento: 40))
        let corpo = try corpoEnviado(para: "/rest/v1/rpc/vagas_abertas")

        #expect(corpo["funcao_id"] as? String == funcao.uuidString.lowercased())
        #expect(corpo["distancia_max_km"] as? Double == 15)
        #expect(corpo["limite"] as? Int == 20)
        #expect(corpo["deslocamento"] as? Int == 40)
        #expect(corpo["latitude"] == nil, "o feed não manda a posição do aparelho: a referência é o ponto base do servidor")
        #expect(!vagas.isEmpty)

        try rpc("detalhe_vaga", "vaga")
        let vagaID = UUID(uuidString: "40000000-0000-0000-0000-000000000001")!
        let vaga = try await cliente().detalheDaVaga(id: vagaID)
        #expect(try corpoEnviado(para: "/rest/v1/rpc/detalhe_vaga") == ["vaga_id": vagaID.uuidString.lowercased()])
        #expect(vaga.id == vagaID)
    }

    @Test("painel_estabelecimento manda id e período, e lê as vagas do painel")
    func painelEstabelecimento() async throws {
        try rpc("painel_estabelecimento", "painel")
        let estabelecimento = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
        let periodo = try Periodo(inicio: ContratoAPI.instante("2026-10-01T03:00:00Z")!, fim: ContratoAPI.instante("2026-11-01T02:59:59Z")!)
        let painel = try await cliente().painelEstabelecimento(id: estabelecimento, periodo: periodo)
        let corpo = try corpoEnviado(para: "/rest/v1/rpc/painel_estabelecimento")

        #expect(corpo["estabelecimento_id"] as? String == estabelecimento.uuidString.lowercased())
        #expect(corpo["de"] as? String == "2026-10-01T03:00:00Z")
        #expect(corpo["ate"] as? String == "2026-11-01T02:59:59Z")
        #expect(painel.estabelecimentoID == estabelecimento)
        #expect(!painel.vagas.isEmpty)
    }

    @Test("republicar_vaga manda vaga_id, período e chave de idempotência, e lê a vaga publicada")
    func republicarVaga() async throws {
        try rpc("republicar_vaga", "vaga-publicada")
        let vagaID = UUID(uuidString: "40000000-0000-0000-0000-000000000001")!
        let chave = UUID()
        let periodo = try Periodo(inicio: ContratoAPI.instante("2026-10-16T22:00:00Z")!, fim: ContratoAPI.instante("2026-10-17T03:00:00Z")!)
        let publicada = try await cliente().republicarVaga(id: vagaID, periodo: periodo, chave: chave)
        let corpo = try corpoEnviado(para: "/rest/v1/rpc/republicar_vaga")

        #expect(corpo["vaga_id"] as? String == vagaID.uuidString.lowercased())
        #expect(corpo["inicio_em"] as? String == "2026-10-16T22:00:00Z")
        #expect(corpo["fim_em"] as? String == "2026-10-17T03:00:00Z")
        // O Foundation codifica UUID em maiúsculas; o Postgres aceita os dois.
        #expect((corpo["chave"] as? String)?.lowercased() == chave.uuidString.lowercased())
        #expect(publicada.vagaID == vagaID)
        #expect(publicada.posicoes.count == 2)
    }

    @Test("configuracao_do_app manda plataforma ios e lê versões, mensagem e loja")
    func configuracaoDoApp() async throws {
        try rpc("configuracao_do_app", "configuracao-do-app")
        let configuracao = try await cliente().configuracaoDoApp()

        #expect(try corpoEnviado(para: "/rest/v1/rpc/configuracao_do_app") == ["plataforma": "ios"])
        #expect(configuracao.versaoMinima == "0.1.0")
        #expect(configuracao.versaoRecomendada == "0.1.0")
        #expect(configuracao.mensagem == "Atualize o Frila para continuar.")
        #expect(configuracao.urlDaLoja.absoluteString == "https://apps.apple.com/app/id6815311991")
    }

    // MARK: Edge Functions: exclusão e exportação (S2, #219)

    @Test("excluir-conta manda confirmar=true e lê perfil_removido_em, dados_apagados_ate e turnos_cancelados")
    func excluirConta() async throws {
        let resposta = #"{"perfil_removido_em":"2026-10-04T03:00:00Z","dados_apagados_ate":"2026-11-03","turnos_cancelados":2}"#
        BackendDeContrato.preparar(["/functions/v1/excluir-conta": .init(status: 202, corpo: Data(resposta.utf8))])
        let exclusao = try await cliente().excluirConta()

        #expect(try corpoEnviado(para: "/functions/v1/excluir-conta") == ["confirmar": true])
        #expect(exclusao.perfilRemovidoEm == ContratoAPI.instante("2026-10-04T03:00:00Z"))
        #expect(exclusao.dadosApagadosAte == (try DataCivil(ano: 2026, mes: 11, dia: 3)))
        #expect(exclusao.turnosCancelados == 2)
    }

    @Test("excluir-conta com dados_apagados_ate fora do formato é resposta inválida, e nada é apagado localmente")
    func excluirContaComDataInvalida() async throws {
        let resposta = #"{"perfil_removido_em":"2026-10-04T03:00:00Z","dados_apagados_ate":"03/11/2026","turnos_cancelados":0}"#
        BackendDeContrato.preparar(["/functions/v1/excluir-conta": .init(status: 202, corpo: Data(resposta.utf8))])
        await #expect(throws: ErroDaApi(codigo: .respostaInvalida, detalhes: "dados_apagados_ate")) {
            try await cliente().excluirConta()
        }
    }

    @Test("excluir-conta com 409 administrador_unico chega como erro tipado do contrato")
    func excluirContaComAdministradorUnico() async throws {
        let resposta = #"{"code":"administrador_unico","message":"Você é o único administrador.","details":null,"hint":null}"#
        BackendDeContrato.preparar(["/functions/v1/excluir-conta": .init(status: 409, corpo: Data(resposta.utf8))])
        await #expect(throws: ErroDaApi(codigo: .administradorUnico, codigoOriginal: "administrador_unico")) {
            try await cliente().excluirConta()
        }
    }

    @Test("exportar-meus-dados devolve o corpo da resposta byte a byte, sem decodificar")
    func exportarMeusDados() async throws {
        let json = Data(#"{"gerado_em":"2026-10-04T03:00:00Z","conta":{"nome":"Ana"}}"#.utf8)
        BackendDeContrato.preparar(["/functions/v1/exportar-meus-dados": .init(corpo: json)])
        #expect(try await cliente().exportarMeusDados() == json)
    }

    // MARK: Sessão e aparelho

    @Test("Sem sessão guardada, possuiSessao é falso e sair ainda tira o token do servidor")
    func sairSemSessao() async throws {
        try rpc("remover_dispositivo", "dispositivo")
        let cliente = try cliente()
        #expect(await cliente.possuiSessao() == false)

        await cliente.sair(tokenFCM: "token-fcm-de-exemplo-0001")

        #expect(try corpoEnviado(para: "/rest/v1/rpc/remover_dispositivo") == (try ContratoTests.fixture("requisicao-remover-dispositivo")))
        #expect(cliente.haSessaoGuardada == false)
    }

    @Test("sair sem token não chama remover_dispositivo")
    func sairSemToken() async throws {
        BackendDeContrato.preparar([:])
        let cliente = try cliente()
        await cliente.sair(tokenFCM: nil)
        #expect(BackendDeContrato.requisicoes.contains { $0.rota == "/rest/v1/rpc/remover_dispositivo" } == false)
    }
}
