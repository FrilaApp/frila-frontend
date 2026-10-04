import Foundation
@testable import FrilaDados
import FrilaDominio
import Testing

/// Cache que o teste controla: guarda em memória e, se mandado, recusa gravar.
private final class CacheDeTeste: CacheLocal, @unchecked Sendable {
    private let trava = NSLock()
    private var guardados: [Turno] = []
    var recusaGravar = false
    private(set) var gravacoes = 0

    func salvar(sessao: SessaoUsuario) async throws {}
    func sessao() async throws -> SessaoUsuario? { nil }
    func salvar(contato: Contato, doTurno turnoID: UUID) async throws {}
    func contato(doTurno turnoID: UUID, em instante: Date) async throws -> Contato? { nil }
    func removerContato(doTurno turnoID: UUID) async throws {}
    func salvar(funcoes: [Funcao]) async throws {}
    func funcoes() async throws -> [Funcao] { [] }
    func limpar() async throws { trava.withLock { guardados = [] } }

    func salvar(turnos: [Turno], em instante: Date) async throws {
        struct GravacaoRecusada: Error {}
        if recusaGravar { throw GravacaoRecusada() }
        trava.withLock { guardados = turnos; gravacoes += 1 }
    }

    func turnosValidos(em instante: Date) async throws -> [Turno] {
        trava.withLock { guardados }
    }
}

private struct RelogioFixo: Relogio {
    let agora: Date
}

private func turno(fim: Date) throws -> Turno {
    let vaga = VagaResumo(
        id: UUID(), funcao: "Garçom", local: "Asa Sul", regiaoAdministrativa: "Plano Piloto",
        periodo: try Periodo(inicio: fim.addingTimeInterval(-4 * 3_600), fim: fim), valor: Dinheiro(centavos: 15000)
    )
    let reputacao = Reputacao(positivas: 0, total: 0, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0)
    return Turno(
        id: UUID(), posicaoID: UUID(), vaga: vaga,
        contraparte: PerfilPublico(id: UUID(), tipo: .estabelecimento, nome: "Bistrô", reputacao: reputacao),
        contatoVisivelAte: fim.addingTimeInterval(7 * 24 * 3_600), verificacao: .pendente, valorAcordado: vaga.valor,
        podeAvaliar: false, contato: nil
    )
}

/// O que `OfflineTests` não exercita: a porta `TurnoRepositorio` (`meusTurnos`), o cache que
/// recusa gravar e o cache vazio sem rede.
@Suite("Meus turnos com cache: a porta do repositório e as bordas do cache (RNF06)")
struct TurnosComCacheTests {
    private let agora = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("meusTurnos, pela porta TurnoRepositorio, devolve os turnos da rede e os guarda no cache")
    func meusTurnosComRede() async throws {
        let esperado = try turno(fim: agora.addingTimeInterval(3 * 3_600))
        let cache = CacheDeTeste()
        let repositorio: any TurnoRepositorio = TurnosComCache(buscar: { [esperado] }, cache: cache, relogio: RelogioFixo(agora: agora))

        let turnos = try await repositorio.meusTurnos()

        #expect(turnos == [esperado])
        #expect(cache.gravacoes == 1)
        #expect(try await cache.turnosValidos(em: agora) == [esperado])
    }

    @Test("meusTurnos sem rede devolve o que está no cache")
    func meusTurnosSemRede() async throws {
        let guardado = try turno(fim: agora.addingTimeInterval(3 * 3_600))
        let cache = CacheDeTeste()
        try await cache.salvar(turnos: [guardado], em: agora)
        let repositorio: any TurnoRepositorio = TurnosComCache(
            buscar: { throw ErroDaApi(codigo: .semRede) }, cache: cache, relogio: RelogioFixo(agora: agora)
        )

        #expect(try await repositorio.meusTurnos() == [guardado])
    }

    @Test("Cache que recusa gravar não atrapalha: a pessoa vê o que veio da rede")
    func cacheQueRecusaGravar() async throws {
        let esperado = try turno(fim: agora.addingTimeInterval(3 * 3_600))
        let cache = CacheDeTeste()
        cache.recusaGravar = true
        let repositorio = TurnosComCache(buscar: { [esperado] }, cache: cache, relogio: RelogioFixo(agora: agora))

        let leitura = try await repositorio.ler()

        #expect(leitura.origem == .rede)
        #expect(leitura.turnos == [esperado])
        #expect(cache.gravacoes == 0)
    }

    @Test("Sem rede e sem nada guardado, a lista vem vazia do cache, e não como erro")
    func semRedeESemCache() async throws {
        let repositorio = TurnosComCache(
            buscar: { throw ErroDaApi(codigo: .semRede) }, cache: CacheDeTeste(), relogio: RelogioFixo(agora: agora)
        )

        let leitura = try await repositorio.ler()

        #expect(leitura.origem == .cache)
        #expect(leitura.turnos.isEmpty)
    }
}
