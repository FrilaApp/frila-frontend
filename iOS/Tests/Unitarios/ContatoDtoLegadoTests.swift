import Foundation
@testable import FrilaDados
import FrilaDominio
import Testing

/// O `ContatoDTO` de `contato_do_turno` segue no cliente de dados até a Fase 2 do contato fora do
/// app (servidor). O app não chama mais essa RPC; estes testes guardam o saneamento do link enquanto
/// ela existir.
@Suite("ContatoDTO legado (contato_do_turno): link do WhatsApp e candidatura tolerante")
struct ContatoDtoLegadoTests {

    @Test("DTO do contrato decodifica whatsapp_url e mapeia para o domínio Contato preservando o link")
    func dtoDoContratoDecodificaETransfereWhatsappURL() throws {
        let json = """
        {
            "nome": "Choperia Central",
            "telefone": "+5561988881234",
            "whatsapp_url": "https://wa.me/5561988881234",
            "visivel_ate": "2026-10-15T22:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(ContratoAPI.ContatoDTO.self, from: json)
        let dominio = dto.dominio()

        #expect(dominio.nome == "Choperia Central")
        #expect(dominio.telefone == "+5561988881234")
        #expect(dominio.whatsappURL.absoluteString == "https://wa.me/5561988881234")
    }

    private nonisolated static let linksMaliciosos = [
        "javascript:alert(1)",
        "http://wa.me/5561988881234",
        "https://wa.me.evil.com/5561988881234",
        "https://evil.com/5561988881234",
        "whatsapp://send?phone=5561988881234",
    ]

    private nonisolated static let linksDoWhatsApp = [
        "https://wa.me/5561988881234",
        "HTTPS://WA.ME/5561988881234",
        "https://api.whatsapp.com/send?phone=5561988881234",
    ]

    private static func contatoJSON(link: String) -> String {
        """
        {"nome": "Choperia Central", "telefone": "+5561988881234", "whatsapp_url": "\(link)", "visivel_ate": "2026-10-15T22:00:00Z"}
        """
    }

    @Test("Link do WhatsApp em https passa intacto (A5)", arguments: linksDoWhatsApp)
    func linkDoWhatsAppPassaIntacto(link: String) throws {
        let dto = try ContratoAPI.decodificador().decode(ContratoAPI.ContatoDTO.self, from: Data(Self.contatoJSON(link: link).utf8))
        #expect(dto.dominio().whatsappURL.absoluteString == link)
    }

    @Test("Link malicioso vira o wa.me do telefone em contato_do_turno, sem erro (A5)", arguments: linksMaliciosos)
    func linkMaliciosoViraWaMeNoContato(link: String) throws {
        let dto = try ContratoAPI.decodificador().decode(ContratoAPI.ContatoDTO.self, from: Data(Self.contatoJSON(link: link).utf8))
        let contato = dto.dominio()
        #expect(contato.whatsappURL.absoluteString == "https://wa.me/5561988881234")
        #expect(contato.telefone == "+5561988881234")
    }

    @Test("Link malicioso no contato de candidatar não derruba a candidatura: o contato nem é lido", arguments: linksMaliciosos)
    func linkMaliciosoNaCandidaturaNaoDerruba(link: String) throws {
        let json = """
        {"estado": "confirmada", "candidatura_id": "6a0f4c9e-7f6a-4d1e-9d8e-000000000001", "posicao_id": "6a0f4c9e-7f6a-4d1e-9d8e-000000000002",
         "turno_id": "6a0f4c9e-7f6a-4d1e-9d8e-000000000003", "contato": \(Self.contatoJSON(link: link))}
        """
        let resultado = try ContratoAPI.decodificador().decode(ContratoAPI.CandidaturaDTO.self, from: Data(json.utf8)).dominio()
        #expect(resultado.estado == .confirmada)
        #expect(resultado.turnoID == UUID(uuidString: "6a0f4c9e-7f6a-4d1e-9d8e-000000000003"))
    }

    @Test("Link malicioso no contato de escolher_candidato não derruba a escolha: o contato nem é lido", arguments: linksMaliciosos)
    func linkMaliciosoNaEscolhaNaoDerruba(link: String) throws {
        let json = """
        {"estado": "confirmada", "posicao_id": "6a0f4c9e-7f6a-4d1e-9d8e-000000000002",
         "turno_id": "6a0f4c9e-7f6a-4d1e-9d8e-000000000003", "contato": \(Self.contatoJSON(link: link))}
        """
        let resultado = try ContratoAPI.decodificador().decode(ContratoAPI.ResultadoConfirmacaoDTO.self, from: Data(json.utf8)).dominio()
        #expect(resultado.turnoID == UUID(uuidString: "6a0f4c9e-7f6a-4d1e-9d8e-000000000003"))
    }
}
