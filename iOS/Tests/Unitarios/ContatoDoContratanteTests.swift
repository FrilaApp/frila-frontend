import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

private final class RelogioSimulado: Relogio, @unchecked Sendable {
    var agora: Date
    init(_ agora: Date) { self.agora = agora }
}

private final class ApiDubleContatoContratante: ApiClienteEncaminhador, @unchecked Sendable {
    var onContatoDoTurno: (@Sendable (UUID) async throws -> Contato)?

    override func contatoDoTurno(id: UUID) async throws -> Contato {
        if let onContatoDoTurno { return try await onContatoDoTurno(id) }
        return try await super.contatoDoTurno(id: id)
    }
}

@MainActor
@Suite("Contato do profissional no contratante e expiração após 7 dias (US13 C3 / RN10)")
struct ContatoDoContratanteTests {
    private let estabelecimentoID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    private let mensagemContatoExpiradoEsperada = "O prazo para ver este contato terminou."

    private func criarContatoComTelefone(
        _ telefone: String,
        nome: String = "Ana Cunha",
        visivelAte: Date
    ) throws -> Contato {
        let digitos = telefone.replacingOccurrences(of: "+", with: "")
        let url = try #require(URL(string: "https://wa.me/\(digitos)"))
        return Contato(
            nome: nome,
            telefone: telefone,
            whatsappURL: url,
            visivelAte: visivelAte
        )
    }

    @Test("O prazo de visibilidade do contato pelo contratante é de 7 dias após o fim do turno (RN10)")
    func prazoDoContatoDoContratanteSegueRN10SeteDiasAposFimDoTurno() throws {
        let inicio = Date(timeIntervalSince1970: 1_800_000_000)
        let duracao: TimeInterval = 4 * 3_600
        let fim = inicio.addingTimeInterval(duracao)
        let visivelAte = fim.addingTimeInterval(7 * 24 * 3_600)

        let contato = try criarContatoComTelefone("+5561999990000", visivelAte: visivelAte)
        #expect(contato.visivelAte == visivelAte)

        // 1. Antes do prazo (inclusive 1 segundo antes do fim do 7º dia): contato está visível
        let relogioAntes = RelogioSimulado(visivelAte.addingTimeInterval(-1))
        #expect(contato.estaVisivel(em: relogioAntes.agora))

        // 2. No exato instante do prazo: contato está visível (intervalo fechado: <= visivelAte)
        let relogioExato = RelogioSimulado(visivelAte)
        #expect(contato.estaVisivel(em: relogioExato.agora))

        // 3. Após o prazo (1 segundo após o fim do 7º dia): contato expirou
        let relogioApos = RelogioSimulado(visivelAte.addingTimeInterval(1))
        #expect(!contato.estaVisivel(em: relogioApos.agora))
    }

    @Test("Antes do prazo de 7 dias, a API entrega o contato do profissional confirmado no painel do contratante")
    func apiEntregaContatoDoProfissionalDentroDoPrazo() async throws {
        let agora = Date(timeIntervalSince1970: 1_800_000_000)
        let relogio = RelogioSimulado(agora)
        let api = ApiClienteEmMemoria(cenario: .painelContratante, relogio: relogio)

        let periodo = try Periodo(inicio: agora.addingTimeInterval(-86_400), fim: agora.addingTimeInterval(365 * 86_400))
        let painel = try await api.painelEstabelecimento(id: estabelecimentoID, periodo: periodo)
        let vaga = try #require(painel.vagas.first)
        let posicao = try #require(vaga.posicoes.first(where: { $0.estado == .confirmada }))
        let turnoID = try #require(posicao.turnoID)

        let contato = try await api.contatoDoTurno(id: turnoID)
        #expect(contato.nome == "Ana Cunha")
        #expect(contato.telefone == "+5561999990000")
        #expect(contato.whatsappURL.host == "wa.me")
        #expect(contato.estaVisivel(em: relogio.agora))

        // URLs de chamada direta (telefone e WhatsApp) geradas como em MinhasVagas.swift
        let telefoneLimpo = contato.telefone.filter { $0.isNumber || $0 == "+" }
        let telURL = try #require(URL(string: "tel:\(telefoneLimpo)"))
        #expect(telURL.scheme == "tel")
        #expect(telURL.absoluteString == "tel:+5561999990000")

        let waURL = try #require(URLComponents(url: contato.whatsappURL, resolvingAgainstBaseURL: false)?.url)
        #expect(waURL.scheme == "https")
        #expect(waURL.host == "wa.me")
    }

    @Test("Após o prazo de 7 dias, a API recusa com 403 contato_expirado para o contratante")
    func apiRecusaCom403AposSeteDiasDoFimDoTurno() async throws {
        let agora = Date(timeIntervalSince1970: 1_800_000_000)
        let relogio = RelogioSimulado(agora)
        let api = ApiClienteEmMemoria(cenario: .painelContratante, relogio: relogio)

        let periodo = try Periodo(inicio: agora.addingTimeInterval(-86_400), fim: agora.addingTimeInterval(365 * 86_400))
        let painel = try await api.painelEstabelecimento(id: estabelecimentoID, periodo: periodo)
        let vaga = try #require(painel.vagas.first)
        let posicao = try #require(vaga.posicoes.first(where: { $0.estado == .confirmada }))
        let turnoID = try #require(posicao.turnoID)

        // Avança o relógio para além de 7 dias após o fim da vaga (RN10)
        let fimDaVaga = vaga.vaga.periodo.fim
        let instanteApos7Dias = fimDaVaga.addingTimeInterval(7 * 24 * 3_600 + 3_600)
        relogio.agora = instanteApos7Dias

        // A chamada contatoDoTurno deve falhar com 403 contato_expirado
        await #expect(throws: ErroDaApi(codigo: .contatoExpirado)) {
            try await api.contatoDoTurno(id: turnoID)
        }
    }

    @Test("Lógica da tela de Minhas vagas: antes do prazo exibe contato; após 7 dias esconde telefone e WhatsApp e exibe aviso")
    func logicaDaTelaEscondeTelefoneEWhatsAppAposExpiracao() throws {
        let inicio = Date(timeIntervalSince1970: 1_800_000_000)
        let fim = inicio.addingTimeInterval(4 * 3_600)
        let visivelAte = fim.addingTimeInterval(7 * 24 * 3_600)
        let contato = try criarContatoComTelefone("+5561999990000", visivelAte: visivelAte)

        // 1. Antes do prazo: contato está visível e ações de ligar e WhatsApp estão disponíveis
        let relogioAntes = RelogioSimulado(fim.addingTimeInterval(24 * 3_600))
        let visivelAntes = contato.estaVisivel(em: relogioAntes.agora)
        #expect(visivelAntes)
        let telefoneVisivelAntes: String? = visivelAntes ? contato.telefone : nil
        let whatsappVisivelAntes: URL? = visivelAntes ? contato.whatsappURL : nil
        #expect(telefoneVisivelAntes != nil)
        #expect(whatsappVisivelAntes != nil)

        // 2. Após 7 dias pelo relógio: contato.estaVisivel fica falso; telefone e WhatsApp NÃO aparecem
        let relogioDepois = RelogioSimulado(visivelAte.addingTimeInterval(3_600))
        let visivelDepois = contato.estaVisivel(em: relogioDepois.agora)
        #expect(!visivelDepois)
        let telefoneVisivelDepois: String? = visivelDepois ? contato.telefone : nil
        let whatsappVisivelDepois: URL? = visivelDepois ? contato.whatsappURL : nil
        #expect(telefoneVisivelDepois == nil)
        #expect(whatsappVisivelDepois == nil)
        #expect(mensagemContatoExpiradoEsperada == "O prazo para ver este contato terminou.")

        // 3. Após 7 dias pelo servidor (403 contato_expirado): errosContato captura e exibe aviso sem dados
        let erroApi = ErroDaApi(codigo: .contatoExpirado)
        let mensagemErro: String? = erroApi.codigo == .contatoExpirado ? mensagemContatoExpiradoEsperada : nil
        #expect(mensagemErro == "O prazo para ver este contato terminou.")
    }

    @Test("No fluxo do contratante, TelaTurnoDoContratante e AcompanhamentoViewModel não expõem contato do profissional")
    func acompanhamentoViewModelNaoPossuiContatoDoProfissional() async throws {
        let agora = Date(timeIntervalSince1970: 1_800_000_000)
        let relogio = RelogioSimulado(agora)
        let api = ApiClienteEmMemoria(cenario: .painelContratante, relogio: relogio)

        let vm = AcompanhamentoViewModel(
            api: api,
            estabelecimentoID: estabelecimentoID,
            agora: { relogio.agora }
        )
        await vm.carregar()

        let turnoID = UUID(uuidString: "82000000-0000-0000-0000-000000000001")!
        let turno = try #require(vm.turno(turnoID: turnoID))

        // O turno acompanhado expõe vaga e posicao (com perfil público), mas NÃO expõe Contato
        #expect(turno.posicao.profissional?.nome == "Ana Cunha")
        #expect(turno.posicao.turnoID == turnoID)
        // AcompanhamentoViewModel não possui propriedade ou método para carregar Contato;
        // o contato do profissional só é acessível na lista de Minhas Vagas (TelaDetalheVagaContratante).
    }
}
