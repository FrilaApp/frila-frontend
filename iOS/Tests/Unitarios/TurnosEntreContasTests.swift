import Foundation
@testable import FrilaDados
import FrilaDominio
import Testing

/// Achado do Lince Codex (18/11/2026): uma leitura de turnos da conta A, ainda em voo na hora de sair, chegava
/// DEPOIS das limpezas da saída e da entrada da conta B e repovoava o cache. Sem rede, B recebia o turno de A.
/// Estes testes usam o `TurnosComCache` e o `ArmazenamentoSwiftData` reais, com o banco em memória.

private struct RelogioParado: Relogio {
    let agora: Date
}

/// A "rede" que o teste segura: a busca só termina quando o teste manda.
private actor RespostaSegurada {
    private var resposta: CheckedContinuation<[Turno], Never>?
    private var esperandoOInicio: [CheckedContinuation<Void, Never>] = []

    func buscar() async -> [Turno] {
        await withCheckedContinuation { continuacao in
            resposta = continuacao
            esperandoOInicio.forEach { $0.resume() }
            esperandoOInicio.removeAll()
        }
    }

    func aguardarInicio() async {
        if resposta != nil { return }
        await withCheckedContinuation { esperandoOInicio.append($0) }
    }

    func concluir(_ turnos: [Turno]) {
        resposta?.resume(returning: turnos)
        resposta = nil
    }
}

private func armazenamentoEmMemoria() throws -> ArmazenamentoSwiftData {
    ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
}

private func turnoSintetico(da casa: String, inicio: Date) throws -> Turno {
    let fim = inicio.addingTimeInterval(3 * 3_600)
    let vaga = VagaResumo(
        id: UUID(), funcao: "Garçom", local: "Local sintético", regiaoAdministrativa: "Plano Piloto",
        periodo: try Periodo(inicio: inicio, fim: fim), valor: Dinheiro(centavos: 15000)
    )
    let reputacao = Reputacao(positivas: 0, total: 0, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0)
    return Turno(
        id: UUID(), posicaoID: UUID(), vaga: vaga,
        contraparte: PerfilPublico(id: UUID(), tipo: .estabelecimento, nome: casa, reputacao: reputacao),
        contatoVisivelAte: fim.addingTimeInterval(7 * 24 * 3_600), verificacao: .pendente, valorAcordado: vaga.valor,
        podeAvaliar: false, contato: nil
    )
}

@Suite("Turnos entre contas: a resposta antiga não repovoa o cache depois da troca de conta", .timeLimit(.minutes(1)))
struct TurnosEntreContasTests {
    private let agora = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("A resposta de turnos da conta A que chega depois da saída e da entrada de B não vai para o cache: B sem rede não recebe o turno de A",
          arguments: [false, true])
    func respostaDeAEmVooNaoRepovoaOCacheDeB(tarefaCancelada: Bool) async throws {
        let cache = try armazenamentoEmMemoria()
        let contaA = UUID()
        let contaB = UUID()
        let turnoDeA = try turnoSintetico(da: "Casa sintética A", inicio: agora)
        try await cache.salvar(sessao: SessaoUsuario(usuarioID: contaA, perfil: .profissional))

        // A começa a ler os turnos e a resposta fica em voo.
        let rede = RespostaSegurada()
        let repositorioDeA = TurnosComCache(buscar: { await rede.buscar() }, cache: cache, relogio: RelogioParado(agora: agora))
        let leituraDeA = Task { try await repositorioDeA.ler() }
        await rede.aguardarInicio()
        if tarefaCancelada { leituraDeA.cancel() }

        // As mesmas operações do banco que a saída de A e a entrada de B fazem: limpezas e a sessão de B.
        try await cache.limpar()
        try await cache.limpar()
        try await cache.salvar(sessao: SessaoUsuario(usuarioID: contaB, perfil: .profissional))
        #expect(try await cache.turnosValidos(em: agora).isEmpty, "depois das limpezas o cache está vazio")

        // Só agora a resposta de A chega.
        await rede.concluir([turnoDeA])
        let recebidoPorA = try await leituraDeA.value
        #expect(recebidoPorA.origem == .rede)

        // B abre os turnos sem rede.
        let repositorioDeB = TurnosComCache(
            buscar: { throw ErroDaApi(codigo: .semRede) }, cache: cache, relogio: RelogioParado(agora: agora)
        )
        let leituraDeB = try await repositorioDeB.ler()

        #expect(leituraDeB.origem == .cache)
        #expect(leituraDeB.turnos.isEmpty, "B não pode receber o turno de A")
        #expect(try await cache.turnosValidos(em: agora).isEmpty, "a resposta antiga não entrou no cache")
        #expect(try await cache.sessao()?.usuarioID == contaB, "a sessão de B continua guardada")
    }

    @Test("A época do cache muda a cada limpeza, e a gravação com a época antiga é recusada sem guardar nada")
    func gravacaoComEpocaAntigaERecusada() async throws {
        let cache = try armazenamentoEmMemoria()
        let turno = try turnoSintetico(da: "Casa sintética A", inicio: agora)
        let antes = await cache.epoca()

        try await cache.limpar()
        let depois = await cache.epoca()
        #expect(depois != antes)

        let gravouComAAntiga = try await cache.salvar(turnos: [turno], em: agora, seAindaNaEpoca: antes)
        #expect(!gravouComAAntiga)
        #expect(try await cache.turnosValidos(em: agora).isEmpty)

        let gravouComAAtual = try await cache.salvar(turnos: [turno], em: agora, seAindaNaEpoca: depois)
        #expect(gravouComAAtual)
        #expect(try await cache.turnosValidos(em: agora) == [turno])
    }

    @Test("A leitura que começa depois da limpeza continua guardando: B com rede e depois sem rede vê os próprios turnos")
    func leituraDepoisDaLimpezaGuardaNormalmente() async throws {
        let cache = try armazenamentoEmMemoria()
        let turnoDeB = try turnoSintetico(da: "Casa sintética B", inicio: agora)
        try await cache.limpar()
        try await cache.salvar(sessao: SessaoUsuario(usuarioID: UUID(), perfil: .profissional))

        let comRede = TurnosComCache(buscar: { [turnoDeB] }, cache: cache, relogio: RelogioParado(agora: agora))
        #expect(try await comRede.ler().origem == .rede)

        let semRede = TurnosComCache(buscar: { throw ErroDaApi(codigo: .semRede) }, cache: cache, relogio: RelogioParado(agora: agora))
        let leitura = try await semRede.ler()
        #expect(leitura.origem == .cache)
        #expect(leitura.turnos == [turnoDeB])
    }
}
