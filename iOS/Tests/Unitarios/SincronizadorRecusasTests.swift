import Foundation
import FrilaDados
import FrilaDominio
import FrilaApresentacao
import Testing
import SwiftData

private final class ApiPresencaRecusada: ApiClienteEncaminhador, @unchecked Sendable {
    let erro: any Error
    private let trava = NSLock()
    private var envios = 0
    var total: Int { trava.withLock { envios } }
    init(erro: any Error) { self.erro = erro; super.init() }
    override func fazerCheckin(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro {
        trava.withLock { envios += 1 }
        throw erro
    }
    override func fazerCheckout(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro {
        trava.withLock { envios += 1 }
        throw erro
    }
}

@Suite("Recusas definitivas da fila")
struct SincronizadorRecusasTests {
    @Test("Recusa definitiva de presença sai da fila e não volta a ser enviada", arguments: [TipoAcaoPendente.checkin, .checkout], [CodigoErroAPI.vagaEncerrada, .semPermissao, .foraDaJanela, .registroNoFuturo, .campoInvalido, .campoObrigatorio, .naoEncontrado, .contaSuspensa])
    func definitiva(tipo: TipoAcaoPendente, codigo: CodigoErroAPI) async throws {
        let fila = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
        let api = ApiPresencaRecusada(erro: ErroDaApi(codigo: codigo))
        let acao = AcaoPendente(tipo: tipo, turnoID: UUID(), instanteDoToque: .now, chave: UUID())
        try await fila.enfileirar(acao)
        let sincronizador = SincronizadorAcoes(fila: fila, api: api)
        await sincronizador.sincronizar()
        await sincronizador.sincronizar()
        #expect(try await fila.pendentes().isEmpty)
        #expect(api.total == 1)
        #expect(try await fila.recusadas() == [AcaoRecusada(acao: acao, codigo: codigo)])
    }

    @Test("Falhas transitórias mantêm a ação e a chave para nova tentativa", arguments: [TipoAcaoPendente.checkin, .checkout])
    func transitoria(tipo: TipoAcaoPendente) async throws {
        let erros: [any Error] = [ErroDaApi(codigo: .semRede), ErroDaApi(codigo: .desconhecido, codigoOriginal: "http_503"), URLError(.timedOut), ErroDaApi(codigo: .naoAutenticado), ErroDaApi(codigo: .limiteExcedido), ErroDaApi(codigo: .respostaInvalida)]
        for erro in erros {
            let fila = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
            let api = ApiPresencaRecusada(erro: erro)
            let acao = AcaoPendente(tipo: tipo, turnoID: UUID(), instanteDoToque: Date(timeIntervalSince1970: 1_800_000_000), chave: UUID())
            try await fila.enfileirar(acao)
            let sincronizador = SincronizadorAcoes(fila: fila, api: api)
            await sincronizador.sincronizar()
            await sincronizador.sincronizar()
            #expect(try await fila.pendentes() == [acao])
            #expect(api.total == 2)
            #expect(try await fila.recusadas().isEmpty)
        }
    }
}

@Suite("Persistência dos avisos da fila")
struct AvisosDaFilaTests {
    @Test("Recusa fica no banco ao recriar o armazenamento e a limpeza da sessão a apaga")
    func persistenciaELimpeza() async throws {
        let container = try PersistenciaFrila.criarContainer(emMemoria: true)
        let fila = ArmazenamentoSwiftData(modelContainer: container)
        let acao = AcaoPendente(tipo: .checkin, turnoID: UUID(), instanteDoToque: .now, chave: UUID())
        try await fila.enfileirar(acao)
        try await fila.recusar(acao, codigo: .vagaEncerrada)
        let reaberta = ArmazenamentoSwiftData(modelContainer: container)
        #expect(try await reaberta.pendentes().isEmpty)
        #expect(try await reaberta.recusadas() == [AcaoRecusada(acao: acao, codigo: .vagaEncerrada)])
        try await reaberta.enfileirar(acao)
        #expect(try await reaberta.pendentes().isEmpty, "a mesma ação recusada não volta para a fila")
        try await reaberta.limpar()
        #expect(try await reaberta.recusadas().isEmpty)
    }

    @Test("Recusa atrasada de uma sessão limpa não recria dados")
    func sessaoEncerrada() async throws {
        let fila = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
        let acao = AcaoPendente(tipo: .checkin, turnoID: UUID(), instanteDoToque: .now, chave: UUID())
        try await fila.enfileirar(acao)
        try await fila.limpar()
        try await fila.recusar(acao, codigo: .semPermissao)
        #expect(try await fila.pendentes().isEmpty)
        #expect(try await fila.recusadas().isEmpty)
    }

    @Test("Turno cancelado lê a recusa da fila antes da guarda das ações", arguments: [TipoAcaoPendente.checkin, .checkout])
    @MainActor
    func turnoCancelado(tipo: TipoAcaoPendente) async throws {
        let api = ApiClienteEmMemoria(cenario: .turnoCancelado)
        let turno = try #require(try await api.meusTurnos().first)
        let fila = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
        let acao = AcaoPendente(tipo: tipo, turnoID: turno.id, instanteDoToque: .now, chave: UUID())
        try await fila.enfileirar(acao)
        await SincronizadorAcoes(fila: fila, api: api).sincronizar()
        let tela = MeuTurnoViewModel(turno: turno, api: api, fila: fila)
        await tela.carregar()
        #expect(tela.cancelado)
        #expect(tela.presenca == nil)
        #expect(tela.recusasDaFila == [AcaoRecusada(acao: acao, codigo: .vagaEncerrada)])
    }

    @Test("Tela aberta remove o estado pendente quando o servidor recusa o envio")
    @MainActor
    func presencaAberta() async throws {
        let api = ApiClienteEmMemoria()
        let vaga = try #require(try await api.vagasAbertas().first)
        _ = try await api.candidatar(vagaID: vaga.id)
        let turno = try #require(try await api.meusTurnos().first)
        let fila = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
        let acao = AcaoPendente(tipo: .checkin, turnoID: turno.id, instanteDoToque: .now, chave: UUID())
        try await fila.enfileirar(acao)
        let presenca = PresencaDoTurnoViewModel(turno: turno, api: api, localizacao: LeitorDeLocalizacaoSimulado(resultado: .failure(.semSinal)), fila: fila)
        await presenca.restaurarPendentes()
        #expect(presenca.checkin != .naoFeito)
        try await fila.recusar(acao, codigo: .foraDaJanela)
        await presenca.restaurarPendentes()
        #expect(presenca.checkin == .naoFeito)
    }
}

@Suite("Dependência entre check-in e check-out na fila")
struct DependenciaDaFilaTests {
    @Test("Check-out sem check-in na fila recebe recusa definitiva")
    func semCheckinPendente() async throws {
        let fila = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
        let api = ApiPresencaRecusada(erro: ErroDaApi(codigo: .checkinPendente))
        let acao = AcaoPendente(tipo: .checkout, turnoID: UUID(), instanteDoToque: .now, chave: UUID())
        try await fila.enfileirar(acao)
        let sincronizador = SincronizadorAcoes(fila: fila, api: api)
        await sincronizador.sincronizar()
        await sincronizador.sincronizar()
        #expect(api.total == 1)
        #expect(try await fila.pendentes().isEmpty)
        #expect(try await fila.recusadas() == [AcaoRecusada(acao: acao, codigo: .checkinPendente)])
    }

    @Test("Check-out aguarda o check-in que ainda está na fila")
    func comCheckinPendente() async throws {
        let fila = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
        let api = ApiPresencaRecusada(erro: ErroDaApi(codigo: .checkinPendente))
        let turnoID = UUID()
        let instante = Date(timeIntervalSince1970: 1_800_000_000)
        let entrada = AcaoPendente(tipo: .checkin, turnoID: turnoID, instanteDoToque: instante, chave: UUID())
        let saida = AcaoPendente(tipo: .checkout, turnoID: turnoID, instanteDoToque: instante.addingTimeInterval(3_600), chave: UUID())
        try await fila.enfileirar(entrada)
        try await fila.enfileirar(saida)
        await SincronizadorAcoes(fila: fila, api: api).sincronizar()
        #expect(try await fila.pendentes() == [entrada, saida])
        #expect(try await fila.recusadas().isEmpty)
    }
}

@Suite("Migração do banco da fila")
struct MigracaoRecusasTests {
    @Test("Banco anterior migra, conserva a fila e persiste a recusa ao reabrir o arquivo")
    func bancoAnterior() async throws {
        let diretorio = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: diretorio, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: diretorio) }
        let url = diretorio.appending(path: "Teste.store")
        let acao = AcaoPendente(tipo: .checkin, turnoID: UUID(), instanteDoToque: Date(timeIntervalSince1970: 1_800_000_000), chave: UUID())
        // Usa o contexto do esquema antigo diretamente: nele o registro de recusa ainda não existe.
        do {
            let esquema = Schema(EsquemaFrilaV1.models)
            let container = try ModelContainer(for: esquema, configurations: [ModelConfiguration("Teste", schema: esquema, url: url)])
            let context = ModelContext(container)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            context.insert(AcaoPendentePersistida(id: acao.id, tipo: acao.tipo.rawValue, conteudo: try encoder.encode(acao), instanteDoToque: acao.instanteDoToque))
            try context.save()
        }
        let esquema = Schema(versionedSchema: EsquemaFrilaV3.self)
        let config = ModelConfiguration("Teste", schema: esquema, url: url)
        do {
            let container = try ModelContainer(for: esquema, migrationPlan: MigracaoFrila.self, configurations: [config])
            let fila = ArmazenamentoSwiftData(modelContainer: container)
            #expect(try await fila.pendentes() == [acao])
            try await fila.recusar(acao, codigo: .vagaEncerrada)
        }
        let reaberta = ArmazenamentoSwiftData(modelContainer: try ModelContainer(for: esquema, migrationPlan: MigracaoFrila.self, configurations: [config]))
        #expect(try await reaberta.pendentes().isEmpty)
        #expect(try await reaberta.recusadas() == [AcaoRecusada(acao: acao, codigo: .vagaEncerrada)])
    }
}
