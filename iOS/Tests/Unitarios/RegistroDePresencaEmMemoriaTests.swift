import Foundation
import FrilaDados
import FrilaDominio
import Testing

/// O dublê segue `fazer_checkin` (a2587a3, 20260925233000_notificacao_para_qualquer_conta.sql) e
/// `fazer_checkout` (20260925000000_checkin_e_checkout.sql) do backend e o contrato: os 200 m
/// valem só para o check-in. A janela do turno não é modelada.
@Suite("Dublê: check-in e check-out")
struct RegistroDePresencaEmMemoriaTests {
    private let antes = Date.now.addingTimeInterval(-3_600)
    private let depois = Date.now.addingTimeInterval(-60)

    /// Um turno confirmado da conta de demonstração do dublê.
    private func turnoConfirmado() async throws -> (ApiClienteEmMemoria, UUID) {
        let api = ApiClienteEmMemoria()
        try await api.entrarDemonstracao(email: "revisao@frila.app", codigo: "codigo-da-revisao")
        let vaga = try #require(try await api.vagasAbertas().first)
        let turnoID = try #require(try await api.candidatar(vagaID: vaga.id).turnoID)
        return (api, turnoID)
    }

    @Test("Check-in a 150 m é geolocalizado e verificado, com a distância")
    func checkinPerto() async throws {
        let (api, turno) = try await turnoConfirmado()
        let registro = try await api.fazerCheckin(turnoID: turno, distanciaMetros: 150, registradoEm: antes)
        #expect(registro.tipo == .geolocalizado)
        #expect(registro.verificacao == .verificado)
        #expect(registro.distanciaMetros == 150)
    }

    @Test("Check-in a 350 m é manual e pendente, sem guardar a distância")
    func checkinLonge() async throws {
        let (api, turno) = try await turnoConfirmado()
        let registro = try await api.fazerCheckin(turnoID: turno, distanciaMetros: 350, registradoEm: antes)
        #expect(registro.tipo == .manual)
        #expect(registro.verificacao == .pendente)
        #expect(registro.distanciaMetros == nil)
    }

    @Test("Check-out a 150 m registra a saída com a distância")
    func checkoutPerto() async throws {
        let (api, turno) = try await turnoConfirmado()
        _ = try await api.fazerCheckin(turnoID: turno, distanciaMetros: 150, registradoEm: antes)

        let saida = try await api.fazerCheckout(turnoID: turno, distanciaMetros: 150, registradoEm: depois)

        #expect(saida.tipo == .geolocalizado)
        #expect(saida.verificacao == .verificado)
        #expect(saida.distanciaMetros == 150)
        #expect(saida.registradoEm == depois)
    }

    @Test("Check-out a 350 m é aceito e mantém tipo e verificação do check-in",
          arguments: [(150, TipoRegistro.geolocalizado, Verificacao.verificado), (350, .manual, .pendente)])
    func checkoutLongeMantemOCheckin(distanciaDoCheckin: Int, tipo: TipoRegistro, verificacao: Verificacao) async throws {
        let (api, turno) = try await turnoConfirmado()
        _ = try await api.fazerCheckin(turnoID: turno, distanciaMetros: distanciaDoCheckin, registradoEm: antes)

        let saida = try await api.fazerCheckout(turnoID: turno, distanciaMetros: 350, registradoEm: depois)

        #expect(saida.tipo == tipo)
        #expect(saida.verificacao == verificacao)
        #expect(saida.distanciaMetros == 350)
        #expect(saida.registradoEm == depois)
    }

    @Test("Check-out sem check-in é checkin_pendente")
    func checkoutSemCheckin() async throws {
        let (api, turno) = try await turnoConfirmado()
        await #expect(throws: ErroDaApi(codigo: .checkinPendente)) {
            try await api.fazerCheckout(turnoID: turno, distanciaMetros: 10, registradoEm: depois)
        }
    }

    @Test("Distância negativa é campo_invalido no check-in e no check-out")
    func distanciaNegativa() async throws {
        let (api, turno) = try await turnoConfirmado()
        let noCheckin = await #expect(throws: ErroDaApi.self) {
            try await api.fazerCheckin(turnoID: turno, distanciaMetros: -1, registradoEm: antes)
        }
        #expect(noCheckin?.codigo == .campoInvalido)
        #expect(noCheckin?.detalhes == "distancia_m")

        _ = try await api.fazerCheckin(turnoID: turno, distanciaMetros: 20, registradoEm: antes)
        let noCheckout = await #expect(throws: ErroDaApi.self) {
            try await api.fazerCheckout(turnoID: turno, distanciaMetros: -1, registradoEm: depois)
        }
        #expect(noCheckout?.codigo == .campoInvalido)
        #expect(noCheckout?.detalhes == "distancia_m")
    }

    @Test("Repetir check-in ou check-out devolve o registro gravado, antes de validar de novo")
    func repeticaoDevolveOGravado() async throws {
        let (api, turno) = try await turnoConfirmado()
        let entrada = try await api.fazerCheckin(turnoID: turno, distanciaMetros: 150, registradoEm: antes)
        // Nem outra distância, nem instante no futuro, nem distância negativa mudam o gravado.
        #expect(try await api.fazerCheckin(turnoID: turno, distanciaMetros: 900, registradoEm: depois) == entrada)
        #expect(try await api.fazerCheckin(turnoID: turno, distanciaMetros: -5, registradoEm: .now.addingTimeInterval(3_600)) == entrada)

        let saida = try await api.fazerCheckout(turnoID: turno, distanciaMetros: 350, registradoEm: depois)
        #expect(try await api.fazerCheckout(turnoID: turno, distanciaMetros: 10, registradoEm: antes) == saida)
        #expect(try await api.fazerCheckout(turnoID: turno, distanciaMetros: -5, registradoEm: .now.addingTimeInterval(3_600)) == saida)
    }
}
