import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing
import UIKit

/// As telas do check-in por código (F12b, etapa 3): o código da casa com a contagem do servidor, o QR, a
/// chave real, a leitura do profissional e a fila offline com os sinais. As regras de dados estão em
/// `CheckinPorCodigoTests`.

private final class RelogioDoDuble: Relogio, @unchecked Sendable {
    private let trava = NSLock()
    private var _agora = Date(timeIntervalSince1970: 1_791_000_000)
    var agora: Date { trava.withLock { _agora } }
    func avancar(_ segundos: TimeInterval) { trava.withLock { _agora = _agora.addingTimeInterval(segundos) } }
}

/// O relógio monotônico da contagem: o teste o avança à mão.
@MainActor
private final class RelogioMonotonicoDeTeste {
    private(set) var instante = ContinuousClock.now
    func avancar(_ segundos: Int) { instante += .seconds(segundos) }
}

private let turnoDoProfissional = UUID(uuidString: "24000000-0000-0000-0000-000000000001")!
private let turnoDaCasa = UUID(uuidString: "82000000-0000-0000-0000-000000000001")!

// MARK: A casa mostra o código

@Suite("Código da casa: contagem do servidor, renovação e erros")
@MainActor
struct CodigoDaCasaViewModelTests {
    private func montar(
        cenario: ApiClienteEmMemoria.Cenario = .checkinPorCodigoCasa, relogio: RelogioDoDuble = RelogioDoDuble()
    ) -> (CodigoDaCasaViewModel, ApiClienteEmMemoria, RelogioMonotonicoDeTeste, RelogioDoDuble) {
        let api = ApiClienteEmMemoria(cenario: cenario, relogio: relogio)
        let monotonico = RelogioMonotonicoDeTeste()
        let modelo = CodigoDaCasaViewModel(turnoID: turnoDaCasa, api: api, agora: { monotonico.instante })
        return (modelo, api, monotonico, relogio)
    }

    @Test("a contagem parte dos segundos que o servidor mandou e anda pelo relógio monotônico")
    func contagem() async {
        let (modelo, _, monotonico, _) = montar()
        await modelo.carregar()
        #expect(modelo.estado == .mostrando(codigo: ApiClienteEmMemoria.codigosDeExemplo[0]))
        #expect(modelo.segundosRestantes == 300)
        monotonico.avancar(100)
        await modelo.passo()
        #expect(modelo.segundosRestantes == 200)
        monotonico.avancar(199)
        await modelo.passo()
        #expect(modelo.segundosRestantes == 1)
        #expect(!modelo.renovando)
    }

    @Test("a contagem não depende do relógio de parede: mudar a hora do aparelho não muda o que resta")
    func relogioDeParedeNaoEntra() async {
        let (modelo, _, _, relogioDoServidor) = montar()
        await modelo.carregar()
        relogioDoServidor.avancar(10_000)
        await modelo.passo()
        #expect(modelo.segundosRestantes == 300, "o passo só olha o relógio monotônico")
    }

    @Test("no zero, renova: chama o servidor de novo e mostra o código novo com a validade cheia")
    func renova() async {
        let (modelo, _, monotonico, relogioDoServidor) = montar()
        await modelo.carregar()
        let primeiro = ApiClienteEmMemoria.codigosDeExemplo[0]
        monotonico.avancar(301)
        relogioDoServidor.avancar(301)
        await modelo.passo()
        #expect(modelo.estado == .mostrando(codigo: ApiClienteEmMemoria.codigosDeExemplo[1]))
        #expect(modelo.estado != .mostrando(codigo: primeiro))
        #expect(modelo.segundosRestantes == 300)
        #expect(!modelo.renovando)
    }

    @Test("o código ainda dentro da validade não renova")
    func naoRenovaAntes() async {
        let (modelo, _, monotonico, _) = montar()
        await modelo.carregar()
        monotonico.avancar(299)
        await modelo.passo()
        #expect(modelo.estado == .mostrando(codigo: ApiClienteEmMemoria.codigosDeExemplo[0]))
        #expect(modelo.segundosRestantes == 1)
    }

    @Test("a chave desligada some com o cartão; presença já verificada também")
    func estadosSemCodigo() async throws {
        let (desligada, apiDesligada, _, _) = montar()
        await apiDesligada.definirRecursos(.desligados)
        await desligada.carregar()
        #expect(desligada.estado == .indisponivel)

        let (verificada, apiVerificada, _, _) = montar()
        _ = try await apiVerificada.confirmarCheckinManual(turnoID: turnoDaCasa)
        await verificada.carregar()
        #expect(verificada.estado == .jaVerificado)
    }

    @Test("depois de 6 erradas o caminho fecha e o cartão diz que vale a confirmação manual")
    func encerrado() async throws {
        let relogio = RelogioDoDuble()
        // A conta do dublê é uma só: o profissional erra o código na conta de profissional, e a casa volta.
        let profissional = ApiClienteEmMemoria(cenario: .checkinPorCodigo, relogio: relogio)
        _ = try await profissional.fazerCheckin(turnoID: turnoDoProfissional, distanciaMetros: nil, registradoEm: relogio.agora)
        for volta in 0..<6 {
            if volta == 3 { relogio.avancar(301) }
            _ = try? await profissional.validarCodigoCheckin(turnoID: turnoDoProfissional, codigo: "000001", distanciaMetros: 10)
        }
        let casa = CodigoDaCasaViewModel(turnoID: turnoDoProfissional, api: ContaDeCasaSobre(profissional))
        await casa.carregar()
        #expect(casa.estado == .encerrado)
    }

    @Test("sem rede, falha; e tentar de novo mostra o código")
    func falhaERecupera() async {
        let relogio = RelogioDoDuble()
        let api = ApiQueFalhaNaPrimeiraVez(base: ApiClienteEmMemoria(cenario: .checkinPorCodigoCasa, relogio: relogio))
        let modelo = CodigoDaCasaViewModel(turnoID: turnoDaCasa, api: api)
        await modelo.carregar()
        #expect(modelo.estado == .falhou)
        await modelo.tentarDeNovo()
        #expect(modelo.estado == .mostrando(codigo: ApiClienteEmMemoria.codigosDeExemplo[0]))
    }

    @Test("o tempo aparece como minutos e segundos")
    func formatar() {
        #expect(CodigoDaCasaViewModel.formatar(segundos: 300) == "5:00")
        #expect(CodigoDaCasaViewModel.formatar(segundos: 272) == "4:32")
        #expect(CodigoDaCasaViewModel.formatar(segundos: 61) == "1:01")
        #expect(CodigoDaCasaViewModel.formatar(segundos: 0) == "0:00")
        #expect(CodigoDaCasaViewModel.formatar(segundos: -5) == "0:00")
    }

    @Test("o QR carrega exatamente os 6 dígitos do código, e nada mais")
    func qrDoCodigo() throws {
        for codigo in ApiClienteEmMemoria.codigosDeExemplo {
            let imagem = try #require(GeradorDeQRCode.imagem(para: codigo))
            #expect(GeradorDeQRCode.texto(de: imagem) == codigo)
        }
        let outra = try #require(GeradorDeQRCode.imagem(para: "000001"))
        #expect(GeradorDeQRCode.texto(de: outra) == "000001")
    }
}

/// A conta de casa sobre o estado de outro dublê: o dublê simula uma conta só, e o estado do servidor é um.
private final class ContaDeCasaSobre: ApiClienteEncaminhador, @unchecked Sendable {
    init(_ base: ApiClienteEmMemoria) {
        super.init(base: base)
    }

    override func gerarCodigoCheckin(turnoID: UUID) async throws -> CodigoDeCheckin {
        await base.definirContaParaTeste(try await casa())
        return try await base.gerarCodigoCheckin(turnoID: turnoID)
    }

    private func casa() async throws -> Conta {
        let atual = try await base.minhaConta()
        return Conta(
            id: atual.id, perfil: .contratante, nome: atual.nome, telefone: atual.telefone, email: atual.email,
            nascimento: atual.nascimento, estado: atual.estado
        )
    }
}

private final class ApiQueFalhaNaPrimeiraVez: ApiClienteEncaminhador, @unchecked Sendable {
    private let trava = NSLock()
    private var chamadas = 0

    override func gerarCodigoCheckin(turnoID: UUID) async throws -> CodigoDeCheckin {
        let numero = trava.withLock { () -> Int in chamadas += 1; return chamadas }
        if numero == 1 { throw ErroDaApi(codigo: .semRede) }
        return try await base.gerarCodigoCheckin(turnoID: turnoID)
    }
}

// MARK: O profissional: chave, botão e fila offline

private final class ApiDeCheckinPendente: ApiClienteEncaminhador, @unchecked Sendable {
    let disponivel: Bool

    init(disponivel: Bool) {
        self.disponivel = disponivel
        super.init()
    }

    override func fazerCheckin(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro {
        ResultadoRegistro(
            turnoID: turnoID, tipo: .manual, verificacao: .pendente, registradoEm: registradoEm, distanciaMetros: nil,
            codigoExigido: true, codigoDisponivel: disponivel
        )
    }
}

private final class ContadorDeLeituras: @unchecked Sendable {
    private let trava = NSLock()
    private var _leituras = 0
    var leituras: Int { trava.withLock { _leituras } }
    func contar() { trava.withLock { _leituras += 1 } }
}

@Suite("Check-in por código no profissional: chave real, botão e medição")
@MainActor
struct CheckinPorCodigoDoProfissionalTests {
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
        api: any ApiCliente, leitura: LeituraDeLocalizacao, recursos: RecursosDoApp, fila: (any FilaDeAcoes)? = nil,
        permissao: PermissaoDeLocalizacao = .aoUsarPrecisa, aoRegistrar: @escaping @MainActor () -> Void = {}
    ) throws -> PresencaDoTurnoViewModel {
        let leitor = LeitorDeLocalizacaoSimulado(permissao: permissao, resultado: .success(leitura))
        return PresencaDoTurnoViewModel(
            turno: try turno(), api: api, localizacao: leitor, fila: fila, relogio: RelogioFixo(agora: agora), pontoDaVaga: ponto,
            aoRegistrar: aoRegistrar, recursos: { recursos }
        )
    }

    /// Um check-in a 350 m: o GPS não serve, e a saída é o registro manual, que fica pendente.
    private func checkinPendente(_ m: PresencaDoTurnoViewModel) async {
        await m.iniciar(.checkin)
        await m.registrarSemGPS()
    }

    private func longe() -> LeituraDeLocalizacao { LeitorDeLocalizacaoSimulado.leitura(a: 350, de: ponto) }
    private func perto(simulada: Bool = false) throws -> LeituraDeLocalizacao {
        let base = LeitorDeLocalizacaoSimulado.leitura(a: 50, de: ponto)
        return LeituraDeLocalizacao(coordenada: base.coordenada, precisaoHorizontalMetros: 10, simulada: simulada)
    }

    @Test("com a chave desligada, nada do código aparece e o check-in é o de hoje")
    func chaveDesligadaNadaMuda() async throws {
        let m = try modelo(api: ApiDeCheckinPendente(disponivel: true), leitura: longe(), recursos: .desligados)
        await m.carregarRecursos()
        await checkinPendente(m)
        #expect(!m.checkinPorCodigoLigado)
        #expect(m.verificacao == .pendente, "o check-in manual pendente de hoje")
        #expect(!m.podeLerOCodigo, "sem a chave, não há leitura do código, mesmo que o servidor diga que está disponível")
        if case .registrado = m.checkin {} else { Issue.record("o check-in devia estar registrado, veio \(m.checkin)") }
    }

    @Test("com a chave ligada e o servidor dizendo que o código está disponível, a leitura aparece")
    func chaveLigada() async throws {
        let m = try modelo(api: ApiDeCheckinPendente(disponivel: true), leitura: longe(), recursos: RecursosDoApp(checkinPorCodigo: true))
        await m.carregarRecursos()
        #expect(!m.podeLerOCodigo, "antes do check-in não há o que ler")
        await checkinPendente(m)
        #expect(m.checkinPorCodigoLigado)
        #expect(m.codigoDisponivel == true)
        #expect(m.podeLerOCodigo)
    }

    @Test("se o servidor diz que o código não está disponível, a leitura não aparece")
    func codigoIndisponivel() async throws {
        let m = try modelo(api: ApiDeCheckinPendente(disponivel: false), leitura: longe(), recursos: RecursosDoApp(checkinPorCodigo: true))
        await m.carregarRecursos()
        await checkinPendente(m)
        #expect(m.codigoDisponivel == false)
        #expect(!m.podeLerOCodigo)
    }

    @Test("o caminho fechado por bloqueios tira a leitura; a validação a tira também")
    func encerradoEValidado() async throws {
        let registros = ContadorDeLeituras()
        let m = try modelo(
            api: ApiDeCheckinPendente(disponivel: true), leitura: longe(), recursos: RecursosDoApp(checkinPorCodigo: true),
            aoRegistrar: { registros.contar() }
        )
        await m.carregarRecursos()
        await checkinPendente(m)
        #expect(m.podeLerOCodigo)
        m.aoEncerrarOCaminhoDoCodigo()
        #expect(!m.podeLerOCodigo)

        let outro = try modelo(
            api: ApiDeCheckinPendente(disponivel: true), leitura: longe(), recursos: RecursosDoApp(checkinPorCodigo: true),
            aoRegistrar: { registros.contar() }
        )
        await outro.carregarRecursos()
        await checkinPendente(outro)
        let antes = registros.leituras
        outro.aoValidarOCodigo(ResultadoRegistro(
            turnoID: outro.turno.id, tipo: .codigo, verificacao: .verificado, registradoEm: agora, distanciaMetros: nil
        ))
        #expect(outro.verificacao == .verificado)
        #expect(!outro.podeLerOCodigo)
        #expect(registros.leituras == antes + 1, "a tela do turno é relida")
        if case let .registrado(feito) = outro.checkin { #expect(!feito.manual) } else { Issue.record("check-in devia estar registrado") }
    }

    @Test("os recursos são lidos uma vez por abertura, e os sinais usam a mesma leitura")
    func recursosUmaVez() async throws {
        let contador = ContadorDeLeituras()
        let api = ApiDeCheckinFalso2()
        let leitor = LeitorDeLocalizacaoSimulado(permissao: .aoUsarPrecisa, resultado: .success(try perto(simulada: true)))
        let m = PresencaDoTurnoViewModel(
            turno: try turno(), api: api, localizacao: leitor, relogio: RelogioFixo(agora: agora), pontoDaVaga: ponto,
            recursos: { contador.contar(); return RecursosDoApp(checkinPorCodigo: true) }
        )
        await m.carregarRecursos()
        await m.carregarRecursos()
        await m.iniciar(.checkin)
        #expect(contador.leituras == 1)
        #expect(api.sinaisDoCheckin == [SinaisDoCheckin(localizacaoSimulada: true, precisaoMetros: 10, saltoDePosicao: false)])
    }

    @Test("a distância para o código é a medida no toque, sem descontar a imprecisão; sem posição, nula")
    func medirDistancia() async throws {
        let api = ApiDeCheckinFalso2()
        let m = try modelo(api: api, leitura: longe(), recursos: .desligados)
        let medida = try #require(await m.medirDistanciaParaOCodigo())
        #expect(abs(medida - 350) <= 2)

        let imprecisa = LeituraDeLocalizacao(coordenada: longe().coordenada, precisaoHorizontalMetros: 180)
        let mImprecisa = try modelo(api: api, leitura: imprecisa, recursos: .desligados)
        let comImprecisao = try #require(await mImprecisa.medirDistanciaParaOCodigo())
        #expect(abs(comImprecisao - 350) <= 2, "a precisão pior não desconta a distância")

        let semPermissao = try modelo(api: api, leitura: longe(), recursos: .desligados, permissao: .negada)
        #expect(await semPermissao.medirDistanciaParaOCodigo() == nil)
        let aproximada = try modelo(api: api, leitura: longe(), recursos: .desligados, permissao: .aoUsarAproximada)
        #expect(await aproximada.medirDistanciaParaOCodigo() == nil)
    }

    @Test("a validação mede a distância no toque: longe não envia e não gasta tentativa, perto envia")
    func validarMedindo() async throws {
        let relogio = RelogioDoDuble()
        let dubleDoServidor = ApiClienteEmMemoria(cenario: .checkinPorCodigo, relogio: relogio)
        _ = try await dubleDoServidor.fazerCheckin(turnoID: turnoDoProfissional, distanciaMetros: nil, registradoEm: relogio.agora)
        let validacao = ValidacaoDoCodigoViewModel(turnoID: turnoDoProfissional, api: dubleDoServidor, medirDistancia: { 150 })
        await validacao.validarMedindo(codigo: ApiClienteEmMemoria.codigosDeExemplo[0])
        #expect(validacao.resultado == .chegueMaisPerto(distanciaMetros: 150))
        #expect(await dubleDoServidor.chamadasAValidarCodigo == 0)

        let perto = ValidacaoDoCodigoViewModel(turnoID: turnoDoProfissional, api: dubleDoServidor, medirDistancia: { 40 })
        await perto.validarMedindo(codigo: ApiClienteEmMemoria.codigosDeExemplo[0])
        if case let .verificado(registro) = perto.resultado { #expect(registro.tipo == .codigo) } else {
            Issue.record("esperava verificado, veio \(perto.resultado)")
        }
    }

    @Test("o formato errado nem lê a localização, e sem posição o código segue")
    func formatoESemPosicao() async throws {
        let contador = ContadorDeLeituras()
        let api = ApiClienteEmMemoria(cenario: .checkinPorCodigo, relogio: RelogioDoDuble())
        let validacao = ValidacaoDoCodigoViewModel(turnoID: turnoDoProfissional, api: api, medirDistancia: { contador.contar(); return nil })
        await validacao.validarMedindo(codigo: "123")
        #expect(validacao.resultado == .formatoInvalido)
        #expect(contador.leituras == 0)
        await validacao.validarMedindo(codigo: "000001")
        #expect(contador.leituras == 1)
        #expect(await api.chamadasAValidarCodigo == 1, "sem posição o código foi ao servidor")
    }
}

/// Responde o check-in como verificado, sem passar pelo dublê, e guarda os sinais que chegaram.
private final class ApiDeCheckinFalso2: ApiClienteEncaminhador, @unchecked Sendable {
    override func fazerCheckin(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro {
        ResultadoRegistro(turnoID: turnoID, tipo: .geolocalizado, verificacao: .verificado, registradoEm: registradoEm, distanciaMetros: distanciaMetros)
    }
}
