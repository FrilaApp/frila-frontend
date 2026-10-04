import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

private struct ErroQualquer: Error {}

private struct RelogioFixo: Relogio {
    let agora: Date
}

private final class ApiDePresenca: ApiClienteEncaminhador, @unchecked Sendable {
    var erro: Error?
    override func fazerCheckin(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro {
        if let erro { throw erro }
        return ResultadoRegistro(turnoID: turnoID, tipo: .manual, verificacao: .pendente, registradoEm: registradoEm, distanciaMetros: distanciaMetros)
    }
}

/// Fila que recusa guardar: o disco cheio ou o cache indisponível.
private final class FilaQueRecusa: FilaDeAcoes, @unchecked Sendable {
    struct Recusada: Error {}
    func enfileirar(_ acao: AcaoPendente) async throws { throw Recusada() }
    func pendentes() async throws -> [AcaoPendente] { [] }
    func remover(id: UUID) async throws {}
    func limpar() async throws {}
}

private func turnoEmCurso(agora: Date) throws -> Turno {
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

/// As bordas da presença (RN08) que `PresencaDoTurnoViewModelTests` não exercita: cancelar a
/// etapa sem GPS, a fila que recusa guardar o registro e o erro que não é da API.
@MainActor
@Suite("Presença do turno: cancelar, fila que recusa e erro desconhecido")
struct PresencaBordasTests {
    private let agora = Date(timeIntervalSince1970: 1_791_000_000)

    private func semGPS(api: ApiDePresenca, fila: (any FilaDeAcoes)?) async throws -> PresencaDoTurnoViewModel {
        // Permissão negada: o fluxo cai direto na etapa sem GPS, sem leitura.
        let leitor = LeitorDeLocalizacaoSimulado(permissao: .negada, resultado: .failure(.permissaoNegada))
        let vm = PresencaDoTurnoViewModel(
            turno: try turnoEmCurso(agora: agora), api: api, localizacao: leitor, fila: fila, relogio: RelogioFixo(agora: agora),
            pontoDaVaga: try Coordenada(latitude: -15.8267, longitude: -47.9218)
        )
        await vm.iniciar(.checkin)
        #expect(vm.etapa == .semGPS(.checkin, .permissaoNegada))
        return vm
    }

    @Test("Cancelar na etapa sem GPS volta à etapa parada, sem registrar nada")
    func cancelar() async throws {
        let vm = try await semGPS(api: ApiDePresenca(), fila: nil)

        vm.cancelar()

        #expect(vm.etapa == .parada)
        #expect(vm.checkin == .naoFeito)
        #expect(vm.podeFazerCheckin)
    }

    @Test("Sem rede e com a fila recusando guardar, o registro não fica como feito e a tela explica")
    func filaRecusa() async throws {
        let api = ApiDePresenca()
        api.erro = ErroDaApi(codigo: .semRede)
        let vm = try await semGPS(api: api, fila: FilaQueRecusa())

        await vm.registrarSemGPS()

        #expect(vm.checkin == .naoFeito)
        #expect(vm.mensagemDeErro == TextosDoProfissional.Presenca.falhaAoGuardar)
    }

    @Test("Sem rede e sem fila, o registro não fica como feito e a mensagem é a de sem conexão")
    func semRedeSemFila() async throws {
        let api = ApiDePresenca()
        api.erro = ErroDaApi(codigo: .semRede)
        let vm = try await semGPS(api: api, fila: nil)

        await vm.registrarSemGPS()

        #expect(vm.checkin == .naoFeito)
        #expect(vm.mensagemDeErro == TextosDoProfissional.Lista.semConexaoMensagem)
    }

    @Test("Erro que não é da API mostra a falha de envio e deixa tentar de novo")
    func erroDesconhecido() async throws {
        let api = ApiDePresenca()
        api.erro = ErroQualquer()
        let vm = try await semGPS(api: api, fila: nil)

        await vm.registrarSemGPS()

        #expect(vm.checkin == .naoFeito)
        #expect(vm.mensagemDeErro == TextosDoProfissional.Presenca.falhaAoEnviar)
        #expect(!vm.ocupado)
    }
}
