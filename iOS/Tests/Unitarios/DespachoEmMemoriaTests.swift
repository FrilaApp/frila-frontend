import Foundation
import FrilaDados
import FrilaDominio
import Testing

/// Sexta-feira, 15/01/2027, 05:00 em São Paulo.
private let agoraDoTeste = Date(timeIntervalSince1970: 1_800_000_000)

/// O dublê segue `criterios_de_notificacao` e `pedir_revisao_despacho` (`20260929190000_contestar_despacho.sql`).
@Suite("Dublê: critérios de notificação e revisão do despacho (#18)")
struct DespachoEmMemoriaTests {
    private let relato = "Tenho a função e os horários cadastrados e não recebi as vagas de sexta."

    @Test("O profissional lê a função, a grade, os 15 km, a equipe da casa das fixtures e o teto de 30 min")
    func criterios() async throws {
        let api = ApiClienteEmMemoria()
        let perfil = try await api.meuPerfilProfissional()
        let casa = try #require(try await api.meusEstabelecimentos().first)

        let criterios = try await api.criteriosDeNotificacao()

        #expect(criterios.funcoes == perfil.funcoes)
        #expect(criterios.disponibilidades == perfil.disponibilidades)
        #expect(criterios.distanciaMaximaKm == 15)
        #expect(criterios.equipesDeConfianca == [EquipeDeConfiancaDoProfissional(estabelecimentoID: casa.id, nome: casa.nome)])
        #expect(criterios.notificacoesNoMaximoACadaMin == 30)
        #expect(!criterios.semCriterios)
    }

    @Test("A grade sai na ordem do backend: dia e hora")
    func ordemDaGrade() async throws {
        let api = ApiClienteEmMemoria()
        _ = try await api.atualizarPerfilProfissional(AlteracaoPerfilProfissional(disponibilidades: [
            JanelaDeDisponibilidade(diaDaSemana: 6, inicio: try HoraDoDia("18:00"), fim: try HoraDoDia("23:00")),
            JanelaDeDisponibilidade(diaDaSemana: 2, inicio: try HoraDoDia("12:00"), fim: try HoraDoDia("15:00")),
            JanelaDeDisponibilidade(diaDaSemana: 2, inicio: try HoraDoDia("08:00"), fim: try HoraDoDia("11:00")),
        ]))
        let criterios = try await api.criteriosDeNotificacao()
        #expect(criterios.disponibilidades.map { "\($0.diaDaSemana) \($0.inicio.contrato)" } == ["2 08:00", "2 12:00", "6 18:00"])
    }

    @Test("Conta de contratante é perfil_incompativel nas duas operações")
    func contratante() async throws {
        let api = ApiClienteEmMemoria(cenario: .contratante)
        await #expect(throws: ErroDaApi(codigo: .perfilIncompativel)) { try await api.criteriosDeNotificacao() }
        await #expect(throws: ErroDaApi(codigo: .perfilIncompativel)) { try await api.pedirRevisaoDespacho(relato: relato) }
    }

    @Test("Sem conta é nao_autenticado; sem perfil profissional, os critérios são nao_encontrado")
    func semContaOuPerfil() async throws {
        let semConta = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        await #expect(throws: ErroDaApi(codigo: .naoAutenticado)) { try await semConta.criteriosDeNotificacao() }
        await #expect(throws: ErroDaApi(codigo: .naoAutenticado)) { try await semConta.pedirRevisaoDespacho(relato: relato) }

        let semPerfil = ApiClienteEmMemoria(cenario: .semPerfilProfissional)
        await #expect(throws: ErroDaApi(codigo: .naoEncontrado)) { try await semPerfil.criteriosDeNotificacao() }
    }

    @Test("A conta suspensa lê os critérios, mas pedir a revisão é sem_permissao com conta_suspensa")
    func contaSuspensa() async throws {
        let api = ApiClienteEmMemoria(cenario: .contaSuspensa)
        #expect(try await api.criteriosDeNotificacao().funcoes.isEmpty == false)
        await #expect(throws: ErroDaApi(codigo: .semPermissao, detalhes: "conta_suspensa")) { try await api.pedirRevisaoDespacho(relato: relato) }
        #expect(await api.relatosDeRevisaoDespacho.isEmpty)

        await api.reativarConta()
        #expect(try await api.pedirRevisaoDespacho(relato: relato).tipo == .revisaoDespacho)
    }

    @Test("O pedido devolve o protocolo de revisão com o quinto dia útil, e guarda o relato aparado")
    func pedirRevisao() async throws {
        let api = ApiClienteEmMemoria(relogio: RelogioFixo(agora: agoraDoTeste))

        let protocolo = try await api.pedirRevisaoDespacho(relato: "  \(relato)  ")

        #expect(protocolo.tipo == .revisaoDespacho)
        #expect(protocolo.criadaEm == agoraDoTeste)
        #expect(protocolo.prazoRespostaAte == (try DataCivil("2027-01-22")))
        #expect(await api.relatosDeRevisaoDespacho == [relato])
    }

    @Test("Não é idempotente: dois pedidos abrem duas ocorrências")
    func doisPedidos() async throws {
        let api = ApiClienteEmMemoria()
        let primeiro = try await api.pedirRevisaoDespacho(relato: relato)
        let segundo = try await api.pedirRevisaoDespacho(relato: relato)
        #expect(primeiro.ocorrenciaID != segundo.ocorrenciaID)
        #expect(await api.relatosDeRevisaoDespacho.count == 2)
    }

    @Test("Relato em branco é campo_obrigatorio; com menos de 10 caracteres, campo_invalido")
    func relatoInvalido() async throws {
        let api = ApiClienteEmMemoria()
        await #expect(throws: ErroDaApi(codigo: .campoObrigatorio, detalhes: "relato")) { try await api.pedirRevisaoDespacho(relato: "  ") }
        await #expect(throws: ErroDaApi(codigo: .campoInvalido, detalhes: "relato")) { try await api.pedirRevisaoDespacho(relato: "não veio") }
        #expect(await api.relatosDeRevisaoDespacho.isEmpty)
    }

    @Test("Sem rede, as duas operações falham como sem_rede")
    func semRede() async throws {
        let api = ApiClienteEmMemoria(cenario: .semRede)
        await #expect(throws: ErroDaApi(codigo: .semRede)) { try await api.criteriosDeNotificacao() }
        await #expect(throws: ErroDaApi(codigo: .semRede)) { try await api.pedirRevisaoDespacho(relato: relato) }
    }
}
