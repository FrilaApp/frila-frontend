import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

private struct ErroQualquer: Error {}

private struct RelogioFixo: Relogio {
    let agora: Date
}

/// Espia o que a folha manda à API: qual RPC e com que motivo.
private final class ApiDeCancelamento: ApiClienteEncaminhador, @unchecked Sendable {
    private let trava = NSLock()
    private var _posicoes: [(id: UUID, motivo: String)] = []
    private var _vagas: [(id: UUID, motivo: String)] = []
    var erro: Error?

    var posicoes: [(id: UUID, motivo: String)] { trava.withLock { _posicoes } }
    var vagas: [(id: UUID, motivo: String)] { trava.withLock { _vagas } }

    override func cancelarPosicao(id: UUID, motivo: String) async throws -> ResultadoCancelamento {
        trava.withLock { _posicoes.append((id, motivo)) }
        if let erro { throw erro }
        return ResultadoCancelamento(posicaoID: id, falta: false, reaberta: true, novaPosicaoID: UUID())
    }

    override func cancelarVaga(id: UUID, motivo: String) async throws -> VagaCancelada {
        trava.withLock { _vagas.append((id, motivo)) }
        if let erro { throw erro }
        return VagaCancelada(vagaID: id, estado: .cancelada, posicoesCanceladas: 2)
    }
}

/// As duas folhas montadas pela API, como o app as monta (#20): a da posição chama
/// `cancelar_posicao`, a da vaga inteira chama `cancelar_vaga`, cada uma com o motivo escolhido.
@MainActor
@Suite("Cancelamento pela API: posição e vaga inteira, com o motivo")
struct CancelamentoPelaApiTests {
    private let agora = Date(timeIntervalSince1970: 1_790_000_000)

    private func periodo() throws -> Periodo {
        let inicio = agora.addingTimeInterval(48 * 3_600)
        return try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(6 * 3_600))
    }

    @Test("A folha da posição chama cancelar_posicao com o motivo e o detalhe, e conclui com o resultado")
    func posicaoPelaApi() async throws {
        let api = ApiDeCancelamento()
        let posicaoID = UUID()
        var concluido: DesfechoDoCancelamento?
        let vm = CancelamentoViewModel(
            lado: .contratante, posicaoID: posicaoID, turnoID: UUID(), periodo: try periodo(), api: api,
            relogio: RelogioFixo(agora: agora), aoConcluir: { concluido = $0 }
        )
        vm.motivo = .outro
        vm.detalhes = "O evento foi adiado"

        await vm.confirmar()

        #expect(api.posicoes.count == 1)
        #expect(api.posicoes.first?.id == posicaoID)
        #expect(api.posicoes.first?.motivo == "O evento foi adiado")
        #expect(api.vagas.isEmpty)
        guard case let .concluido(.posicao(resultado)) = vm.estado else {
            Issue.record("esperava concluído com o resultado da posição, veio \(vm.estado)")
            return
        }
        #expect(resultado.posicaoID == posicaoID)
        #expect(concluido == .posicao(resultado))
    }

    @Test("A folha da vaga inteira chama cancelar_vaga, nunca cancelar_posicao, e conclui com a vaga cancelada")
    func vagaInteiraPelaApi() async throws {
        let api = ApiDeCancelamento()
        let vagaID = UUID()
        let vm = CancelamentoViewModel(vagaID: vagaID, periodo: try periodo(), api: api, relogio: RelogioFixo(agora: agora))
        #expect(vm.lado == .contratante)
        #expect(vm.alvo == .vaga(id: vagaID))
        #expect(!vm.vaiReabrir)
        vm.motivo = .outro
        vm.detalhes = "Fechamos a casa neste dia"

        await vm.confirmar()

        #expect(api.vagas.count == 1)
        #expect(api.vagas.first?.id == vagaID)
        #expect(api.vagas.first?.motivo == "Fechamos a casa neste dia")
        #expect(api.posicoes.isEmpty)
        #expect(vm.estado == .concluido(.vaga(VagaCancelada(vagaID: vagaID, estado: .cancelada, posicoesCanceladas: 2))))
    }

    @Test("Erro que não é da API vira a falha genérica, e a folha deixa tentar de novo")
    func erroDesconhecido() async throws {
        let api = ApiDeCancelamento()
        api.erro = ErroQualquer()
        let vm = CancelamentoViewModel(vagaID: UUID(), periodo: try periodo(), api: api, relogio: RelogioFixo(agora: agora))
        vm.motivo = .outro
        vm.detalhes = "Fechamos a casa"

        await vm.confirmar()

        #expect(vm.estado == .falha(TextosDoCancelamento.falhaGenerica))
        #expect(vm.podeConfirmar)
    }

    @Test("O id de cada motivo é o próprio valor, para a lista da folha")
    func idDoMotivo() {
        for motivo in MotivoDeCancelamento.opcoes(para: .profissional) + MotivoDeCancelamento.opcoes(para: .contratante) {
            #expect(motivo.id == motivo.rawValue)
        }
    }
}
