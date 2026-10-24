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
        #expect(rascunho.payPerPosition == 0)
        // O horário padrão do app (daqui a 3 h, por 3 h) já vem marcado, no passo de 30 min da roleta.
        #expect(rascunho.shiftDate == FrilaLPEJobShiftFormat.dateLabel(agora.addingTimeInterval(3 * 3_600)))
        #expect(rascunho.startTime == FormularioEstudioFrilaLPE.relogio(de: agora.addingTimeInterval(3 * 3_600)).fieldLabel)
        #expect(FrilaLPEJobShiftFormat.durationMinutes(start: rascunho.startTime, end: rascunho.endTime) == 180)
    }

    @Test("Rascunho inicial traz o que o view model já guarda: função, valor, responsável e turno")
    func rascunhoInicialPreenchido() throws {
        let formulario = try formulario { _ in throw ErroDaApi(codigo: .desconhecido) }
        let vaga = formulario.vaga
        vaga.funcaoID = funcao.id
        vaga.valorTexto = "14000"
        vaga.posicoesTexto = "3"
        vaga.responsavelLocal = "Gerente de Teste"
        vaga.traje = "Camisa preta"
        vaga.refeicao = true
        vaga.inicio = agora.addingTimeInterval(30 * 3_600)
        vaga.fim = vaga.inicio.addingTimeInterval(8 * 3_600)
        let rascunho = formulario.rascunhoInicial
        #expect(rascunho.role == "Garçom")
        #expect(rascunho.roleOrigin == .catalog)
        #expect(rascunho.payPerPosition == 140)
        #expect(rascunho.positionsCount == 3)
        #expect(rascunho.totalBudget == 420)
        #expect(rascunho.contactPerson == "Gerente de Teste")
        #expect(rascunho.dressCode == "Camisa preta")
        #expect(rascunho.mealIncluded)
        #expect(FrilaLPEJobFormSection.firstIncomplete(in: rascunho) == nil)
        // Ida e volta: o rascunho pré-preenchido devolve ao view model o mesmo período.
        let periodo = try #require(formulario.periodo(de: rascunho))
        #expect(periodo.fim.timeIntervalSince(periodo.inicio) == 8 * 3_600)
        #expect(abs(periodo.inicio.timeIntervalSince(vaga.inicio)) < 15 * 60)
    }

    @Test("Hora do view model cai na opção mais próxima da roleta de 30 minutos")
    func relogioNoPassoDaRoleta() {
        let calendario = FrilaLPEShiftCalendar.brasilia
        func data(_ hora: Int, _ minuto: Int) -> Date {
            calendario.date(bySettingHour: hora, minute: minuto, second: 0, of: agora)!
        }
        #expect(FormularioEstudioFrilaLPE.relogio(de: data(18, 0)).fieldLabel == "18:00")
        #expect(FormularioEstudioFrilaLPE.relogio(de: data(18, 10)).fieldLabel == "18:00")
        #expect(FormularioEstudioFrilaLPE.relogio(de: data(18, 20)).fieldLabel == "18:30")
        #expect(FormularioEstudioFrilaLPE.relogio(de: data(23, 50)).fieldLabel == "00:00")
    }

    @Test("Hora arredondada que cruza a meia-noite leva a data do turno ao dia seguinte (Loki, #498)")
    func relogioCruzaMeiaNoite() throws {
        let formulario = try formulario { _ in throw ErroDaApi(codigo: .desconhecido) }
        let calendario = FrilaLPEShiftCalendar.brasilia
        let vaga = formulario.vaga
        let dia = try #require(calendario.date(byAdding: .day, value: 2, to: calendario.startOfDay(for: agora)))
        vaga.inicio = try #require(calendario.date(bySettingHour: 23, minute: 50, second: 0, of: dia))
        vaga.fim = vaga.inicio.addingTimeInterval(6 * 3_600)
        let rascunho = formulario.rascunhoInicial
        let diaSeguinte = try #require(calendario.date(byAdding: .day, value: 1, to: dia))
        #expect(rascunho.shiftDate == FrilaLPEJobShiftFormat.dateLabel(diaSeguinte, calendar: calendario))
        #expect(rascunho.startTime == "00:00")
        #expect(rascunho.endTime == "06:00")
        // Ida e volta: o período reconstruído fica a 10 minutos do original, no dia certo.
        let periodo = try #require(formulario.periodo(de: rascunho))
        #expect(abs(periodo.inicio.timeIntervalSince(vaga.inicio)) <= 10 * 60)
        #expect(periodo.fim.timeIntervalSince(periodo.inicio) == 6 * 3_600)
        // 23:40 arredonda para baixo e fica no mesmo dia.
        vaga.inicio = try #require(calendario.date(bySettingHour: 23, minute: 40, second: 0, of: dia))
        #expect(formulario.rascunhoInicial.shiftDate == FrilaLPEJobShiftFormat.dateLabel(dia, calendar: calendario))
        #expect(formulario.rascunhoInicial.startTime == "23:30")
    }

    @Test("Sem rede a publicação fica na fila: não é erro nem celebração")
    func publicacaoSemRedeFicaNaFila() async throws {
        let formulario = try formulario { _ in throw ErroDaApi(codigo: .semRede) }
        let resultado = await formulario.publicar(rascunhoCompleto(formulario))
        #expect(resultado == .queued)
        #expect(formulario.vaga.publicacaoPendente != nil)
        #expect(formulario.vaga.mensagemErro == nil)
        #expect(formulario.vaga.mostraAvisoPublicacaoContinua)
        #expect(formulario.vaga.textoAoFechar == TextosPublicarVaga.voltar)
    }

    @Test("Erro do servidor volta como falha com a mensagem do app")
    func erroDoServidor() async throws {
        let formulario = try formulario { _ in throw ErroDaApi(codigo: .desconhecido) }
        let resultado = await formulario.publicar(rascunhoCompleto(formulario))
        #expect(resultado == .failed(TextosPublicarVaga.erroPublicar))
        // Erro genérico não é recusa definitiva: a publicação fica pendente para "Tentar novamente".
        #expect(formulario.vaga.publicacaoPendente != nil)
        #expect(formulario.vaga.mensagemErro == TextosPublicarVaga.erroPublicar)
    }

    @Test("Sincronizar acompanha o rascunho: a seleção volta a urgência quando o início fica perto (MS-RF01)")
    func sincronizarAjustaOModo() throws {
        let formulario = try formulario { _ in throw ErroDaApi(codigo: .desconhecido) }
        var rascunho = rascunhoCompleto(formulario)
        formulario.sincronizar(rascunho)
        #expect(formulario.vaga.selecaoDisponivel)
        formulario.vaga.modo = .selecao
        #expect(formulario.vaga.prazoDeEscolha != nil)
        rascunho.shiftDate = FrilaLPEJobShiftFormat.dateLabel(agora)
        rascunho.startTime = FormularioEstudioFrilaLPE.relogio(de: agora.addingTimeInterval(4 * 3_600)).fieldLabel
        rascunho.endTime = FormularioEstudioFrilaLPE.relogio(de: agora.addingTimeInterval(8 * 3_600)).fieldLabel
        formulario.sincronizar(rascunho)
        #expect(!formulario.vaga.selecaoDisponivel)
        #expect(formulario.vaga.modo == .urgencia)
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
        var rascunho = formulario.rascunhoInicial
        rascunho.contactPerson = ""
        let resultado = await formulario.publicar(rascunho)
        #expect(resultado == .failed(formulario.erroDaPublicacao ?? ""))
        #expect(formulario.erroDaPublicacao != nil)
        #expect(await api.chamadasAPublicarVaga == 0)
    }

    @Test("Valor por hora não existe no contrato: não publica")
    func semValorPorHora() async throws {
        let api = ApiClienteEmMemoria(relogio: RelogioDoEstudio(agora: agora))
        let formulario = try formulario { try await api.publicarVaga($0) }
        var rascunho = rascunhoCompleto(formulario)
        rascunho.paymentMode = .hourly
        #expect(await formulario.publicar(rascunho) == .failed(FormularioEstudioFrilaLPE.semValorPorHora))
        #expect(await api.chamadasAPublicarVaga == 0)
    }

    @Test("Rascunho completo publica pela API em memória")
    func publicaPelaApi() async throws {
        let api = ApiClienteEmMemoria(relogio: RelogioDoEstudio(agora: agora))
        let formulario = try formulario { try await api.publicarVaga($0) }
        let resultado = await formulario.publicar(rascunhoCompleto(formulario))
        #expect(resultado == .published)
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
