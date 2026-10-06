import Foundation
import FrilaDados
import FrilaDominio
import Testing

/// O dublê segue `equipe_de_confianca`, `incluir_na_equipe` e `remover_da_equipe`
/// (`20260929210000_equipe_de_confianca.sql`).
@Suite("Dublê: equipe de confiança (#24)")
struct EquipeEmMemoriaTests {
    private let profissional = UUID(uuidString: "80000000-0000-0000-0000-000000000001")!

    /// A casa da conta de contratante do cenário, e o par com o profissional das fixtures.
    private func casa(_ api: ApiClienteEmMemoria) async throws -> (id: UUID, membro: MembroDaEquipe) {
        let casa = try #require(try await api.meusEstabelecimentos().first)
        return (casa.id, MembroDaEquipe(estabelecimentoID: casa.id, profissionalID: profissional))
    }

    @Test("A equipe da casa do contratante começa vazia; com o profissional do turno verificado, incluir o põe nela")
    func incluir() async throws {
        let api = ApiClienteEmMemoria(cenario: .painelContratante)
        let (casaID, membro) = try await casa(api)
        #expect(try await api.equipeDeConfianca(estabelecimentoID: casaID).isEmpty)

        #expect(try await api.incluirNaEquipe(membro) == membro)

        let equipe = try await api.equipeDeConfianca(estabelecimentoID: casaID)
        #expect(equipe.map(\.id) == [profissional])
        #expect(equipe.first?.nome == "Ana Cunha")
        // Idempotente.
        #expect(try await api.incluirNaEquipe(membro) == membro)
        #expect(try await api.equipeDeConfianca(estabelecimentoID: casaID).count == 1)
    }

    @Test("Sem turno com presença verificada na casa, incluir é sem_permissao com sem_turno_cumprido")
    func semTurnoCumprido() async throws {
        // O turno de `checkinManualPendente` ainda não foi verificado; em `contratante` não há turno.
        for cenario in [ApiClienteEmMemoria.Cenario.checkinManualPendente, .contratante] {
            let api = ApiClienteEmMemoria(cenario: cenario)
            let (casaID, membro) = try await casa(api)
            await #expect(throws: ErroDaApi(codigo: .semPermissao, detalhes: "sem_turno_cumprido")) { try await api.incluirNaEquipe(membro) }
            #expect(try await api.equipeDeConfianca(estabelecimentoID: casaID).isEmpty)
        }
    }

    @Test("O cenário com membro já lista o profissional, e remover o tira sem erro; remover de novo é idempotente")
    func remover() async throws {
        let api = ApiClienteEmMemoria(cenario: .equipeDeConfiancaComMembro)
        let (casaID, membro) = try await casa(api)
        #expect(try await api.equipeDeConfianca(estabelecimentoID: casaID).map(\.id) == [profissional])

        #expect(try await api.removerDaEquipe(membro) == membro)
        #expect(try await api.equipeDeConfianca(estabelecimentoID: casaID).isEmpty)
        #expect(try await api.removerDaEquipe(membro) == membro)
    }

    @Test("Profissional que a casa não conhece é nao_encontrado")
    func profissionalDesconhecido() async throws {
        let api = ApiClienteEmMemoria(cenario: .painelContratante)
        let (casaID, _) = try await casa(api)
        let desconhecido = MembroDaEquipe(estabelecimentoID: casaID, profissionalID: UUID())
        await #expect(throws: ErroDaApi(codigo: .naoEncontrado)) { try await api.incluirNaEquipe(desconhecido) }
    }

    @Test("Casa que não é da conta é sem_permissao nas três operações")
    func outraCasa() async throws {
        let api = ApiClienteEmMemoria(cenario: .painelContratante)
        let outra = MembroDaEquipe(estabelecimentoID: UUID(), profissionalID: profissional)
        await #expect(throws: ErroDaApi(codigo: .semPermissao)) { try await api.equipeDeConfianca(estabelecimentoID: outra.estabelecimentoID) }
        await #expect(throws: ErroDaApi(codigo: .semPermissao)) { try await api.incluirNaEquipe(outra) }
        await #expect(throws: ErroDaApi(codigo: .semPermissao)) { try await api.removerDaEquipe(outra) }
    }

    @Test("Conta de profissional lê a própria equipe pela casa das fixtures, mas incluir e remover são perfil_incompativel")
    func contaDeProfissional() async throws {
        let api = ApiClienteEmMemoria()
        let (casaID, membro) = try await casa(api)
        #expect(try await api.equipeDeConfianca(estabelecimentoID: casaID).map(\.id) == [profissional])
        await #expect(throws: ErroDaApi(codigo: .perfilIncompativel)) { try await api.incluirNaEquipe(membro) }
        await #expect(throws: ErroDaApi(codigo: .perfilIncompativel)) { try await api.removerDaEquipe(membro) }
    }

    @Test("Sem conta é nao_autenticado; sem rede, sem_rede")
    func semContaOuRede() async throws {
        let membro = MembroDaEquipe(estabelecimentoID: UUID(), profissionalID: profissional)
        let semConta = ApiClienteEmMemoria(cenario: .primeiroAcesso)
        await #expect(throws: ErroDaApi(codigo: .naoAutenticado)) { try await semConta.equipeDeConfianca(estabelecimentoID: membro.estabelecimentoID) }
        await #expect(throws: ErroDaApi(codigo: .naoAutenticado)) { try await semConta.incluirNaEquipe(membro) }

        let semRede = ApiClienteEmMemoria(cenario: .semRede)
        await #expect(throws: ErroDaApi(codigo: .semRede)) { try await semRede.equipeDeConfianca(estabelecimentoID: membro.estabelecimentoID) }
        await #expect(throws: ErroDaApi(codigo: .semRede)) { try await semRede.removerDaEquipe(membro) }
    }
}
