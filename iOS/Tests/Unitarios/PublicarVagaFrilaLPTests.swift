import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

private actor FilaFrilaLPTeste: FilaDeAcoes {
    private var itens: [AcaoPendente] = []
    func recusar(_ acao: AcaoPendente, codigo: CodigoErroAPI) async throws { remover(id: acao.id) }
    func recusadas() -> [AcaoRecusada] { [] }
    func enfileirar(_ acao: AcaoPendente) { itens.removeAll { $0.id == acao.id }; itens.append(acao) }
    func pendentes() -> [AcaoPendente] { itens }
    func remover(id: UUID) { itens.removeAll { $0.id == id } }
    func limpar() { itens.removeAll() }
}

@MainActor
@Suite("Enxerto FrilaLowPhase: publicar vaga")
struct PublicarVagaFrilaLPTests {
    /// 15/01/2027, 05:00 em Brasília.
    private let agora = Date(timeIntervalSince1970: 1_800_000_000)
    private let funcao = Funcao(id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!, nome: "Garçom", categoria: "Salão")
    private let calendario = FrilaLPShiftCalendar.brasilia

    private func estabelecimento() throws -> Estabelecimento {
        Estabelecimento(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!, nome: "Bistrô", tipo: .foodService,
            endereco: "Rua das Flores, 10", regiaoAdministrativa: "Águas Claras",
            ponto: try Coordenada(latitude: -15.78, longitude: -47.93)
        )
    }

    private func formulario(
        agora referencia: Date? = nil,
        publicar: @escaping @Sendable (PublicacaoVaga) async throws -> VagaPublicada = { _ in throw ErroDaApi(codigo: .desconhecido) }
    ) throws -> FormularioPublicarVagaFrilaLP {
        let fixo = referencia ?? agora
        let vaga = PublicarVagaViewModel(
            estabelecimento: try estabelecimento(), funcoes: [funcao], fila: FilaFrilaLPTeste(), agora: { fixo }, publicar: publicar
        )
        return FormularioPublicarVagaFrilaLP(vaga: vaga, agora: { fixo }, calendario: calendario)
    }

    private func preencher(_ form: FormularioPublicarVagaFrilaLP) {
        form.vaga.funcaoID = funcao.id
        form.valorCentavos = 14_000
        form.posicoes = 2
        form.vaga.responsavelLocal = "Renata no balcão"
    }

    /// "15 18:00": dia do mês e hora em Brasília.
    private func hora(_ data: Date) -> String {
        let c = calendario.dateComponents([.day, .hour, .minute], from: data)
        return String(format: "%d %02d:%02d", c.day ?? 0, c.hour ?? 0, c.minute ?? 0)
    }

    // MARK: Estado do formulário

    @Test("Abre como na origem: hoje, 18h às 02h, gravado no view model com a virada da noite")
    func estadoInicial() throws {
        let form = try formulario()
        #expect(form.dia == .today)
        #expect(hora(form.vaga.inicio) == "15 18:00")
        #expect(hora(form.vaga.fim) == "16 02:00")
        #expect(form.notaDeVirada == "Termina no dia seguinte: sáb 16/01, às 02:00.")
        #expect(form.vaga.local == "Rua das Flores, 10")
    }

    @Test("Se as 18h de hoje já passaram, abre em amanhã")
    func abreEmAmanhaDepoisDasDezoito() throws {
        let form = try formulario(agora: agora.addingTimeInterval(14 * 3_600))
        #expect(form.dia == .tomorrow)
        #expect(hora(form.vaga.inicio) == "16 18:00")
    }

    @Test("Dia e janela mudam início e fim do view model")
    func diaEJanelaMudamOHorario() throws {
        let form = try formulario()
        form.escolher(.tomorrow)
        form.janela = FrilaLPShiftWindow(start: FrilaLPShiftClock(hour: 9), end: FrilaLPShiftClock(hour: 15, minute: 30))
        #expect(hora(form.vaga.inicio) == "16 09:00")
        #expect(hora(form.vaga.fim) == "16 15:30")
        #expect(form.notaDeVirada == nil)

        form.escolherData(calendario.date(byAdding: .day, value: 5, to: agora)!)
        #expect(form.outraDataEscolhida)
        #expect(hora(form.vaga.inicio) == "20 09:00")
        form.escolherData(agora)
        #expect(form.dia == .today)
    }

    @Test("Posições e valor vão para os textos do view model e somam o total")
    func posicoesEValor() throws {
        let form = try formulario()
        preencher(form)
        #expect(form.vaga.posicoesTexto == "2")
        #expect(form.vaga.valorCentavos == 14_000)
        #expect(form.totalCentavos == 28_000)
        #expect(form.resumo.hasPrefix("Garçom, 2 posições, hoje, "))
        form.valorCentavos = 0
        #expect(form.vaga.valorTexto.isEmpty)
    }

    // MARK: Validação

    @Test("Bloqueios da origem: sem valor, fim igual ao início e início no passado")
    func bloqueios() throws {
        let form = try formulario()
        #expect(form.bloqueio == "Informe o valor por posição.")
        preencher(form)
        #expect(form.bloqueio == nil)
        form.janela = FrilaLPShiftWindow(start: FrilaLPShiftClock(hour: 20), end: FrilaLPShiftClock(hour: 20))
        #expect(form.bloqueio == "O fim precisa ser diferente do início.")
        form.janela = FrilaLPShiftWindow(start: FrilaLPShiftClock(hour: 4), end: FrilaLPShiftClock(hour: 8))
        #expect(form.bloqueio == "Esse início já passou. Escolha outro horário ou outra data.")
        #expect(form.podeComecarEnvio() == false)
    }

    @Test("Sem bloqueio, a validação do app ainda exige quem recebe no local")
    func validacaoDoApp() throws {
        let form = try formulario()
        preencher(form)
        form.vaga.responsavelLocal = " "
        #expect(form.podeComecarEnvio() == false)
        #expect(form.vaga.erros[.responsavel] != nil)
        #expect(form.erroDaPublicacao == form.vaga.erros[.responsavel])

        form.vaga.responsavelLocal = "Renata no balcão"
        #expect(form.podeComecarEnvio())
        #expect(form.erroDaPublicacao == nil)
    }

    // MARK: Publicação

    @Test("Publica pelo ApiClienteEmMemoria com os campos do formulário")
    func publicaPelaApiEmMemoria() async throws {
        let api = ApiClienteEmMemoria()
        let form = try formulario { try await api.publicarVaga($0) }
        preencher(form)
        #expect(form.podeComecarEnvio())

        let publicou = await form.publicar()

        #expect(publicou)
        #expect(await api.chamadasAPublicarVaga == 1)
        #expect(await api.vagasCriadas == 1)
        #expect(form.vaga.resultado != nil)
    }

    @Test("Publicar com campo faltando não chama a API")
    func semChamadaComCampoFaltando() async throws {
        let api = ApiClienteEmMemoria()
        let form = try formulario { try await api.publicarVaga($0) }
        form.valorCentavos = 14_000

        let publicou = await form.publicar()

        #expect(publicou == false)
        #expect(await api.chamadasAPublicarVaga == 0)
        #expect(form.erroDaPublicacao != nil)
    }
}
