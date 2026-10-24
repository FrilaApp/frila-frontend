import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

private actor FilaDoEstudio: FilaDeAcoes {
    func recusar(_ acao: AcaoPendente, codigo: CodigoErroAPI) { remover(id: acao.id) }
    func recusadas() -> [AcaoRecusada] { [] }

    private var itens: [AcaoPendente] = []
    func enfileirar(_ acao: AcaoPendente) { itens.removeAll { $0.id == acao.id }; itens.append(acao) }
    func pendentes() -> [AcaoPendente] { itens }
    func remover(id: UUID) { itens.removeAll { $0.id == id } }
    func limpar() { itens.removeAll() }
}

private struct RelogioDoEstudio: Relogio {
    let agora: Date
}

/// Enxerto do estúdio de criação do FrilaLowPhase: o rascunho chega ao `PublicarVagaViewModel` e
/// publica pelo mesmo caminho do app, sem campo novo.
@MainActor
@Suite("Enxerto do estúdio de criação (FrilaLowPhase)")
struct EstudioFrilaLPETests {
    private let agora = Date(timeIntervalSince1970: 1_800_000_000)
    private let funcao = Funcao(id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!, nome: "Garçom", categoria: "Salão")

    private func estabelecimento() throws -> Estabelecimento {
        Estabelecimento(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!, nome: "Bistrô Ipê", tipo: .foodService,
            endereco: "CLS 405, Asa Sul, Brasília - DF", regiaoAdministrativa: "Plano Piloto",
            ponto: try Coordenada(latitude: -15.8121, longitude: -47.8997)
        )
    }

    private func formulario(publicar: @escaping @Sendable (PublicacaoVaga) async throws -> VagaPublicada) throws -> FormularioEstudioFrilaLPE {
        let fixo = agora
        let vaga = PublicarVagaViewModel(estabelecimento: try estabelecimento(), funcoes: [funcao], fila: FilaDoEstudio(), agora: { fixo }, publicar: publicar)
        return FormularioEstudioFrilaLPE(vaga: vaga, agora: { fixo })
    }

    private func rascunhoCompleto(_ formulario: FormularioEstudioFrilaLPE) -> FrilaLPEJobCreationDraft {
        var rascunho = formulario.rascunhoInicial
        rascunho.role = "garcom"
        rascunho.shiftDate = FrilaLPEJobShiftFormat.dateLabel(agora.addingTimeInterval(2 * 86_400))
        rascunho.startTime = "18:00"
        rascunho.endTime = "02:00"
        rascunho.payPerPosition = 140
        rascunho.positionsCount = 2
        rascunho.mealIncluded = true
        rascunho.contactPerson = "Renata no balcão"
        rascunho.dressCode = "Camisa preta"
        return rascunho
    }

    @Test("Rascunho inicial traz a casa, o endereço dela e o valor por turno")
    func rascunhoInicial() throws {
        let formulario = try formulario { _ in throw ErroDaApi(codigo: .desconhecido) }
        let rascunho = formulario.rascunhoInicial
        #expect(rascunho.client == "Bistrô Ipê")
        #expect(rascunho.address == "CLS 405, Asa Sul, Brasília - DF")
        #expect(rascunho.paymentMode == .perShift)
        #expect(rascunho.role.isEmpty)
    }

    @Test("Sem quem recebe o profissional, o turno fica incompleto e Publicar leva até ele")
    func turnoExigeQuemRecebe() throws {
        let formulario = try formulario { _ in throw ErroDaApi(codigo: .desconhecido) }
        var rascunho = rascunhoCompleto(formulario)
        #expect(FrilaLPEJobFormSection.firstIncomplete(in: rascunho) == nil)
        rascunho.contactPerson = "  "
        #expect(!FrilaLPEJobFormSection.turno.isComplete(rascunho))
        #expect(FrilaLPEJobFormSection.firstIncomplete(in: rascunho) == .turno)
    }

    @Test("Rascunho vira os campos do contrato, com o turno que passa da meia-noite")
    func aplicarRascunho() throws {
        let formulario = try formulario { _ in throw ErroDaApi(codigo: .desconhecido) }
        formulario.aplicar(rascunhoCompleto(formulario))
        let vaga = formulario.vaga
        #expect(vaga.funcaoID == funcao.id)
        #expect(vaga.fim.timeIntervalSince(vaga.inicio) == 8 * 3_600)
        #expect(vaga.valorCentavos == 14_000)
        #expect(vaga.posicoesTexto == "2")
        #expect(vaga.refeicao)
        #expect(!vaga.transporte)
        #expect(vaga.responsavelLocal == "Renata no balcão")
        #expect(vaga.traje == "Camisa preta")
        #expect(vaga.validar())
    }

    @Test("Função criada no estúdio não existe no contrato e não é enviada")
    func funcaoPersonalizada() throws {
        let formulario = try formulario { _ in throw ErroDaApi(codigo: .desconhecido) }
        var rascunho = rascunhoCompleto(formulario)
        rascunho.roleOrigin = .custom
        formulario.aplicar(rascunho)
        #expect(formulario.vaga.funcaoID == nil)
        #expect(!formulario.vaga.validar())
        #expect(formulario.vaga.erros[.funcao] != nil)
    }

    @Test("Rascunho incompleto não chama a rede e devolve o erro da validação do app")
    func validacaoSemRede() async throws {
        let api = ApiClienteEmMemoria(relogio: RelogioDoEstudio(agora: agora))
        let formulario = try formulario { try await api.publicarVaga($0) }
        let erro = await formulario.publicar(formulario.rascunhoInicial)
        #expect(erro != nil)
        #expect(erro == formulario.erroDaPublicacao)
        #expect(await api.chamadasAPublicarVaga == 0)
    }

    @Test("Valor por hora não existe no contrato: não publica")
    func semValorPorHora() async throws {
        let api = ApiClienteEmMemoria(relogio: RelogioDoEstudio(agora: agora))
        let formulario = try formulario { try await api.publicarVaga($0) }
        var rascunho = rascunhoCompleto(formulario)
        rascunho.paymentMode = .hourly
        #expect(await formulario.publicar(rascunho) == FormularioEstudioFrilaLPE.semValorPorHora)
        #expect(await api.chamadasAPublicarVaga == 0)
    }

    @Test("Rascunho completo publica pela API em memória")
    func publicaPelaApi() async throws {
        let api = ApiClienteEmMemoria(relogio: RelogioDoEstudio(agora: agora))
        let formulario = try formulario { try await api.publicarVaga($0) }
        let erro = await formulario.publicar(rascunhoCompleto(formulario))
        #expect(erro == nil)
        #expect(formulario.vaga.resultado != nil)
        #expect(await api.chamadasAPublicarVaga == 1)
        let enviada = try #require(await api.publicacoesRecebidas.first)
        #expect(enviada.funcaoID == funcao.id)
        #expect(enviada.posicoes == 2)
        #expect(enviada.valor.centavos == 14_000)
        #expect(enviada.inclusos.refeicao && enviada.traje == "Camisa preta")
        #expect(enviada.periodo.fim.timeIntervalSince(enviada.periodo.inicio) == 8 * 3_600)
    }

    @Test("As roletas passam a usar as funções do servidor, agrupadas pela categoria")
    func catalogoDoServidor() throws {
        let formulario = try formulario { _ in throw ErroDaApi(codigo: .desconhecido) }
        formulario.vaga.funcoes = [
            funcao,
            Funcao(id: UUID(), nome: "Bartender", categoria: "Bar"),
            Funcao(id: UUID(), nome: "Cumim", categoria: "Salão")
        ]
        formulario.usarFuncoesNoCatalogo()
        #expect(FrilaLPERoleCatalog.categories.map(\.name) == ["Salão", "Bar"])
        #expect(FrilaLPERoleCatalog.roles(inCategoryID: "Salão").map(\.name) == ["Garçom", "Cumim"])
        #expect(FrilaLPERoleCatalog.match("garcom")?.id == funcao.id.uuidString)
    }
}
