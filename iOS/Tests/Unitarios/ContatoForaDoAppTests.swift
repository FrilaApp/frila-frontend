@testable import FrilaApresentacao
@testable import FrilaDados
import Foundation
import FrilaDominio
import Testing

/// Contato fora do app, Fase 1: o servidor pode continuar mandando `contato` e
/// `contato_visivel_ate` (como hoje) ou deixar de mandar (Fase 2). Nos dois casos a candidatura, a
/// confirmação e o resumo do turno decodificam, e o app não leva o contato para dentro do modelo.
@Suite("Contato fora do app: tolerância dos DTOs")
struct ContatoForaDoAppTests {
    /// A fixture do contrato como dicionário, para tirar ou anular um campo antes de decodificar.
    private static func variacao(_ nome: String, _ ajuste: (inout [String: Any]) -> Void) throws -> Data {
        var objeto = try #require(JSONSerialization.jsonObject(with: FixturesDoContrato.dados(nome)) as? [String: Any])
        ajuste(&objeto)
        return try JSONSerialization.data(withJSONObject: objeto)
    }

    private static func primeiroTurno(_ ajuste: (inout [String: Any]) -> Void) throws -> Data {
        var lista = try #require(JSONSerialization.jsonObject(with: FixturesDoContrato.dados("turnos")) as? [[String: Any]])
        ajuste(&lista[0])
        return try JSONSerialization.data(withJSONObject: [lista[0]])
    }

    // MARK: candidatar

    @Test("candidatar decodifica com o contato, sem o campo e com o campo nulo, e a confirmação segue igual", arguments: [
        "com contato", "sem contato", "contato nulo",
    ])
    func candidatar(caso: String) throws {
        let dados = try Self.variacao("candidatura-urgencia") { objeto in
            switch caso {
            case "sem contato": objeto.removeValue(forKey: "contato")
            case "contato nulo": objeto["contato"] = NSNull()
            default: break
            }
        }
        let resultado = try ContratoAPI.decodificador().decode(ContratoAPI.CandidaturaDTO.self, from: dados).dominio()
        #expect(resultado.estado == .confirmada)
        #expect(resultado.turnoID == UUID(uuidString: "9a8b7c6d-5e4f-4a3b-8c2d-1e0f0b8a7c6d"))
        #expect(resultado.posicaoID != nil)
    }

    @Test("candidatar em vaga de seleção (pendente) segue sem turno nem contato")
    func candidatarPendente() throws {
        let resultado = try ContratoAPI.decodificador().decode(
            ContratoAPI.CandidaturaDTO.self, from: FixturesDoContrato.dados("candidatura-selecao")
        ).dominio()
        #expect(resultado.estado == .pendente)
        #expect(resultado.turnoID == nil)
    }

    // MARK: escolher_candidato

    @Test("escolher_candidato decodifica com o contato, sem o campo e com o campo nulo", arguments: [
        "com contato", "sem contato", "contato nulo",
    ])
    func escolherCandidato(caso: String) throws {
        let dados = try Self.variacao("resultado-confirmacao") { objeto in
            switch caso {
            case "sem contato": objeto.removeValue(forKey: "contato")
            case "contato nulo": objeto["contato"] = NSNull()
            default: break
            }
        }
        let confirmacao = try ContratoAPI.decodificador().decode(ContratoAPI.ResultadoConfirmacaoDTO.self, from: dados).dominio()
        #expect(confirmacao.turnoID == UUID(uuidString: "60000000-0000-0000-0000-000000000002"))
        #expect(confirmacao.posicaoID == UUID(uuidString: "50000000-0000-0000-0000-000000000002"))
    }

    @Test("escolher_candidato com contato malformado também confirma: o contato não é lido")
    func escolherCandidatoComContatoMalformado() throws {
        let dados = try Self.variacao("resultado-confirmacao") { $0["contato"] = ["nome": 7, "whatsapp_url": "não é url"] }
        let confirmacao = try ContratoAPI.decodificador().decode(ContratoAPI.ResultadoConfirmacaoDTO.self, from: dados).dominio()
        #expect(confirmacao.turnoID == UUID(uuidString: "60000000-0000-0000-0000-000000000002"))
    }

    // MARK: resumo do turno

    @Test("O resumo do turno decodifica sem contato_visivel_ate e com ele nulo: o turno segue, sem prazo")
    func turnoSemPrazoDoContato() throws {
        for ajuste: (inout [String: Any]) -> Void in [
            { $0.removeValue(forKey: "contato_visivel_ate") },
            { $0["contato_visivel_ate"] = NSNull() },
        ] {
            let dados = try Self.primeiroTurno(ajuste)
            let turno = try #require(try ContratoAPI.decodificador().decode([ContratoAPI.TurnoDTO].self, from: dados).first).dominio()
            #expect(turno.vaga.funcao == "Garçom")
            #expect(turno.contato == nil)
            #expect(turno.contatoVisivelAte == .distantFuture)
            #expect(turno.checkin != nil)
        }
    }

    @Test("O resumo do turno com contato_visivel_ate (como o servidor manda hoje) continua igual")
    func turnoComPrazoDoContato() throws {
        let turno = try #require(try FixturesDoContrato.carregar("turnos", como: [ContratoAPI.TurnoDTO].self).first).dominio()
        #expect(turno.contatoVisivelAte == ContratoAPI.instante("2026-10-17T01:00:00Z"))
    }

    // MARK: o app, de ponta a ponta

    @Test("Candidatar e confirmar seguem funcionando: o view model recebe o turno e nada de contato")
    @MainActor
    func viewModelConfirma() async throws {
        let api = ApiClienteEmMemoria()
        let naLista = try #require(try await api.vagasAbertas().first)
        let vaga = try await api.detalheDaVaga(id: naLista.id)
        let turnoID = UUID()
        let vm = CandidaturaViewModel(
            vaga: vaga,
            candidatar: { _ in ResultadoCandidatura(estado: .confirmada, candidaturaID: UUID(), posicaoID: UUID(), turnoID: turnoID) }
        )
        await vm.candidatar()
        #expect(vm.estado == .concluida(.confirmada(turnoID: turnoID)))
    }
}
