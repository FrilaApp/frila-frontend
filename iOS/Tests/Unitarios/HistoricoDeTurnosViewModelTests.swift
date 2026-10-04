import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

@MainActor
@Suite("Histórico de turnos: view model (#23)")
struct HistoricoDeTurnosViewModelTests {
    /// 03/10/2026, 12:00 em São Paulo.
    static let agora = ContratoAPI.instante("2026-10-03T15:00:00Z")!

    private final class DubleExportarTurnos: ApiClienteEncaminhador, @unchecked Sendable {
        private let trava = NSLock()
        private var _pedidos: [PedidoExportacaoTurnos] = []
        private var respostas: [Result<ResultadoExportacaoTurnos, ErroDaApi>]
        var atrasoEmNanosegundos: UInt64?

        var pedidos: [PedidoExportacaoTurnos] { trava.withLock { _pedidos } }

        /// Uma resposta por chamada, na ordem; a última se repete.
        init(_ respostas: Result<ResultadoExportacaoTurnos, ErroDaApi>...) {
            self.respostas = respostas
            super.init(base: ApiClienteEmMemoria())
        }

        override func exportarTurnos(_ pedido: PedidoExportacaoTurnos) async throws -> ResultadoExportacaoTurnos {
            let resposta = trava.withLock {
                _pedidos.append(pedido)
                return respostas.count > 1 ? respostas.removeFirst() : respostas[0]
            }
            if let atrasoEmNanosegundos { try? await Task.sleep(nanoseconds: atrasoEmNanosegundos) }
            return try resposta.get()
        }
    }

    private static func diretorio() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func modelo(
        _ api: any ApiCliente,
        estabelecimentoID: UUID? = nil,
        agora: Date = agora,
        diretorio: URL
    ) -> HistoricoDeTurnosViewModel {
        HistoricoDeTurnosViewModel(api: api, estabelecimentoID: estabelecimentoID, relogio: RelogioFixo(agora: agora), diretorioTemporario: diretorio)
    }

    @Test("Nome do arquivo: frila-turnos-AAAA-MM-DD_AAAA-MM-DD com a extensão do formato")
    func nomeDoArquivo() throws {
        let periodo = try PeriodoDeExportacao(de: DataCivil("2026-10-01"), ate: DataCivil("2026-10-31"))
        #expect(HistoricoDeTurnosViewModel.nomeDoArquivo(periodo: periodo, formato: .csv) == "frila-turnos-2026-10-01_2026-10-31.csv")
        #expect(HistoricoDeTurnosViewModel.nomeDoArquivo(periodo: periodo, formato: .pdf) == "frila-turnos-2026-10-01_2026-10-31.pdf")
    }

    @Test("Profissional, CSV: pede este mês sem estabelecimento e entrega ao compartilhar o arquivo intacto, com o nome do período")
    func exportaCSVDoProfissional() async throws {
        let csv = try FixturesDoContrato.arquivo("exportar-turnos", extensao: "csv")
        let duble = DubleExportarTurnos(.success(.arquivo(csv)))
        let diretorio = try Self.diretorio()
        defer { try? FileManager.default.removeItem(at: diretorio) }
        let vm = Self.modelo(duble, diretorio: diretorio)

        await vm.exportar()

        let pedido = try #require(duble.pedidos.first)
        #expect(pedido.periodo == (try PeriodoDeExportacao(de: DataCivil("2026-10-01"), ate: DataCivil("2026-10-03"))))
        #expect(pedido.formato == .csv)
        #expect(pedido.estabelecimentoID == nil)
        #expect(vm.estado == .ocioso)
        #expect(vm.mostrarFolhaCompartilhamento)
        let url = try #require(vm.arquivoParaCompartilhar)
        #expect(url.lastPathComponent == "frila-turnos-2026-10-01_2026-10-03.csv")
        #expect(try Data(contentsOf: url) == csv)

        vm.folhaCompartilhamentoFechada()
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(vm.arquivoParaCompartilhar == nil)
    }

    @Test("Contratante, PDF do mês passado: manda o estabelecimento e o PDF chega intacto")
    func exportaPDFDoContratante() async throws {
        let pdf = try FixturesDoContrato.arquivo("exportar-turnos", extensao: "pdf")
        let duble = DubleExportarTurnos(.success(.arquivo(pdf)))
        let diretorio = try Self.diretorio()
        defer { try? FileManager.default.removeItem(at: diretorio) }
        let estabelecimento = UUID()
        let vm = Self.modelo(duble, estabelecimentoID: estabelecimento, diretorio: diretorio)

        vm.escolher(.mesPassado)
        vm.escolher(formato: .pdf)
        await vm.exportar()

        let pedido = try #require(duble.pedidos.first)
        #expect(pedido.estabelecimentoID == estabelecimento)
        #expect(pedido.formato == .pdf)
        #expect(pedido.periodo == (try PeriodoDeExportacao(de: DataCivil("2026-09-01"), ate: DataCivil("2026-09-30"))))
        let url = try #require(vm.arquivoParaCompartilhar)
        #expect(url.lastPathComponent == "frila-turnos-2026-09-01_2026-09-30.pdf")
        #expect(try Data(contentsOf: url) == pdf)
        vm.folhaCompartilhamentoFechada()
    }

    @Test("204: mostra que não há turnos, não grava arquivo e não abre o compartilhar")
    func semTurnos() async throws {
        let duble = DubleExportarTurnos(.success(.semTurnos))
        let diretorio = try Self.diretorio()
        defer { try? FileManager.default.removeItem(at: diretorio) }
        let vm = Self.modelo(duble, diretorio: diretorio)

        await vm.exportar()

        #expect(vm.estado == .semTurnos)
        #expect(!vm.mostrarFolhaCompartilhamento)
        #expect(vm.arquivoParaCompartilhar == nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: diretorio.path).isEmpty)
    }

    @Test("Sem rede: mensagem de conexão e Tentar novamente; a nova tentativa entrega o arquivo")
    func semRedeETentarNovamente() async throws {
        let csv = Data("data\n".utf8)
        let duble = DubleExportarTurnos(.failure(ErroDaApi(codigo: .semRede)), .success(.arquivo(csv)))
        let diretorio = try Self.diretorio()
        defer { try? FileManager.default.removeItem(at: diretorio) }
        let vm = Self.modelo(duble, diretorio: diretorio)

        await vm.exportar()
        #expect(vm.estado == .erro(mensagem: "Sem conexão. Tente novamente quando a internet voltar.", repetivel: true))
        #expect(!vm.mostrarFolhaCompartilhamento)

        await vm.exportar()
        #expect(vm.estado == .ocioso)
        #expect(vm.mostrarFolhaCompartilhamento)
        #expect(duble.pedidos.count == 2)
        vm.folhaCompartilhamentoFechada()
    }

    @Test("Erro do servidor pode ser repetido; sessão vencida e falta de permissão, não")
    func errosRepetiveis() async throws {
        let diretorio = try Self.diretorio()
        defer { try? FileManager.default.removeItem(at: diretorio) }
        let casos: [(ErroDaApi, Bool)] = [
            (ErroDaApi(codigo: .desconhecido), true),
            (ErroDaApi(codigo: .respostaInvalida), true),
            (ErroDaApi(codigo: .naoAutenticado), false),
            (ErroDaApi(codigo: .semPermissao), false),
        ]
        for (erro, repetivel) in casos {
            let vm = Self.modelo(DubleExportarTurnos(.failure(erro)), diretorio: diretorio)
            await vm.exportar()
            #expect(vm.estado == .erro(mensagem: MensagemDoErroAPI.texto(erro), repetivel: repetivel))
        }
    }

    @Test("Às 22:30 de 31/10 em São Paulo já é 01/11 em UTC, e este mês continua sendo outubro")
    func hojeEmSaoPaulo() throws {
        let diretorio = try Self.diretorio()
        defer { try? FileManager.default.removeItem(at: diretorio) }
        let vm = Self.modelo(DubleExportarTurnos(.success(.semTurnos)), agora: try #require(ContratoAPI.instante("2026-11-01T01:30:00Z")), diretorio: diretorio)

        #expect(vm.periodo == (try PeriodoDeExportacao(de: DataCivil("2026-10-01"), ate: DataCivil("2026-10-31"))))
        vm.escolher(.mesPassado)
        #expect(vm.periodo == (try PeriodoDeExportacao(de: DataCivil("2026-09-01"), ate: DataCivil("2026-09-30"))))
    }

    @Test("Intervalo livre: o fim não passa de hoje, e o início nunca fica depois do fim")
    func intervaloLivre() async throws {
        let diretorio = try Self.diretorio()
        defer { try? FileManager.default.removeItem(at: diretorio) }
        let duble = DubleExportarTurnos(.success(.semTurnos))
        let vm = Self.modelo(duble, diretorio: diretorio)
        vm.escolher(.intervalo)
        #expect(vm.periodo == (try PeriodoDeExportacao(de: DataCivil("2026-10-01"), ate: DataCivil("2026-10-03"))))

        vm.escolher(fim: Self.agora.addingTimeInterval(10 * 24 * 3600))
        #expect(vm.fimEscolhido == Self.agora)

        vm.escolher(inicio: try #require(ContratoAPI.instante("2026-09-20T15:00:00Z")))
        vm.escolher(fim: try #require(ContratoAPI.instante("2026-09-10T15:00:00Z")))
        #expect(vm.periodo == (try PeriodoDeExportacao(de: DataCivil("2026-09-10"), ate: DataCivil("2026-09-10"))))

        vm.escolher(inicio: try #require(ContratoAPI.instante("2026-09-05T15:00:00Z")))
        await vm.exportar()
        #expect(duble.pedidos.last?.periodo == (try PeriodoDeExportacao(de: DataCivil("2026-09-05"), ate: DataCivil("2026-09-10"))))
    }

    @Test("Mudar o período ou o formato apaga o aviso do pedido anterior")
    func mudarOPedidoApagaOAviso() async throws {
        let diretorio = try Self.diretorio()
        defer { try? FileManager.default.removeItem(at: diretorio) }
        let vm = Self.modelo(DubleExportarTurnos(.success(.semTurnos)), diretorio: diretorio)

        await vm.exportar()
        #expect(vm.estado == .semTurnos)
        vm.escolher(.mesPassado)
        #expect(vm.estado == .ocioso)

        await vm.exportar()
        vm.escolher(formato: .pdf)
        #expect(vm.estado == .ocioso)
    }

    @Test("Toque duplo: a segunda chamada durante o envio não pede de novo")
    func toqueDuplo() async throws {
        let diretorio = try Self.diretorio()
        defer { try? FileManager.default.removeItem(at: diretorio) }
        let duble = DubleExportarTurnos(.success(.semTurnos))
        duble.atrasoEmNanosegundos = 100_000_000
        let vm = Self.modelo(duble, diretorio: diretorio)

        async let primeira: () = vm.exportar()
        async let segunda: () = vm.exportar()
        _ = await (primeira, segunda)

        #expect(duble.pedidos.count == 1)
    }

    @Test("Antes de gravar, apaga só os relatórios de turnos esquecidos no diretório temporário")
    func limpaArquivosAntigos() async throws {
        let diretorio = try Self.diretorio()
        defer { try? FileManager.default.removeItem(at: diretorio) }
        let antigo = diretorio.appendingPathComponent("frila-turnos-2026-01-01_2026-01-31.pdf")
        let alheio = diretorio.appendingPathComponent("frila-meus-dados-2026-10-03.json")
        try Data("x".utf8).write(to: antigo)
        try Data("y".utf8).write(to: alheio)
        let vm = Self.modelo(DubleExportarTurnos(.success(.arquivo(Data("data\n".utf8)))), diretorio: diretorio)

        await vm.exportar()

        #expect(!FileManager.default.fileExists(atPath: antigo.path))
        #expect(FileManager.default.fileExists(atPath: alheio.path))
        vm.folhaCompartilhamentoFechada()
    }
}
