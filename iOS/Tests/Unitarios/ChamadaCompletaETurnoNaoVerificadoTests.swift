import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

/// Lotes 2 e 3 da conferência visual da 1.1 (`orquestracao/retornos/conferencia-visual-1-1.md`): os
/// cenários de vitrine da chamada direta (V1, V2, V3) e do turno não verificado (V4, B6) no dublê, e
/// o estado "não verificado" no Meu turno do profissional.
@Suite("Chamada direta completa e turno não verificado no dublê")
@MainActor
struct ChamadaCompletaETurnoNaoVerificadoTests {
    private let vagaComChamadaAberta = UUID(uuidString: "c1000000-0000-0000-0000-000000000002")!
    private let vagaComChamadaRecusada = UUID(uuidString: "c1000000-0000-0000-0000-000000000003")!
    private let turnoDoProfissional = UUID(uuidString: "22000000-0000-0000-0000-000000000001")!
    private let turnoDaCasa = UUID(uuidString: "82000000-0000-0000-0000-000000000001")!

    // MARK: V2, V3: chamada recebida pelo profissional

    @Test("chamada-recebida: conta de profissional, chave ligada e a chamada aberta da casa, fora da lista de vagas")
    func chamadaRecebida() async throws {
        let api = ApiClienteEmMemoria(cenario: .chamadaRecebida)
        #expect(try await api.minhaConta().perfil == .profissional)
        #expect(try await api.configuracaoDoApp().recursos.chamadaDireta, "Preferências de chamada aparecem com a chave ligada")

        let detalhe = try await api.detalheChamada(id: ApiClienteEmMemoria.chamadaRecebidaID)
        #expect(detalhe.estado == .aberta)
        #expect(detalhe.outraParte.tipo == .estabelecimento, "quem chamou é a casa: é o alvo de Denunciar e Bloquear")
        #expect(detalhe.recado?.isEmpty == false)
        #expect(!(try await api.vagasAbertas(.todas)).contains { $0.id == detalhe.vagaID }, "a vaga direta nunca é listada")

        let modelo = ChamadaRecebidaViewModel(chamadaID: ApiClienteEmMemoria.chamadaRecebidaID, api: api)
        await modelo.carregar()
        #expect(modelo.podeResponder)
        await modelo.aceitar()
        #expect(modelo.resultado?.chamada.estado == .aceita)
    }

    // MARK: V1: Acompanhar chamadas

    @Test("chamadas-enviadas: a vaga com a chamada aberta deixa cancelar e não oferece publicar para todos")
    func acompanharChamadaAberta() async throws {
        let api = ApiClienteEmMemoria(cenario: .chamadasEnviadas)
        let modelo = AcompanharChamadasViewModel(vagaID: vagaComChamadaAberta, api: api)
        await modelo.carregar()

        let chamada = try #require(modelo.chamadas.only)
        #expect(chamada.estado == .aberta)
        #expect(!modelo.podePublicarParaTodos)

        await modelo.cancelar(chamadaID: chamada.id)
        #expect(modelo.chamadas.only?.estado == .cancelada)
        #expect(modelo.sucessoMensagem != nil)
    }

    @Test("chamadas-enviadas: com a chamada recusada, publicar para todos cria uma vaga normal uma vez só (RN35)")
    func publicarParaTodos() async throws {
        let api = ApiClienteEmMemoria(cenario: .chamadasEnviadas)
        let modelo = AcompanharChamadasViewModel(vagaID: vagaComChamadaRecusada, api: api)
        await modelo.carregar()

        #expect(modelo.chamadas.only?.estado == .recusada)
        #expect(modelo.podePublicarParaTodos)
        await modelo.publicarParaTodos()
        let nova = try #require(modelo.vagaPublicadaNovaID)
        #expect(nova != vagaComChamadaRecusada)
        #expect(!modelo.podePublicarParaTodos, "uma vez só")
    }

    @Test("As duas vagas diretas aparecem no painel da casa com a origem chamada_direta")
    func vagasDiretasNoPainel() async throws {
        let api = ApiClienteEmMemoria(cenario: .chamadasEnviadas)
        let casa = try #require(try await api.meusEstabelecimentos().first)
        let agora = Date()
        let painel = try await api.painelEstabelecimento(
            id: casa.id, periodo: try Periodo(inicio: agora.addingTimeInterval(-86_400), fim: agora.addingTimeInterval(7 * 86_400)))
        let diretas = painel.vagas.filter { $0.vaga.origem == .chamadaDireta }.map(\.vaga.id)
        #expect(Set(diretas) == [vagaComChamadaAberta, vagaComChamadaRecusada])
    }

    // MARK: V4, B6: turno não verificado

    @Test("turno-nao-verificado: o turno do profissional terminou com a presença não verificada, e o Meu turno diz isso")
    func turnoNaoVerificadoDoProfissional() async throws {
        let api = ApiClienteEmMemoria(cenario: .turnoNaoVerificado)
        let turno = try #require(try await api.meusTurnos().first { $0.id == turnoDoProfissional })
        #expect(turno.verificacao == .naoVerificado)
        #expect(turno.vaga.periodo.fim < Date())
        #expect(!turno.podeAvaliar, "sem presença verificada não há avaliação (RN07)")

        let modelo = MeuTurnoViewModel(turno: turno, api: api)
        #expect(modelo.naoVerificado)
        #expect(!modelo.cancelado)
    }

    @Test("O turno verificado não vira não verificado no Meu turno")
    func turnoVerificadoNaoMudaOTitulo() async throws {
        let api = ApiClienteEmMemoria(cenario: .turnoEncerrado)
        let turno = try #require(try await api.meusTurnos().first { $0.id == turnoDoProfissional })
        #expect(!MeuTurnoViewModel(turno: turno, api: api).naoVerificado)
    }

    @Test("turno-nao-verificado-contratante: a posição do turno da casa chega não verificada e sem confirmação pendente")
    func turnoNaoVerificadoDaCasa() async throws {
        let api = ApiClienteEmMemoria(cenario: .turnoNaoVerificadoContratante)
        #expect(try await api.minhaConta().perfil == .contratante)
        let casa = try #require(try await api.meusEstabelecimentos().first)
        let agora = Date()
        let painel = try await api.painelEstabelecimento(
            id: casa.id, periodo: try Periodo(inicio: agora.addingTimeInterval(-7 * 86_400), fim: agora.addingTimeInterval(7 * 86_400)))
        let posicao = try #require(painel.vagas.flatMap(\.posicoes).first { $0.turnoID == turnoDaCasa })
        #expect(posicao.verificacao == .naoVerificado)
        #expect(!painel.checkinsPendentes.contains(turnoDaCasa), "não há o que confirmar: o turno já terminou")
    }
}

private extension Array {
    /// O único elemento, ou `nil` quando há zero ou mais de um.
    var only: Element? { count == 1 ? first : nil }
}
