import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import SwiftData
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
        Issue.record("contato_do_turno não deve ser chamado")
        throw ErroDaApi(codigo: .desconhecido)
    }
}

private func criarArmazenamentoLocal() throws -> ArmazenamentoSwiftData {
    ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
}

/// Um turno como o servidor (ou uma versão antiga do app) ainda poderia entregar: com o contato junto.
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
@Suite("Modo avião do Meu turno (#73 e #109): persistência, lista e detalhe sem contato")
struct ModoAviaoMeuTurnoTests {

    @Test("A confirmação não guarda contato no aparelho, e o turno abre sem rede")
    func confirmacaoNaoGuardaContato() async throws {
        let api = ApiClienteEmMemoria()
        try await api.entrarDemonstracao(email: "revisao@frila.app", codigo: "codigo-da-revisao")
        let vagaNaLista = try #require(try await api.vagasAbertas().first)
        let vaga = try await api.detalheDaVaga(id: vagaNaLista.id)
        let cache = try criarArmazenamentoLocal()
        let candidatura = CandidaturaViewModel(vaga: vaga, api: api)
        let roteador = RoteadorDoProfissional()
        await roteador.candidatar(viewModel: candidatura)
        guard case let .concluida(.confirmada(turnoID)) = candidatura.estado else {
            Issue.record("A candidatura deveria confirmar o turno")
            return
        }
        let id = try #require(turnoID)
        #expect(try await cache.contato(doTurno: id, em: Date.now) == nil)
        let confirmado = try #require(try await api.meusTurnos().first)
        try await cache.salvar(turnos: [confirmado], em: Date.now)
        let semRede = ApiDubleModoAviao(base: api)
        semRede.semRede = true
        let detalhe = MeuTurnoViewModel(turno: confirmado, api: semRede, fila: cache)
        await detalhe.carregar()
        #expect(detalhe.turno.id == id)
        #expect(detalhe.detalheCarregado)
        #expect(try await cache.contato(doTurno: id, em: Date.now) == nil)
    }

    @Test("O turno vai ao cache sem o contato que trouxer, e volta sem ele")
    func turnoEntraNoCacheSemContato() async throws {
        let agora = Date(timeIntervalSince1970: 1_800_000_000)
        let turno = try criarTurnoConfirmadoComContato(inicio: agora, fim: agora.addingTimeInterval(3_600))
        #expect(turno.contato != nil)
        let cache = try criarArmazenamentoLocal()
        try await cache.salvar(turnos: [turno], em: agora)
        let lidos = try await cache.turnosValidos(em: agora)
        #expect(lidos.map(\.id) == [turno.id])
        #expect(lidos.first?.contato == nil)
        #expect(try await cache.contato(doTurno: turno.id, em: agora) == nil)
    }

    @Test("Contato guardado por uma versão antiga sai do aparelho na primeira leitura dos turnos")
    func contatoLegadoEhApagado() async throws {
        let agora = Date(timeIntervalSince1970: 1_800_000_000)
        let turno = try criarTurnoConfirmadoComContato(inicio: agora, fim: agora.addingTimeInterval(3_600))
        let cache = try criarArmazenamentoLocal()
        try await cache.salvar(turnos: [turno.com(contato: nil)], em: agora)
        try await cache.salvar(contato: #require(turno.contato), doTurno: turno.id)
        #expect(try await cache.contato(doTurno: turno.id, em: agora) != nil)

        let turnos = try await cache.turnosValidos(em: agora)

        #expect(turnos.first?.contato == nil)
        #expect(try await cache.contato(doTurno: turno.id, em: agora) == nil)
    }

    @Test("Abrir Meu turno limpa o contato guardado daquele turno")
    func abrirMeuTurnoLimpaOContatoGuardado() async throws {
        let agora = Date(timeIntervalSince1970: 1_800_000_000)
        let turno = try criarTurnoConfirmadoComContato(inicio: agora, fim: agora.addingTimeInterval(3_600))
        let cache = try criarArmazenamentoLocal()
        try await cache.salvar(turnos: [turno.com(contato: nil)], em: agora)
        try await cache.salvar(contato: #require(turno.contato), doTurno: turno.id)

        let detalhe = MeuTurnoViewModel(turno: turno, api: ApiDubleModoAviao(), fila: cache, relogio: RelogioMutavel(agora))
        await detalhe.carregar()

        #expect(try await cache.contato(doTurno: turno.id, em: agora) == nil)
    }

    @Test("Sair da conta apaga o cache de turnos, inclusive um contato que uma versão antiga deixou")
    func sairApagaContatoGuardado() async throws {
        let agora = Date(timeIntervalSince1970: 1_800_000_000)
        let confirmado = try criarTurnoConfirmadoComContato(inicio: agora, fim: agora.addingTimeInterval(3_600))
        let cache = try criarArmazenamentoLocal()
        try await cache.salvar(contato: #require(confirmado.contato), doTurno: confirmado.id)
        await SaidaDaConta(api: ApiClienteEmMemoria(), armazenamento: cache).sair(tokenFCM: nil)
        #expect(try await cache.contato(doTurno: confirmado.id, em: agora) == nil)
        #expect(try await cache.turnosValidos(em: agora).isEmpty)
    }

    @Test("Banco V2 migra conservando turnos e recusas")
    func migracaoEmDisco() async throws {
        let diretorio = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: diretorio, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: diretorio) }
        let url = diretorio.appending(path: "Turnos.store")
        let agora = Date(timeIntervalSince1970: 1_800_000_000)
        let confirmado = try criarTurnoConfirmadoComContato(inicio: agora, fim: agora.addingTimeInterval(3_600))
        let acao = AcaoPendente(tipo: .checkin, turnoID: confirmado.id, instanteDoToque: agora, chave: UUID())
        let recusa = AcaoRecusada(acao: acao, codigo: .vagaEncerrada)
        do {
            let esquema = Schema(versionedSchema: EsquemaFrilaV2.self)
            let container = try ModelContainer(for: esquema, configurations: [ModelConfiguration("Turnos", schema: esquema, url: url)])
            let context = ModelContext(container)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            context.insert(TurnoPersistido(id: confirmado.id, conteudo: try encoder.encode(confirmado.com(contato: nil)), fim: confirmado.vaga.periodo.fim, contatoVisivelAte: confirmado.contatoVisivelAte, salvoEm: agora))
            context.insert(AcaoRecusadaPersistida(id: recusa.id, conteudo: try JSONEncoder().encode(recusa)))
            try context.save()
        }
        let esquema = Schema(versionedSchema: EsquemaFrilaV4.self)
        let config = ModelConfiguration("Turnos", schema: esquema, url: url)
        let container = try ModelContainer(for: esquema, migrationPlan: MigracaoFrila.self, configurations: [config])
        let cache = ArmazenamentoSwiftData(modelContainer: container)
        #expect(try await cache.turnosValidos(em: agora).first?.id == confirmado.id)
        #expect(try await cache.recusadas() == [recusa])
    }

    @Test("Modo avião de ponta a ponta: lista Meus turnos e detalhe do turno exibem os dados do cache, sem contato")
    func modoAviaoPontaAPontaListaEDetalhe() async throws {
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
        #expect(turnoDaLista.contato == nil)

        // 4. O profissional toca no turno para abrir o detalhe (MeuTurnoViewModel):
        //    O ViewModel recebe o turno do cache e chama carregar() sem rede
        let viewModelDetalhe = MeuTurnoViewModel(turno: turnoDaLista, api: api, relogio: relogio)
        await viewModelDetalhe.carregar()

        // 5. Todos os dados do detalhe continuam legíveis no modo avião, e o mapa segue disponível:
        #expect(viewModelDetalhe.turno.vaga.funcao == "Cozinheiro Chefe")
        #expect(viewModelDetalhe.turno.vaga.local == "Restaurante Asa Norte")
        #expect(viewModelDetalhe.turno.valorAcordado == Dinheiro(centavos: 25000))
        #expect(viewModelDetalhe.turno.vaga.periodo.inicio == agora)
        #expect(viewModelDetalhe.turno.vaga.periodo.fim == fim)
        #expect(viewModelDetalhe.quemRecebeExibicao == "Restaurante Asa Norte")
        #expect(viewModelDetalhe.urlMapas != nil)
        #expect(viewModelDetalhe.observacoesDaVaga == nil)
    }
}
