import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

private func instante(_ horas: Double = 0) -> Date {
    Date(timeIntervalSince1970: 1_800_000_000 + horas * 3_600)
}

private func contato(visivelAte: Date, nome: String = "Marcos Lima") throws -> Contato {
    Contato(nome: nome, telefone: "+5561999990000", whatsappURL: try #require(URL(string: "https://wa.me/5561999990000")), visivelAte: visivelAte)
}

private func turno(inicio: Date, fim: Date, contatoVisivelAte: Date, contato: Contato? = nil, local: String = "Bar da Quadra, CLN 203") throws -> Turno {
    let vaga = VagaResumo(id: UUID(), funcao: "Garçom", local: local, regiaoAdministrativa: "Plano Piloto", periodo: try Periodo(inicio: inicio, fim: fim), valor: Dinheiro(centavos: 15000))
    let reputacao = Reputacao(positivas: 10, total: 10, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0)
    return Turno(
        id: UUID(), posicaoID: UUID(), vaga: vaga,
        contraparte: PerfilPublico(id: UUID(), tipo: .estabelecimento, nome: "Bar da Quadra", reputacao: reputacao),
        contatoVisivelAte: contatoVisivelAte, verificacao: .pendente, valorAcordado: vaga.valor, podeAvaliar: false, contato: contato
    )
}

private struct RelogioFixo: Relogio {
    let agora: Date
}

private final class ApiDeContato: ApiClienteEncaminhador, @unchecked Sendable {
    var resposta: Result<Contato, Error>
    init(_ resposta: Result<Contato, Error>) {
        self.resposta = resposta
        super.init()
    }
    override func contatoDoTurno(id: UUID) async throws -> Contato { try resposta.get() }
}

/// As bordas da regra do contato na tela do turno (RN10): o servidor manda um contato já vencido,
/// o modo avião com o contato guardado vencido, um erro qualquer com o contato vencido, e os
/// atalhos de mapa e de "quem recebe".
@MainActor
@Suite("Contato do turno na tela: bordas da RN10 e atalhos")
struct ContatoDoTurnoNaTelaTests {
    private let agora = instante()

    @Test("Servidor devolve contato com visivel_ate no passado: a tela esconde o contato e diz que expirou")
    func servidorDevolveContatoVencido() async throws {
        let turno = try turno(inicio: instante(-6), fim: instante(-2), contatoVisivelAte: instante(24 * 7))
        let api = ApiDeContato(.success(try contato(visivelAte: instante(-1))))
        let modelo = MeuTurnoViewModel(turno: turno, api: api, relogio: RelogioFixo(agora: agora))

        await modelo.carregar()

        #expect(modelo.contato == nil)
        #expect(modelo.contatoExpirado)
        #expect(modelo.urlWhatsApp == nil)
    }

    @Test("Sem rede, com o contato guardado dentro do prazo, a tela mantém o contato (RNF06)")
    func semRedeComContatoNoPrazo() async throws {
        let guardado = try contato(visivelAte: instante(24))
        let turno = try turno(inicio: instante(-6), fim: instante(-2), contatoVisivelAte: instante(24), contato: guardado)
        let api = ApiDeContato(.failure(ErroDaApi(codigo: .semRede)))
        let modelo = MeuTurnoViewModel(turno: turno, api: api, relogio: RelogioFixo(agora: agora))

        await modelo.carregar()

        #expect(modelo.contato == guardado)
        #expect(!modelo.contatoExpirado)
        #expect(modelo.urlWhatsApp?.host() == "wa.me")
    }

    @Test("Sem rede e com o contato guardado já vencido pelo relógio do aparelho, a tela esconde o contato")
    func semRedeComContatoVencido() async throws {
        // O turno diz que o contato vale, mas o próprio contato guardado venceu: o mais restritivo manda.
        let guardado = try contato(visivelAte: instante(-1))
        let turno = try turno(inicio: instante(-6), fim: instante(-2), contatoVisivelAte: instante(24), contato: guardado)
        let api = ApiDeContato(.failure(ErroDaApi(codigo: .semRede)))
        let modelo = MeuTurnoViewModel(turno: turno, api: api, relogio: RelogioFixo(agora: agora))

        await modelo.carregar()

        #expect(modelo.contato == nil)
        #expect(modelo.contatoExpirado)
    }

    @Test("Erro que não é falta de rede: o contato guardado fica se está no prazo, e some se venceu")
    func outroErroPreservaOuEsconde() async throws {
        let noPrazo = try contato(visivelAte: instante(24))
        let turnoNoPrazo = try turno(inicio: instante(-6), fim: instante(-2), contatoVisivelAte: instante(24), contato: noPrazo)
        let modeloNoPrazo = MeuTurnoViewModel(turno: turnoNoPrazo, api: ApiDeContato(.failure(ErroDaApi(codigo: .desconhecido))), relogio: RelogioFixo(agora: agora))
        await modeloNoPrazo.carregar()
        #expect(modeloNoPrazo.contato == noPrazo)
        #expect(!modeloNoPrazo.contatoExpirado)

        let vencido = try contato(visivelAte: instante(-1))
        let turnoVencido = try turno(inicio: instante(-6), fim: instante(-2), contatoVisivelAte: instante(24), contato: vencido)
        let modeloVencido = MeuTurnoViewModel(turno: turnoVencido, api: ApiDeContato(.failure(ErroDaApi(codigo: .desconhecido))), relogio: RelogioFixo(agora: agora))
        await modeloVencido.carregar()
        #expect(modeloVencido.contato == nil)
        #expect(modeloVencido.contatoExpirado)
    }

    @Test("Servidor diz contato_expirado: a tela esconde o contato mesmo com um guardado no prazo")
    func servidorDizExpirado() async throws {
        let guardado = try contato(visivelAte: instante(24))
        let turno = try turno(inicio: instante(-6), fim: instante(-2), contatoVisivelAte: instante(24), contato: guardado)
        let modelo = MeuTurnoViewModel(turno: turno, api: ApiDeContato(.failure(ErroDaApi(codigo: .contatoExpirado))), relogio: RelogioFixo(agora: agora))

        await modelo.carregar()

        #expect(modelo.contato == nil)
        #expect(modelo.contatoExpirado)
    }

    @Test("O atalho do mapa abre o Apple Maps com o endereço do turno na busca")
    func atalhoDoMapa() async throws {
        let turno = try turno(inicio: instante(1), fim: instante(5), contatoVisivelAte: instante(24), local: "CLN 203, Asa Norte")
        let modelo = MeuTurnoViewModel(turno: turno, api: ApiDeContato(.failure(ErroDaApi(codigo: .semRede))), relogio: RelogioFixo(agora: agora))

        let url = try #require(modelo.urlMapas)
        let componentes = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(componentes.scheme == "https")
        #expect(componentes.host == "maps.apple.com")
        #expect(componentes.queryItems?.first { $0.name == "q" }?.value == "CLN 203, Asa Norte")
    }

    @Test("Quem recebe: o nome do contato liberado vale sobre o nome do estabelecimento")
    func quemRecebe() async throws {
        let liberado = try contato(visivelAte: instante(24), nome: "Marcos Lima")
        let turno = try turno(inicio: instante(1), fim: instante(5), contatoVisivelAte: instante(24))
        let modelo = MeuTurnoViewModel(turno: turno, api: ApiDeContato(.success(liberado)), relogio: RelogioFixo(agora: agora))

        #expect(modelo.quemRecebeExibicao == "Bar da Quadra")
        await modelo.carregar()
        #expect(modelo.quemRecebeExibicao == "Marcos Lima")
    }
}
