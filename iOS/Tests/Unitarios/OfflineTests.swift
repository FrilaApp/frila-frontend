import Foundation
@testable import FrilaDados
import FrilaDominio
import Testing

/// Relógio que o teste avança: é o relógio do aparelho que decide o prazo do contato sem rede.
private final class RelogioAjustavel: Relogio, @unchecked Sendable {
    private let trava = NSLock()
    private var _agora: Date
    init(_ agora: Date) { _agora = agora }
    var agora: Date { trava.withLock { _agora } }
    func ajustar(para instante: Date) { trava.withLock { _agora = instante } }
}

/// Fonte de turnos que o teste liga e desliga da rede.
private final class FonteDeTurnos: @unchecked Sendable {
    private let trava = NSLock()
    private var _semRede = false
    let turnos: [Turno]
    init(_ turnos: [Turno]) { self.turnos = turnos }
    var semRede: Bool {
        get { trava.withLock { _semRede } }
        set { trava.withLock { _semRede = newValue } }
    }
    func buscar() throws -> [Turno] {
        if semRede { throw ErroDaApi(codigo: .semRede) }
        return turnos
    }
}

/// Estados de conexão que o teste empurra, um de cada vez.
private final class MonitorDeTeste: MonitorDeConexao, @unchecked Sendable {
    let sequencia: AsyncStream<Bool>
    let continuacao: AsyncStream<Bool>.Continuation
    init() { (sequencia, continuacao) = AsyncStream<Bool>.makeStream() }
    func estados() -> AsyncStream<Bool> { sequencia }
}

/// Conta os envios da fila, e avisa a cada um, sem `sleep`.
private final class ContadorDeEnvios: @unchecked Sendable {
    private let trava = NSLock()
    private var _total = 0
    let avisos: AsyncStream<Void>
    private let avisar: AsyncStream<Void>.Continuation
    init() { (avisos, avisar) = AsyncStream<Void>.makeStream() }
    var total: Int { trava.withLock { _total } }
    func contar() { trava.withLock { _total += 1 }; avisar.yield() }
}

private func armazenamento() throws -> ArmazenamentoSwiftData {
    ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
}

private func turno(fim: Date) throws -> Turno {
    let inicio = fim.addingTimeInterval(-4 * 3_600)
    let vaga = VagaResumo(id: UUID(), funcao: "Garçom", local: "Asa Sul", regiaoAdministrativa: "Plano Piloto", periodo: try Periodo(inicio: inicio, fim: fim), valor: Dinheiro(centavos: 15000))
    let reputacao = Reputacao(positivas: 0, total: 0, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0)
    let visivelAte = fim.addingTimeInterval(7 * 24 * 3_600)
    let contato = Contato(nome: "Bistrô", telefone: "+5561999990000", whatsappURL: try #require(URL(string: "https://wa.me/5561999990000")), visivelAte: visivelAte)
    return Turno(
        id: UUID(), posicaoID: UUID(), vaga: vaga,
        contraparte: PerfilPublico(id: UUID(), tipo: .estabelecimento, nome: "Bistrô", reputacao: reputacao),
        contatoVisivelAte: visivelAte, verificacao: .pendente, valorAcordado: vaga.valor, podeAvaliar: false,
        contato: contato
    )
}

@Suite("Cache e fila offline (#111)")
struct OfflineTests {
    @Test("Modo avião: Meus turnos devolve os turnos da última leitura com rede, com o contato")
    func modoAviao() async throws {
        let agora = Date(timeIntervalSince1970: 1_800_000_000)
        let confirmado = try turno(fim: agora.addingTimeInterval(3 * 3_600))
        let fonte = FonteDeTurnos([confirmado])
        let repositorio = TurnosComCache(buscar: { try fonte.buscar() }, cache: try armazenamento(), relogio: RelogioAjustavel(agora))

        let comRede = try await repositorio.ler()
        #expect(comRede.origem == .rede)

        fonte.semRede = true
        let semRede = try await repositorio.ler()
        #expect(semRede.origem == .cache)
        #expect(semRede.turnos.map(\.id) == [confirmado.id])
        #expect(semRede.turnos.first?.contato != nil)
    }

    @Test("Sem rede e com o relógio 8 dias depois do fim, o contato não aparece")
    func contatoSomeOffline() async throws {
        let fim = Date(timeIntervalSince1970: 1_800_000_000)
        let relogio = RelogioAjustavel(fim.addingTimeInterval(-3_600))
        let fonte = FonteDeTurnos([try turno(fim: fim)])
        let repositorio = TurnosComCache(buscar: { try fonte.buscar() }, cache: try armazenamento(), relogio: relogio)
        _ = try await repositorio.ler()

        fonte.semRede = true
        relogio.ajustar(para: fim.addingTimeInterval(8 * 24 * 3_600))
        let leitura = try await repositorio.ler()

        #expect(leitura.origem == .cache)
        #expect(leitura.turnos.allSatisfy { $0.contato == nil })
        // O turno sai do cache 24 h depois do fim: com 8 dias, já nem está lá.
        #expect(leitura.turnos.isEmpty)
    }

    @Test("Erro que não é falta de rede sobe, em vez de mostrar o cache de uma sessão encerrada")
    func quatroZeroUmNaoCaiNoCache() async throws {
        let cache = try armazenamento()
        let agora = Date(timeIntervalSince1970: 1_800_000_000)
        try await cache.salvar(turnos: [try turno(fim: agora.addingTimeInterval(3_600))], em: agora)
        let repositorio = TurnosComCache(buscar: { throw ErroDaApi(codigo: .naoAutenticado) }, cache: cache, relogio: RelogioAjustavel(agora))

        await #expect(throws: ErroDaApi(codigo: .naoAutenticado)) { _ = try await repositorio.ler() }
    }

    @Test("Check-in feito sem rede sai quando a conexão volta, com o instante do toque")
    func filaSaiAoReconectar() async throws {
        let api = ApiClienteEmMemoria()
        try await api.entrarDemonstracao(email: "revisao@frila.app", codigo: "codigo-da-revisao")
        let vaga = try #require(try await api.vagasAbertas().first)
        let turnoID = try #require(try await api.candidatar(vagaID: vaga.id).turnoID)
        let fila = try armazenamento()
        // A fila guarda o instante em ISO-8601, em segundos inteiros: é a precisão que vai ao servidor.
        let toque = Date(timeIntervalSince1970: (Date.now.timeIntervalSince1970 - 1_800).rounded(.down))
        try await fila.enfileirar(AcaoPendente(tipo: .checkin, turnoID: turnoID, instanteDoToque: toque, chave: UUID(), distanciaMetros: 120))

        let monitor = MonitorDeTeste()
        let reenvio = ReenvioAoReconectar(monitor: monitor, sincronizador: SincronizadorAcoes(fila: fila, api: api))
        let acompanhamento = Task { await reenvio.acompanhar() }
        monitor.continuacao.yield(false)
        monitor.continuacao.yield(true)
        monitor.continuacao.finish()
        await acompanhamento.value

        #expect(try await fila.pendentes().isEmpty)
        // O dublê é idempotente pelo turno: repetir devolve o registro gravado, com o instante enviado.
        let gravado = try await api.fazerCheckin(turnoID: turnoID, distanciaMetros: 120, registradoEm: .now)
        #expect(gravado.registradoEm == toque)
    }

    @Test("Check-out feito sem rede sai quando a conexão volta, com o instante do toque")
    func checkoutFilaSaiAoReconectar() async throws {
        let api = ApiClienteEmMemoria()
        try await api.entrarDemonstracao(email: "revisao@frila.app", codigo: "codigo-da-revisao")
        let vaga = try #require(try await api.vagasAbertas().first)
        let turnoID = try #require(try await api.candidatar(vagaID: vaga.id).turnoID)
        let antes = Date(timeIntervalSince1970: (Date.now.timeIntervalSince1970 - 3_600).rounded(.down))
        _ = try await api.fazerCheckin(turnoID: turnoID, distanciaMetros: 150, registradoEm: antes)

        let fila = try armazenamento()
        // A fila guarda o instante em ISO-8601, em segundos inteiros: é a precisão que vai ao servidor.
        let toque = Date(timeIntervalSince1970: (Date.now.timeIntervalSince1970 - 1_800).rounded(.down))
        try await fila.enfileirar(AcaoPendente(tipo: .checkout, turnoID: turnoID, instanteDoToque: toque, chave: UUID(), distanciaMetros: 150))

        let monitor = MonitorDeTeste()
        let reenvio = ReenvioAoReconectar(monitor: monitor, sincronizador: SincronizadorAcoes(fila: fila, api: api))
        let acompanhamento = Task { await reenvio.acompanhar() }
        monitor.continuacao.yield(false)
        monitor.continuacao.yield(true)
        monitor.continuacao.finish()
        await acompanhamento.value

        #expect(try await fila.pendentes().isEmpty)
        // O dublê é idempotente pelo turno: repetir devolve o registro gravado, com o instante enviado.
        let gravado = try await api.fazerCheckout(turnoID: turnoID, distanciaMetros: 150, registradoEm: .now)
        #expect(gravado.registradoEm == toque)
        #expect(gravado.distanciaMetros == 150)
    }

    @Test("A fila só sai na passagem para conectado, não a cada aviso de conexão")
    func soNaPassagemParaConectado() async {
        let monitor = MonitorDeTeste()
        let contador = ContadorDeEnvios()
        let reenvio = ReenvioAoReconectar(monitor: monitor) { contador.contar() }
        let acompanhamento = Task { await reenvio.acompanhar() }
        for estado in [true, true, false, false, true] { monitor.continuacao.yield(estado) }
        monitor.continuacao.finish()
        await acompanhamento.value
        #expect(contador.total == 2)
    }

    @Test("Sair da conta apaga o cache e a fila")
    func sairApaga() async throws {
        let agora = Date.now
        let local = try armazenamento()
        try await local.salvar(turnos: [try turno(fim: agora.addingTimeInterval(3_600))], em: agora)
        try await local.enfileirar(AcaoPendente(tipo: .checkout, turnoID: UUID(), instanteDoToque: agora, chave: UUID()))
        DestinoGuardado.salvar(.profissional)

        await SaidaDaConta(api: ApiClienteEmMemoria(), armazenamento: local).sair(tokenFCM: nil)

        #expect(try await local.turnosValidos(em: agora).isEmpty)
        #expect(try await local.pendentes().isEmpty)
        #expect(DestinoGuardado.obter() == nil)
    }

    @Test("Sessão encerrada sem a pessoa pedir também apaga o cache e a fila")
    func encerramentoApaga() async throws {
        let agora = Date.now
        let local = try armazenamento()
        try await local.salvar(turnos: [try turno(fim: agora.addingTimeInterval(3_600))], em: agora)
        try await local.enfileirar(AcaoPendente(tipo: .avaliacao, turnoID: UUID(), instanteDoToque: agora, chave: UUID(), resposta: true))
        DestinoGuardado.salvar(.profissional)

        let (encerramentos, avisar) = AsyncStream<Void>.makeStream()
        let observador = ObservadorDeTeste(encerramentos)
        let saida = SaidaDaConta(api: ApiClienteEmMemoria(), armazenamento: local)
        let acompanhamento = Task { await saida.acompanharEncerramentos(de: observador) }
        avisar.yield()
        avisar.finish()
        await acompanhamento.value

        #expect(try await local.turnosValidos(em: agora).isEmpty)
        #expect(try await local.pendentes().isEmpty)
        #expect(DestinoGuardado.obter() == nil)
    }
}

private struct ObservadorDeTeste: ObservadorDeSessao {
    let sequencia: AsyncStream<Void>
    init(_ sequencia: AsyncStream<Void>) { self.sequencia = sequencia }
    func encerramentos() -> AsyncStream<Void> { sequencia }
}
