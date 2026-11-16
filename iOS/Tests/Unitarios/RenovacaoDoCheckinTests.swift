import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

private final class RelogioDaRenovacao: Relogio, @unchecked Sendable {
    private let trava = NSLock()
    private var instante: Date
    init(_ instante: Date) { self.instante = instante }
    var agora: Date { trava.withLock { instante } }
    func avancar(_ segundos: TimeInterval) { trava.withLock { instante += segundos } }
}

/// Só o contrato da renovação: o dublê geral ainda retorna o primeiro check-in por idempotência.
private final class ApiDaRenovacao: ApiClienteEncaminhador, @unchecked Sendable {
    private let trava = NSLock()
    private let chegadaOriginal: Date
    private var envios: [(Date, Int?)] = []
    init(chegadaOriginal: Date) { self.chegadaOriginal = chegadaOriginal; super.init() }
    var toques: [Date] { trava.withLock { envios.map(\.0) } }
    var distancias: [Int?] { trava.withLock { envios.map(\.1) } }

    override func fazerCheckin(
        turnoID: UUID, distanciaMetros: Int?, registradoEm: Date, sinais: SinaisDoCheckin?
    ) async throws -> ResultadoRegistro {
        trava.withLock { envios.append((registradoEm, distanciaMetros)) }
        return ResultadoRegistro(
            turnoID: turnoID, tipo: .manual, verificacao: .pendente,
            registradoEm: chegadaOriginal, distanciaMetros: distanciaMetros,
            codigoExigido: true, codigoDisponivel: distanciaMetros.map { $0 <= 50 } ?? false
        )
    }
}

@MainActor
@Suite("Recuperação da chegada pendente pelo profissional")
struct RenovacaoDoCheckinTests {
    private let inicio = Date(timeIntervalSince1970: 1_791_000_000)

    private func cena(
        verificacao: Verificacao = .pendente, codigoLigado: Bool = true, distancia: Int? = 70
    ) async throws -> (PresencaDoTurnoViewModel, ApiDaRenovacao, RelogioDaRenovacao) {
        let relogio = RelogioDaRenovacao(inicio.addingTimeInterval(600))
        let chegada = inicio.addingTimeInterval(300)
        let vaga = VagaResumo(
            id: UUID(), funcao: "Garçom", local: "Casa sintética", regiaoAdministrativa: "Plano Piloto",
            periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(3_600)),
            valor: Dinheiro(centavos: 15_000)
        )
        let turno = Turno(
            id: UUID(), posicaoID: UUID(), vaga: vaga,
            contraparte: PerfilPublico(
                id: UUID(), tipo: .estabelecimento, nome: "Casa sintética",
                reputacao: Reputacao(positivas: 0, total: 0, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0)
            ),
            contatoVisivelAte: inicio.addingTimeInterval(86_400),
            checkin: Presenca(instante: chegada, tipo: .manual, distanciaMetros: distancia),
            verificacao: verificacao, valorAcordado: vaga.valor, podeAvaliar: false
        )
        let api = ApiDaRenovacao(chegadaOriginal: chegada)
        let ponto = try Coordenada(latitude: -15.8267, longitude: -47.9218)
        let vm = PresencaDoTurnoViewModel(
            turno: turno, api: api,
            localizacao: LeitorDeLocalizacaoSimulado(resultado: .success(LeitorDeLocalizacaoSimulado.leitura(a: 30, de: ponto))),
            relogio: relogio, pontoDaVaga: ponto,
            recursos: { RecursosDoApp(checkinPorCodigo: codigoLigado) }
        )
        await vm.carregarRecursos()
        return (vm, api, relogio)
    }

    @Test("Chegada registrada longe ou sem GPS permite novo toque perto sem esconder o check-out", arguments: [70, nil] as [Int?])
    func aproximaNovamente(distancia: Int?) async throws {
        let (vm, api, relogio) = try await cena(distancia: distancia)
        #expect(vm.podeFazerCheckin)
        #expect(vm.podeFazerCheckout)
        #expect(!vm.podeLerOCodigo)
        await vm.iniciar(.checkin)
        #expect(api.distancias == [30])
        #expect(api.toques == [relogio.agora])
        #expect(vm.podeLerOCodigo)
        #expect(vm.verificacao == .pendente)
        if case let .registrado(feito) = vm.checkin {
            #expect(feito.instante == inicio.addingTimeInterval(300))
        } else { Issue.record("A renovação perdeu a chegada já registrada") }
    }

    @Test("Evidência antiga e cache desconhecido não impedem renovar a aproximação")
    func renovaDepoisDeQuinzeMinutos() async throws {
        let (vm, api, relogio) = try await cena(distancia: 30)
        relogio.avancar(901)
        #expect(vm.codigoDisponivel == nil)
        #expect(vm.podeFazerCheckin)
        await vm.iniciar(.checkin)
        #expect(api.toques == [relogio.agora])
        #expect(vm.podeLerOCodigo)
    }

    @Test("Renovação respeita a borda do fim do turno, sem folga extra")
    func janela() async throws {
        let (vm, api, relogio) = try await cena()
        relogio.avancar(3_000)
        #expect(vm.podeFazerCheckin)
        relogio.avancar(1)
        #expect(!vm.podeFazerCheckin)
        await vm.iniciar(.checkin)
        #expect(api.toques.isEmpty)
        #expect(vm.podeFazerCheckout)
    }

    @Test("Chave desligada ou presença já verificada não renovam", arguments: [false, true])
    func preservaLegadoEVerificado(verificado: Bool) async throws {
        let (vm, api, _) = try await cena(verificacao: verificado ? .verificado : .pendente, codigoLigado: verificado)
        #expect(!vm.podeFazerCheckin)
        await vm.iniciar(.checkin)
        #expect(api.toques.isEmpty)
    }
}
