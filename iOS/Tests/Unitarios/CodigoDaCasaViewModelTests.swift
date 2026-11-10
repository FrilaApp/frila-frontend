import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

private final class ApiClienteDubleCheckinCasa: ApiClienteEncaminhador, @unchecked Sendable {
    var aoGerarCodigo: ((UUID) async throws -> CodigoDeCheckin)?

    override func gerarCodigoCheckin(turnoID: UUID) async throws -> CodigoDeCheckin {
        if let aoGerarCodigo {
            return try await aoGerarCodigo(turnoID)
        }
        return try await base.gerarCodigoCheckin(turnoID: turnoID)
    }
}

@Suite("Código da Casa no Check-in Semiautomático (Visão Contratante)")
struct CodigoDaCasaViewModelTests {
    private let turnoID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    @Test("Carrega código com zeros à esquerda preservados e segundos restantes do servidor")
    @MainActor
    func carregaCodigoComSucesso() async {
        let api = ApiClienteDubleCheckinCasa()
        api.aoGerarCodigo = { id in
            CodigoDeCheckin(
                turnoID: id,
                codigo: "049215",
                expiraEm: Date().addingTimeInterval(300),
                segundosRestantes: 300
            )
        }

        let vm = CodigoDaCasaViewModel(turnoID: turnoID, api: api)
        #expect(vm.estado == .carregando)

        await vm.carregar()

        #expect(vm.estado == .mostrando(codigo: "049215"))
        #expect(vm.segundosRestantes == 300)
        #expect(!vm.renovando)
    }

    @Test("Passo do relógio monotônico decrementa segundos restantes e renova ao zerar")
    @MainActor
    func passoDoRelogioERenovacao() async {
        let api = ApiClienteDubleCheckinCasa()
        var chamadas = 0
        api.aoGerarCodigo = { id in
            chamadas += 1
            let codigo = chamadas == 1 ? "012345" : "987654"
            return CodigoDeCheckin(
                turnoID: id,
                codigo: codigo,
                expiraEm: Date().addingTimeInterval(10),
                segundosRestantes: 10
            )
        }

        var instanteAtual = ContinuousClock.now
        let vm = CodigoDaCasaViewModel(turnoID: turnoID, api: api, agora: { instanteAtual })

        await vm.carregar()
        #expect(vm.estado == .mostrando(codigo: "012345"))
        #expect(vm.segundosRestantes == 10)

        // Avança 4 segundos
        instanteAtual = instanteAtual + .seconds(4)
        await vm.passo()
        #expect(vm.segundosRestantes == 6)

        // Avança 6 segundos adicionais (atinge zero)
        instanteAtual = instanteAtual + .seconds(6)
        await vm.passo()

        // Deve ter disparado a renovação e carregado o novo código
        #expect(chamadas == 2)
        #expect(vm.estado == .mostrando(codigo: "987654"))
        #expect(!vm.renovando)
    }

    @Test("Formatação de segundos restantes em minutos e segundos")
    func formatacaoDeSegundos() {
        #expect(CodigoDaCasaViewModel.formatar(segundos: 300) == "5:00")
        #expect(CodigoDaCasaViewModel.formatar(segundos: 272) == "4:32")
        #expect(CodigoDaCasaViewModel.formatar(segundos: 59) == "0:59")
        #expect(CodigoDaCasaViewModel.formatar(segundos: 9) == "0:09")
        #expect(CodigoDaCasaViewModel.formatar(segundos: 0) == "0:00")
        #expect(CodigoDaCasaViewModel.formatar(segundos: -15) == "0:00")
    }

    @Test("checkin_pendente mapeia para estado aguardandoChegada")
    @MainActor
    func checkinPendenteMapeiaAguardandoChegada() async {
        let api = ApiClienteDubleCheckinCasa()
        api.aoGerarCodigo = { _ in
            throw ErroDaApi(codigo: .checkinPendente)
        }

        let vm = CodigoDaCasaViewModel(turnoID: turnoID, api: api)
        await vm.carregar()

        #expect(vm.estado == .aguardandoChegada)
        #expect(vm.segundosRestantes == 0)
    }

    @Test("checkin_ja_confirmado mapeia para estado jaVerificado")
    @MainActor
    func checkinJaConfirmadoMapeiaJaVerificado() async {
        let api = ApiClienteDubleCheckinCasa()
        api.aoGerarCodigo = { _ in
            throw ErroDaApi(codigo: .checkinJaConfirmado)
        }

        let vm = CodigoDaCasaViewModel(turnoID: turnoID, api: api)
        await vm.carregar()

        #expect(vm.estado == .jaVerificado)
    }

    @Test("codigo_bloqueado encerrado mapeia para estado encerrado")
    @MainActor
    func codigoBloqueadoMapeiaEncerrado() async {
        let api = ApiClienteDubleCheckinCasa()
        api.aoGerarCodigo = { _ in
            throw ErroDaApi(codigo: .codigoBloqueado, detalhes: "encerrado")
        }

        let vm = CodigoDaCasaViewModel(turnoID: turnoID, api: api)
        await vm.carregar()

        #expect(vm.estado == .encerrado)
    }

    @Test("recurso_desligado mapeia para estado indisponivel")
    @MainActor
    func recursoDesligadoMapeiaIndisponivel() async {
        let api = ApiClienteDubleCheckinCasa()
        api.aoGerarCodigo = { _ in
            throw ErroDaApi(codigo: .semPermissao, detalhes: "recurso_desligado")
        }

        let vm = CodigoDaCasaViewModel(turnoID: turnoID, api: api)
        await vm.carregar()

        #expect(vm.estado == .indisponivel)
    }

    @Test("fora_da_janela mapeia para estado foraDaJanela")
    @MainActor
    func foraDaJanelaMapeiaForaDaJanela() async {
        let api = ApiClienteDubleCheckinCasa()
        api.aoGerarCodigo = { _ in
            throw ErroDaApi(codigo: .foraDaJanela)
        }

        let vm = CodigoDaCasaViewModel(turnoID: turnoID, api: api)
        await vm.carregar()

        #expect(vm.estado == .foraDaJanela)
    }

    @Test("Erro de rede mapeia para falhou e tentarDeNovo recupera")
    @MainActor
    func falhaDeRedeETentarDeNovo() async {
        let api = ApiClienteDubleCheckinCasa()
        var falhar = true
        api.aoGerarCodigo = { id in
            if falhar {
                throw ErroDaApi(codigo: .semRede)
            }
            return CodigoDeCheckin(
                turnoID: id,
                codigo: "777888",
                expiraEm: Date().addingTimeInterval(300),
                segundosRestantes: 300
            )
        }

        let vm = CodigoDaCasaViewModel(turnoID: turnoID, api: api)
        await vm.carregar()

        #expect(vm.estado == .falhou)

        // Recupera a conexão e tenta novamente
        falhar = false
        await vm.tentarDeNovo()

        #expect(vm.estado == .mostrando(codigo: "777888"))
        #expect(vm.segundosRestantes == 300)
    }

    @Test("Acessibilidade: código por extenso soletra dígitos individuais para VoiceOver")
    func codigoPorExtensoSoletraDigitos() {
        let soletrado = TextosDoCheckinPorCodigoCasa.codigoPorExtenso("049215")
        #expect(soletrado.contains("0 4 9 2 1 5"))
    }
}
