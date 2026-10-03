import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

private actor FilaDeAcoesMemoria: FilaDeAcoes {
    func recusar(_ acao: AcaoPendente, codigo: CodigoErroAPI) async throws { try await remover(id: acao.id) }
    func recusadas() -> [AcaoRecusada] { [] }

    var itens: [AcaoPendente] = []

    init(itens: [AcaoPendente] = []) {
        self.itens = itens
    }

    func enfileirar(_ acao: AcaoPendente) throws {
        itens.append(acao)
    }

    func pendentes() throws -> [AcaoPendente] {
        itens
    }

    func remover(id: UUID) throws {
        itens.removeAll(where: { $0.id == id })
    }

    func limpar() throws {
        itens.removeAll()
    }
}

private final class ApiClienteAvaliacaoDuble: ApiClienteEncaminhador, @unchecked Sendable {
    private let trava = NSLock()
    var erroAvaliar: (any Error)?
    var pausaAvaliar: UInt64 = 0
    private var _chamadasAvaliar: [(turnoID: UUID, resposta: Bool)] = []

    var chamadasAvaliar: [(turnoID: UUID, resposta: Bool)] {
        trava.withLock { _chamadasAvaliar }
    }

    override func avaliar(turnoID: UUID, resposta: Bool) async throws -> Avaliacao {
        let (erro, pausa) = trava.withLock {
            _chamadasAvaliar.append((turnoID, resposta))
            return (erroAvaliar, pausaAvaliar)
        }

        if pausa > 0 {
            try? await Task.sleep(nanoseconds: pausa)
        }

        if let erro {
            throw erro
        }
        return Avaliacao(turnoID: turnoID, resposta: resposta, criadaEm: Date())
    }
}

private final class RelogioSimulado: Relogio, @unchecked Sendable {
    var agora: Date
    init(_ agora: Date) { self.agora = agora }
}

private func criarTurno(
    fim: Date,
    verificacao: Verificacao = .verificado,
    podeAvaliar: Bool = true
) throws -> Turno {
    let inicio = fim.addingTimeInterval(-4 * 3600)
    let vaga = VagaResumo(
        id: UUID(),
        funcao: "Garçom",
        local: "Bar do Lago",
        regiaoAdministrativa: "Plano Piloto",
        periodo: try Periodo(inicio: inicio, fim: fim),
        valor: Dinheiro(centavos: 15000)
    )
    let reputacao = Reputacao(positivas: 10, total: 10, taxaComparecimento: nil, turnosConsiderados: 10, turnosRealizados: 10)
    let contraparte = PerfilPublico(id: UUID(), tipo: .estabelecimento, nome: "Bar do Lago", reputacao: reputacao)
    return Turno(
        id: UUID(),
        posicaoID: UUID(),
        vaga: vaga,
        contraparte: contraparte,
        contatoVisivelAte: fim.addingTimeInterval(7 * 24 * 3600),
        verificacao: verificacao,
        valorAcordado: vaga.valor,
        podeAvaliar: podeAvaliar
    )
}

@Suite("Avaliação do turno (#22)")
struct AvaliacaoTurnoViewModelTests {
    private let contaID = UUID()
    private let agora = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Sucesso: registra avaliação online e salva resposta no armazenamento local")
    @MainActor
    func sucessoOnline() async throws {
        let api = ApiClienteAvaliacaoDuble()
        let armazenamento = ArmazenamentoAvaliacoesEmMemoria()
        let turno = try criarTurno(fim: agora.addingTimeInterval(-3600))
        let vm = AvaliacaoTurnoViewModel(
            turnoID: turno.id,
            contaID: contaID,
            turno: turno,
            api: api,
            armazenamento: armazenamento,
            relogio: RelogioSimulado(agora)
        )

        vm.resposta = true
        let salvou = await vm.salvar()

        #expect(salvou == true)
        #expect(vm.sucesso == true)
        #expect(vm.jaAvaliado == true)
        #expect(vm.mensagemDeSucesso == TextosDoProfissional.Avaliacao.avaliadoSucesso)
        #expect(vm.mensagemDeErro == nil)
        #expect(armazenamento.resposta(para: turno.id, contaID: contaID) == true)
        #expect(api.chamadasAvaliar.count == 1)
        #expect(api.chamadasAvaliar.first?.resposta == true)
    }

    @Test("Erro 422: avaliacao_indisponivel exibe mensagem explicativa")
    @MainActor
    func erro422AvaliacaoIndisponivel() async throws {
        let api = ApiClienteAvaliacaoDuble()
        api.erroAvaliar = ErroDaApi(codigo: .avaliacaoIndisponivel)
        let armazenamento = ArmazenamentoAvaliacoesEmMemoria()
        let turno = try criarTurno(fim: agora.addingTimeInterval(-3600))
        let vm = AvaliacaoTurnoViewModel(
            turnoID: turno.id,
            contaID: contaID,
            turno: turno,
            api: api,
            armazenamento: armazenamento,
            relogio: RelogioSimulado(agora)
        )

        vm.resposta = true
        let salvou = await vm.salvar()

        #expect(salvou == false)
        #expect(vm.sucesso == false)
        #expect(vm.jaAvaliado == false)
        #expect(vm.mensagemDeErro == TextosDoProfissional.Avaliacao.erroIndisponivel)
        #expect(armazenamento.resposta(para: turno.id, contaID: contaID) == nil)
    }

    @Test("Erro 409: estado neutro sem gravar ou mostrar a resposta recusada")
    @MainActor
    func erro409AvaliacaoJaRegistrada() async throws {
        let api = ApiClienteAvaliacaoDuble()
        api.erroAvaliar = ErroDaApi(codigo: .avaliacaoJaRegistrada)
        let armazenamento = ArmazenamentoAvaliacoesEmMemoria()
        let turno = try criarTurno(fim: agora.addingTimeInterval(-3600))
        let vm = AvaliacaoTurnoViewModel(
            turnoID: turno.id,
            contaID: contaID,
            turno: turno,
            api: api,
            armazenamento: armazenamento,
            relogio: RelogioSimulado(agora)
        )

        vm.resposta = false
        let salvou = await vm.salvar()

        #expect(salvou == false)
        #expect(vm.sucesso == false)
        #expect(vm.jaAvaliado == true)
        #expect(vm.mensagemDeErro == nil)
        #expect(vm.resposta == nil)
        #expect(armazenamento.resposta(para: turno.id, contaID: contaID) == nil)
        vm.resposta = true
        #expect(vm.resposta == nil)
        #expect(await vm.salvar() == false)
        #expect(api.chamadasAvaliar.count == 1)
        let reaberto = AvaliacaoTurnoViewModel(turnoID: turno.id, contaID: contaID, api: api, armazenamento: armazenamento)
        #expect(reaberto.jaAvaliado)
        #expect(reaberto.resposta == nil)
    }

    @Test("Sem rede: enfileira ação de avaliação na fila offline e salva localmente")
    @MainActor
    func semRedeEnfileirando() async throws {
        let api = ApiClienteAvaliacaoDuble()
        api.erroAvaliar = ErroDaApi(codigo: .semRede)
        let container = try PersistenciaFrila.criarContainer(emMemoria: true)
        let fila = ArmazenamentoSwiftData(modelContainer: container)
        let suite = "avaliacao-offline-test-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let armazenamento = UserDefaultsArmazenamentoAvaliacoes(defaults: defaults)
        let turno = try criarTurno(fim: agora.addingTimeInterval(-3600))
        let vm = AvaliacaoTurnoViewModel(
            turnoID: turno.id,
            contaID: contaID,
            turno: turno,
            api: api,
            fila: fila,
            armazenamento: armazenamento,
            relogio: RelogioSimulado(agora)
        )

        vm.resposta = true
        let salvou = await vm.salvar()

        #expect(salvou == true)
        #expect(vm.sucesso == true)
        #expect(vm.enfileiradoOffline == true)
        #expect(vm.jaAvaliado == true)
        #expect(vm.mensagemDeSucesso == TextosDoProfissional.Avaliacao.avaliadoOffline)
        #expect(vm.mensagemDeErro == nil)
        #expect(armazenamento.resposta(para: turno.id, contaID: contaID) == true)

        let pendentes = try await fila.pendentes()
        #expect(pendentes.count == 1)
        #expect(pendentes.first?.tipo == .avaliacao)
        #expect(pendentes.first?.turnoID == turno.id)
        #expect(pendentes.first?.resposta == true)
        #expect(pendentes.first?.contaID == contaID)
        vm.resposta = false
        #expect(await vm.salvar() == false)
        let reaberto = AvaliacaoTurnoViewModel(turnoID: turno.id, contaID: contaID, turno: turno,
                                             api: api, fila: ArmazenamentoSwiftData(modelContainer: container),
                                             armazenamento: UserDefaultsArmazenamentoAvaliacoes(defaults: defaults))
        await reaberto.carregar()
        #expect(reaberto.resposta == true)
        #expect(reaberto.enfileiradoOffline)
        #expect(reaberto.mensagemDeSucesso == TextosDoProfissional.Avaliacao.avaliadoOffline)
        reaberto.resposta = false
        #expect(reaberto.resposta == true)
        #expect(await reaberto.salvar() == false)
        #expect(try await fila.pendentes().count == 1)
        #expect(api.chamadasAvaliar.count == 1)
    }

    @Test("Reentrada com guard: chamadas simultâneas a salvar chamam a API apenas uma vez")
    @MainActor
    func reentradaComGuard() async throws {
        let api = ApiClienteAvaliacaoDuble()
        api.pausaAvaliar = 50_000_000 // 50ms
        let armazenamento = ArmazenamentoAvaliacoesEmMemoria()
        let turno = try criarTurno(fim: agora.addingTimeInterval(-3600))
        let vm = AvaliacaoTurnoViewModel(
            turnoID: turno.id,
            contaID: contaID,
            turno: turno,
            api: api,
            armazenamento: armazenamento,
            relogio: RelogioSimulado(agora)
        )

        vm.resposta = true
        async let primeira = vm.salvar()
        async let segunda = vm.salvar()

        let (r1, r2) = await (primeira, segunda)
        #expect((r1 && !r2) || (!r1 && r2))
        #expect(api.chamadasAvaliar.count == 1)
    }

    @Test("Reabrir mostra a resposta dada salva no armazenamento")
    @MainActor
    func reabrirMostraRespostaDada() async throws {
        let api = ApiClienteAvaliacaoDuble()
        let armazenamento = ArmazenamentoAvaliacoesEmMemoria()
        let turnoID = UUID()
        let primeira = AvaliacaoTurnoViewModel(turnoID: turnoID, contaID: contaID, api: api, armazenamento: armazenamento)
        primeira.resposta = false
        #expect(await primeira.salvar())

        let vm = AvaliacaoTurnoViewModel(
            turnoID: turnoID,
            contaID: contaID,
            api: api,
            armazenamento: armazenamento,
            relogio: RelogioSimulado(agora)
        )

        #expect(vm.resposta == false)
        #expect(vm.jaAvaliado == true)

        let salvou = await vm.salvar()
        #expect(salvou == false)
        #expect(api.chamadasAvaliar.count == 1)
    }

    @Test("Reabrir carrega resposta da fila de ações pendentes se não gravada no armazenamento")
    @MainActor
    func reabrirCarregaRespostaDaFilaPendente() async throws {
        let api = ApiClienteAvaliacaoDuble()
        let fila = FilaDeAcoesMemoria()
        let armazenamento = ArmazenamentoAvaliacoesEmMemoria()
        let turnoID = UUID()

        let acao = AcaoPendente(
            tipo: .avaliacao,
            turnoID: turnoID,
            contaID: contaID,
            instanteDoToque: agora,
            chave: UUID(),
            resposta: true
        )
        try await fila.enfileirar(acao)

        let vm = AvaliacaoTurnoViewModel(
            turnoID: turnoID,
            contaID: contaID,
            api: api,
            fila: fila,
            armazenamento: armazenamento,
            relogio: RelogioSimulado(agora)
        )

        await vm.carregar()

        #expect(vm.resposta == true)
        #expect(vm.jaAvaliado == true)
        #expect(vm.enfileiradoOffline == true)
        #expect(armazenamento.resposta(para: turnoID, contaID: contaID) == true)
    }

    @Test("Validação local: não permite avaliar antes do fim previsto ou sem presença verificada")
    @MainActor
    func validacaoAntesDoFimOuSemPresenca() async throws {
        let api = ApiClienteAvaliacaoDuble()
        let armazenamento = ArmazenamentoAvaliacoesEmMemoria()

        // Turno no futuro
        let turnoFuturo = try criarTurno(fim: agora.addingTimeInterval(3600), verificacao: .verificado)
        let vmFuturo = AvaliacaoTurnoViewModel(
            turnoID: turnoFuturo.id,
            contaID: contaID,
            turno: turnoFuturo,
            api: api,
            armazenamento: armazenamento,
            relogio: RelogioSimulado(agora)
        )
        vmFuturo.resposta = true
        let salvouFuturo = await vmFuturo.salvar()
        #expect(salvouFuturo == false)
        #expect(vmFuturo.mensagemDeErro == TextosDoProfissional.Avaliacao.erroIndisponivel)

        // Turno sem presença verificada
        let turnoSemPresenca = try criarTurno(fim: agora.addingTimeInterval(-3600), verificacao: .pendente)
        let vmSemPresenca = AvaliacaoTurnoViewModel(
            turnoID: turnoSemPresenca.id,
            contaID: contaID,
            turno: turnoSemPresenca,
            api: api,
            armazenamento: armazenamento,
            relogio: RelogioSimulado(agora)
        )
        vmSemPresenca.resposta = true
        let salvouSemPresenca = await vmSemPresenca.salvar()
        #expect(salvouSemPresenca == false)
        #expect(vmSemPresenca.mensagemDeErro == TextosDoProfissional.Avaliacao.erroIndisponivel)
        #expect(api.chamadasAvaliar.isEmpty)
    }

    @Test("MeuTurnoViewModel: podeAvaliar só é verdadeiro após fim previsto e com presença verificada")
    @MainActor
    func meuTurnoPodeAvaliar() async throws {
        let api = ApiClienteAvaliacaoDuble()
        let armazenamento = ArmazenamentoAvaliacoesEmMemoria()
        let relogio = RelogioSimulado(agora)

        // Antes do fim
        let turnoAntesDoFim = try criarTurno(fim: agora.addingTimeInterval(3600), verificacao: .verificado)
        let vm1 = MeuTurnoViewModel(turno: turnoAntesDoFim, api: api, contaID: contaID, armazenamentoAvaliacoes: armazenamento, relogio: relogio)
        #expect(vm1.podeAvaliar == false)

        // Depois do fim, mas presença pendente
        let turnoPendente = try criarTurno(fim: agora.addingTimeInterval(-3600), verificacao: .pendente)
        let vm2 = MeuTurnoViewModel(turno: turnoPendente, api: api, contaID: contaID, armazenamentoAvaliacoes: armazenamento, relogio: relogio)
        #expect(vm2.podeAvaliar == false)

        // Depois do fim, mas presença não verificada
        let turnoNaoVerificado = try criarTurno(fim: agora.addingTimeInterval(-3600), verificacao: .naoVerificado)
        let vm3 = MeuTurnoViewModel(turno: turnoNaoVerificado, api: api, contaID: contaID, armazenamentoAvaliacoes: armazenamento, relogio: relogio)
        #expect(vm3.podeAvaliar == false)

        // Depois do fim e verificado
        let turnoPronto = try criarTurno(fim: agora.addingTimeInterval(-3600), verificacao: .verificado)
        let vm4 = MeuTurnoViewModel(turno: turnoPronto, api: api, contaID: contaID, armazenamentoAvaliacoes: armazenamento, relogio: relogio)
        #expect(vm4.podeAvaliar == true)
        #expect(vm4.jaAvaliado == false)

        // Quando avaliado
        armazenamento.salvar(resposta: true, para: turnoPronto.id, contaID: contaID)
        #expect(vm4.respostaAvaliacao == true)
        #expect(vm4.jaAvaliado == true)
    }
    @Test("Segunda resposta é barrada, inclusive em modelo aberto antes do primeiro envio")
    @MainActor
    func segundaRespostaBarrada() async {
        let api = ApiClienteAvaliacaoDuble()
        let armazenamento = ArmazenamentoAvaliacoesEmMemoria()
        let turnoID = UUID()
        let primeira = AvaliacaoTurnoViewModel(turnoID: turnoID, contaID: contaID, api: api, armazenamento: armazenamento)
        let segunda = AvaliacaoTurnoViewModel(turnoID: turnoID, contaID: contaID, api: api, armazenamento: armazenamento)
        primeira.resposta = true
        #expect(await primeira.salvar())
        primeira.resposta = false
        #expect(primeira.resposta == true)
        #expect(await primeira.salvar() == false)
        segunda.resposta = false
        #expect(await segunda.salvar() == false)
        #expect(segunda.resposta == true)
        #expect(api.chamadasAvaliar.count == 1)
    }

    @Test("pode_avaliar falso sem cache bloqueia a escolha sem inventar resposta")
    @MainActor
    func jaRegistradaSemRespostaLocal() async throws {
        let api = ApiClienteAvaliacaoDuble()
        let turno = try criarTurno(fim: agora.addingTimeInterval(-3600), podeAvaliar: false)
        let armazenamento = ArmazenamentoAvaliacoesEmMemoria()
        let vm = AvaliacaoTurnoViewModel(turnoID: turno.id, contaID: contaID, turno: turno,
                                       api: api, armazenamento: armazenamento)
        await vm.carregar()
        #expect(vm.jaAvaliado)
        #expect(vm.resposta == nil)
        #expect(vm.mensagemDeErro == nil)
        vm.resposta = true
        #expect(vm.resposta == nil)
        #expect(await vm.salvar() == false)
        #expect(api.chamadasAvaliar.isEmpty)
        #expect(armazenamento.resposta(para: turno.id, contaID: contaID) == nil)
    }

    @Test("Outra conta não vê resposta confirmada nem pendente no mesmo turno")
    @MainActor
    func outraContaNaoVeResposta() async throws {
        let api = ApiClienteAvaliacaoDuble()
        let fila = FilaDeAcoesMemoria()
        let armazenamento = ArmazenamentoAvaliacoesEmMemoria()
        let turnoID = UUID()
        armazenamento.salvar(resposta: true, para: turnoID, contaID: contaID)
        try await fila.enfileirar(AcaoPendente(tipo: .avaliacao, turnoID: turnoID, contaID: contaID,
                                              instanteDoToque: agora, chave: UUID(), resposta: true))
        let outra = AvaliacaoTurnoViewModel(turnoID: turnoID, contaID: UUID(), api: api, fila: fila, armazenamento: armazenamento)
        await outra.carregar()
        #expect(outra.resposta == nil)
        #expect(!outra.jaAvaliado)
        #expect(!outra.enfileiradoOffline)
    }

    @Test("Fila persistida mantém só a primeira avaliação por conta e turno")
    func filaNaoDuplica() async throws {
        let fila = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
        let turnoID = UUID()
        let primeira = AcaoPendente(tipo: .avaliacao, turnoID: turnoID, contaID: contaID,
                                    instanteDoToque: agora, chave: UUID(), resposta: false)
        try await fila.enfileirar(primeira)
        try await fila.enfileirar(AcaoPendente(tipo: .avaliacao, turnoID: turnoID, contaID: contaID,
                                              instanteDoToque: agora, chave: UUID(), resposta: true))
        #expect(try await fila.pendentes() == [primeira])
    }

    @Test("409 no reenvio remove a pendente e reabre em estado neutro")
    @MainActor
    func conflitoNoReenvio() async throws {
        let api = ApiClienteAvaliacaoDuble()
        let autor = try await api.minhaConta().id
        api.erroAvaliar = ErroDaApi(codigo: .avaliacaoJaRegistrada)
        let fila = FilaDeAcoesMemoria()
        let armazenamento = ArmazenamentoAvaliacoesEmMemoria()
        let turnoID = UUID()
        armazenamento.salvar(resposta: false, para: turnoID, contaID: autor)
        try await fila.enfileirar(AcaoPendente(tipo: .avaliacao, turnoID: turnoID, contaID: autor,
                                              instanteDoToque: agora, chave: UUID(), resposta: false))
        await SincronizadorAcoes(fila: fila, api: api, avaliacaoJaRegistrada: { acao in
            armazenamento.registrarSemResposta(para: acao.turnoID!, contaID: acao.contaID!)
        }).sincronizar()
        #expect(try await fila.pendentes().isEmpty)
        let reaberto = AvaliacaoTurnoViewModel(turnoID: turnoID, contaID: autor, api: api,
                                             fila: fila, armazenamento: armazenamento)
        await reaberto.carregar()
        #expect(reaberto.jaAvaliado)
        #expect(reaberto.resposta == nil)
        #expect(!reaberto.enfileiradoOffline)
        #expect(reaberto.mensagemDeSucesso == nil)
    }

    @Test("Reenvio não manda a avaliação pendente de outra conta")
    func reenvioRespeitaAutor() async throws {
        let api = ApiClienteAvaliacaoDuble()
        let fila = FilaDeAcoesMemoria()
        try await fila.enfileirar(AcaoPendente(tipo: .avaliacao, turnoID: UUID(), contaID: UUID(),
                                              instanteDoToque: agora, chave: UUID(), resposta: true))
        try await fila.enfileirar(AcaoPendente(tipo: .avaliacao, turnoID: UUID(),
                                              instanteDoToque: agora, chave: UUID(), resposta: false))
        await SincronizadorAcoes(fila: fila, api: api).sincronizar()
        #expect(api.chamadasAvaliar.isEmpty)
        #expect(try await fila.pendentes().count == 2)
    }

}
