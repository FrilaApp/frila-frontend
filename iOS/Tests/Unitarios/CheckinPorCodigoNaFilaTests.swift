import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

/// R1 do Lince (parecer do #726): o check-in feito sem rede, com a chave `checkin_por_codigo` ligada, sai da
/// fila com os sinais da leitura, e a proteção por risco não se perde em modo avião. As ações guardadas antes
/// do campo `sinais` ainda se leem.

private final class RelogioDoDuble: Relogio, @unchecked Sendable {
    private let trava = NSLock()
    private var _agora = Date(timeIntervalSince1970: 1_791_000_000)
    var agora: Date { trava.withLock { _agora } }
}

private let turnoDoProfissional = UUID(uuidString: "24000000-0000-0000-0000-000000000001")!

private final class ApiSemRedeNoCheckin: ApiClienteEncaminhador, @unchecked Sendable {
    override func fazerCheckin(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro {
        throw ErroDaApi(codigo: .semRede)
    }
}

private actor FilaEmMemoriaDeTeste: FilaDeAcoes {
    func recusar(_ acao: AcaoPendente, codigo: CodigoErroAPI) async throws { try await remover(id: acao.id) }
    func recusadas() -> [AcaoRecusada] { [] }

    var itens: [AcaoPendente] = []
    func enfileirar(_ acao: AcaoPendente) throws { itens.append(acao) }
    func pendentes() throws -> [AcaoPendente] { itens }
    func remover(id: UUID) throws { itens.removeAll { $0.id == id } }
    func limpar() throws { itens.removeAll() }
}

@Suite("Check-in por código: a fila offline leva os sinais")
@MainActor
struct CheckinPorCodigoNaFilaTests {
    private let agora = Date(timeIntervalSince1970: 1_791_000_000)
    private let ponto = try! Coordenada(latitude: -15.8267, longitude: -47.9218)
    private struct RelogioFixo: Relogio { let agora: Date }

    private func turno() throws -> Turno {
        let vaga = VagaResumo(
            id: UUID(), funcao: "Garçom", local: "Bar do Lago", regiaoAdministrativa: "Plano Piloto",
            periodo: try Periodo(inicio: agora.addingTimeInterval(-600), fim: agora.addingTimeInterval(4 * 3_600)), valor: Dinheiro(centavos: 15000)
        )
        let reputacao = Reputacao(positivas: 10, total: 10, taxaComparecimento: nil, turnosConsiderados: 10, turnosRealizados: 10)
        return Turno(
            id: UUID(), posicaoID: UUID(), vaga: vaga,
            contraparte: PerfilPublico(id: UUID(), tipo: .estabelecimento, nome: "Bar do Lago", reputacao: reputacao),
            contatoVisivelAte: agora.addingTimeInterval(24 * 3_600), verificacao: .pendente, valorAcordado: vaga.valor, podeAvaliar: false, contato: nil
        )
    }

    private func modelo(
        api: any ApiCliente, leitura: LeituraDeLocalizacao, recursos: RecursosDoApp, fila: any FilaDeAcoes
    ) throws -> PresencaDoTurnoViewModel {
        let leitor = LeitorDeLocalizacaoSimulado(permissao: .aoUsarPrecisa, resultado: .success(leitura))
        return PresencaDoTurnoViewModel(
            turno: try turno(), api: api, localizacao: leitor, fila: fila, relogio: RelogioFixo(agora: agora), pontoDaVaga: ponto,
            recursos: { recursos }
        )
    }

    private func perto(simulada: Bool) -> LeituraDeLocalizacao {
        let base = LeitorDeLocalizacaoSimulado.leitura(a: 50, de: ponto)
        return LeituraDeLocalizacao(coordenada: base.coordenada, precisaoHorizontalMetros: 10, simulada: simulada)
    }

    @Test("o check-in sem rede, com a chave ligada, entra na fila com os sinais da leitura")
    func filaGuardaOsSinais() async throws {
        let fila = FilaEmMemoriaDeTeste()
        let m = try modelo(
            api: ApiSemRedeNoCheckin(), leitura: perto(simulada: true), recursos: RecursosDoApp(checkinPorCodigo: true), fila: fila
        )
        await m.iniciar(.checkin)
        let acao = try #require(await fila.itens.first)
        #expect(acao.tipo == .checkin)
        #expect(acao.sinais == SinaisDoCheckin(localizacaoSimulada: true, precisaoMetros: 10, saltoDePosicao: false))
    }

    @Test("com a chave desligada, a ação da fila sai sem sinais, como hoje")
    func filaSemChaveSemSinais() async throws {
        let fila = FilaEmMemoriaDeTeste()
        let m = try modelo(api: ApiSemRedeNoCheckin(), leitura: perto(simulada: true), recursos: .desligados, fila: fila)
        await m.iniciar(.checkin)
        let acao = try #require(await fila.itens.first)
        #expect(acao.sinais == nil)
    }

    @Test("o sincronizador manda os sinais guardados no reenvio, e a ação antiga segue sem sinais")
    func sincronizadorMandaOsSinais() async throws {
        let fila = FilaEmMemoriaDeTeste()
        let relogio = RelogioDoDuble()
        let base = ApiClienteEmMemoria(cenario: .checkinPorCodigo, relogio: relogio)
        let api = ApiClienteEncaminhador(base: base)
        let sinais = SinaisDoCheckin(localizacaoSimulada: true, precisaoMetros: 12, saltoDePosicao: true)
        try await fila.enfileirar(AcaoPendente(
            tipo: .checkin, turnoID: turnoDoProfissional, instanteDoToque: relogio.agora, chave: UUID(), distanciaMetros: 50, sinais: sinais
        ))
        await SincronizadorAcoes(fila: fila, api: api).sincronizar()
        #expect(api.sinaisDoCheckin == [sinais])
        #expect(await fila.itens.isEmpty)

        let antiga = ApiClienteEncaminhador(base: ApiClienteEmMemoria(cenario: .checkinPorCodigo, relogio: relogio))
        try await fila.enfileirar(AcaoPendente(
            tipo: .checkin, turnoID: turnoDoProfissional, instanteDoToque: relogio.agora, chave: UUID(), distanciaMetros: 50
        ))
        await SincronizadorAcoes(fila: fila, api: antiga).sincronizar()
        #expect(antiga.sinaisDoCheckin == [nil])
    }

    @Test("a ação guardada antes do campo sinais ainda se lê, sem sinais; e o campo sobrevive à gravação")
    func decodificacaoTolerante() throws {
        let antiga = """
        {"id":"11111111-1111-1111-1111-111111111111","tipo":"checkin","turnoID":"24000000-0000-0000-0000-000000000001",
         "instanteDoToque":"2026-11-09T10:00:00Z","chave":"22222222-2222-2222-2222-222222222222","distanciaMetros":50}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let lida = try decoder.decode(AcaoPendente.self, from: Data(antiga.utf8))
        #expect(lida.sinais == nil)
        #expect(lida.distanciaMetros == 50)

        let sinais = SinaisDoCheckin(localizacaoSimulada: false, precisaoMetros: nil, saltoDePosicao: true)
        let acao = AcaoPendente(tipo: .checkin, turnoID: turnoDoProfissional, instanteDoToque: agora, chave: UUID(), sinais: sinais)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let volta = try decoder.decode(AcaoPendente.self, from: try encoder.encode(acao))
        #expect(volta.sinais == sinais)
        #expect(acao.com(contaID: UUID()).sinais == sinais, "trocar o autor não perde os sinais")
    }

    @Test("a precisão enorme tem teto, e a que o aparelho não informa sai nula")
    func tetoDaPrecisao() throws {
        let c = try Coordenada(latitude: -15.8, longitude: -47.9)
        #expect(SinaisDoCheckin(leitura: LeituraDeLocalizacao(coordenada: c, precisaoHorizontalMetros: 1e30)).precisaoMetros == 100_000)
        #expect(SinaisDoCheckin(leitura: LeituraDeLocalizacao(coordenada: c, precisaoHorizontalMetros: 99_999.4)).precisaoMetros == 99_999)
        #expect(SinaisDoCheckin(leitura: LeituraDeLocalizacao(coordenada: c, precisaoHorizontalMetros: -1)).precisaoMetros == nil)
    }
}
