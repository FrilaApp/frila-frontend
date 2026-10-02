import Foundation
import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

@Suite("Avaliações por conta no aparelho (#22)")
struct ArmazenamentoAvaliacoesTests {
    @Test("Duas contas no mesmo turno têm respostas independentes e sobrevivem à reabertura")
    func respostasPorTurnoEConta() throws {
        let suite = "avaliacoes-tests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let turnoID = UUID()
        let outraConta = UUID()
        let contaID = UUID()
        let armazenamento = UserDefaultsArmazenamentoAvaliacoes(defaults: defaults)
        armazenamento.salvar(resposta: false, para: turnoID, contaID: contaID)
        #expect(armazenamento.resposta(para: turnoID, contaID: outraConta) == nil)
        armazenamento.salvar(resposta: true, para: turnoID, contaID: outraConta)

        let reaberto = UserDefaultsArmazenamentoAvaliacoes(defaults: try #require(UserDefaults(suiteName: suite)))
        #expect(reaberto.resposta(para: turnoID, contaID: contaID) == false)
        #expect(reaberto.resposta(para: turnoID, contaID: outraConta) == true)
        #expect(reaberto.resposta(para: UUID(), contaID: contaID) == nil)
    }

    @Test("Chaves legadas sem autor não são atribuídas à conta atual")
    func ignoraChaveSemAutor() throws {
        let suite = "avaliacoes-tests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let turnoID = UUID()
        defaults.set(true, forKey: "frila_avaliacao_" + turnoID.uuidString)
        #expect(UserDefaultsArmazenamentoAvaliacoes(defaults: defaults).resposta(para: turnoID, contaID: UUID()) == nil)
    }

    @Test("Saída da conta remove respostas, inclusive legadas, e a fila de avaliação")
    func saidaRemoveAvaliacoes() async throws {
        let suite = "avaliacoes-tests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let armazenamento = UserDefaultsArmazenamentoAvaliacoes(defaults: defaults)
        let turnoID = UUID()
        let contaID = UUID()
        armazenamento.salvar(resposta: true, para: turnoID, contaID: contaID)
        defaults.set(false, forKey: "frila_avaliacao_" + turnoID.uuidString)
        defaults.set(true, forKey: "preferencia-alheia")
        let cache = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
        try await cache.salvar(sessao: SessaoUsuario(usuarioID: contaID, perfil: .profissional))
        try await cache.enfileirar(AcaoPendente(tipo: .avaliacao, turnoID: turnoID, contaID: contaID,
                                               instanteDoToque: .now, chave: UUID(), resposta: true))
        await SaidaDaConta(api: ApiClienteEmMemoria(), armazenamento: cache,
                          limparAvaliacoes: { armazenamento.limpar() }).sair(tokenFCM: nil)
        #expect(armazenamento.resposta(para: turnoID, contaID: contaID) == nil)
        #expect(armazenamento.resposta(para: turnoID, contaID: UUID()) == nil)
        #expect(defaults.object(forKey: "frila_avaliacao_" + turnoID.uuidString) == nil)
        #expect(defaults.bool(forKey: "preferencia-alheia"))
        #expect(try await cache.sessao() == nil)
        #expect(try await cache.pendentes().isEmpty)
    }

    @Test("Encerramento involuntário também remove avaliações locais")
    func encerramentoRemoveAvaliacoes() async {
        let armazenamento = ArmazenamentoAvaliacoesEmMemoria()
        let contaID = UUID()
        let turnoID = UUID()
        armazenamento.salvar(resposta: false, para: turnoID, contaID: contaID)
        let (eventos, continuacao) = AsyncStream<Void>.makeStream()
        continuacao.yield()
        continuacao.finish()
        let saida = SaidaDaConta(api: ApiClienteEmMemoria(), armazenamento: nil,
                                limparAvaliacoes: { armazenamento.limpar() })
        await saida.acompanharEncerramentos(de: Observador(eventos: eventos))
        #expect(armazenamento.resposta(para: turnoID, contaID: contaID) == nil)
    }

    @Test("ID online vem da conta autenticada e é guardado na sessão local")
    func identidadeOnline() async throws {
        let api = ApiClienteEmMemoria()
        let conta = try await api.minhaConta()
        let cache = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
        #expect(try await IdentidadeDaAvaliacao.obter(api: api, cache: cache) == conta.id)
        #expect(try await cache.sessao()?.usuarioID == conta.id)
    }

    @Test("Offline usa a sessão local; nova entrada não reutiliza o ID da conta anterior")
    func identidadeOfflineENovaEntrada() async throws {
        let contaID = UUID()
        let api = ApiClienteEmMemoria(cenario: .semRede)
        let cache = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
        try await cache.salvar(sessao: SessaoUsuario(usuarioID: contaID, perfil: .profissional))
        #expect(try await IdentidadeDaAvaliacao.obter(api: api, cache: cache) == contaID)
        await #expect(throws: ErroDaApi(codigo: .semRede)) {
            _ = try await IdentidadeDaAvaliacao.obter(api: api, cache: cache, permitirCache: false)
        }
        #expect(try await cache.sessao() == nil)
        await #expect(throws: ErroDaApi(codigo: .semRede)) {
            _ = try await IdentidadeDaAvaliacao.obter(api: api, cache: cache)
        }
    }
    @Test("Registro sem resposta persiste sem virar Sim ou Não")
    func registroNeutroPersistido() throws {
        let suite = "avaliacoes-tests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let turnoID = UUID()
        let contaID = UUID()
        let armazenamento = UserDefaultsArmazenamentoAvaliacoes(defaults: defaults)
        armazenamento.salvar(resposta: false, para: turnoID, contaID: contaID)
        armazenamento.registrarSemResposta(para: turnoID, contaID: contaID)
        let reaberto = UserDefaultsArmazenamentoAvaliacoes(defaults: try #require(UserDefaults(suiteName: suite)))
        #expect(reaberto.jaRegistrada(para: turnoID, contaID: contaID))
        #expect(reaberto.resposta(para: turnoID, contaID: contaID) == nil)
        #expect(!reaberto.jaRegistrada(para: turnoID, contaID: UUID()))
    }

}

private struct Observador: ObservadorDeSessao {
    let eventos: AsyncStream<Void>
    func encerramentos() -> AsyncStream<Void> { eventos }
}
