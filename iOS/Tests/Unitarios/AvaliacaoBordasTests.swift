import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

private struct ErroQualquer: Error {}

private struct RelogioFixo: Relogio {
    let agora: Date
}

private final class ApiDeAvaliacao: ApiClienteEncaminhador, @unchecked Sendable {
    var erro: Error?
    private(set) var chamadas = 0
    override func avaliar(turnoID: UUID, resposta: Bool) async throws -> Avaliacao {
        chamadas += 1
        if let erro { throw erro }
        return Avaliacao(turnoID: turnoID, resposta: resposta, criadaEm: Date(timeIntervalSince1970: 1_791_000_000))
    }
}

/// Fila que recusa guardar: o disco cheio ou o cache indisponível.
private final class FilaQueRecusa: FilaDeAcoes, @unchecked Sendable {
    struct Recusada: Error {}
    func enfileirar(_ acao: AcaoPendente) async throws { throw Recusada() }
    func pendentes() async throws -> [AcaoPendente] { [] }
    func remover(id: UUID) async throws {}
    func limpar() async throws {}
    func recusar(_ acao: AcaoPendente, codigo: CodigoErroAPI) async throws { try await remover(id: acao.id) }
    func recusadas() async throws -> [AcaoRecusada] { [] }
}

private final class FilaEmMemoria: FilaDeAcoes, @unchecked Sendable {
    private let trava = NSLock()
    private var itens: [AcaoPendente] = []
    func enfileirar(_ acao: AcaoPendente) async throws { trava.withLock { itens.append(acao) } }
    func pendentes() async throws -> [AcaoPendente] { trava.withLock { itens } }
    func remover(id: UUID) async throws { trava.withLock { itens.removeAll { $0.id == id } } }
    func limpar() async throws { trava.withLock { itens.removeAll() } }
    func recusar(_ acao: AcaoPendente, codigo: CodigoErroAPI) async throws { try await remover(id: acao.id) }
    func recusadas() async throws -> [AcaoRecusada] { [] }
}

private final class ArmazenamentoEmMemoria: ArmazenamentoAvaliacoes, @unchecked Sendable {
    private let trava = NSLock()
    private var respostas: [String: Bool] = [:]
    private var semResposta: Set<String> = []
    private func chave(_ turnoID: UUID, _ contaID: UUID) -> String { "\(contaID)-\(turnoID)" }
    func resposta(para turnoID: UUID, contaID: UUID) -> Bool? { trava.withLock { respostas[chave(turnoID, contaID)] } }
    func salvar(resposta: Bool, para turnoID: UUID, contaID: UUID) { trava.withLock { respostas[chave(turnoID, contaID)] = resposta } }
    func jaRegistrada(para turnoID: UUID, contaID: UUID) -> Bool {
        trava.withLock { respostas[chave(turnoID, contaID)] != nil || semResposta.contains(chave(turnoID, contaID)) }
    }
    func registrarSemResposta(para turnoID: UUID, contaID: UUID) { _ = trava.withLock { semResposta.insert(chave(turnoID, contaID)) } }
    func limpar() { trava.withLock { respostas = [:]; semResposta = [] } }
}

private func turnoVerificado(fim: Date) throws -> Turno {
    let vaga = VagaResumo(
        id: UUID(), funcao: "Garçom", local: "Bar do Lago", regiaoAdministrativa: "Plano Piloto",
        periodo: try Periodo(inicio: fim.addingTimeInterval(-4 * 3_600), fim: fim), valor: Dinheiro(centavos: 15000)
    )
    let reputacao = Reputacao(positivas: 10, total: 10, taxaComparecimento: nil, turnosConsiderados: 10, turnosRealizados: 10)
    return Turno(
        id: UUID(), posicaoID: UUID(), vaga: vaga,
        contraparte: PerfilPublico(id: UUID(), tipo: .estabelecimento, nome: "Bar do Lago", reputacao: reputacao),
        contatoVisivelAte: fim.addingTimeInterval(7 * 24 * 3_600), verificacao: .verificado, valorAcordado: vaga.valor,
        podeAvaliar: true, contato: nil
    )
}

/// As bordas da avaliação (RN07) que `AvaliacaoTurnoViewModelTests` não exercita: sem resposta
/// escolhida, `URLError` cru da rede, sem rede sem fila, fila que recusa guardar, 409 com resposta
/// conhecida, `avaliacao_indisponivel` e os erros genéricos.
@MainActor
@Suite("Avaliação do turno: bordas do envio e da fila offline")
struct AvaliacaoBordasTests {
    private let agora = Date(timeIntervalSince1970: 1_791_000_000)
    private let contaID = UUID()

    private func modelo(api: ApiDeAvaliacao, fila: (any FilaDeAcoes)? = nil, armazenamento: ArmazenamentoEmMemoria = ArmazenamentoEmMemoria()) throws -> (AvaliacaoTurnoViewModel, Turno) {
        let turno = try turnoVerificado(fim: agora.addingTimeInterval(-3_600))
        let vm = AvaliacaoTurnoViewModel(
            turnoID: turno.id, contaID: contaID, turno: turno, api: api, fila: fila, armazenamento: armazenamento, relogio: RelogioFixo(agora: agora)
        )
        return (vm, turno)
    }

    @Test("Salvar sem escolher a resposta não chama a API e pede a resposta")
    func semResposta() async throws {
        let api = ApiDeAvaliacao()
        let (vm, _) = try modelo(api: api)

        #expect(await vm.salvar() == false)
        #expect(vm.mensagemDeErro == TextosDoProfissional.Avaliacao.erroSelecioneResposta)
        #expect(api.chamadas == 0)
    }

    @Test("URLError cru da rede entra na fila como sem rede")
    func urlErrorVaiParaAFila() async throws {
        let api = ApiDeAvaliacao()
        api.erro = URLError(.notConnectedToInternet)
        let fila = FilaEmMemoria()
        let (vm, turno) = try modelo(api: api, fila: fila)
        vm.resposta = true

        #expect(await vm.salvar())
        #expect(vm.enfileiradoOffline)
        #expect(vm.mensagemDeSucesso == TextosDoProfissional.Avaliacao.avaliadoOffline)
        let pendente = try #require(try await fila.pendentes().first)
        #expect(pendente.tipo == .avaliacao)
        #expect(pendente.turnoID == turno.id)
        #expect(pendente.resposta == true)
        #expect(pendente.contaID == contaID)
    }

    @Test("Sem rede e sem fila, a avaliação não é guardada e a mensagem é a de sem rede")
    func semRedeSemFila() async throws {
        let api = ApiDeAvaliacao()
        api.erro = ErroDaApi(codigo: .semRede)
        let (vm, _) = try modelo(api: api)
        vm.resposta = true

        #expect(await vm.salvar() == false)
        #expect(!vm.enfileiradoOffline)
        #expect(vm.mensagemDeErro == MensagemDoErroAPI.texto(ErroDaApi(codigo: .semRede)))
    }

    @Test("Sem rede e com a fila recusando guardar, a mensagem é a de sem rede e nada fica como enviado")
    func filaRecusa() async throws {
        let api = ApiDeAvaliacao()
        api.erro = ErroDaApi(codigo: .semRede)
        let (vm, _) = try modelo(api: api, fila: FilaQueRecusa())
        vm.resposta = false

        #expect(await vm.salvar() == false)
        #expect(!vm.enfileiradoOffline)
        #expect(!vm.sucesso)
        #expect(vm.mensagemDeErro == MensagemDoErroAPI.texto(ErroDaApi(codigo: .semRede)))
    }

    @Test("409 com uma resposta já conhecida neste aparelho mantém a conhecida, não a recusada")
    func conflitoComRespostaConhecida() async throws {
        let api = ApiDeAvaliacao()
        api.erro = ErroDaApi(codigo: .avaliacaoJaRegistrada)
        let armazenamento = ArmazenamentoEmMemoria()
        let (vm, turno) = try modelo(api: api, armazenamento: armazenamento)
        armazenamento.salvar(resposta: true, para: turno.id, contaID: contaID)
        vm.resposta = false

        #expect(await vm.salvar() == false)
        #expect(vm.jaAvaliado)
        #expect(vm.resposta == true)
        #expect(armazenamento.resposta(para: turno.id, contaID: contaID) == true)
        #expect(vm.mensagemDeErro == nil)
    }

    @Test("avaliacao_indisponivel, outro erro da API e erro desconhecido mostram cada um a sua mensagem")
    func outrosErros() async throws {
        let api = ApiDeAvaliacao()

        api.erro = ErroDaApi(codigo: .avaliacaoIndisponivel)
        let (indisponivel, _) = try modelo(api: api)
        indisponivel.resposta = true
        #expect(await indisponivel.salvar() == false)
        #expect(indisponivel.mensagemDeErro == TextosDoProfissional.Avaliacao.erroIndisponivel)

        api.erro = ErroDaApi(codigo: .naoAutenticado)
        let (naoAutenticado, _) = try modelo(api: api)
        naoAutenticado.resposta = true
        #expect(await naoAutenticado.salvar() == false)
        #expect(naoAutenticado.mensagemDeErro == MensagemDoErroAPI.texto(ErroDaApi(codigo: .naoAutenticado)))

        api.erro = ErroQualquer()
        let (desconhecido, _) = try modelo(api: api)
        desconhecido.resposta = true
        #expect(await desconhecido.salvar() == false)
        #expect(desconhecido.mensagemDeErro == TextosDoProfissional.Avaliacao.erroGenerico)
        #expect(!desconhecido.jaAvaliado)
    }

    @Test("registradaEm é nulo por padrão para armazenamentos que não guardam o instante")
    func registradaEmPadrao() {
        #expect(ArmazenamentoEmMemoria().registradaEm(para: UUID(), contaID: UUID()) == nil)
    }
}
