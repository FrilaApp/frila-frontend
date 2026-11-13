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
        #expect(TextosDoCheckinPorCodigo.Profissional.semLocalizacao == "Não conseguimos sua localização. Peça ao responsável da casa que confirme sua chegada.")
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

    @Test("Erro fora_do_raio do servidor mapeia para foraDoRaio e preserva tentativas")
    @MainActor
    func erroForaDoRaioDoServidorMapeiaForaDoRaio() async {
        let api = ApiClienteDubleCheckinProfissional()
        api.aoValidarCodigo = { _, _, _ in
            throw ErroDaApi(codigo: .foraDoRaio)
        }

        let vm = ValidacaoDoCodigoViewModel(turnoID: turnoID, api: api, medirDistancia: { 10 })
        await vm.validarMedindo(codigo: "123456")
        #expect(vm.resultado == .foraDoRaio)
        #expect(TextosDoCheckinPorCodigo.Profissional.foraDoRaio == "Você ainda está longe do local. Aproxime-se e tente de novo.")
        #expect(MensagemDoErroAPI.texto(ErroDaApi(codigo: .foraDoRaio)) == "Você ainda está longe do local. Aproxime-se e tente de novo.")
    }

    @Test("Erro sem_localizacao do servidor mapeia para semLocalizacao")
    @MainActor
    func erroSemLocalizacaoDoServidorMapeiaSemLocalizacao() async {
        let api = ApiClienteDubleCheckinProfissional()
        api.aoValidarCodigo = { _, _, _ in
            throw ErroDaApi(codigo: .semLocalizacao)
        }

        let vm = ValidacaoDoCodigoViewModel(turnoID: turnoID, api: api, medirDistancia: { 10 })
        await vm.validarMedindo(codigo: "123456")
        #expect(vm.resultado == .semLocalizacao)
        #expect(TextosDoCheckinPorCodigo.Profissional.semLocalizacao == "Não conseguimos sua localização. Peça ao responsável da casa que confirme sua chegada.")
        #expect(MensagemDoErroAPI.texto(ErroDaApi(codigo: .semLocalizacao)) == "Não conseguimos sua localização. Peça ao responsável da casa que confirme sua chegada.")
    }

    @Test("Textos da confirmação tardia de 24h em TextosDaPresenca")
    func textosConfirmacaoTardiaPresenca() {
        #expect(
            TextosDoProfissional.Presenca.checkinAguardando("14:30") ==
            "Check-in manual feito às 14:30. Aguardando a confirmação da casa, que pode confirmar até 24 horas depois do fim do turno."
        )
        #expect(
            TextosDoProfissional.Presenca.checkinNaoConfirmado("14:30") ==
            "Check-in manual feito às 14:30. A casa não confirmou em até 24 horas depois do fim do turno."
        )
        #expect(
            TextosDoProfissional.Presenca.naoVerificadaAviso ==
            "Presença não verificada. O prazo para a casa confirmar a sua presença terminou e ficou registrado como não verificado. Se algo não bate, fale com o Frila em Ajuda no turno."
        )
    }
}

// MARK: O botão do código sobrevive à recriação da tela (D-22)

/// Responde o check-in como um check-in manual pendente, com o `codigo_disponivel` que o teste escolher.
private final class ApiDeCheckinComCodigoDisponivel: ApiClienteEncaminhador, @unchecked Sendable {
    private let disponivel: Bool

    init(disponivel: Bool) {
        self.disponivel = disponivel
        super.init()
    }

    override func fazerCheckin(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro {
        ResultadoRegistro(
            turnoID: turnoID, tipo: .manual, verificacao: .pendente, registradoEm: registradoEm,
            distanciaMetros: distanciaMetros, codigoDisponivel: disponivel
        )
    }
}

@Suite("O botão do código da casa depende do que o servidor disse e sobrevive à recriação da tela")
@MainActor
struct BotaoDoCodigoDaCasaTests {
    private let agora = Date(timeIntervalSince1970: 1_791_000_000)
    private let ponto = try! Coordenada(latitude: -15.8267, longitude: -47.9218)

    private struct RelogioFixo: Relogio { let agora: Date }

    private func turno(comCheckin: Bool = false, id: UUID = UUID()) throws -> Turno {
        let vaga = VagaResumo(
            id: UUID(), funcao: "Garçom", local: "Bar do Lago", regiaoAdministrativa: "Plano Piloto",
            periodo: try Periodo(inicio: agora.addingTimeInterval(-600), fim: agora.addingTimeInterval(4 * 3_600)), valor: Dinheiro(centavos: 15000)
        )
        let reputacao = Reputacao(positivas: 10, total: 10, taxaComparecimento: nil, turnosConsiderados: 10, turnosRealizados: 10)
        return Turno(
            id: id, posicaoID: UUID(), vaga: vaga,
            contraparte: PerfilPublico(id: UUID(), tipo: .estabelecimento, nome: "Bar do Lago", reputacao: reputacao),
            contatoVisivelAte: agora.addingTimeInterval(24 * 3_600),
            checkin: comCheckin ? Presenca(instante: agora, tipo: .manual, distanciaMetros: 30) : nil,
            verificacao: .pendente, valorAcordado: vaga.valor, podeAvaliar: false, contato: nil
        )
    }

    /// A tela do turno: um view model novo. A recriação é outro view model sobre o mesmo turno e o mesmo cache.
    private func tela(turno: Turno, api: any ApiCliente, cache: CacheDeLeituras) async -> PresencaDoTurnoViewModel {
        let perto = try! Coordenada(latitude: -15.8269, longitude: -47.9219)
        let leitura = LeituraDeLocalizacao(coordenada: perto, precisaoHorizontalMetros: 12, simulada: false, saltoDePosicao: false)
        let modelo = PresencaDoTurnoViewModel(
            turno: turno, api: api,
            localizacao: LeitorDeLocalizacaoSimulado(permissao: .aoUsarPrecisa, resultado: .success(leitura)),
            relogio: RelogioFixo(agora: agora), pontoDaVaga: ponto, cache: cache,
            recursos: { RecursosDoApp(checkinPorCodigo: true) }
        )
        await modelo.carregarRecursos()
        return modelo
    }

    @Test("check-in com codigo_disponivel true mostra o botão, e a tela criada de novo continua mostrando")
    func comCodigoDisponivelOBotaoSobrevive() async throws {
        let turno = try turno()
        let cache = CacheDeLeituras()
        let primeira = await tela(turno: turno, api: ApiDeCheckinComCodigoDisponivel(disponivel: true), cache: cache)
        await primeira.iniciar(.checkin)
        #expect(primeira.podeLerOCodigo)

        let recriada = await tela(turno: try self.turno(comCheckin: true, id: turno.id), api: ApiDeCheckinComCodigoDisponivel(disponivel: true), cache: cache)
        #expect(recriada.podeLerOCodigo, "o que o servidor disse no check-in vale também na tela nova")
    }

    @Test("check-in com codigo_disponivel false não mostra o botão, nem na tela criada de novo")
    func semCodigoDisponivelOBotaoNaoVolta() async throws {
        let turno = try turno()
        let cache = CacheDeLeituras()
        let primeira = await tela(turno: turno, api: ApiDeCheckinComCodigoDisponivel(disponivel: false), cache: cache)
        await primeira.iniciar(.checkin)
        #expect(!primeira.podeLerOCodigo)

        let recriada = await tela(turno: try self.turno(comCheckin: true, id: turno.id), api: ApiDeCheckinComCodigoDisponivel(disponivel: false), cache: cache)
        #expect(!recriada.podeLerOCodigo, "D-22 caso 2: check-in longe, a tela nova não pode oferecer o código")
    }

    @Test("caminho do código encerrado continua sumido na tela criada de novo")
    func encerradoContinuaSumido() async throws {
        let turno = try turno()
        let cache = CacheDeLeituras()
        let primeira = await tela(turno: turno, api: ApiDeCheckinComCodigoDisponivel(disponivel: true), cache: cache)
        await primeira.iniciar(.checkin)
        #expect(primeira.podeLerOCodigo)
        primeira.aoEncerrarOCaminhoDoCodigo()
        #expect(!primeira.podeLerOCodigo)

        let recriada = await tela(turno: try self.turno(comCheckin: true, id: turno.id), api: ApiDeCheckinComCodigoDisponivel(disponivel: true), cache: cache)
        #expect(!recriada.podeLerOCodigo, "D-22 caso 1: depois dos 6 erros o botão não volta")
    }

    @Test("tela nova sem nada guardado (codigo_disponivel nil) não mostra o botão")
    func semNadaGuardadoSemBotao() async throws {
        let semCache = await tela(turno: try turno(comCheckin: true), api: ApiDeCheckinComCodigoDisponivel(disponivel: true), cache: CacheDeLeituras())
        #expect(semCache.codigoDisponivel == nil)
        #expect(!semCache.podeLerOCodigo, "sem o valor do servidor, não se oferece o código")
    }

    @Test("o que foi guardado de um turno não vale para outro")
    func guardadoPorTurno() async throws {
        let cache = CacheDeLeituras()
        let turnoA = try turno()
        let primeira = await tela(turno: turnoA, api: ApiDeCheckinComCodigoDisponivel(disponivel: true), cache: cache)
        await primeira.iniciar(.checkin)

        let outroTurno = await tela(turno: try turno(comCheckin: true), api: ApiDeCheckinComCodigoDisponivel(disponivel: true), cache: cache)
        #expect(!outroTurno.podeLerOCodigo)
    }

    @Test("o estado do código sobrevive ao app fechado e some junto com o cache ao sair da conta")
    func sobreviveAoAppEApagaNaSaida() async throws {
        let nome = "teste-codigo-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: nome))
        defer { defaults.removePersistentDomain(forName: nome) }
        let turno = try turno()
        let cache = CacheDeLeituras(defaults: defaults)
        let primeira = await tela(turno: turno, api: ApiDeCheckinComCodigoDisponivel(disponivel: true), cache: cache)
        await primeira.iniciar(.checkin)
        primeira.aoEncerrarOCaminhoDoCodigo()
        let outro = try self.turno()
        let segunda = await tela(turno: outro, api: ApiDeCheckinComCodigoDisponivel(disponivel: true), cache: cache)
        await segunda.iniciar(.checkin)

        // O app abre de novo: outro cache sobre o mesmo disco.
        let reaberto = CacheDeLeituras(defaults: defaults)
        #expect(reaberto.caminhoDoCodigoEncerrado(turnoID: turno.id))
        #expect(reaberto.codigoDisponivel(turnoID: turno.id) == true)
        #expect(reaberto.codigoDisponivel(turnoID: outro.id) == true)
        #expect(!reaberto.caminhoDoCodigoEncerrado(turnoID: outro.id))
        let telaReaberta = await tela(turno: try self.turno(comCheckin: true, id: outro.id), api: ApiDeCheckinComCodigoDisponivel(disponivel: true), cache: reaberto)
        #expect(telaReaberta.podeLerOCodigo)

        // Sair da conta limpa o cache, e com ele o que ficou no disco.
        reaberto.limpar()
        #expect(reaberto.codigoDisponivel(turnoID: turno.id) == nil)
        let aposSair = CacheDeLeituras(defaults: defaults)
        #expect(aposSair.codigoDisponivel(turnoID: outro.id) == nil)
        #expect(!aposSair.caminhoDoCodigoEncerrado(turnoID: turno.id))
    }
}
