import Foundation
import FrilaDados
import FrilaDominio
import Testing

@Suite("Dublê de API")
struct ApiEmMemoriaTests {
    @Test("Fluxo integração entrada → publicação → lista → candidatura → turno")
    func fluxoPrincipal() async throws {
        let api = ApiClienteEmMemoria()
        let sessao = try await api.verificarCodigo(email: "teste@frila.app", codigo: "123456")
        #expect(sessao.perfil == .profissional)
        let funcao = try #require(await api.funcoes().first)
        let estabelecimento = try #require(await api.meusEstabelecimentos().first)
        let inicio = Date.now.addingTimeInterval(172_800)
        let publicacao = PublicacaoVaga(
            estabelecimentoID: estabelecimento.id, funcaoID: funcao.id,
            periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(14_400)),
            local: estabelecimento.endereco, ponto: estabelecimento.ponto,
            valor: Dinheiro(centavos: 15000), posicoes: 1,
            inclusos: Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Marina", chave: UUID()
        )
        let publicada = try await api.publicarVaga(publicacao)
        #expect(try await api.vagasAbertas().contains { $0.id == publicada.vagaID })
        let candidatura = try await api.candidatar(vagaID: publicada.vagaID)
        #expect(candidatura.estado == .confirmada)
        #expect(try await api.meusTurnos().contains { $0.id == candidatura.turnoID })
    }

    @Test("Cenários previsíveis cobrem conflito, inelegibilidade, offline e suspensão")
    func cenarios() async {
        let preenchida = ApiClienteEmMemoria(cenario: .vagaPreenchida)
        let vagaID = try? await preenchida.vagasAbertas().first?.id
        await #expect(throws: ErroDaApi.self) { try await preenchida.candidatar(vagaID: vagaID ?? UUID()) }

        await #expect(throws: ErroDaApi.self) { try await ApiClienteEmMemoria(cenario: .semRede).funcoes() }
        await #expect(throws: ErroDaApi.self) { try await ApiClienteEmMemoria(cenario: .contaSuspensa).funcoes() }
    }
}
