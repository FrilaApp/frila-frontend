import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

private final class ApiClienteDubleCheckinProfissional: ApiClienteEncaminhador, @unchecked Sendable {
    var aoValidarCodigo: ((UUID, String, Int?) async throws -> ResultadoRegistro)?

    override func validarCodigoCheckin(turnoID: UUID, codigo: String, distanciaMetros: Int?) async throws -> ResultadoRegistro {
        if let aoValidarCodigo {
            return try await aoValidarCodigo(turnoID, codigo, distanciaMetros)
        }
        return try await base.validarCodigoCheckin(turnoID: turnoID, codigo: codigo, distanciaMetros: distanciaMetros)
    }
}

@Suite("Validação do Código de Check-in (Visão Profissional)")
struct CheckinPorCodigoProfissionalTests {
    private let turnoID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    @Test("Formato válido aceita apenas 6 dígitos ASCII preservando zeros à esquerda")
    func formatoValidoAceitaApenasSeisDigitos() {
        #expect(ValidacaoDoCodigoViewModel.formatoValido("049215"))
        #expect(ValidacaoDoCodigoViewModel.formatoValido("000000"))
        #expect(ValidacaoDoCodigoViewModel.formatoValido("999999"))
        #expect(!ValidacaoDoCodigoViewModel.formatoValido("12345"))
        #expect(!ValidacaoDoCodigoViewModel.formatoValido("1234567"))
        #expect(!ValidacaoDoCodigoViewModel.formatoValido("12345a"))
        #expect(!ValidacaoDoCodigoViewModel.formatoValido(" 12345"))
        #expect(!ValidacaoDoCodigoViewModel.formatoValido(""))
    }

    @Test("Código com formato inválido não mede distância nem chama servidor")
    @MainActor
    func formatoInvalidoNaoChamaApi() async {
        let api = ApiClienteDubleCheckinProfissional()
        var mediu = false
        var chamou = false
        api.aoValidarCodigo = { _, _, _ in
            chamou = true
            throw ErroDaApi(codigo: .codigoInvalido)
        }

        let vm = ValidacaoDoCodigoViewModel(
            turnoID: turnoID,
            api: api,
            medirDistancia: {
                mediu = true
                return 10
            }
        )

        await vm.validarMedindo(codigo: "123")
        #expect(vm.resultado == .formatoInvalido)
        #expect(!mediu)
        #expect(!chamou)
    }

    @Test("Distância medida acima do raio não envia código e preserva tentativa")
    @MainActor
    func distanciaAcimaDoRaioPreservaTentativa() async {
        let api = ApiClienteDubleCheckinProfissional()
        var chamou = false
        api.aoValidarCodigo = { _, _, _ in
            chamou = true
            throw ErroDaApi(codigo: .codigoInvalido)
        }

        let vm = ValidacaoDoCodigoViewModel(
            turnoID: turnoID,
            api: api,
            medirDistancia: { 150 }
        )

        await vm.validarMedindo(codigo: "049215")
        #expect(vm.resultado == .chegueMaisPerto(distanciaMetros: 150))
        #expect(!chamou)
    }

    @Test("Fronteira de 50m do check-in semiautomático: 51m barra com chegueMaisPerto, nil barra com semLocalizacao; 50m e 30m liberam envio")
    @MainActor
    func fronteiraDe50mSemiauto() async {
        // Teste direto da regra de domínio
        #expect(RegraDePresenca.decisaoDoEnvioDoCodigoSemiauto(distanciaMetros: 30) == .liberado)
        #expect(RegraDePresenca.decisaoDoEnvioDoCodigoSemiauto(distanciaMetros: 50) == .liberado)
        #expect(RegraDePresenca.decisaoDoEnvioDoCodigoSemiauto(distanciaMetros: 51) == .chegueMaisPerto(distanciaMetros: 51))
        #expect(RegraDePresenca.decisaoDoEnvioDoCodigoSemiauto(distanciaMetros: nil) == .semLocalizacao)

        let api = ApiClienteDubleCheckinProfissional()
        var chamadas = 0
        api.aoValidarCodigo = { _, _, _ in
            chamadas += 1
            throw ErroDaApi(codigo: .codigoInvalido)
        }

        // Teste com nil (sem GPS): não chama API e orienta semLocalizacao sem inventar 0 m
        let vmNil = ValidacaoDoCodigoViewModel(turnoID: turnoID, api: api, medirDistancia: { nil })
        await vmNil.validarMedindo(codigo: "123456")
        #expect(vmNil.resultado == .semLocalizacao)
        #expect(chamadas == 0)

        // Teste com 51m: não chama API
        let vm51 = ValidacaoDoCodigoViewModel(turnoID: turnoID, api: api, medirDistancia: { 51 })
        await vm51.validarMedindo(codigo: "123456")
        #expect(vm51.resultado == .chegueMaisPerto(distanciaMetros: 51))
        #expect(chamadas == 0)

        // Teste com 50m: chama API
        let vm50 = ValidacaoDoCodigoViewModel(turnoID: turnoID, api: api, medirDistancia: { 50 })
        await vm50.validarMedindo(codigo: "123456")
        #expect(chamadas == 1)
    }

    @Test("Sem GPS (distância nula) mostra orientação semLocalizacao e não envia código")
    @MainActor
    func semLocalizacaoNaoInventaZero() async {
        let api = ApiClienteDubleCheckinProfissional()
        var chamadas = 0
        api.aoValidarCodigo = { _, _, _ in
            chamadas += 1
            throw ErroDaApi(codigo: .codigoInvalido)
        }
        let vm = ValidacaoDoCodigoViewModel(turnoID: turnoID, api: api, medirDistancia: { nil })
        await vm.validarMedindo(codigo: "654321")
        #expect(vm.resultado == .semLocalizacao)
        #expect(chamadas == 0)
        #expect(TextosDoCheckinPorCodigo.Profissional.semLocalizacao == "Sem localização. Peça ao responsável que confirme sua chegada.")
    }

    @Test("Código correto dentro do raio valida com sucesso e preserva string com zero")
    @MainActor
    func validaCodigoComSucessoDentroDoRaio() async {
        let api = ApiClienteDubleCheckinProfissional()
        var codigoRecebido: String?
        var distanciaRecebida: Int?
        let agora = Date()

        api.aoValidarCodigo = { id, cod, dist in
            codigoRecebido = cod
            distanciaRecebida = dist
            return ResultadoRegistro(
                turnoID: id,
                tipo: .codigo,
                verificacao: .verificado,
                registradoEm: agora,
                distanciaMetros: dist
            )
        }

        let vm = ValidacaoDoCodigoViewModel(
            turnoID: turnoID,
            api: api,
            medirDistancia: { 25 }
        )

        await vm.validarMedindo(codigo: "049215")

        #expect(codigoRecebido == "049215")
        #expect(distanciaRecebida == 25)
        if case let .verificado(reg) = vm.resultado {
            #expect(reg.verificacao == .verificado)
            #expect(reg.tipo == .codigo)
        } else {
            Issue.record("Esperava resultado .verificado")
        }
    }

    @Test("Erro codigo_invalido do servidor mapeia para invalido")
    @MainActor
    func erroCodigoInvalidoMapeiaInvalido() async {
        let api = ApiClienteDubleCheckinProfissional()
        api.aoValidarCodigo = { _, _, _ in
            throw ErroDaApi(codigo: .codigoInvalido)
        }

        let vm = ValidacaoDoCodigoViewModel(turnoID: turnoID, api: api, medirDistancia: { 10 })
        await vm.validarMedindo(codigo: "111222")
        #expect(vm.resultado == .invalido)
    }

    @Test("Erro codigo_bloqueado encerrado mapeia para bloqueado(.encerrado)")
    @MainActor
    func erroCodigoBloqueadoEncerradoMapeiaBloqueado() async {
        let api = ApiClienteDubleCheckinProfissional()
        api.aoValidarCodigo = { _, _, _ in
            throw ErroDaApi(codigo: .codigoBloqueado, detalhes: "encerrado")
        }

        let vm = ValidacaoDoCodigoViewModel(turnoID: turnoID, api: api, medirDistancia: { 10 })
        await vm.validarMedindo(codigo: "111222")
        #expect(vm.resultado == .bloqueado(.encerrado))
    }

    @Test("Erro checkin_ja_confirmado mapeia para jaVerificado")
    @MainActor
    func erroCheckinJaConfirmadoMapeiaJaVerificado() async {
        let api = ApiClienteDubleCheckinProfissional()
        api.aoValidarCodigo = { _, _, _ in
            throw ErroDaApi(codigo: .checkinJaConfirmado)
        }

        let vm = ValidacaoDoCodigoViewModel(turnoID: turnoID, api: api, medirDistancia: { 10 })
        await vm.validarMedindo(codigo: "111222")
        #expect(vm.resultado == .jaVerificado)
    }

    @Test("Erro de rede mapeia para respostaPerdida sem repetir automaticamente")
    @MainActor
    func erroDeRedeMapeiaRespostaPerdida() async {
        let api = ApiClienteDubleCheckinProfissional()
        api.aoValidarCodigo = { _, _, _ in
            throw ErroDaApi(codigo: .semRede)
        }

        let vm = ValidacaoDoCodigoViewModel(turnoID: turnoID, api: api, medirDistancia: { 10 })
        await vm.validarMedindo(codigo: "111222")
        #expect(vm.resultado == .respostaPerdida)
    }

    @Test("PresencaDoTurnoViewModel gerencia visibilidade de podeLerOCodigo e encerramento")
    @MainActor
    func visibilidadePodeLerOCodigoEEncerramento() async throws {
        let apiMemoria = ApiClienteEmMemoria(cenario: .checkinPorCodigo)
        let turno = try #require(try await apiMemoria.meusTurnos().first)
        let localizacao = LeitorDeLocalizacaoSimulado(resultado: .failure(.semSinal))

        let vm = PresencaDoTurnoViewModel(
            turno: turno,
            api: apiMemoria,
            localizacao: localizacao,
            recursos: { RecursosDoApp(checkinPorCodigo: true) }
        )

        // Antes de carregar recursos, a chave não foi lida
        #expect(!vm.podeLerOCodigo)

        await vm.carregarRecursos()
        #expect(vm.checkinPorCodigoLigado)

        // Ao validar com sucesso pelo código, verificacao vira .verificado e podeLerOCodigo fecha
        let reg = ResultadoRegistro(
            turnoID: turno.id,
            tipo: .codigo,
            verificacao: .verificado,
            registradoEm: Date(),
            distanciaMetros: 20
        )
        vm.aoValidarOCodigo(reg)
        #expect(vm.verificacao == .verificado)
        #expect(!vm.podeLerOCodigo)

        // Cenário de encerramento do código
        let vmBloqueado = PresencaDoTurnoViewModel(
            turno: turno,
            api: apiMemoria,
            localizacao: localizacao,
            recursos: { RecursosDoApp(checkinPorCodigo: true) }
        )
        await vmBloqueado.carregarRecursos()

        vmBloqueado.aoEncerrarOCaminhoDoCodigo()
        #expect(vmBloqueado.caminhoDoCodigoEncerrado)
        #expect(!vmBloqueado.podeLerOCodigo)
    }
}
