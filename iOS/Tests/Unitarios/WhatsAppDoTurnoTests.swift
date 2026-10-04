import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

private func criarContatoComTelefone(_ telefone: String, visivelAte: Date) throws -> Contato {
    let digitos = telefone.replacingOccurrences(of: "+", with: "")
    let url = try #require(URL(string: "https://wa.me/\(digitos)"))
    return Contato(
        nome: "Responsável do Bistrô",
        telefone: telefone,
        whatsappURL: url,
        visivelAte: visivelAte
    )
}

private func criarTurnoParaWhatsApp(
    funcao: String = "Garçom & Barista",
    local: String = "Café & Bistrô das Nações",
    inicio: Date,
    fim: Date,
    contato: Contato?
) throws -> Turno {
    let vaga = VagaResumo(
        id: UUID(),
        funcao: funcao,
        local: local,
        regiaoAdministrativa: "Plano Piloto",
        periodo: try Periodo(inicio: inicio, fim: fim),
        valor: Dinheiro(centavos: 18000)
    )
    let contraparte = PerfilPublico(
        id: UUID(),
        tipo: .estabelecimento,
        nome: "Café & Bistrô",
        reputacao: Reputacao(positivas: 5, total: 5, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0)
    )
    let visivelAte = fim.addingTimeInterval(7 * 24 * 3_600)
    return Turno(
        id: UUID(),
        posicaoID: UUID(),
        vaga: vaga,
        contraparte: contraparte,
        contatoVisivelAte: visivelAte,
        verificacao: .pendente,
        valorAcordado: vaga.valor,
        podeAvaliar: false,
        contato: contato
    )
}

private final class RelogioFixo: Relogio, @unchecked Sendable {
    let agora: Date
    init(_ agora: Date) { self.agora = agora }
}

private final class ApiDubleWhatsApp: ApiClienteEncaminhador, @unchecked Sendable {
    var onContatoDoTurno: (@Sendable (UUID) async throws -> Contato)?

    override func contatoDoTurno(id: UUID) async throws -> Contato {
        if let onContatoDoTurno { return try await onContatoDoTurno(id) }
        return try await super.contatoDoTurno(id: id)
    }
}

@MainActor
@Suite("WhatsApp do Meu turno (#109): número, codificação da mensagem e visibilidade")
struct WhatsAppDoTurnoTests {

    @Test("O número do endereço wa.me contém exatamente os dígitos do contato com código do país")
    func numeroDoEnderecoMantemDigitosComCodigoDoPais() async throws {
        let inicio = Date(timeIntervalSince1970: 1_800_000_000)
        let fim = inicio.addingTimeInterval(4 * 3_600)
        let visivelAte = fim.addingTimeInterval(7 * 24 * 3_600)

        // Testa número de Brasília (+55 61 ...)
        let contatoBrasilia = try criarContatoComTelefone("+5561999990000", visivelAte: visivelAte)
        let turnoBrasilia = try criarTurnoParaWhatsApp(inicio: inicio, fim: fim, contato: contatoBrasilia)
        let vmBrasilia = MeuTurnoViewModel(turno: turnoBrasilia, api: ApiDubleWhatsApp(), relogio: RelogioFixo(inicio))

        let urlBrasilia = try #require(vmBrasilia.urlWhatsApp)
        #expect(urlBrasilia.scheme == "https")
        #expect(urlBrasilia.host == "wa.me")
        #expect(urlBrasilia.path == "/5561999990000")

        // Testa número de São Paulo (+55 11 ...) para provar que o caminho não está engessado em um número só
        let contatoSP = try criarContatoComTelefone("+5511987654321", visivelAte: visivelAte)
        let turnoSP = try criarTurnoParaWhatsApp(inicio: inicio, fim: fim, contato: contatoSP)
        let vmSP = MeuTurnoViewModel(turno: turnoSP, api: ApiDubleWhatsApp(), relogio: RelogioFixo(inicio))

        let urlSP = try #require(vmSP.urlWhatsApp)
        #expect(urlSP.scheme == "https")
        #expect(urlSP.host == "wa.me")
        #expect(urlSP.path == "/5511987654321")
    }

    @Test("A mensagem leva função, data e local, e sai codificada com acentos, espaços e o caractere &")
    func mensagemLevaFuncaoDataELocalCodificadaCorretamente() async throws {
        // Sexta-feira às 18:00 (em fuso de São Paulo UTC-3)
        let inicio = Date(timeIntervalSince1970: 1_800_000_000)
        let fim = inicio.addingTimeInterval(4 * 3_600)
        let visivelAte = fim.addingTimeInterval(7 * 24 * 3_600)

        let funcaoComAcentoEEComercial = "Garçom & Barista"
        let localComAcentoEEComercial = "Café & Bistrô das Nações"

        let contato = try criarContatoComTelefone("+5561999990000", visivelAte: visivelAte)
        let turno = try criarTurnoParaWhatsApp(
            funcao: funcaoComAcentoEEComercial,
            local: localComAcentoEEComercial,
            inicio: inicio,
            fim: fim,
            contato: contato
        )
        let vm = MeuTurnoViewModel(turno: turno, api: ApiDubleWhatsApp(), relogio: RelogioFixo(inicio))

        let url = try #require(vm.urlWhatsApp)
        let urlString = url.absoluteString

        // 1. A URL contém wa.me com os dígitos corretos
        #expect(urlString.hasPrefix("https://wa.me/5561999990000?text="))

        // 2. O '&' do nome do local e da função NÃO cria novos parâmetros de query (não divide a query em múltiplos query items)
        let componentes = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(componentes.queryItems?.count == 1)
        #expect(componentes.queryItems?.first?.name == "text")

        // 3. Na query codificada (percent-encoded), caracteres especiais estão devidamente escapados:
        //    - Espaços são codificados como %20
        //    - '&' é codificado como %26
        //    - Acentos como 'ç' (%C3%A7), 'ã' (%C3%A3), 'é' (%C3%A9), 'ô' (%C3%B4)
        let queryCodificada = try #require(componentes.percentEncodedQuery)
        #expect(!queryCodificada.contains(" "))
        #expect(queryCodificada.contains("%26"), "O caractere '&' deve estar percent-encoded como %26 para não corromper a query string")
        #expect(queryCodificada.contains("%20"), "Espaços devem estar percent-encoded como %20")
        #expect(queryCodificada.contains("%C3%A7") || queryCodificada.contains("%C3%A3"), "Acentos devem estar em UTF-8 percent-encoded")

        // 4. Ao decodificar o valor do query item text, a mensagem sai íntegra com todos os campos
        let dataFormatadaEsperada = FormatadorFrila().intervalo(turno.vaga.periodo)
        let mensagemDecodificada = try #require(componentes.queryItems?.first?.value)

        #expect(mensagemDecodificada.contains(funcaoComAcentoEEComercial))
        #expect(mensagemDecodificada.contains(dataFormatadaEsperada))
        #expect(mensagemDecodificada.contains(localComAcentoEEComercial))
        #expect(mensagemDecodificada == "Olá! Sou o profissional do turno de \(funcaoComAcentoEEComercial) em \(dataFormatadaEsperada) no \(localComAcentoEEComercial).")
    }

    @Test("O botão do WhatsApp só existe com o contato liberado, e some quando expirado ou nulo")
    func botaoWhatsAppSoExisteComContatoLiberadoESomeExpirado() async throws {
        let agora = Date(timeIntervalSince1970: 1_800_000_000)
        let fim = agora.addingTimeInterval(4 * 3_600)
        let visivelAte = fim.addingTimeInterval(7 * 24 * 3_600)
        let contato = try criarContatoComTelefone("+5561999990000", visivelAte: visivelAte)

        // 1. Contato liberado e dentro do prazo: urlWhatsApp está presente
        let turnoAtivo = try criarTurnoParaWhatsApp(inicio: agora, fim: fim, contato: contato)
        let vmAtivo = MeuTurnoViewModel(turno: turnoAtivo, api: ApiDubleWhatsApp(), relogio: RelogioFixo(agora))
        #expect(vmAtivo.urlWhatsApp != nil)
        #expect(!vmAtivo.contatoExpirado)
        #expect(vmAtivo.contato != nil)

        // 2. Contato não carregado inicialmente (contato == nil): urlWhatsApp é nil
        let turnoSemContato = try criarTurnoParaWhatsApp(inicio: agora, fim: fim, contato: nil)
        let vmSemContato = MeuTurnoViewModel(turno: turnoSemContato, api: ApiDubleWhatsApp(), relogio: RelogioFixo(agora))
        #expect(vmSemContato.urlWhatsApp == nil)
        #expect(!vmSemContato.contatoExpirado)

        // 3. Contato expirado pelo relógio (> 7 dias após o fim do turno): urlWhatsApp é nil e contatoExpirado é true
        let relogioAposExpiracao = RelogioFixo(visivelAte.addingTimeInterval(3_600))
        let vmExpiradoRelogio = MeuTurnoViewModel(turno: turnoAtivo, api: ApiDubleWhatsApp(), relogio: relogioAposExpiracao)
        #expect(vmExpiradoRelogio.urlWhatsApp == nil)
        #expect(vmExpiradoRelogio.contato == nil)
        #expect(vmExpiradoRelogio.contatoExpirado)

        // 4. Contato expirado pelo servidor (403 contato_expirado retornado por contatoDoTurno): urlWhatsApp é nil
        let apiExpirada = ApiDubleWhatsApp()
        apiExpirada.onContatoDoTurno = { _ in throw ErroDaApi(codigo: .contatoExpirado) }
        let vmExpiradoAPI = MeuTurnoViewModel(turno: turnoSemContato, api: apiExpirada, relogio: RelogioFixo(agora))
        await vmExpiradoAPI.carregar()
        #expect(vmExpiradoAPI.urlWhatsApp == nil)
        #expect(vmExpiradoAPI.contato == nil)
        #expect(vmExpiradoAPI.contatoExpirado)
    }

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

    @Test("Link malicioso vira o wa.me do telefone em candidatar, e a candidatura não vira erro (A5)", arguments: linksMaliciosos)
    func linkMaliciosoViraWaMeNaCandidatura(link: String) throws {
        let json = """
        {"estado": "confirmada", "candidatura_id": "6a0f4c9e-7f6a-4d1e-9d8e-000000000001", "posicao_id": "6a0f4c9e-7f6a-4d1e-9d8e-000000000002",
         "turno_id": "6a0f4c9e-7f6a-4d1e-9d8e-000000000003", "contato": \(Self.contatoJSON(link: link))}
        """
        let resultado = try ContratoAPI.decodificador().decode(ContratoAPI.CandidaturaDTO.self, from: Data(json.utf8)).dominio()
        #expect(resultado.estado == .confirmada)
        #expect(resultado.contato?.whatsappURL.absoluteString == "https://wa.me/5561988881234")
    }

    @Test("Link malicioso vira o wa.me do telefone em escolher_candidato, e a escolha não vira erro (A5)", arguments: linksMaliciosos)
    func linkMaliciosoViraWaMeNaEscolha(link: String) throws {
        let json = """
        {"estado": "confirmada", "posicao_id": "6a0f4c9e-7f6a-4d1e-9d8e-000000000002",
         "turno_id": "6a0f4c9e-7f6a-4d1e-9d8e-000000000003", "contato": \(Self.contatoJSON(link: link))}
        """
        let resultado = try ContratoAPI.decodificador().decode(ContratoAPI.ResultadoConfirmacaoDTO.self, from: Data(json.utf8)).dominio()
        #expect(resultado.contato.whatsappURL.absoluteString == "https://wa.me/5561988881234")
    }
}
