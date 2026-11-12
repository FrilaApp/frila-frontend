import CryptoKit
import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

private final class ApiClienteDubleCheckinCasa: ApiClienteEncaminhador, @unchecked Sendable {
    var aoGerarCodigo: ((UUID) async throws -> CodigoDeCheckin)?

    override func gerarCodigoCheckin(turnoID: UUID) async throws -> CodigoDeCheckin {
        if let aoGerarCodigo {
            return try await aoGerarCodigo(turnoID)
        }
        return try await base.gerarCodigoCheckin(turnoID: turnoID)
    }
}

@Suite("Código da Casa no Check-in Semiautomático (Visão Contratante)")
struct CodigoDaCasaViewModelTests {
    private let turnoID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    @Test("Carrega código com zeros à esquerda preservados e segundos restantes do servidor")
    @MainActor
    func carregaCodigoComSucesso() async {
        let api = ApiClienteDubleCheckinCasa()
        api.aoGerarCodigo = { id in
            CodigoDeCheckin(
                turnoID: id,
                codigo: "049215",
                expiraEm: Date().addingTimeInterval(300),
                segundosRestantes: 300
            )
        }

        let vm = CodigoDaCasaViewModel(turnoID: turnoID, api: api)
        #expect(vm.estado == .carregando)

        await vm.carregar()

        #expect(vm.estado == .mostrando(codigo: "049215"))
        #expect(vm.segundosRestantes == 300)
        #expect(!vm.renovando)
    }

    @Test("Passo do relógio monotônico decrementa segundos restantes e renova ao zerar")
    @MainActor
    func passoDoRelogioERenovacao() async {
        let api = ApiClienteDubleCheckinCasa()
        var chamadas = 0
        api.aoGerarCodigo = { id in
            chamadas += 1
            let codigo = chamadas == 1 ? "012345" : "987654"
            return CodigoDeCheckin(
                turnoID: id,
                codigo: codigo,
                expiraEm: Date().addingTimeInterval(10),
                segundosRestantes: 10
            )
        }

        var instanteAtual = ContinuousClock.now
        let vm = CodigoDaCasaViewModel(turnoID: turnoID, api: api, agora: { instanteAtual })

        await vm.carregar()
        #expect(vm.estado == .mostrando(codigo: "012345"))
        #expect(vm.segundosRestantes == 10)

        // Avança 4 segundos
        instanteAtual = instanteAtual + .seconds(4)
        await vm.passo()
        #expect(vm.segundosRestantes == 6)

        // Avança 6 segundos adicionais (atinge zero)
        instanteAtual = instanteAtual + .seconds(6)
        await vm.passo()

        // Deve ter disparado a renovação e carregado o novo código
        #expect(chamadas == 2)
        #expect(vm.estado == .mostrando(codigo: "987654"))
        #expect(!vm.renovando)
    }

    @Test("Formatação de segundos restantes em minutos e segundos")
    func formatacaoDeSegundos() {
        #expect(CodigoDaCasaViewModel.formatar(segundos: 300) == "5:00")
        #expect(CodigoDaCasaViewModel.formatar(segundos: 272) == "4:32")
        #expect(CodigoDaCasaViewModel.formatar(segundos: 59) == "0:59")
        #expect(CodigoDaCasaViewModel.formatar(segundos: 9) == "0:09")
        #expect(CodigoDaCasaViewModel.formatar(segundos: 0) == "0:00")
        #expect(CodigoDaCasaViewModel.formatar(segundos: -15) == "0:00")
    }

    @Test("checkin_pendente mapeia para estado aguardandoChegada")
    @MainActor
    func checkinPendenteMapeiaAguardandoChegada() async {
        let api = ApiClienteDubleCheckinCasa()
        api.aoGerarCodigo = { _ in
            throw ErroDaApi(codigo: .checkinPendente)
        }

        let vm = CodigoDaCasaViewModel(turnoID: turnoID, api: api)
        await vm.carregar()

        #expect(vm.estado == .aguardandoChegada)
        #expect(vm.segundosRestantes == 0)
    }

    @Test("checkin_ja_confirmado mapeia para estado jaVerificado")
    @MainActor
    func checkinJaConfirmadoMapeiaJaVerificado() async {
        let api = ApiClienteDubleCheckinCasa()
        api.aoGerarCodigo = { _ in
            throw ErroDaApi(codigo: .checkinJaConfirmado)
        }

        let vm = CodigoDaCasaViewModel(turnoID: turnoID, api: api)
        await vm.carregar()

        #expect(vm.estado == .jaVerificado)
    }

    @Test("codigo_bloqueado encerrado mapeia para estado encerrado")
    @MainActor
    func codigoBloqueadoMapeiaEncerrado() async {
        let api = ApiClienteDubleCheckinCasa()
        api.aoGerarCodigo = { _ in
            throw ErroDaApi(codigo: .codigoBloqueado, detalhes: "encerrado")
        }

        let vm = CodigoDaCasaViewModel(turnoID: turnoID, api: api)
        await vm.carregar()

        #expect(vm.estado == .encerrado)
    }

    @Test("recurso_desligado mapeia para estado indisponivel")
    @MainActor
    func recursoDesligadoMapeiaIndisponivel() async {
        let api = ApiClienteDubleCheckinCasa()
        api.aoGerarCodigo = { _ in
            throw ErroDaApi(codigo: .semPermissao, detalhes: "recurso_desligado")
        }

        let vm = CodigoDaCasaViewModel(turnoID: turnoID, api: api)
        await vm.carregar()

        #expect(vm.estado == .indisponivel)
    }

    @Test("fora_da_janela mapeia para estado foraDaJanela")
    @MainActor
    func foraDaJanelaMapeiaForaDaJanela() async {
        let api = ApiClienteDubleCheckinCasa()
        api.aoGerarCodigo = { _ in
            throw ErroDaApi(codigo: .foraDaJanela)
        }

        let vm = CodigoDaCasaViewModel(turnoID: turnoID, api: api)
        await vm.carregar()

        #expect(vm.estado == .foraDaJanela)
    }

    @Test("Erro de rede mapeia para falhou e tentarDeNovo recupera")
    @MainActor
    func falhaDeRedeETentarDeNovo() async {
        let api = ApiClienteDubleCheckinCasa()
        var falhar = true
        api.aoGerarCodigo = { id in
            if falhar {
                throw ErroDaApi(codigo: .semRede)
            }
            return CodigoDeCheckin(
                turnoID: id,
                codigo: "777888",
                expiraEm: Date().addingTimeInterval(300),
                segundosRestantes: 300
            )
        }

        let vm = CodigoDaCasaViewModel(turnoID: turnoID, api: api)
        await vm.carregar()

        #expect(vm.estado == .falhou)

        // Recupera a conexão e tenta novamente
        falhar = false
        await vm.tentarDeNovo()

        #expect(vm.estado == .mostrando(codigo: "777888"))
        #expect(vm.segundosRestantes == 300)
    }

    @Test("Acessibilidade: código por extenso soletra dígitos individuais para VoiceOver")
    func codigoPorExtensoSoletraDigitos() {
        let soletrado = TextosDoCheckinPorCodigoCasa.codigoPorExtenso("049215")
        #expect(soletrado.contains("0 4 9 2 1 5"))
    }

    @Test("Single-flight: chamadas concorrentes a carregar não disparam múltiplas requisições em voo")
    @MainActor
    func singleFlightEvitaRequisicoesConcorrentes() async {
        let api = ApiClienteDubleCheckinCasa()
        var chamadas = 0
        api.aoGerarCodigo = { id in
            chamadas += 1
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            return CodigoDeCheckin(
                turnoID: id,
                codigo: "123456",
                expiraEm: Date().addingTimeInterval(300),
                segundosRestantes: 300
            )
        }

        let vm = CodigoDaCasaViewModel(turnoID: turnoID, api: api)

        // Dispara duas chamadas concorrentes
        async let t1: () = vm.carregar()
        async let t2: () = vm.carregar()
        _ = await (t1, t2)

        #expect(chamadas == 1)
        #expect(vm.estado == .mostrando(codigo: "123456"))
    }

    @Test("verificarConfirmacao dispara aoConfirmar quando servidor responde checkin_ja_confirmado")
    @MainActor
    func verificarConfirmacaoDisparaAoConfirmarQuandoJaVerificado() async {
        let api = ApiClienteDubleCheckinCasa()
        var jaConfirmou = false
        api.aoGerarCodigo = { id in
            if jaConfirmou {
                throw ErroDaApi(codigo: .checkinJaConfirmado)
            }
            return CodigoDeCheckin(
                turnoID: id,
                codigo: "654321",
                expiraEm: Date().addingTimeInterval(300),
                segundosRestantes: 300
            )
        }

        var confirmacaoDisparada = false
        let vm = CodigoDaCasaViewModel(
            turnoID: turnoID,
            api: api,
            aoConfirmar: {
                confirmacaoDisparada = true
            }
        )

        await vm.carregar()
        #expect(vm.estado == .mostrando(codigo: "654321"))
        #expect(!confirmacaoDisparada)

        // Profissional validou no backend
        jaConfirmou = true
        await vm.verificarConfirmacao()

        #expect(vm.estado == .jaVerificado)
        #expect(confirmacaoDisparada)
    }

    @Test("verificarConfirmacao relê em aguardandoChegada e transita para mostrando ao receber código")
    @MainActor
    func verificarConfirmacaoReleEmAguardandoChegada() async {
        let api = ApiClienteDubleCheckinCasa()
        var chegou = false
        api.aoGerarCodigo = { id in
            if !chegou {
                throw ErroDaApi(codigo: .checkinPendente)
            }
            return CodigoDeCheckin(
                turnoID: id,
                codigo: "847291",
                expiraEm: Date().addingTimeInterval(300),
                segundosRestantes: 300
            )
        }

        let vm = CodigoDaCasaViewModel(turnoID: turnoID, api: api)
        await vm.carregar()
        #expect(vm.estado == .aguardandoChegada)

        // Profissional registra a chegada (Cheguei)
        chegou = true
        await vm.verificarConfirmacao()

        #expect(vm.estado == .mostrando(codigo: "847291"))
        #expect(vm.segundosRestantes == 300)
    }

    @Test("verificarConfirmacao não relê quando há chamada em voo")
    @MainActor
    func verificarConfirmacaoNaoReleComChamadaEmVoo() async {
        let api = ApiClienteDubleCheckinCasa()
        var chamadas = 0
        api.aoGerarCodigo = { id in
            chamadas += 1
            try await Task.sleep(nanoseconds: 50_000_000)
            return CodigoDeCheckin(
                turnoID: id,
                codigo: "123456",
                expiraEm: Date().addingTimeInterval(300),
                segundosRestantes: 300
            )
        }

        let vm = CodigoDaCasaViewModel(turnoID: turnoID, api: api)

        // Dispara carga inicial e releitura concorrente
        async let t1: () = vm.carregar()
        async let t2: () = vm.verificarConfirmacao()
        _ = await (t1, t2)

        #expect(chamadas == 1)
        #expect(vm.estado == .mostrando(codigo: "123456"))
    }

    @Test("verificarConfirmacao não executa requisição quando a tarefa foi cancelada ao sair da tela")
    @MainActor
    func verificarConfirmacaoParaAoCancelarTarefa() async {
        let api = ApiClienteDubleCheckinCasa()
        var chamadas = 0
        api.aoGerarCodigo = { id in
            chamadas += 1
            return CodigoDeCheckin(
                turnoID: id,
                codigo: "123456",
                expiraEm: Date().addingTimeInterval(300),
                segundosRestantes: 300
            )
        }

        let vm = CodigoDaCasaViewModel(turnoID: turnoID, api: api)
        await vm.carregar()
        #expect(chamadas == 1)

        // Tarefa cancelada (como ao fechar ou sair da tela)
        let tarefaCancelada = Task { @MainActor in
            #expect(Task.isCancelled)
            await vm.verificarConfirmacao()
        }
        tarefaCancelada.cancel()
        await tarefaCancelada.value

        #expect(chamadas == 1)
    }

    @Test("Erro de rede na releitura periódica mantém o estado da tela intacto (não troca para falhou)")
    @MainActor
    func erroDeRedeNaReleituraNaoTrocaEstado() async {
        let api = ApiClienteDubleCheckinCasa()
        var falhaDeRede = false
        var emitirCodigo = false
        api.aoGerarCodigo = { id in
            if falhaDeRede {
                throw ErroDaApi(codigo: .semRede)
            }
            if !emitirCodigo {
                throw ErroDaApi(codigo: .checkinPendente)
            }
            return CodigoDeCheckin(
                turnoID: id,
                codigo: "654321",
                expiraEm: Date().addingTimeInterval(300),
                segundosRestantes: 300
            )
        }

        let vm = CodigoDaCasaViewModel(turnoID: turnoID, api: api)
        await vm.carregar()
        #expect(vm.estado == .aguardandoChegada)

        // Releitura periódica em segundo plano com oscilação de rede: mantém aguardandoChegada
        falhaDeRede = true
        await vm.verificarConfirmacao()
        #expect(vm.estado == .aguardandoChegada)

        // Restabelece rede e emite código
        falhaDeRede = false
        emitirCodigo = true
        await vm.verificarConfirmacao()
        #expect(vm.estado == .mostrando(codigo: "654321"))

        // Nova oscilação de rede com código em exibição: mantém mostrando com o código
        falhaDeRede = true
        await vm.verificarConfirmacao()
        #expect(vm.estado == .mostrando(codigo: "654321"))
        #expect(vm.segundosRestantes == 300)
    }
}

@Suite("Check-in Semiautomático: Prova Integrada contra PostgREST Local no Mesmo Turno", .serialized)
struct CheckinSemiautoLocalPostgrestIntegrationTests {
    private let supabaseURL = URL(string: "http://127.0.0.1:54321")!
    private let chavePublicavel = "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"
    private let jwtSecret = "super-secret-jwt-token-with-at-least-32-characters-long".data(using: .utf8)!

    private let turnoID = UUID(uuidString: "c8440000-0000-4000-8000-000000000041")!
    private let casaID = UUID(uuidString: "c8440000-0000-4000-8000-000000000001")!
    private let casaEmail = "dono-piloto@test.invalid"
    private let profID = UUID(uuidString: "c8440000-0000-4000-8000-000000000032")!
    private let profEmail = "prof-piloto@test.invalid"

    private func b64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func criarJWT(sub: UUID, email: String) throws -> String {
        let now = Int(Date().timeIntervalSince1970)
        let headerData = try JSONSerialization.data(withJSONObject: ["alg": "HS256", "typ": "JWT"])
        let payloadData = try JSONSerialization.data(withJSONObject: [
            "sub": sub.uuidString.lowercased(),
            "email": email,
            "role": "authenticated",
            "aud": "authenticated",
            "iat": now,
            "exp": now + 7200
        ])
        let headerB64 = b64url(headerData)
        let payloadB64 = b64url(payloadData)
        let assinaturaConteudo = Data("\(headerB64).\(payloadB64)".utf8)
        let key = SymmetricKey(data: jwtSecret)
        let hmac = HMAC<SHA256>.authenticationCode(for: assinaturaConteudo, using: key)
        let sigB64 = b64url(Data(hmac))
        return "\(headerB64).\(payloadB64).\(sigB64)"
    }

    private func criarSessao(sub: UUID, email: String, token: String) throws -> Data {
        let iso = ISO8601DateFormatter().string(from: Date())
        let dict: [String: Any] = [
            "access_token": token,
            "token_type": "bearer",
            "expires_in": 7200,
            "expires_at": Int(Date().addingTimeInterval(7200).timeIntervalSince1970),
            "refresh_token": token,
            "user": [
                "id": sub.uuidString.lowercased(),
                "app_metadata": ["provider": "email", "providers": ["email"]],
                "user_metadata": [String: String](),
                "aud": "authenticated",
                "email": email,
                "phone": "",
                "created_at": iso,
                "role": "authenticated",
                "updated_at": iso,
                "identities": [] as [Any],
                "is_anonymous": false
            ] as [String: Any]
        ]
        return try JSONSerialization.data(withJSONObject: dict)
    }

    private func criarCliente(sub: UUID, email: String) async throws -> SupabaseApiCliente {
        let token = try criarJWT(sub: sub, email: email)
        let sessionData = try criarSessao(sub: sub, email: email, token: token)
        let storage = ArmazenamentoDeSessaoEmMemoria()
        try storage.store(key: "supabase.auth.token", value: sessionData)
        try storage.store(key: "sb-127-auth-token", value: sessionData)
        try storage.store(key: "sb-localhost-auth-token", value: sessionData)

        let cliente = SupabaseApiCliente(
            url: supabaseURL,
            chavePublicavel: chavePublicavel,
            telemetria: TelemetryNula(),
            sessaoHTTP: SupabaseApiCliente.sessaoComPrazo(),
            armazenamentoDaSessao: storage
        )
        return cliente
    }

    @Test("Caminho Feliz integrado: Casa e Profissional no mesmo turno contra PostgREST local com atualização automática")
    @MainActor
    func caminhoFelizIntegradoNoMesmoTurno() async throws {
        let apiCasa = try await criarCliente(sub: casaID, email: casaEmail)
        let apiProf = try await criarCliente(sub: profID, email: profEmail)

        #expect(apiCasa.haSessaoGuardada, "Sessão da Casa deve estar guardada e carregada no cliente")
        #expect(apiProf.haSessaoGuardada, "Sessão do Profissional deve estar guardada e carregada no cliente")

        // 1. Instancia o ViewModel da Casa com callback aoConfirmar
        var atualizacaoAutomaticaDisparada = false
        let vmCasa = await CodigoDaCasaViewModel(
            turnoID: turnoID,
            api: apiCasa,
            aoConfirmar: {
                atualizacaoAutomaticaDisparada = true
            }
        )

        // 1.1 Casa tenta carregar código ANTES da chegada
        await vmCasa.carregar()
        let estadoInicial = await vmCasa.estado
        #expect(estadoInicial == .aguardandoChegada, "Antes da chegada, a casa fica aguardando e não vaza código")

        // 2. Profissional registra chegada a 30m simulados via PostgREST local
        let resultadoChegada = try await apiProf.fazerCheckin(
            turnoID: turnoID,
            distanciaMetros: 30,
            registradoEm: Date(),
            sinais: SinaisDoCheckin(localizacaoSimulada: true, precisaoMetros: nil, saltoDePosicao: false)
        )
        #expect(resultadoChegada.verificacao == .pendente, "Presença manual permanece pendente")

        // 3. Com a MESMA instância do ViewModel da Casa AINDA ATIVA, carrega o código emitido
        await vmCasa.carregar()
        let estadoComCodigo = await vmCasa.estado
        guard case let .mostrando(codigoGerado) = estadoComCodigo else {
            Issue.record("A casa deveria estar mostrando o código após a chegada. Estado: \(estadoComCodigo)")
            return
        }
        #expect(ValidacaoDoCodigoViewModel.formatoValido(codigoGerado), "Código gerado deve ter 6 dígitos numéricos")
        let segundos = await vmCasa.segundosRestantes
        #expect(segundos > 0, "Contagem de validade ativa")

        // 4. Profissional instancia seu ViewModel e valida o código com distância simulada de 30m
        let vmProf = await ValidacaoDoCodigoViewModel(
            turnoID: turnoID,
            api: apiProf,
            medirDistancia: { 30 }
        )
        await vmProf.validarMedindo(codigo: codigoGerado)
        let resultadoValidacao = await vmProf.resultado
        guard case let .verificado(registro) = resultadoValidacao else {
            Issue.record("Validação do profissional falhou no PostgREST: \(resultadoValidacao)")
            return
        }
        #expect(registro.verificacao == .verificado, "Presença deve vir confirmada como verificado")
        #expect(registro.tipo == .codigo, "Tipo de check-in deve ser codigo")

        // 5. COM A INSTÂNCIA vmCasa PRESERVADA EM MEMÓRIA (sem reabrir), executa a verificação periódica de polling
        #expect(!atualizacaoAutomaticaDisparada, "Antes do polling, a confirmação ainda não disparou")
        await vmCasa.verificarConfirmacao()

        let estadoAposConfirmacao = await vmCasa.estado
        #expect(estadoAposConfirmacao == .jaVerificado, "Ao detectar 409 checkin_ja_confirmado, o estado passa para .jaVerificado")
        #expect(atualizacaoAutomaticaDisparada, "O callback aoConfirmar da Casa DEVE disparar automaticamente em runtime")
    }
}
