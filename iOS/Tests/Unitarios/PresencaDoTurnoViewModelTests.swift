import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

private typealias ViewModel = PresencaDoTurnoViewModel

/// Relógio que o teste avança entre um toque e outro.
private final class RelogioDeToque: Relogio, @unchecked Sendable {
    private let trava = NSLock()
    private var _agora: Date
    init(_ agora: Date) { _agora = agora }
    var agora: Date { trava.withLock { _agora } }
    func avancar(_ segundos: TimeInterval) { trava.withLock { _agora = _agora.addingTimeInterval(segundos) } }
}

private struct RegistroEnviado: Equatable {
    let turnoID: UUID
    let distanciaMetros: Int?
    let registradoEm: Date
}

/// O dublê do contrato, com o que o teste precisa por cima: anotar o que foi enviado, cortar a rede
/// e recusar o registro.
private final class ApiDePresenca: ApiCliente, @unchecked Sendable {
    let base: ApiClienteEmMemoria
    private let trava = NSLock()
    private var _semRede = false
    private var _erro: ErroDaApi?
    private var _checkins: [RegistroEnviado] = []
    private var _checkouts: [RegistroEnviado] = []
    private var _detalhes = 0

    init(base: ApiClienteEmMemoria = ApiClienteEmMemoria()) { self.base = base }

    var semRede: Bool {
        get { trava.withLock { _semRede } }
        set { trava.withLock { _semRede = newValue } }
    }
    var erro: ErroDaApi? {
        get { trava.withLock { _erro } }
        set { trava.withLock { _erro = newValue } }
    }
    var checkins: [RegistroEnviado] { trava.withLock { _checkins } }
    var checkouts: [RegistroEnviado] { trava.withLock { _checkouts } }
    var detalhes: Int { trava.withLock { _detalhes } }

    private func exigirRede() throws {
        if semRede { throw ErroDaApi(codigo: .semRede) }
    }

    func solicitarCodigo(email: String) async throws { try await base.solicitarCodigo(email: email) }
    func verificarCodigo(email: String, codigo: String) async throws { try await base.verificarCodigo(email: email, codigo: codigo) }
    func entrarDemonstracao(email: String, codigo: String) async throws { try await base.entrarDemonstracao(email: email, codigo: codigo) }
    func possuiSessao() async -> Bool { await base.possuiSessao() }

    func minhaConta() async throws -> Conta { try await base.minhaConta() }
    func criarConta(_ cadastro: CadastroConta) async throws -> Conta { try await base.criarConta(cadastro) }
    func criarPerfilProfissional(_ dados: DadosPerfilProfissional) async throws -> PerfilProfissional { try await base.criarPerfilProfissional(dados) }
    func meuPerfilProfissional() async throws -> PerfilProfissional { try await base.meuPerfilProfissional() }
    func atualizarPerfilProfissional(_ alteracao: AlteracaoPerfilProfissional) async throws -> PerfilProfissional { try await base.atualizarPerfilProfissional(alteracao) }

    func cadastrarEstabelecimento(_ cadastro: CadastroEstabelecimento) async throws -> Estabelecimento { try await base.cadastrarEstabelecimento(cadastro) }
    func meusEstabelecimentos() async throws -> [EstabelecimentoDaConta] { try await base.meusEstabelecimentos() }
    func painelEstabelecimento(id: UUID, periodo: Periodo) async throws -> Painel { try await base.painelEstabelecimento(id: id, periodo: periodo) }

    func funcoes() async throws -> [Funcao] { try await base.funcoes() }
    func publicarVaga(_ publicacao: PublicacaoVaga) async throws -> VagaPublicada { try await base.publicarVaga(publicacao) }
    func republicarVaga(id: UUID, periodo: Periodo, chave: UUID) async throws -> VagaPublicada { try await base.republicarVaga(id: id, periodo: periodo, chave: chave) }
    func vagasAbertas(_ filtro: FiltroVagas) async throws -> [VagaNaLista] { try await base.vagasAbertas(filtro) }
    func detalheDaVaga(id: UUID) async throws -> Vaga {
        trava.withLock { _detalhes += 1 }
        try exigirRede()
        return try await base.detalheDaVaga(id: id)
    }
    func candidatar(vagaID: UUID) async throws -> ResultadoCandidatura { try await base.candidatar(vagaID: vagaID) }
    func perfilPublico(id: UUID) async throws -> PerfilPublico { try await base.perfilPublico(id: id) }

    func meusTurnos() async throws -> [Turno] { try await base.meusTurnos() }
    func contatoDoTurno(id: UUID) async throws -> Contato { try await base.contatoDoTurno(id: id) }
    func avisarACaminho(turnoID: UUID) async throws -> ResultadoACaminho { try await base.avisarACaminho(turnoID: turnoID) }
    func fazerCheckin(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro {
        try exigirRede()
        if let erro { throw erro }
        trava.withLock { _checkins.append(RegistroEnviado(turnoID: turnoID, distanciaMetros: distanciaMetros, registradoEm: registradoEm)) }
        return try await base.fazerCheckin(turnoID: turnoID, distanciaMetros: distanciaMetros, registradoEm: registradoEm)
    }
    func fazerCheckout(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro {
        try exigirRede()
        if let erro { throw erro }
        trava.withLock { _checkouts.append(RegistroEnviado(turnoID: turnoID, distanciaMetros: distanciaMetros, registradoEm: registradoEm)) }
        return try await base.fazerCheckout(turnoID: turnoID, distanciaMetros: distanciaMetros, registradoEm: registradoEm)
    }
    func avaliar(turnoID: UUID, resposta: Bool) async throws -> Avaliacao { try await base.avaliar(turnoID: turnoID, resposta: resposta) }

    func configuracaoDoApp() async throws -> ConfiguracaoApp { try await base.configuracaoDoApp() }
    func removerDispositivo(tokenFCM: String) async throws { try await base.removerDispositivo(tokenFCM: tokenFCM) }
    func sair(tokenFCM: String?) async { await base.sair(tokenFCM: tokenFCM) }
}

/// Um turno confirmado no dublê, o ponto da vaga dele e o relógio do aparelho.
private struct Cena {
    let api: ApiDePresenca
    let turno: Turno
    let ponto: Coordenada
    let relogio: RelogioDeToque
    let fila: ArmazenamentoSwiftData

    /// O instante do primeiro toque, em segundo inteiro: é a precisão que a fila guarda.
    var toque: Date { relogio.agora }

    static func montar() async throws -> Cena {
        let api = ApiDePresenca()
        let vaga = try #require(try await api.vagasAbertas().first)
        _ = try await api.candidatar(vagaID: vaga.id)
        let turno = try #require(try await api.meusTurnos().first)
        let ponto = try await api.base.detalheDaVaga(id: vaga.id).ponto
        let agora = Date(timeIntervalSince1970: (Date.now.timeIntervalSince1970 - 1_800).rounded(.down))
        let fila = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
        return Cena(api: api, turno: turno, ponto: ponto, relogio: RelogioDeToque(agora), fila: fila)
    }

    func leitor(
        a metros: Double = 150,
        precisao: Double = 10,
        permissao: PermissaoDeLocalizacao = .aoUsarPrecisa,
        respostaAoPedido: PermissaoDeLocalizacao = .aoUsarPrecisa,
        respostaAPrecisaoTemporaria: PermissaoDeLocalizacao = .aoUsarAproximada
    ) -> LeitorDeLocalizacaoSimulado {
        LeitorDeLocalizacaoSimulado(
            permissao: permissao,
            respostaAoPedido: respostaAoPedido,
            respostaAPrecisaoTemporaria: respostaAPrecisaoTemporaria,
            resultado: .success(LeitorDeLocalizacaoSimulado.leitura(a: metros, de: ponto, precisaoMetros: precisao))
        )
    }

    @MainActor
    func viewModel(_ leitor: LeitorDeLocalizacaoSimulado, turno outro: Turno? = nil, comPonto: Bool = true) -> ViewModel {
        ViewModel(turno: outro ?? turno, api: api, localizacao: leitor, fila: fila, relogio: relogio, pontoDaVaga: comPonto ? ponto : nil)
    }

    /// A tela reaberta depois de um check-in verificado: o check-in existe no servidor e o turno
    /// já vem de Meus turnos com ele gravado. É o ponto de partida do check-out.
    @MainActor
    func comCheckinFeito(_ leitor: LeitorDeLocalizacaoSimulado) async -> ViewModel {
        let chegada = viewModel(self.leitor(a: 20))
        await chegada.iniciar(.checkin)
        let instante = relogio.agora
        relogio.avancar(4 * 60)
        let comCheckin = Turno(
            id: turno.id, posicaoID: turno.posicaoID, vaga: turno.vaga, contraparte: turno.contraparte,
            contatoVisivelAte: turno.contatoVisivelAte,
            checkin: Presenca(instante: instante, tipo: .geolocalizado, distanciaMetros: 20),
            verificacao: chegada.verificacao, valorAcordado: turno.valorAcordado, podeAvaliar: false
        )
        return viewModel(leitor, turno: comCheckin)
    }
}

@MainActor
@Suite("Check-in e check-out com localização no toque (#17)")
struct PresencaDoTurnoViewModelTests {
    // MARK: Critério 1

    @Test("Check-in a 150 m fica verificado, com a distância inteira e o instante do toque")
    func checkinPerto() async throws {
        let cena = try await Cena.montar()
        let leitor = cena.leitor(a: 150.4)
        let vm = cena.viewModel(leitor)

        await vm.iniciar(.checkin)

        #expect(cena.api.checkins == [RegistroEnviado(turnoID: cena.turno.id, distanciaMetros: 150, registradoEm: cena.toque)])
        #expect(vm.checkin == .registrado(.init(instante: cena.toque, distanciaMetros: 150, manual: false)))
        #expect(vm.verificacao == .verificado)
        #expect(!vm.aguardandoConfirmacao)
        #expect(vm.etapa == .parada)
        #expect(vm.mensagemDeErro == nil)
        #expect(!vm.podeFazerCheckin)
        #expect(vm.podeFazerCheckout)
    }

    @Test("Check-in a 350 m não é enviado: oferece o manual, que vai sem distância e fica aguardando confirmação")
    func checkinLonge() async throws {
        let cena = try await Cena.montar()
        let vm = cena.viewModel(cena.leitor(a: 350))

        await vm.iniciar(.checkin)
        #expect(vm.etapa == .semGPS(.checkin, .longe(distanciaMetros: 350)))
        #expect(cena.api.checkins.isEmpty)
        #expect(vm.checkin == .naoFeito)

        cena.relogio.avancar(20)
        let toqueNoManual = cena.relogio.agora
        await vm.registrarSemGPS()

        #expect(cena.api.checkins == [RegistroEnviado(turnoID: cena.turno.id, distanciaMetros: nil, registradoEm: toqueNoManual)])
        #expect(vm.checkin == .registrado(.init(instante: toqueNoManual, distanciaMetros: nil, manual: true)))
        #expect(vm.verificacao == .pendente)
        #expect(vm.aguardandoConfirmacao)
        #expect(vm.etapa == .parada)
    }

    @Test("O limite do check-in é 200 m: 200 verifica, 201 oferece o manual", arguments: [(200.0, true), (201.0, false)])
    func limiteDeDistancia(metros: Double, verifica: Bool) async throws {
        let cena = try await Cena.montar()
        let vm = cena.viewModel(cena.leitor(a: metros))

        await vm.iniciar(.checkin)

        #expect((vm.verificacao == .verificado) == verifica)
        #expect(cena.api.checkins.count == (verifica ? 1 : 0))
    }

    // MARK: Localização só no toque

    @Test("Abrir a tela não pede permissão nem lê o GPS; a leitura acontece uma vez, no toque, com limite de 10 s")
    func soNoToque() async throws {
        let cena = try await Cena.montar()
        let leitor = cena.leitor(permissao: .naoDeterminada)
        let vm = cena.viewModel(leitor)
        await vm.restaurarPendentes()
        #expect(await leitor.leituras == 0)
        #expect(await leitor.pedidosDePermissao == 0)

        await vm.iniciar(.checkin)
        // Primeiro a explicação; o pedido do sistema só vem com o "Continuar".
        #expect(vm.etapa == .explicando(.checkin))
        #expect(await leitor.pedidosDePermissao == 0)
        #expect(await leitor.leituras == 0)

        await vm.continuarComPermissao()
        #expect(await leitor.pedidosDePermissao == 1)
        #expect(await leitor.leituras == 1)
        #expect(await leitor.ultimoTempoLimite == .seconds(10))
        #expect(vm.verificacao == .verificado)
        // O instante é o do toque em "Fazer check-in", não o do fim da leitura.
        #expect(cena.api.checkins.first?.registradoEm == cena.toque)
    }

    @Test("Toque duplo em Fazer check-in envia um registro só")
    func toqueDuplo() async throws {
        let cena = try await Cena.montar()
        let leitor = cena.leitor()
        let vm = cena.viewModel(leitor)

        async let primeiro: Void = vm.iniciar(.checkin)
        async let segundo: Void = vm.iniciar(.checkin)
        _ = await (primeiro, segundo)

        #expect(cena.api.checkins.count == 1)
        #expect(await leitor.leituras == 1)
    }

    // MARK: Falhas do GPS

    @Test("Permissão negada no pedido leva a 'Não consegui pelo GPS' sem ler a posição, e o manual funciona")
    func permissaoNegada() async throws {
        let cena = try await Cena.montar()
        let leitor = cena.leitor(permissao: .naoDeterminada, respostaAoPedido: .negada)
        let vm = cena.viewModel(leitor)

        await vm.iniciar(.checkin)
        await vm.continuarComPermissao()
        #expect(vm.etapa == .semGPS(.checkin, .permissaoNegada))
        #expect(await leitor.leituras == 0)

        await vm.registrarSemGPS()
        #expect(vm.aguardandoConfirmacao)
        #expect(cena.api.checkins.map(\.distanciaMetros) == [nil])
    }

    @Test("Permissão já negada vai direto ao manual, sem explicação nem novo pedido")
    func permissaoJaNegada() async throws {
        let cena = try await Cena.montar()
        let leitor = cena.leitor(permissao: .negada)
        let vm = cena.viewModel(leitor)

        await vm.iniciar(.checkin)

        #expect(vm.etapa == .semGPS(.checkin, .permissaoNegada))
        #expect(await leitor.pedidosDePermissao == 0)
        #expect(await leitor.leituras == 0)
    }

    @Test("Sem sinal ou com o prazo esgotado, oferece o manual", arguments: [ErroDeLocalizacao.semSinal, .tempoEsgotado])
    func semSinal(erro: ErroDeLocalizacao) async throws {
        let cena = try await Cena.montar()
        let vm = cena.viewModel(LeitorDeLocalizacaoSimulado(resultado: .failure(erro)))

        await vm.iniciar(.checkin)

        #expect(vm.etapa == .semGPS(.checkin, .semSinal))
        #expect(cena.api.checkins.isEmpty)
    }

    @Test("Precisão horizontal acima de 100 m vira manual; com 100 m a leitura vale", arguments: [(100.0, true), (101.0, false)])
    func precisao(metros: Double, vale: Bool) async throws {
        let cena = try await Cena.montar()
        let vm = cena.viewModel(cena.leitor(a: 150, precisao: metros))

        await vm.iniciar(.checkin)

        #expect(vm.etapa == (vale ? .parada : .semGPS(.checkin, .imprecisa)))
        #expect(cena.api.checkins.count == (vale ? 1 : 0))
    }

    @Test("Localização aproximada pede a precisa com a chave CheckIn; concedida, o check-in segue pelo GPS")
    func aproximadaConcedida() async throws {
        let cena = try await Cena.montar()
        let leitor = cena.leitor(permissao: .aoUsarAproximada, respostaAPrecisaoTemporaria: .aoUsarPrecisa)
        let vm = cena.viewModel(leitor)

        await vm.iniciar(.checkin)

        #expect(await leitor.chavesDePrecisaoTemporaria == ["CheckIn"])
        #expect(vm.verificacao == .verificado)
    }

    @Test("Localização aproximada mantida oferece o manual, sem ler a posição")
    func aproximadaMantida() async throws {
        let cena = try await Cena.montar()
        let leitor = cena.leitor(permissao: .aoUsarAproximada)
        let vm = cena.viewModel(leitor)

        await vm.iniciar(.checkin)

        #expect(await leitor.chavesDePrecisaoTemporaria == ["CheckIn"])
        #expect(vm.etapa == .semGPS(.checkin, .localizacaoAproximada))
        #expect(await leitor.leituras == 0)
    }

    @Test("Sem o ponto da vaga, busca o detalhe no toque; se nem ele vem, oferece o manual sem ligar o GPS")
    func pontoDaVaga() async throws {
        let cena = try await Cena.montar()
        let leitor = cena.leitor()
        let vm = cena.viewModel(leitor, comPonto: false)

        cena.api.semRede = true
        await vm.iniciar(.checkin)
        #expect(vm.etapa == .semGPS(.checkin, .enderecoIndisponivel))
        #expect(await leitor.leituras == 0)

        cena.api.semRede = false
        await vm.tentarGPSDeNovo()
        #expect(cena.api.detalhes == 2)
        #expect(vm.verificacao == .verificado)
        #expect(cena.api.checkins.map(\.distanciaMetros) == [150])
    }

    @Test("Depois de uma falha, tentar o GPS de novo é um toque novo, com instante novo")
    func tentarDeNovo() async throws {
        let cena = try await Cena.montar()
        let vm = cena.viewModel(cena.leitor(a: 350))
        await vm.iniciar(.checkin)

        cena.relogio.avancar(45)
        await vm.tentarGPSDeNovo()

        #expect(vm.etapa == .semGPS(.checkin, .longe(distanciaMetros: 350)))
        cena.relogio.avancar(5)
        await vm.registrarSemGPS()
        #expect(cena.api.checkins.first?.registradoEm == cena.relogio.agora)
    }

    // MARK: Critério 3

    @Test("Sem rede, o check-in fica pendente na fila e sobe depois com o instante do toque")
    func checkinSemRede() async throws {
        let cena = try await Cena.montar()
        let vm = cena.viewModel(cena.leitor(a: 150))
        let toque = cena.toque
        cena.api.semRede = true

        await vm.iniciar(.checkin)

        #expect(vm.checkin == .naFila(.init(instante: toque, distanciaMetros: 150, manual: false)))
        #expect(vm.mensagemDeErro == nil)
        #expect(!vm.podeFazerCheckin)
        let pendentes = try await cena.fila.pendentes()
        #expect(pendentes.map(\.tipo) == [.checkin])
        #expect(pendentes.first?.turnoID == cena.turno.id)
        #expect(pendentes.first?.instanteDoToque == toque)
        #expect(pendentes.first?.distanciaMetros == 150)

        // Reabrir a tela ainda sem rede: o que está na fila aparece como pendente, sem botão novo.
        let reaberta = cena.viewModel(cena.leitor())
        await reaberta.restaurarPendentes()
        #expect(reaberta.checkin == vm.checkin)
        #expect(!reaberta.podeFazerCheckin)

        cena.relogio.avancar(40 * 60)
        cena.api.semRede = false
        await SincronizadorAcoes(fila: cena.fila, api: cena.api).sincronizar()

        #expect(try await cena.fila.pendentes().isEmpty)
        #expect(cena.api.checkins == [RegistroEnviado(turnoID: cena.turno.id, distanciaMetros: 150, registradoEm: toque)])
    }

    @Test("Meu turno entrega o ponto da vaga ao carregar: sem rede no toque, a distância ainda é medida")
    func pontoVemDoMeuTurno() async throws {
        let cena = try await Cena.montar()
        let presenca = cena.viewModel(cena.leitor(a: 150), comPonto: false)
        let tela = MeuTurnoViewModel(turno: cena.turno, api: cena.api, relogio: cena.relogio, presenca: presenca)
        await tela.carregar()
        cena.api.semRede = true

        await presenca.iniciar(.checkin)

        #expect(presenca.checkin == .naFila(.init(instante: cena.toque, distanciaMetros: 150, manual: false)))
    }

    @Test("Sem rede e sem GPS, o check-in manual também entra na fila, sem distância")
    func manualSemRede() async throws {
        let cena = try await Cena.montar()
        let vm = cena.viewModel(cena.leitor(permissao: .negada))
        cena.api.semRede = true

        await vm.iniciar(.checkin)
        await vm.registrarSemGPS()

        #expect(vm.checkin == .naFila(.init(instante: cena.toque, distanciaMetros: nil, manual: true)))
        #expect(!vm.aguardandoConfirmacao)
        let pendentes = try await cena.fila.pendentes()
        #expect(pendentes.map(\.distanciaMetros) == [nil])
    }

    @Test("Sem rede e sem fila neste aparelho, avisa e mantém o botão")
    func semRedeSemFila() async throws {
        let cena = try await Cena.montar()
        let vm = ViewModel(turno: cena.turno, api: cena.api, localizacao: cena.leitor(), relogio: cena.relogio, pontoDaVaga: cena.ponto)
        cena.api.semRede = true

        await vm.iniciar(.checkin)

        #expect(vm.checkin == .naoFeito)
        #expect(vm.mensagemDeErro == TextosDoProfissional.Lista.semConexaoMensagem)
        #expect(vm.podeFazerCheckin)
    }

    // MARK: Critério 5

    @Test("Check-out a 150 m registra a saída com a distância e o instante do toque")
    func checkoutPerto() async throws {
        let cena = try await Cena.montar()
        let vm = await cena.comCheckinFeito(cena.leitor(a: 150))
        #expect(vm.podeFazerCheckout)

        await vm.iniciar(.checkout)

        #expect(cena.api.checkouts == [RegistroEnviado(turnoID: cena.turno.id, distanciaMetros: 150, registradoEm: cena.toque)])
        #expect(vm.checkout == .registrado(.init(instante: cena.toque, distanciaMetros: 150, manual: false)))
        #expect(vm.mensagemDeErro == nil)
        #expect(!vm.podeFazerCheckout)
    }

    @Test("Check-out a 350 m é aceito sem erro e sem pedir manual, com a distância medida")
    func checkoutLonge() async throws {
        let cena = try await Cena.montar()
        let vm = await cena.comCheckinFeito(cena.leitor(a: 350))

        await vm.iniciar(.checkout)

        #expect(vm.etapa == .parada)
        #expect(vm.mensagemDeErro == nil)
        #expect(cena.api.checkouts.map(\.distanciaMetros) == [350])
        #expect(vm.checkout == .registrado(.init(instante: cena.toque, distanciaMetros: 350, manual: false)))
        // A saída longe não desfaz a presença verificada no check-in.
        #expect(vm.verificacao == .verificado)
    }

    @Test("Sem rede, o check-out fica pendente e sobe depois com o instante do toque")
    func checkoutSemRede() async throws {
        let cena = try await Cena.montar()
        let vm = await cena.comCheckinFeito(cena.leitor(a: 150))
        cena.api.semRede = true

        await vm.iniciar(.checkout)

        let toque = cena.toque
        #expect(vm.checkout == .naFila(.init(instante: toque, distanciaMetros: 150, manual: false)))
        #expect(try await cena.fila.pendentes().map(\.tipo) == [.checkout])

        cena.relogio.avancar(3_600)
        cena.api.semRede = false
        await SincronizadorAcoes(fila: cena.fila, api: cena.api).sincronizar()

        #expect(try await cena.fila.pendentes().isEmpty)
        #expect(cena.api.checkouts == [RegistroEnviado(turnoID: cena.turno.id, distanciaMetros: 150, registradoEm: toque)])
    }

    @Test("Check-in e check-out feitos sem rede sobem na ordem dos toques")
    func osDoisSemRede() async throws {
        let cena = try await Cena.montar()
        let vm = cena.viewModel(cena.leitor(a: 150))
        cena.api.semRede = true

        await vm.iniciar(.checkin)
        #expect(vm.podeFazerCheckout)
        cena.relogio.avancar(4 * 60)
        await vm.iniciar(.checkout)

        cena.api.semRede = false
        await SincronizadorAcoes(fila: cena.fila, api: cena.api).sincronizar()

        #expect(try await cena.fila.pendentes().isEmpty)
        #expect(cena.api.checkins.count == 1)
        #expect(cena.api.checkouts.count == 1)
    }

    @Test("Check-out sem GPS oferece registrar a saída sem localização, que vai sem distância")
    func checkoutSemGPS() async throws {
        let cena = try await Cena.montar()
        let vm = await cena.comCheckinFeito(LeitorDeLocalizacaoSimulado(resultado: .failure(.tempoEsgotado)))

        await vm.iniciar(.checkout)
        #expect(vm.etapa == .semGPS(.checkout, .semSinal))

        await vm.registrarSemGPS()
        #expect(cena.api.checkouts.map(\.distanciaMetros) == [nil])
        #expect(vm.checkout == .registrado(.init(instante: cena.toque, distanciaMetros: nil, manual: false)))
    }

    @Test("Antes do check-in não há check-out")
    func checkoutAntesDoCheckin() async throws {
        let cena = try await Cena.montar()
        let leitor = cena.leitor()
        let vm = cena.viewModel(leitor)
        #expect(!vm.podeFazerCheckout)

        await vm.iniciar(.checkout)

        #expect(cena.api.checkouts.isEmpty)
        #expect(await leitor.leituras == 0)
    }

    // MARK: Recusa do servidor e estado que vem do turno

    @Test("Recusa do servidor aparece como mensagem e o botão continua disponível", arguments: [
        (CodigoErroAPI.foraDaJanela, TextosDoProfissional.Presenca.foraDaJanela),
        (.registroNoFuturo, TextosDoProfissional.Presenca.relogioAdiantado),
        (.semPermissao, MensagemDoErroAPI.texto(ErroDaApi(codigo: .semPermissao))),
    ])
    func recusa(codigo: CodigoErroAPI, mensagem: String) async throws {
        let cena = try await Cena.montar()
        let vm = cena.viewModel(cena.leitor())
        cena.api.erro = ErroDaApi(codigo: codigo)

        await vm.iniciar(.checkin)

        #expect(vm.mensagemDeErro == mensagem)
        #expect(vm.checkin == .naoFeito)
        #expect(vm.podeFazerCheckin)
        #expect(try await cena.fila.pendentes().isEmpty)
    }

    @Test("O turno que já chega com check-in manual pendente abre aguardando confirmação")
    func turnoComManualPendente() async throws {
        let cena = try await Cena.montar()
        let instante = cena.toque.addingTimeInterval(-600)
        let turno = Turno(
            id: cena.turno.id, posicaoID: cena.turno.posicaoID, vaga: cena.turno.vaga, contraparte: cena.turno.contraparte,
            contatoVisivelAte: cena.turno.contatoVisivelAte,
            checkin: Presenca(instante: instante, tipo: .manual, distanciaMetros: nil),
            verificacao: .pendente, valorAcordado: cena.turno.valorAcordado, podeAvaliar: false
        )

        let vm = cena.viewModel(cena.leitor(), turno: turno)

        #expect(vm.aguardandoConfirmacao)
        #expect(!vm.podeFazerCheckin)
        #expect(vm.podeFazerCheckout)
    }
}

@Suite("Permissão de localização do app (#17)")
struct PermissaoDeLocalizacaoDoAppTests {
    private static let raiz = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static let chavesDeSempre = ["NSLocationAlwaysAndWhenInUseUsageDescription", "NSLocationAlwaysUsageDescription"]

    @Test("O Info.plist do app instalado declara só a permissão 'ao usar', com a chave CheckIn, e nunca a 'sempre'")
    func infoPlistDoApp() throws {
        let info = try #require(Bundle.main.infoDictionary)
        try #require(Bundle.main.bundleIdentifier?.hasPrefix("com.frila") == true, "o teste precisa rodar dentro do app")

        #expect((info["NSLocationWhenInUseUsageDescription"] as? String)?.isEmpty == false)
        let temporaria = try #require(info["NSLocationTemporaryUsageDescriptionDictionary"] as? [String: String])
        #expect(temporaria[RegraDePresenca.chaveDaPrecisaoTemporaria]?.isEmpty == false)
        for chave in Self.chavesDeSempre {
            #expect(info[chave] == nil, "\(chave) não pode existir: a localização é lida só no toque")
        }
        #expect((info["UIBackgroundModes"] as? [String] ?? []).contains("location") == false)
    }

    @Test("Nem o plist parcial nem o project.yml declaram a permissão 'sempre'")
    func fontesDoPlist() throws {
        for arquivo in ["Sources/App/Info.plist", "project.yml", "Resources/InfoPlist.xcstrings"] {
            let texto = try String(contentsOf: Self.raiz.appending(path: arquivo), encoding: .utf8)
            #expect(!texto.contains("NSLocationAlways"), "\(arquivo) declara a permissão 'sempre'")
        }
    }

    @Test("O código não pede a permissão 'sempre' nem lê a localização em segundo plano")
    func codigoSemSegundoPlano() throws {
        let proibidos = ["requestAlwaysAuthorization", "allowsBackgroundLocationUpdates", "startMonitoringSignificantLocationChanges", "startMonitoring(for"]
        let fontes = Self.raiz.appending(path: "Sources")
        let enumerador = try #require(FileManager.default.enumerator(at: fontes, includingPropertiesForKeys: nil))
        var comGerenciador: [String] = []
        var achados: [String] = []
        for url in enumerador.compactMap({ $0 as? URL }) where url.pathExtension == "swift" {
            let texto = try String(contentsOf: url, encoding: .utf8)
            if texto.contains("CLLocationManager(") { comGerenciador.append(url.lastPathComponent) }
            for proibido in proibidos where texto.contains(proibido) { achados.append("\(url.lastPathComponent): \(proibido)") }
        }
        #expect(comGerenciador == ["LeitorDeLocalizacaoDoSistema.swift"], "só o leitor do sistema lê a posição do aparelho")
        #expect(achados.isEmpty, "localização fora do toque em \(achados)")
    }
}

@Suite("Textos da presença no catálogo pt-BR (#17)")
struct TextosDaPresencaTests {
    @Test("Todo texto do check-in e do check-out existe no catálogo, com tradução")
    func noCatalogo() throws {
        let raiz = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let dados = try Data(contentsOf: raiz.appending(path: "Resources/Localizable.xcstrings"))
        let catalogo = try #require(try JSONSerialization.jsonObject(with: dados) as? [String: Any])
        let chaves = Set(try #require(catalogo["strings"] as? [String: Any]).keys)

        typealias Textos = TextosDoProfissional.Presenca
        let fixos = [
            Textos.titulo, Textos.fazerCheckin, Textos.fazerCheckout, Textos.explicacaoTitulo, Textos.explicacao,
            Textos.continuar, Textos.agoraNao, Textos.lendo, Textos.enviando, Textos.semGPSTitulo,
            Textos.motivoPermissaoNegada, Textos.motivoAproximada, Textos.motivoSemSinal, Textos.motivoImprecisa,
            Textos.motivoEnderecoIndisponivel, Textos.manualExplicacao, Textos.checkinManual,
            Textos.saidaSemLocalizacaoExplicacao, Textos.saidaSemLocalizacao, Textos.tentarGPS, Textos.abrirAjustes,
            Textos.foraDaJanela, Textos.relogioAdiantado, Textos.falhaAoGuardar, Textos.falhaAoEnviar,
        ]
        let interpolados = [
            "O GPS indica que você está a cerca de %lld m do endereço da vaga.",
            "Check-in verificado às %@.",
            "Check-in verificado às %@, a %lld m do endereço.",
            "Check-in manual feito às %@. Aguardando confirmação do contratante.",
            "Check-in feito às %@, sem verificação.",
            "Sem conexão. O check-in manual das %@ está guardado neste aparelho e será enviado quando a internet voltar, com esse horário. Depois ele aguarda a confirmação do contratante.",
            "Sem conexão. O check-in das %@ está guardado neste aparelho e será enviado quando a internet voltar, com esse horário.",
            "Check-out registrado às %@.",
            "Check-out registrado às %@, a %lld m do endereço.",
            "Sem conexão. O check-out das %@ está guardado neste aparelho e será enviado quando a internet voltar, com esse horário.",
        ]
        let faltantes = (fixos + interpolados).filter { !chaves.contains($0) }
        #expect(faltantes.isEmpty, "textos da presença fora do catálogo: \(faltantes)")

        // As funções com interpolação montam o texto a partir do mesmo padrão do catálogo.
        #expect(Textos.checkinVerificado("17:58", metros: 150) == "Check-in verificado às 17:58, a 150 m do endereço.")
        #expect(Textos.checkoutRegistrado("23:02", metros: nil) == "Check-out registrado às 23:02.")
        #expect(Textos.motivoLonge(350) == "O GPS indica que você está a cerca de 350 m do endereço da vaga.")
    }
}
