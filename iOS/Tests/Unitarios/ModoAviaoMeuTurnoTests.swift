import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

private final class RelogioMutavel: Relogio, @unchecked Sendable {
    private let trava = NSLock()
    private var _agora: Date
    init(_ agora: Date) { _agora = agora }
    var agora: Date { trava.withLock { _agora } }
    func ajustar(para instante: Date) { trava.withLock { _agora = instante } }
}

private final class ApiDubleModoAviao: ApiClienteEncaminhador, @unchecked Sendable {
    var semRede = false

    override func detalheDaVaga(id: UUID) async throws -> Vaga {
        if semRede { throw ErroDaApi(codigo: .semRede) }
        return try await super.detalheDaVaga(id: id)
    }

    override func meusTurnos() async throws -> [Turno] {
        if semRede { throw ErroDaApi(codigo: .semRede) }
        return try await super.meusTurnos()
    }

    override func contatoDoTurno(id: UUID) async throws -> Contato {
        if semRede { throw ErroDaApi(codigo: .semRede) }
        return try await super.contatoDoTurno(id: id)
    }
}

private func criarArmazenamentoLocal() throws -> ArmazenamentoSwiftData {
    ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
}

private func criarTurnoConfirmadoComContato(
    inicio: Date,
    fim: Date,
    funcao: String = "Cozinheiro Chefe",
    local: String = "Restaurante Asa Norte",
    valor: Dinheiro = Dinheiro(centavos: 25000)
) throws -> Turno {
    let vaga = VagaResumo(
        id: UUID(),
        funcao: funcao,
        local: local,
        regiaoAdministrativa: "Plano Piloto",
        periodo: try Periodo(inicio: inicio, fim: fim),
        valor: valor
    )
    let contraparte = PerfilPublico(
        id: UUID(),
        tipo: .estabelecimento,
        nome: "Restaurante Asa Norte",
        reputacao: Reputacao(positivas: 12, total: 12, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0)
    )
    let visivelAte = fim.addingTimeInterval(7 * 24 * 3_600)
    let contato = Contato(
        nome: "Clara Gerente",
        telefone: "+5561988887777",
        whatsappURL: try #require(URL(string: "https://wa.me/5561988887777")),
        visivelAte: visivelAte
    )
    return Turno(
        id: UUID(),
        posicaoID: UUID(),
        vaga: vaga,
        contraparte: contraparte,
        contatoVisivelAte: visivelAte,
        verificacao: .pendente,
        valorAcordado: valor,
        podeAvaliar: false,
        contato: contato
    )
}

@MainActor
@Suite("Modo avião do Meu turno (#73 e #109): persistência, lista e detalhe com contato legíveis")
struct ModoAviaoMeuTurnoTests {

    @Test("Modo avião de ponta a ponta: lista Meus turnos e detalhe do turno exibem contato e dados a partir do cache SwiftData")
    func modoAviaoPontaAPontaListaEDetalheComContato() async throws {
        let agora = Date(timeIntervalSince1970: 1_800_000_000)
        let fim = agora.addingTimeInterval(5 * 3_600)
        let relogio = RelogioMutavel(agora)

        let turnoConfirmado = try criarTurnoConfirmadoComContato(inicio: agora, fim: fim)
        let cache = try criarArmazenamentoLocal()
        let api = ApiDubleModoAviao()

        // 1. Online: o repositório busca da rede e popula o cache local SwiftData
        let repositorio = TurnosComCache(
            buscar: {
                if api.semRede { throw ErroDaApi(codigo: .semRede) }
                return [turnoConfirmado]
            },
            cache: cache,
            relogio: relogio
        )

        let leituraOnline = try await repositorio.ler()
        #expect(leituraOnline.origem == .rede)
        #expect(leituraOnline.turnos.count == 1)

        // 2. Transição para Modo Avião (sem rede)
        api.semRede = true

        // 3. A lista Meus turnos (MeusTurnosViewModel) é carregada sem rede:
        //    Lê do cache, entra em .carregada com origem .cache e disponibiliza o turno
        let viewModelLista = MeusTurnosViewModel(repositorio: repositorio)
        await viewModelLista.carregar()

        #expect(viewModelLista.origem == .cache)
        #expect(viewModelLista.turnos.count == 1)
        guard case let .carregada(turnosOffline, origemOffline) = viewModelLista.estado else {
            Issue.record("A lista deveria estar em estado .carregada a partir do cache")
            return
        }
        #expect(origemOffline == .cache)
        #expect(turnosOffline.count == 1)

        let turnoDaLista = try #require(turnosOffline.first)
        #expect(turnoDaLista.id == turnoConfirmado.id)
        #expect(turnoDaLista.vaga.funcao == "Cozinheiro Chefe")
        #expect(turnoDaLista.vaga.local == "Restaurante Asa Norte")
        #expect(turnoDaLista.valorAcordado == Dinheiro(centavos: 25000))
        #expect(turnoDaLista.contato?.nome == "Clara Gerente")
        #expect(turnoDaLista.contato?.telefone == "+5561988887777")

        // 4. O profissional toca no turno para abrir o detalhe (MeuTurnoViewModel):
        //    O ViewModel recebe o turno do cache e chama carregar() sem rede
        let viewModelDetalhe = MeuTurnoViewModel(turno: turnoDaLista, api: api, relogio: relogio)
        await viewModelDetalhe.carregar()

        // 5. Todos os dados do detalhe continuam perfeitamente legíveis no modo avião:
        #expect(viewModelDetalhe.turno.vaga.funcao == "Cozinheiro Chefe")
        #expect(viewModelDetalhe.turno.vaga.local == "Restaurante Asa Norte")
        #expect(viewModelDetalhe.turno.valorAcordado == Dinheiro(centavos: 25000))
        #expect(viewModelDetalhe.turno.vaga.periodo.inicio == agora)
        #expect(viewModelDetalhe.turno.vaga.periodo.fim == fim)
        #expect(viewModelDetalhe.quemRecebeExibicao == "Clara Gerente")

        // 6. O contato e o WhatsApp continuam visíveis e disponíveis:
        #expect(!viewModelDetalhe.contatoExpirado)
        let contatoDetalhe = try #require(viewModelDetalhe.contato)
        #expect(contatoDetalhe.nome == "Clara Gerente")
        #expect(contatoDetalhe.telefone == "+5561988887777")

        let urlWhatsApp = try #require(viewModelDetalhe.urlWhatsApp)
        #expect(urlWhatsApp.host == "wa.me")
        #expect(urlWhatsApp.path == "/5561988887777")

        let componentes = try #require(URLComponents(url: urlWhatsApp, resolvingAgainstBaseURL: false))
        let mensagem = try #require(componentes.queryItems?.first(where: { $0.name == "text" })?.value)
        #expect(mensagem.contains("Cozinheiro Chefe"))
        #expect(mensagem.contains("Restaurante Asa Norte"))
    }

    @Test("Modo avião com relógio adiantado (> 7 dias): contato expira pelo relógio do aparelho mesmo sem rede")
    func modoAviaoContatoExpiraPeloRelogioDoAparelho() async throws {
        let agora = Date(timeIntervalSince1970: 1_800_000_000)
        let fim = agora.addingTimeInterval(4 * 3_600)
        let visivelAte = fim.addingTimeInterval(7 * 24 * 3_600)
        let relogio = RelogioMutavel(agora)

        let turno = try criarTurnoConfirmadoComContato(inicio: agora, fim: fim)
        let cache = try criarArmazenamentoLocal()
        let api = ApiDubleModoAviao()

        // Salva turno com contato no cache
        try await cache.salvar(turnos: [turno], em: agora)

        // Modo avião ativado
        api.semRede = true

        // Relógio do aparelho avança para 8 dias após o fim do turno
        let instanteAposExpiracao = visivelAte.addingTimeInterval(24 * 3_600)
        relogio.ajustar(para: instanteAposExpiracao)

        // 1. O cache local (turnosValidos) já oculta o contato de acordo com a RN10
        let turnosValidosNoCache = try await cache.turnosValidos(em: instanteAposExpiracao)
        #expect(turnosValidosNoCache.allSatisfy { $0.contato == nil })

        // 2. O detalhe (MeuTurnoViewModel) com o relógio expirado oculta o contato e desativa o WhatsApp
        let vmDetalhe = MeuTurnoViewModel(turno: turno, api: api, relogio: relogio)
        await vmDetalhe.carregar()

        #expect(vmDetalhe.contato == nil)
        #expect(vmDetalhe.contatoExpirado)
        #expect(vmDetalhe.urlWhatsApp == nil)
    }
}
