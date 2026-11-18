import Foundation
import FrilaDados
import FrilaDominio
@testable import FrilaApresentacao
import Testing

@Suite("R2: cartão de vaga do feed")
struct CartaoDeVagaDoFeedTests {
    /// Uma vaga sintética a `dias` dias de `agora`, no modo pedido.
    private func amostra(base: VagaNaLista, dias: Int, modo: ModoPreenchimento, agora: Date) throws -> VagaNaLista {
        let inicio = agora.addingTimeInterval(Double(dias) * 24 * 3600)
        return VagaNaLista(
            id: UUID(), funcao: base.funcao, estabelecimento: base.estabelecimento,
            periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(4 * 3600)),
            local: base.local, regiaoAdministrativa: base.regiaoAdministrativa, distanciaKm: base.distanciaKm,
            valor: base.valor, posicoesAbertas: 2, inclusos: base.inclusos, modo: modo
        )
    }

    @Test("O destaque é a primeira vaga de aceite direto da lista; sem nenhuma, não há destaque")
    @MainActor
    func destaqueEAPrimeiraDeAceiteDireto() async throws {
        let api = ApiClienteEmMemoria()
        let base = try #require(try await api.vagasAbertas(.todas).first)
        let agora = Date.now
        let selecao = try amostra(base: base, dias: 5, modo: .selecao, agora: agora)
        let primeiraUrgente = try amostra(base: base, dias: 5, modo: .urgencia, agora: agora)
        let segundaUrgente = try amostra(base: base, dias: 6, modo: .urgencia, agora: agora)

        let destaque = CartaoDeVagaDoFeed.destaque(em: [selecao, primeiraUrgente, segundaUrgente], agora: agora)
        #expect(destaque == primeiraUrgente.id)

        let semUrgencia = CartaoDeVagaDoFeed.destaque(em: [selecao, try amostra(base: base, dias: 7, modo: .selecao, agora: agora)], agora: agora)
        #expect(semUrgencia == nil)
        #expect(CartaoDeVagaDoFeed.destaque(em: [], agora: agora) == nil)
    }
}
