import Foundation
@testable import FrilaDados
import FrilaDominio
import Testing

private struct RelogioFixo: Relogio {
    let agora: Date
}

@Suite("Telemetria: contrato 0.2.41, RN15, RNF08 e resiliência")
struct TelemetriaTests {
    // MARK: - Dicionário fechado e fixtures de contrato

    @Test("Os 14 eventos do contrato 0.2.41 correspondem aos valores estritos do enum")
    func dicionarioDeEventos() {
        let mapeamentoEsperado: [EventoDeTelemetria: String] = [
            .appAberto: "app_aberto",
            .cadastroConcluido: "cadastro_concluido",
            .permissaoPushNegada: "permissao_push_negada",
            .vagaVista: "vaga_vista",
            .vagaDetalheAberto: "vaga_detalhe_aberto",
            .candidaturaEnviada: "candidatura_enviada",
            .candidaturaRetirada: "candidatura_retirada",
            .checkinTentado: "checkin_tentado",
            .checkinConcluido: "checkin_concluido",
            .checkoutConcluido: "checkout_concluido",
            .avaliacaoEnviada: "avaliacao_enviada",
            .contatoAberto: "contato_aberto",
            .acaoEnfileiradaOffline: "acao_enfileirada_offline",
            .atualizacaoObrigatoriaExibida: "atualizacao_obrigatoria_exibida",
        ]

        #expect(EventoDeTelemetria.allCases.count == 14)
        for (evento, valor) in mapeamentoEsperado {
            #expect(evento.rawValue == valor)
        }
    }

    @Test("Fixture registrar-evento.json decodifica com registrado = true")
    func decodificaFixtureResposta() throws {
        let resposta = try FixturesDoContrato.carregar(
            "registrar-evento",
            como: ContratoAPI.RegistrarEventoRespostaDTO.self
        )
        #expect(resposta.registrado == true)
    }

    @Test("Fixture requisicao-registrar-evento.json possui estrutura estrita do contrato")
    func decodificaFixtureRequisicao() throws {
        let dados = try FixturesDoContrato.dados("requisicao-registrar-evento")
        let json = try #require(JSONSerialization.jsonObject(with: dados) as? [String: Any])

        #expect(json["evento"] as? String == "app_aberto")
        #expect(json["vaga_id"] as? String == "11111111-1111-4111-8111-111111111111")
        #expect(json["turno_id"] as? String == "22222222-2222-4222-8222-222222222222")
        #expect(json["ocorrido_em"] as? String == "2026-10-14T14:30:00Z")
    }

    // MARK: - ApiClienteEmMemoria

    @Test("ApiClienteEmMemoria registra evento com sucesso quando autenticado")
    func registroComSucesso() async throws {
        let agora = Date()
        let api = ApiClienteEmMemoria(relogio: RelogioFixo(agora: agora))
        let vaga = try #require(try await api.vagasAbertas().first)
        let turnoID = try #require(try await api.candidatar(vagaID: vaga.id).turnoID)

        let registro = RegistroDeEvento(
            evento: .vagaVista,
            vagaID: vaga.id,
            turnoID: turnoID,
            ocorridoEm: agora
        )

        let sucesso = try await api.registrarEvento(registro)
        #expect(sucesso == true)
        let registrados = await api.eventosRegistrados
        #expect(registrados.count == 1)
        #expect(registrados.first == registro)
    }

    @Test("ApiClienteEmMemoria recusa registrar_evento sem sessão ativa (401 nao_autenticado)")
    func recusaSemAutenticacao() async {
        let api = ApiClienteEmMemoria(cenario: .entrada)
        await #expect(throws: ErroDaApi(codigo: .naoAutenticado)) {
            try await api.registrarEvento(.appAberto)
        }
    }

    @Test("ApiClienteEmMemoria recusa instante de ocorrência no futuro (422 registro_no_futuro)")
    func recusaRegistroNoFuturo() async {
        let agora = Date()
        let api = ApiClienteEmMemoria(relogio: RelogioFixo(agora: agora))
        let instanteNoFuturo = agora.addingTimeInterval(3600)
        let registro = RegistroDeEvento(
            evento: .appAberto,
            ocorridoEm: instanteNoFuturo
        )

        await #expect(throws: ErroDaApi(codigo: .registroNoFuturo)) {
            try await api.registrarEvento(registro)
        }
    }

    @Test("ApiClienteEmMemoria recusa vaga_id inexistente (422 campo_invalido)")
    func recusaVagaInexistente() async {
        let api = ApiClienteEmMemoria()
        let vagaFantasma = UUID(uuidString: "00000000-0000-4000-8000-000000000099")!
        let registro = RegistroDeEvento(
            evento: .vagaVista,
            vagaID: vagaFantasma
        )

        let erro = await #expect(throws: ErroDaApi.self) {
            try await api.registrarEvento(registro)
        }
        #expect(erro?.codigo == .campoInvalido)
        #expect(erro?.detalhes == "vaga_id")
    }

    @Test("ApiClienteEmMemoria recusa turno_id inexistente (422 campo_invalido)")
    func recusaTurnoInexistente() async {
        let api = ApiClienteEmMemoria()
        let turnoFantasma = UUID(uuidString: "00000000-0000-4000-8000-000000000099")!
        let registro = RegistroDeEvento(
            evento: .checkinTentado,
            turnoID: turnoFantasma
        )

        let erro = await #expect(throws: ErroDaApi.self) {
            try await api.registrarEvento(registro)
        }
        #expect(erro?.codigo == .campoInvalido)
        #expect(erro?.detalhes == "turno_id")
    }

    // MARK: - RegistradorDeTelemetria (Resiliência RNF08 / RN15)

    @Test("RegistradorDeTelemetria despacha com sucesso")
    func registradorSucesso() async {
        let api = ApiClienteEmMemoria()
        let registrador = RegistradorDeTelemetria(api: api)

        let ok = await registrador.registrar(.appAberto)
        #expect(ok == true)
        let registrados = await api.eventosRegistrados
        #expect(registrados.count == 1)
        #expect(registrados.first?.evento == .appAberto)
    }

    @Test("RegistradorDeTelemetria silencia falhas de API e não quebra o fluxo")
    func registradorSilenciaFalhas() async {
        let api = ApiClienteEmMemoria(cenario: .entrada)
        let registrador = RegistradorDeTelemetria(api: api)

        // Não lança exceção mesmo que a API recuse
        let ok = await registrador.registrar(.appAberto)
        #expect(ok == false)
        let registrados = await api.eventosRegistrados
        #expect(registrados.isEmpty)
    }

    @Test("RegistradorDeTelemetria com disparo não bloqueante (fire-and-forget) não propaga exceção")
    func registradorDisparoNaoBloqueante() async throws {
        let api = ApiClienteEmMemoria()
        let registrador = RegistradorDeTelemetria(api: api)

        registrador.disparar(.cadastroConcluido)
        // Pequena espera cooperativa para dar tempo à Task desacoplada executar
        try await Task.sleep(nanoseconds: 50_000_000)

        let registrados = await api.eventosRegistrados
        #expect(registrados.contains(where: { $0.evento == .cadastroConcluido }))
    }
}
