import Foundation
import FrilaApresentacao
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

    @Test("criar_conta envia sinal_idade no corpo da RPC para cada valor do contrato e omite sem sinal")
    func criarContaComSinalIdade() async throws {
        let valores: [(SinalIdade, String)] = [
            (.dezoitoOuMais, "dezoito_ou_mais"),
            (.recusou, "recusou"),
            (.indisponivel, "indisponivel"),
        ]

        for (sinal, esperado) in valores {
            try rpc("criar_conta", "usuario")
            _ = try await cliente().criarConta(CadastroConta(
                nome: "Ana Cunha", telefone: "+5561988887777", nascimento: try DataCivil(ano: 1998, mes: 4, dia: 12),
                perfil: .profissional, versaoTermos: "2026-09-22", sinalIdade: sinal
            ))
            let corpo = try corpoEnviado(para: "/rest/v1/rpc/criar_conta")
            #expect(corpo["sinal_idade"] as? String == esperado)
        }

        // Sem sinal: a chave sinal_idade não está presente no corpo enviado
        try rpc("criar_conta", "usuario")
        _ = try await cliente().criarConta(CadastroConta(
            nome: "Ana Cunha", telefone: "+5561988887777", nascimento: try DataCivil(ano: 1998, mes: 4, dia: 12),
            perfil: .profissional, versaoTermos: "2026-09-22"
        ))
        let corpoSemSinal = try corpoEnviado(para: "/rest/v1/rpc/criar_conta")
        #expect(corpoSemSinal["sinal_idade"] == nil)
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

    @Test("publicar_escala (0.2.96) manda o evento, as vagas e uma chave só, e lê o evento e uma vaga publicada por item")
    func publicarEscala() async throws {
        try rpc("publicar_escala", "escala-publicada")
        let escala = try ContratoDaEscalaTests.pedido()

        let publicada = try await cliente().publicarEscala(escala)
        let corpo = try corpoEnviado(para: "/rest/v1/rpc/publicar_escala")

        #expect(corpo == (try ContratoTests.fixture("requisicao-publicar-escala")))
        #expect(publicada.eventoID == UUID(uuidString: "70000000-0000-0000-0000-000000000001"))
        #expect(publicada.vagas.count == escala.vagas.count)
    }

    @Test("publicar_escala com 422 campo_invalido chega com o caminho do campo em details")
    func publicarEscalaRecusada() async throws {
        let resposta = #"{"code":"campo_invalido","message":"campo_invalido","details":"vagas[1].valor_centavos","hint":null}"#
        BackendDeContrato.preparar(["/rest/v1/rpc/publicar_escala": .init(status: 422, corpo: Data(resposta.utf8))])

        await #expect(throws: ErroDaApi(codigo: .campoInvalido, codigoOriginal: "campo_invalido", detalhes: "vagas[1].valor_centavos")) {
            try await cliente().publicarEscala(try ContratoDaEscalaTests.pedido())
        }
    }

    // MARK: Equipe da casa (0.2.73 e 0.2.103)

    private static let casaDaEquipe = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    private static let membroRemovido = UUID(uuidString: "93000000-0000-0000-0000-000000000003")!

    private func recusa(_ rota: String, status: Int, codigo: String, detalhes: String? = nil) {
        let detalhe = detalhes.map { "\"\($0)\"" } ?? "null"
        let corpo = #"{"code":"\#(codigo)","message":"\#(codigo)","details":\#(detalhe),"hint":null}"#
        BackendDeContrato.preparar(["/rest/v1/rpc/\(rota)": .init(status: status, corpo: Data(corpo.utf8))])
    }

    @Test("membros_do_estabelecimento manda o estabelecimento_id e lê as pessoas da casa: membro_id do vínculo, papel, desde e e_voce")
    func membrosDaCasa() async throws {
        try rpc("membros_do_estabelecimento", "membros-do-estabelecimento")

        let membros = try await cliente().membrosDaCasa(estabelecimentoID: Self.casaDaEquipe)

        let corpo = try corpoEnviado(para: "/rest/v1/rpc/membros_do_estabelecimento")
        #expect(corpo == ["estabelecimento_id": "30000000-0000-0000-0000-000000000001"] as NSDictionary)
        #expect(membros.count == 3)
        #expect(membros[0].id == UUID(uuidString: "93000000-0000-0000-0000-000000000001"))
        #expect(membros[0].nome == "Ana Prado")
        #expect(membros[0].papel == .administrador)
        #expect(membros[0].eVoce)
        #expect(membros[0].desde == ContratoAPI.instante("2025-10-14T12:00:00Z"))
        #expect(membros[2].papel == .operador)
        #expect(!membros[2].eVoce)
    }

    @Test("convidar_membro manda estabelecimento_id, email e papel, sem p_, e lê o token e o vencimento")
    func convidarMembro() async throws {
        try rpc("convidar_membro", "convite-de-membro")

        let convite = try await cliente().convidarMembro(estabelecimentoID: Self.casaDaEquipe, email: "paulo.lima@example.com", papel: .operador)

        #expect(try corpoEnviado(para: "/rest/v1/rpc/convidar_membro") == (try ContratoTests.fixture("requisicao-convidar-membro")))
        #expect(convite.token == String(repeating: "ef", count: 32))
        #expect(convite.expiraEm == ContratoAPI.instante("2026-11-25T15:30:00Z"))
    }

    @Test("aceitar_convite_membro manda só o token e lê a casa e o papel em que a conta entrou")
    func aceitarConvite() async throws {
        try rpc("aceitar_convite_membro", "membro-adicionado")

        let membro = try await cliente().aceitarConviteDeMembro(token: String(repeating: "ef", count: 32))

        #expect(try corpoEnviado(para: "/rest/v1/rpc/aceitar_convite_membro") == (try ContratoTests.fixture("requisicao-aceitar-convite-membro")))
        #expect(membro.estabelecimentoID == UUID(uuidString: "30000000-0000-0000-0000-000000000003"))
        #expect(membro.papel == .operador)
    }

    @Test("remover_membro e transferir_administracao mandam os nomes do contrato (membro_id e novo_admin_id), sem p_")
    func removerETransferir() async throws {
        try rpc("remover_membro", "membro-removido")
        try await cliente().removerMembro(estabelecimentoID: Self.casaDaEquipe, membroID: Self.membroRemovido)
        #expect(try corpoEnviado(para: "/rest/v1/rpc/remover_membro") == (try ContratoTests.fixture("requisicao-remover-membro")))

        try rpc("transferir_administracao", "administracao-transferida")
        try await cliente().transferirAdministracao(estabelecimentoID: Self.casaDaEquipe, novoAdministradorID: Self.membroRemovido)
        #expect(try corpoEnviado(para: "/rest/v1/rpc/transferir_administracao") == (try ContratoTests.fixture("requisicao-transferir-administracao")))
    }

    @Test("403 sem_permissao sem details é a recusa de administrador; com conta_suspensa é a suspensão, e a casa não existir dá a mesma recusa")
    func recusaDeAdministradorNoServidor() async throws {
        recusa("membros_do_estabelecimento", status: 403, codigo: "sem_permissao")
        let erro = await #expect(throws: ErroDaApi.self) { _ = try await cliente().membrosDaCasa(estabelecimentoID: Self.casaDaEquipe) }
        #expect(erro?.codigo == .semPermissao)
        #expect(erro?.detalhes == nil)
        #expect(erro?.recusaDeAdministrador == true)
        #expect(erro?.contaSuspensa == false)

        recusa("convidar_membro", status: 403, codigo: "sem_permissao", detalhes: "conta_suspensa")
        let suspensa = await #expect(throws: ErroDaApi.self) {
            _ = try await cliente().convidarMembro(estabelecimentoID: Self.casaDaEquipe, email: "a@b.co", papel: .operador)
        }
        #expect(suspensa?.recusaDeAdministrador == false)
        #expect(suspensa?.contaSuspensa == true)
    }

    @Test("422 convite_invalido e 422 ultimo_administrador chegam como o código original, e 404 como nao_encontrado")
    func recusasDeRegra() async throws {
        recusa("aceitar_convite_membro", status: 422, codigo: "convite_invalido")
        let invalido = await #expect(throws: ErroDaApi.self) { _ = try await cliente().aceitarConviteDeMembro(token: String(repeating: "ef", count: 32)) }
        #expect(invalido?.conviteInvalido == true)

        // Contrato 0.2.115: o e-mail da conta não é o do convite. 403 sem `details`, e o convite não é consumido.
        recusa("aceitar_convite_membro", status: 403, codigo: "convite_de_outro_email")
        let outroEmail = await #expect(throws: ErroDaApi.self) { _ = try await cliente().aceitarConviteDeMembro(token: String(repeating: "ef", count: 32)) }
        #expect(outroEmail?.conviteDeOutroEmail == true)
        #expect(outroEmail?.conviteInvalido == false)
        #expect(outroEmail?.recusaDeAdministrador == false)

        recusa("remover_membro", status: 422, codigo: "ultimo_administrador")
        let ultimo = await #expect(throws: ErroDaApi.self) {
            try await cliente().removerMembro(estabelecimentoID: Self.casaDaEquipe, membroID: Self.membroRemovido)
        }
        #expect(ultimo?.ultimoAdministrador == true)

        recusa("transferir_administracao", status: 404, codigo: "nao_encontrado")
        let ausente = await #expect(throws: ErroDaApi.self) {
            try await cliente().transferirAdministracao(estabelecimentoID: Self.casaDaEquipe, novoAdministradorID: Self.membroRemovido)
        }
        #expect(ausente?.codigo == .naoEncontrado)
    }

    @Test("O erro do convite nunca leva o token: nem no código, nem nos detalhes")
    func erroSemOToken() async throws {
        let token = String(repeating: "ef", count: 32)
        recusa("aceitar_convite_membro", status: 422, codigo: "convite_invalido")

        let erro = await #expect(throws: ErroDaApi.self) { _ = try await cliente().aceitarConviteDeMembro(token: token) }

        #expect(!String(describing: erro).contains(token))
        #expect(!String(reflecting: erro).contains(token))
    }

    @Test("configuracao_do_app manda plataforma ios e a versao_app do app (0.2.65), e lê versões, mensagem e loja")
    func configuracaoDoApp() async throws {
        try rpc("configuracao_do_app", "configuracao-do-app")
        let configuracao = try await cliente().configuracaoDoApp()
        let versao = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)

        #expect(try corpoEnviado(para: "/rest/v1/rpc/configuracao_do_app") == ["plataforma": "ios", "versao_app": versao])
        // Fora do formato, o servidor trata a versão como ausente e devolve os recursos desligados (0.2.67).
        #expect(versao.wholeMatch(of: /[0-9]{1,6}(\.[0-9]{1,6}){0,3}/) != nil, "versão \(versao) fora do formato do contrato")
        #expect(configuracao.versaoMinima == "0.1.0")
        #expect(configuracao.versaoRecomendada == "0.1.0")
        #expect(configuracao.mensagem == "Atualize o Frila para continuar.")
        #expect(configuracao.urlDaLoja.absoluteString == "https://apps.apple.com/app/id6815311991")
    }

    /// A resposta de hoje (sem `perfil_rico` nem `checkin_por_codigo`), a da 0.2.65 sem versão que o
    /// servidor aceite (tudo desligado) e a da 0.2.68 em diante, com a chave nova `checkin_por_codigo`, que
    /// o app lê desde a F12b.
    static let respostasDaConfiguracao: [(String, String, RecursosDoApp)] = [
        ("hoje", #"{"foto_de_perfil": true, "chamada_direta": false}"#, RecursosDoApp(fotoDePerfil: true)),
        ("0.2.65 sem versão", #"{"foto_de_perfil": false, "chamada_direta": false, "perfil_rico": false, "checkin_por_codigo": false}"#, .desligados),
        ("0.2.70", #"{"foto_de_perfil": true, "chamada_direta": true, "perfil_rico": true, "checkin_por_codigo": true}"#,
         RecursosDoApp(fotoDePerfil: true, chamadaDireta: true, perfilRico: true, checkinPorCodigo: true)),
    ]

    @Test("configuracao_do_app de hoje e da 0.2.65: os recursos seguem o servidor e o portão de versão mínima continua", arguments: respostasDaConfiguracao)
    @MainActor
    func configuracaoNasDuasFormas(forma: String, recursos: String, esperados: RecursosDoApp) async throws {
        let corpo = #"{"plataforma": "ios", "versao_minima": "1.1.0", "versao_recomendada": "1.1.0", "url_da_loja": "https://apps.apple.com/app/id6815311991", "mensagem": "Atualize o Frila para continuar.", "recursos": "# + recursos + "}"
        BackendDeContrato.preparar([
            "/rest/v1/rpc/configuracao_do_app": .init(corpo: Data(corpo.utf8)),
            "/rest/v1/rpc/registrar_evento": .init(corpo: try FixturesDoContrato.dados("registrar-evento")),
        ])
        let api = try cliente()

        let configuracao = try await api.configuracaoDoApp()
        #expect(configuracao.recursos == esperados, "\(forma)")
        #expect(configuracao.versaoMinima == "1.1.0", "\(forma)")

        let abaixo = AtualizacaoObrigatoriaViewModel(api: api, versaoAtual: "1.0.9")
        await abaixo.verificar()
        guard case .bloqueado = abaixo.estado else { Issue.record("\(forma): 1.0.9 abaixo de 1.1.0 devia bloquear; estado: \(abaixo.estado)"); return }
        let igual = AtualizacaoObrigatoriaViewModel(api: api, versaoAtual: "1.1")
        await igual.verificar()
        #expect(igual.estado == .liberado, "\(forma)")
    }

    // MARK: Telemetria (RN15, RNF08, contrato 0.2.41)

    @Test("registrar_evento manda evento, identificadores opcionais e ocorrido_em, e lê registrado: true")
    func registrarEvento() async throws {
        try rpc("registrar_evento", "registrar-evento")
        let vagaID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let turnoID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        let ocorridoEm = ContratoAPI.instante("2026-10-14T14:30:00Z")!
        let registro = RegistroDeEvento(
            evento: .appAberto,
            vagaID: vagaID,
            turnoID: turnoID,
            ocorridoEm: ocorridoEm
        )
        let registrado = try await cliente().registrarEvento(registro)
        let corpo = try corpoEnviado(para: "/rest/v1/rpc/registrar_evento")

        #expect(corpo["evento"] as? String == "app_aberto")
        #expect((corpo["vaga_id"] as? String)?.lowercased() == vagaID.uuidString.lowercased())
        #expect((corpo["turno_id"] as? String)?.lowercased() == turnoID.uuidString.lowercased())
        #expect(corpo["ocorrido_em"] as? String == "2026-10-14T14:30:00Z")
        #expect(registrado == true)
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

    // MARK: Busca de profissionais (0.2.88)

    private static let cartaoDaBusca = #"""
    {"itens":[{"id":"b5000000-0000-0000-0000-000000000001","nome":"Maria S.",
      "servico":{"funcao":{"id":"20000000-0000-0000-0000-000000000001","nome":"Garçom","categoria":"Salão"},"unidade":"hora","valor_centavos":3500},
      "regioes":[{"id":1,"numero":"I","nome":"Plano Piloto","ativo":true}],"atende_todo_df":false,"distancia_faixa":"ate_5_km",
      "reputacao":{"positivas":9,"total":10,"taxa_comparecimento":0.9,"turnos_considerados":10,"turnos_realizados":9}}],
     "proximo_cursor":"c2"}
    """#

    @Test("buscar_profissionais vai por POST com o corpo do contrato e lê a página com o cursor")
    func buscarProfissionais() async throws {
        BackendDeContrato.preparar(["/rest/v1/rpc/buscar_profissionais": .init(corpo: Data(Self.cartaoDaBusca.utf8))])
        let casa = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
        let garcom = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
        let horario = try Periodo(inicio: ContratoAPI.instante("2026-11-17T23:00:00Z")!, fim: ContratoAPI.instante("2026-11-18T02:00:00Z")!)
        let pagina = try await cliente().buscarProfissionais(
            FiltroBuscaProfissionais(estabelecimentoID: casa, funcaoID: garcom, regiaoID: 1, horario: horario), cursor: "c1", limite: 20
        )

        // Com corpo, o PostgREST recebeu um POST (o GET levaria os filtros na URL).
        #expect(try corpoEnviado(para: "/rest/v1/rpc/buscar_profissionais") == [
            "estabelecimento_id": casa.uuidString.lowercased(), "funcao_id": garcom.uuidString.lowercased(), "regiao_id": 1,
            "inicio_em": "2026-11-17T23:00:00Z", "fim_em": "2026-11-18T02:00:00Z", "cursor": "c1", "limite": 20,
        ])
        #expect(pagina.itens.map(\.nome) == ["Maria S."])
        #expect(pagina.itens.first?.distanciaFaixa == .ate5km)
        #expect(pagina.proximoCursor == "c2")
    }

    @Test("buscar_profissionais lê foto_url e foto_id do cartão quando vêm, e trata como ausentes quando não vêm")
    func buscarProfissionaisComESemFoto() async throws {
        let semFoto = Self.cartaoDaBusca
        let fotoID = "50000000-0000-0000-0000-000000000009"
        let comFoto = semFoto.replacingOccurrences(
            of: #""distancia_faixa":"ate_5_km","#,
            with: #""distancia_faixa":"ate_5_km","foto_url":"https://frila-teste.supabase.co/ler-midia?t=abc","foto_id":"\#(fotoID)","#)
        try #require(comFoto != semFoto)
        let filtro = FiltroBuscaProfissionais(estabelecimentoID: UUID(), funcaoID: UUID())

        BackendDeContrato.preparar(["/rest/v1/rpc/buscar_profissionais": .init(corpo: Data(semFoto.utf8))])
        let sem = try #require(try await cliente().buscarProfissionais(filtro, cursor: nil, limite: nil).itens.first)
        #expect(sem.fotoURL == nil && sem.fotoID == nil)

        BackendDeContrato.preparar(["/rest/v1/rpc/buscar_profissionais": .init(corpo: Data(comFoto.utf8))])
        let com = try #require(try await cliente().buscarProfissionais(filtro, cursor: nil, limite: nil).itens.first)
        #expect(com.fotoURL?.absoluteString == "https://frila-teste.supabase.co/ler-midia?t=abc")
        #expect(com.fotoID == UUID(uuidString: fotoID))
    }

    @Test("buscar_profissionais: 429 limite_excedido e 422 cursor_invalido chegam tipados, com ou sem envelope")
    func buscarProfissionaisRecusas() async throws {
        let filtro = FiltroBuscaProfissionais(estabelecimentoID: UUID(), funcaoID: UUID())
        let casos: [(Int, String, CodigoErroAPI)] = [
            (429, #"{"code":"limite_excedido","message":"limite_excedido","details":null,"hint":null}"#, .limiteExcedido),
            (429, "Too Many Requests", .limiteExcedido),
            (422, #"{"code":"cursor_invalido","message":"cursor_invalido","details":null,"hint":null}"#, .cursorInvalido),
        ]
        for (status, corpo, esperado) in casos {
            BackendDeContrato.preparar(["/rest/v1/rpc/buscar_profissionais": .init(status: status, corpo: Data(corpo.utf8))])
            let erro = await #expect(throws: ErroDaApi.self) { _ = try await cliente().buscarProfissionais(filtro, cursor: nil, limite: nil) }
            #expect(erro?.codigo == esperado, "status \(status)")
            // Sem retentativa: cada repetição gastaria uma busca do limite de 60 por hora.
            #expect(BackendDeContrato.requisicoes.filter { $0.rota == "/rest/v1/rpc/buscar_profissionais" }.count == 1)
        }
    }

    @Test("aceitar_termos vai por POST com só a versão (o instante é do servidor) e lê o aceite em vigor")
    func aceitarTermos() async throws {
        let resposta = #"{"termos_versao":"2026-11-13","aceito_em":"2026-11-16T15:00:00Z"}"#
        BackendDeContrato.preparar(["/rest/v1/rpc/aceitar_termos": .init(corpo: Data(resposta.utf8))])
        let aceite = try await cliente().aceitarTermos(versao: "2026-11-13")

        #expect(try corpoEnviado(para: "/rest/v1/rpc/aceitar_termos") == ["termos_versao": "2026-11-13"])
        #expect(aceite.termosVersao == "2026-11-13")
        #expect(aceite.aceitoEm == ContratoAPI.instante("2026-11-16T15:00:00Z"))
    }

    @Test("aceitar_termos: 422 campo_invalido e campo_obrigatorio chegam tipados, e não é retentada")
    func aceitarTermosRecusas() async throws {
        let casos: [(String, CodigoErroAPI)] = [
            (#"{"code":"campo_invalido","message":"campo_invalido","details":"termos_versao","hint":null}"#, .campoInvalido),
            (#"{"code":"campo_obrigatorio","message":"campo_obrigatorio","details":"termos_versao","hint":null}"#, .campoObrigatorio),
        ]
        for (corpo, esperado) in casos {
            BackendDeContrato.preparar(["/rest/v1/rpc/aceitar_termos": .init(status: 422, corpo: Data(corpo.utf8))])
            let erro = await #expect(throws: ErroDaApi.self) { _ = try await cliente().aceitarTermos(versao: "x") }
            #expect(erro?.codigo == esperado)
            #expect(erro?.detalhes == "termos_versao")
            #expect(BackendDeContrato.requisicoes.filter { $0.rota == "/rest/v1/rpc/aceitar_termos" }.count == 1)
        }
    }

    @Test("buscar_profissionais: 403 sem_permissao com termos_pendentes chega tipado")
    func buscarProfissionaisTermosPendentes() async throws {
        let corpo = #"{"code":"sem_permissao","message":"sem_permissao","details":"termos_pendentes","hint":null}"#
        BackendDeContrato.preparar(["/rest/v1/rpc/buscar_profissionais": .init(status: 403, corpo: Data(corpo.utf8))])
        let erro = await #expect(throws: ErroDaApi.self) {
            _ = try await cliente().buscarProfissionais(FiltroBuscaProfissionais(estabelecimentoID: UUID(), funcaoID: UUID()), cursor: nil, limite: nil)
        }
        #expect(erro?.codigo == .semPermissao)
        #expect(erro?.termosPendentes == true)
        #expect(erro?.recursoDesligado == false)
        #expect(DecodificadorErroAPI.mapear(codigo: "sem_permissao", detalhes: "conta_suspensa").termosPendentes == false)
        #expect(DecodificadorErroAPI.mapear(codigo: "termos_pendentes", detalhes: nil).termosPendentes)
    }

    @Test("minha_conta lê termos_versao quando vem e trata como ausente quando não vem")
    func minhaContaComETermosVersao() async throws {
        let sem = #"{"id":"10000000-0000-0000-0000-000000000001","perfil":"contratante","nome":"Ana","telefone":"+5561988887777","email":"a@b.com","nascimento":"1990-01-01","estado":"ativa"}"#
        let com = sem.replacingOccurrences(of: #""estado":"ativa""#, with: #""estado":"ativa","termos_versao":"2026-11-13""#)
        BackendDeContrato.preparar(["/rest/v1/rpc/minha_conta": .init(corpo: Data(sem.utf8))])
        #expect(try await cliente().minhaConta().termosVersao == nil)
        BackendDeContrato.preparar(["/rest/v1/rpc/minha_conta": .init(corpo: Data(com.utf8))])
        #expect(try await cliente().minhaConta().termosVersao == "2026-11-13")
    }

    @Test("definir_preferencia_chamadas manda aceita_chamadas com a versão do texto e lê as pendências")
    func definirAceitaChamadas() async throws {
        let resposta = #"{"aceita_de_quem_ja_trabalhou":true,"pausado_ate":null,"antecedencia_minima_h":6,"aceita_de":"todos","aceita_chamadas":true,"pendencias_para_busca":["sem_regiao"]}"#
        BackendDeContrato.preparar(["/rest/v1/rpc/definir_preferencia_chamadas": .init(corpo: Data(resposta.utf8))])
        let preferencia = try await cliente().definirPreferenciaChamadas(AlteracaoPreferenciaChamadas(aceitaChamadas: true, versaoTextoBusca: "busca-v1"))

        #expect(try corpoEnviado(para: "/rest/v1/rpc/definir_preferencia_chamadas") == ["aceita_chamadas": true, "versao_texto_busca": "busca-v1"])
        #expect(preferencia.aceitaChamadas)
        #expect(preferencia.pendenciasParaBusca == [.semRegiao])
    }

    @Test("minhas_chamadas manda o estado e o cursor e devolve o proximo_cursor da página (0.2.95: a busca segue o cursor)")
    func paginaDeMinhasChamadasTrazOCursor() async throws {
        BackendDeContrato.preparar(["/rest/v1/rpc/minhas_chamadas": .init(corpo: Data(#"{"itens":[],"proximo_cursor":"c2"}"#.utf8))])
        let pagina = try await cliente().paginaDeMinhasChamadas(estado: .aberta, cursor: "c1", limite: nil)

        let corpo = try corpoEnviado(para: "/rest/v1/rpc/minhas_chamadas")
        #expect(corpo["estado"] as? String == "aberta")
        #expect(corpo["cursor"] as? String == "c1")
        #expect(pagina.proximoCursor == "c2")
        #expect(pagina.itens.isEmpty)
    }
}

// MARK: - Rede ruim e valor novo do contrato (robustez antes do TestFlight)

/// A `URLSession` falhando como falha numa rede ruim: a conexão existe, mas o pedido não volta.
private final class RedeRuim: URLProtocol {
    nonisolated(unsafe) static var codigo: URLError.Code = .timedOut

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(Self.codigo)) }
    override func stopLoading() {}
}

@Suite("Cliente Supabase: rede ruim vira semRede, e item com valor novo sai da lista sem derrubar a resposta", .serialized)
struct RedeRuimEValorNovoTests {
    private func cliente(_ protocolo: URLProtocol.Type) throws -> SupabaseApiCliente {
        let configuracao = URLSessionConfiguration.ephemeral
        configuracao.protocolClasses = [protocolo]
        return SupabaseApiCliente(
            url: try #require(URL(string: "https://frila-teste.supabase.co")),
            chavePublicavel: "sb_publishable_teste",
            telemetria: TelemetryNula(),
            sessaoHTTP: URLSession(configuration: configuracao),
            armazenamentoDaSessao: ArmazenamentoDeSessaoEmMemoria()
        )
    }

    /// A fixture com o caminho `chave/indice/chave…` trocado por `valor`; `copias` repete o item
    /// de uma fixture de lista para a troca pegar só um deles.
    private func fixture(_ nome: String, copias: Int = 1, trocando caminho: String, por valor: Any) throws -> Data {
        func aplicar(_ no: Any, _ resto: ArraySlice<Substring>) -> Any {
            guard let passo = resto.first else { return valor }
            if var lista = no as? [Any], let indice = Int(passo), lista.indices.contains(indice) {
                lista[indice] = aplicar(lista[indice], resto.dropFirst())
                return lista
            }
            if var objeto = no as? [String: Any] {
                objeto[String(passo)] = aplicar(objeto[String(passo)] ?? [:], resto.dropFirst())
                return objeto
            }
            return no
        }
        var raiz = try JSONSerialization.jsonObject(with: FixturesDoContrato.dados(nome))
        if copias > 1, let lista = raiz as? [Any], let primeiro = lista.first {
            raiz = lista + Array(repeating: primeiro, count: copias - lista.count)
        }
        return try JSONSerialization.data(withJSONObject: aplicar(raiz, caminho.split(separator: "/")[...]))
    }

    private func rpc(_ nome: String, _ corpo: Data) {
        BackendDeContrato.preparar(["/rest/v1/rpc/\(nome)": .init(corpo: corpo)])
    }

    @Test("Tempo esgotado, conexão perdida, DNS, host e dados móveis bloqueados são semRede, como a rede ausente", arguments: [
        URLError.Code.notConnectedToInternet, .timedOut, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost,
        .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff,
    ])
    func redeRuimEhSemRede(codigo: URLError.Code) async throws {
        RedeRuim.codigo = codigo
        let erro = await #expect(throws: ErroDaApi.self) { _ = try await cliente(RedeRuim.self).meusTurnos() }
        #expect(erro?.codigo == .semRede)
    }

    @Test("Falha de TLS não é falta de rede: continua desconhecida, e não abre o cache")
    func tlsNaoEhSemRede() async throws {
        RedeRuim.codigo = .secureConnectionFailed
        let erro = await #expect(throws: ErroDaApi.self) { _ = try await cliente(RedeRuim.self).meusTurnos() }
        #expect(erro?.codigo == .desconhecido)
    }

    @Test("meus_turnos: verificação nova vira pendente e tipo de check-in novo fica sem valor; o turno segue")
    func turnoComValorNovoTolerado() async throws {
        rpc("meus_turnos", try fixture("turnos", trocando: "0/verificacao", por: "valor_novo"))
        var turnos = try await cliente(BackendDeContrato.self).meusTurnos()
        #expect(turnos.count == 1)
        #expect(turnos.first?.verificacao == .pendente)

        rpc("meus_turnos", try fixture("turnos", trocando: "0/checkin_tipo", por: "valor_novo"))
        turnos = try await cliente(BackendDeContrato.self).meusTurnos()
        #expect(turnos.count == 1)
        #expect(turnos.first?.checkin?.tipo == nil)
    }

    @Test("meus_turnos: o turno cuja contraparte tem tipo novo sai da lista, e os outros ficam")
    func turnoComContraparteNovaSai() async throws {
        rpc("meus_turnos", try fixture("turnos", copias: 3, trocando: "1/contraparte/tipo", por: "valor_novo"))
        let turnos = try await cliente(BackendDeContrato.self).meusTurnos()
        #expect(turnos.count == 2)
    }

    @Test("vagas_abertas e minhas_candidaturas: o item com modo ou estado novo sai, os outros ficam")
    func listasComItemNovo() async throws {
        rpc("vagas_abertas", try fixture("vagas-abertas", copias: 3, trocando: "2/modo", por: "valor_novo"))
        #expect(try await cliente(BackendDeContrato.self).vagasAbertas(.todas).count == 2)

        rpc("minhas_candidaturas", try fixture("minhas-candidaturas", trocando: "0/estado", por: "valor_novo"))
        let candidaturas = try await cliente(BackendDeContrato.self).minhasCandidaturas(estado: nil)
        #expect(candidaturas.map(\.estado) == [.recusada])
    }

    @Test("vagas_abertas: o item com valor fora do domínio (centavos 0) sai, e a lista não falha")
    func itemForaDoDominioSai() async throws {
        rpc("vagas_abertas", try fixture("vagas-abertas", copias: 2, trocando: "0/valor_centavos", por: 0))
        #expect(try await cliente(BackendDeContrato.self).vagasAbertas(.todas).count == 1)
    }

    @Test("painel: a posição com estado novo sai da vaga, e a vaga com estado ou modo novo sai do painel")
    func painelComValorNovo() async throws {
        rpc("painel_estabelecimento", try fixture("painel", trocando: "vagas/0/posicoes/1/estado", por: "valor_novo"))
        let periodo = try Periodo(inicio: .distantPast, fim: .distantFuture)
        var painel = try await cliente(BackendDeContrato.self).painelEstabelecimento(id: UUID(), periodo: periodo)
        #expect(painel.vagas.count == 1)
        #expect(painel.vagas.first?.posicoes.count == 1)

        rpc("painel_estabelecimento", try fixture("painel", trocando: "vagas/0/modo", por: "valor_novo"))
        painel = try await cliente(BackendDeContrato.self).painelEstabelecimento(id: UUID(), periodo: periodo)
        #expect(painel.vagas.isEmpty)
        #expect(painel.estabelecimentoID == UUID(uuidString: "30000000-0000-0000-0000-000000000001")) // o resto do painel chega
    }

    @Test("meus_estabelecimentos: papel novo vira operador e tipo novo vira outro")
    func estabelecimentoComValorNovo() async throws {
        rpc("meus_estabelecimentos", try fixture("meus-estabelecimentos", trocando: "0/papel", por: "valor_novo"))
        #expect(try await cliente(BackendDeContrato.self).meusEstabelecimentos().first?.papel == .operador)

        rpc("meus_estabelecimentos", try fixture("meus-estabelecimentos", trocando: "0/tipo", por: "valor_novo"))
        #expect(try await cliente(BackendDeContrato.self).meusEstabelecimentos().first?.tipo == .outro)
    }

    @Test("membros_do_estabelecimento: papel novo do contrato vira operador, o de menos permissão")
    func membroComPapelNovo() async throws {
        rpc("membros_do_estabelecimento", try fixture("membros-do-estabelecimento", trocando: "0/papel", por: "gerente"))

        let membros = try await cliente(BackendDeContrato.self).membrosDaCasa(estabelecimentoID: UUID())

        // A lista não cai, a pessoa aparece com o papel de menos permissão e marcada como desconhecida (sem ação de administrador).
        #expect(membros.first?.papel == .operador)
        #expect(membros.first?.papelConhecido == false)
        #expect(membros.filter { !$0.papelConhecido }.count == 1)
        #expect(membros.count == 3)
    }

    @Test("Protocolo com tipo novo vira denúncia e registro com tipo novo vira manual")
    func protocoloERegistroComTipoNovo() async throws {
        rpc("denunciar", try fixture("protocolo", trocando: "tipo", por: "valor_novo"))
        let alvo = Alvo(tipo: .profissional, id: UUID())
        let protocolo = try await cliente(BackendDeContrato.self).denunciar(Denuncia(alvo: alvo, turnoID: nil, motivo: .outro, relato: "x", chave: UUID()))
        #expect(protocolo.tipo == .denuncia)

        rpc("fazer_checkin", try fixture("resultado-registro", trocando: "tipo", por: "valor_novo"))
        let registro = try await cliente(BackendDeContrato.self).fazerCheckin(turnoID: UUID(), distanciaMetros: nil, registradoEm: .now)
        #expect(registro.tipo == .manual)
    }

    @Test("Resposta que não é lista com perfil ou estado da conta novo continua recusada: o app não escolhe fluxo nem presume conta ativa", arguments: [
        ("minha_conta", "usuario", "perfil"), ("minha_conta", "usuario", "estado"), ("situacao_da_conta", "situacao-da-conta-suspensa", "estado"),
    ])
    func contaComValorNovoFechaFechado(rota: String, fixtura: String, campo: String) async throws {
        rpc(rota, try fixture(fixtura, trocando: campo, por: "valor_novo"))
        let api = try cliente(BackendDeContrato.self)
        let erro = await #expect(throws: ErroDaApi.self) {
            if rota == "minha_conta" { _ = try await api.minhaConta() } else { _ = try await api.situacaoDaConta() }
        }
        #expect(erro?.codigo == .respostaInvalida)
    }
}
