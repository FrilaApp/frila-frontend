import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

private final class Relogio: @unchecked Sendable {
    private let trava = NSLock()
    private var _agora = Date(timeIntervalSince1970: 1_000_000)
    var agora: Date { trava.withLock { _agora } }
    func avancar(_ s: TimeInterval) { trava.withLock { _agora += s } }
}

private actor Pedidos {
    private(set) var total = 0
    func contar() { total += 1 }
}

/// A resposta continua retida mesmo se a tarefa for cancelada, como uma resposta já recebida.
private actor DetalheRetido {
    let chegada: AsyncStream<Void>
    private let avisar: AsyncStream<Void>.Continuation
    private var resposta: CheckedContinuation<Vaga, any Error>?
    private(set) var cancelado = false

    init() { (chegada, avisar) = AsyncStream<Void>.makeStream() }

    func buscar() async throws -> Vaga {
        let vaga: Vaga = try await withCheckedThrowingContinuation { resposta in
            self.resposta = resposta
            avisar.yield()
        }
        cancelado = Task.isCancelled
        return vaga
    }

    func responder(_ resultado: Result<Vaga, any Error>) {
        resposta?.resume(with: resultado)
        resposta = nil
    }
}

private func umaVaga() async throws -> Vaga {
    let api = ApiClienteEmMemoria()
    let primeira = try #require(try await api.vagasAbertas(.todas).first)
    return try await api.detalheDaVaga(id: primeira.id)
}

@Suite("Cache das leituras de rede")
struct CacheDeLeiturasTests {
    @Test("Dentro da validade, o detalhe vem do cache; passada a validade, busca de novo")
    func validade() async throws {
        let relogio = Relogio()
        let cache = CacheDeLeituras(agora: { relogio.agora })
        let vaga = try await umaVaga()
        let pedidos = Pedidos()
        let buscar: @Sendable () async throws -> Vaga = { await pedidos.contar(); return vaga }

        _ = try await cache.detalhe(id: vaga.id, buscar: buscar)
        _ = try await cache.detalhe(id: vaga.id, buscar: buscar)
        #expect(await pedidos.total == 1)

        relogio.avancar(CacheDeLeituras.validade + 1)
        _ = try await cache.detalhe(id: vaga.id, buscar: buscar)
        #expect(await pedidos.total == 2)
        #expect(cache.detalheGuardado(id: vaga.id)?.id == vaga.id)
    }

    @Test("Pedidos iguais ao mesmo tempo viram um só")
    func juntaEmVoo() async throws {
        let cache = CacheDeLeituras()
        let vaga = try await umaVaga()
        let pedidos = Pedidos()
        let buscar: @Sendable () async throws -> Vaga = {
            await pedidos.contar()
            try await Task.sleep(for: .milliseconds(150))
            return vaga
        }
        async let a = cache.detalheAtual(id: vaga.id, buscar: buscar)
        async let b = cache.detalheAtual(id: vaga.id, buscar: buscar)
        _ = try await (a, b)
        #expect(await pedidos.total == 1)
    }

    @Test("detalheAtual sempre vai à rede, mesmo com o detalhe guardado")
    func atualIgnoraGuardado() async throws {
        let cache = CacheDeLeituras()
        let vaga = try await umaVaga()
        let pedidos = Pedidos()
        let buscar: @Sendable () async throws -> Vaga = { await pedidos.contar(); return vaga }
        _ = try await cache.detalhe(id: vaga.id, buscar: buscar)
        _ = try await cache.detalheAtual(id: vaga.id, buscar: buscar)
        #expect(await pedidos.total == 2)
    }

    @Test("Limpar esquece detalhes e listas")
    func limpar() async throws {
        let cache = CacheDeLeituras()
        let vaga = try await umaVaga()
        let lista = try await ApiClienteEmMemoria().vagasAbertas(.todas)
        _ = try await cache.detalhe(id: vaga.id) { vaga }
        cache.guardar(lista: lista, chave: "x", epoca: cache.epoca)
        cache.limpar()
        #expect(cache.detalheGuardado(id: vaga.id) == nil)
        #expect(cache.lista(chave: "x") == nil)
    }

    @Test("Resposta antiga após limpar não grava nem remove a tarefa da nova época", arguments: [false, true])
    func respostaDeOutraEpoca(falhaAntiga: Bool) async throws {
        let cache = CacheDeLeituras()
        let vaga = try await umaVaga()
        let antiga = DetalheRetido()
        let nova = DetalheRetido()
        let epoca = cache.epoca
        let pedidoAntigo = Task { try await cache.detalhe(id: vaga.id) { try await antiga.buscar() } }
        for await _ in antiga.chegada { break }

        cache.limpar()
        #expect(cache.epoca == epoca + 1)
        let pedidoNovo = Task { try await cache.detalhe(id: vaga.id) { try await nova.buscar() } }
        for await _ in nova.chegada { break }
        await antiga.responder(falhaAntiga ? .failure(ErroDaApi(codigo: .semRede)) : .success(vaga))
        _ = try? await pedidoAntigo.value
        #expect(cache.detalheGuardado(id: vaga.id) == nil)

        // Se a conclusão antiga apagou o pedido novo, esta limpeza não conseguirá cancelá-lo.
        cache.limpar()
        await nova.responder(.success(vaga))
        _ = try await pedidoNovo.value
        #expect(await nova.cancelado)
        #expect(cache.detalheGuardado(id: vaga.id) == nil)
    }

    @Test("Uma lista da época anterior não substitui a lista da conta atual")
    func listaDeOutraEpoca() async throws {
        let cache = CacheDeLeituras()
        let lista = try await ApiClienteEmMemoria().vagasAbertas(.todas)
        let epocaAntiga = cache.epoca
        cache.limpar()
        cache.guardar(lista: [], chave: "x", epoca: cache.epoca)
        cache.guardar(lista: lista, chave: "x", epoca: epocaAntiga)
        #expect(cache.lista(chave: "x") == [])
    }

    @Test("A sessão de rede do app tem prazo próprio: 15 s por pedido, 60 s no total")
    func prazoDaSessao() {
        let s = SupabaseApiCliente.sessaoComPrazo()
        #expect(s.configuration.timeoutIntervalForRequest == 15)
        #expect(s.configuration.timeoutIntervalForResource == 60)
        #expect(s.configuration.waitsForConnectivity == false)
    }

    @MainActor
    @Test("Feed: mostra a lista guardada e, sem rede, mantém a guardada em vez de falhar")
    func feedMantemGuardada() async throws {
        let cache = CacheDeLeituras()
        let vagas = try await ApiClienteEmMemoria().vagasAbertas(.todas)
        let falhar = Pedidos()
        let vm = FeedVagasViewModel(
            buscarVagas: { _ in
                await falhar.contar()
                if await falhar.total > 1 { throw ErroDaApi(codigo: .semRede) }
                return vagas
            },
            buscarFuncoes: { [] },
            cache: cache
        )
        await vm.carregar()
        #expect(vm.estado == .carregada(vagas))

        let outro = FeedVagasViewModel(
            buscarVagas: { _ in throw ErroDaApi(codigo: .semRede) },
            buscarFuncoes: { [] },
            cache: cache
        )
        await outro.carregar()
        #expect(outro.estado == .carregada(vagas))
    }
}
