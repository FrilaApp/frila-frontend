import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

private func instante(_ horas: Double = 0) -> Date {
    Date(timeIntervalSince1970: 1_800_000_000 + horas * 3_600)
}

private func turno(inicio: Date, fim: Date, local: String = "Bar da Quadra, CLN 203") throws -> Turno {
    let vaga = VagaResumo(id: UUID(), funcao: "Garçom", local: local, regiaoAdministrativa: "Plano Piloto", periodo: try Periodo(inicio: inicio, fim: fim), valor: Dinheiro(centavos: 15000))
    let reputacao = Reputacao(positivas: 10, total: 10, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0)
    return Turno(
        id: UUID(), posicaoID: UUID(), vaga: vaga,
        contraparte: PerfilPublico(id: UUID(), tipo: .estabelecimento, nome: "Bar da Quadra", reputacao: reputacao),
        contatoVisivelAte: fim.addingTimeInterval(7 * 24 * 3_600), verificacao: .pendente, valorAcordado: vaga.valor, podeAvaliar: false
    )
}

private struct RelogioFixo: Relogio {
    let agora: Date
}

/// Falha o teste se a tela chamar `contato_do_turno`: o contato ficou fora do app.
private final class ApiSemContato: ApiClienteEncaminhador, @unchecked Sendable {
    override func contatoDoTurno(id: UUID) async throws -> Contato {
        Issue.record("contato_do_turno não deve ser chamado")
        throw ErroDaApi(codigo: .desconhecido)
    }
}

/// O "Como chegar" de Meu turno (contato fora do app, Fase 1): o atalho do mapa usa o endereço da
/// vaga, e nenhuma carga da tela pede o contato.
@MainActor
@Suite("Meu turno: Como chegar, sem contato")
struct ComoChegarNaTelaTests {
    private let agora = instante()

    @Test("O atalho do mapa abre o Apple Maps com o endereço do turno na busca")
    func atalhoDoMapa() async throws {
        let turno = try turno(inicio: instante(1), fim: instante(5), local: "CLN 203, Asa Norte")
        let modelo = MeuTurnoViewModel(turno: turno, api: ApiSemContato(), relogio: RelogioFixo(agora: agora))

        let url = try #require(modelo.urlMapas)
        let componentes = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(componentes.scheme == "https")
        #expect(componentes.host == "maps.apple.com")
        #expect(componentes.queryItems?.first { $0.name == "q" }?.value == "CLN 203, Asa Norte")
    }

    @Test("Carregar a tela, com ou sem rede, nunca pede o contato do turno")
    func carregarNaoPedeContato() async throws {
        let turno = try turno(inicio: instante(-6), fim: instante(-2))
        let modelo = MeuTurnoViewModel(turno: turno, api: ApiSemContato(), relogio: RelogioFixo(agora: agora))

        await modelo.carregar()

        #expect(modelo.detalheCarregado)
        #expect(modelo.quemRecebeExibicao.isEmpty == false)
    }
}
