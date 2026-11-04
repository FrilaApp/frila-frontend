import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

private func dataReferencia(offsetHoras: Double = 0) -> Date {
    Date(timeIntervalSince1970: 1_800_000_000 + offsetHoras * 3_600)
}

private func criarContatoExemplo(visivelAte: Date) throws -> Contato {
    Contato(
        nome: "Marcos Lima",
        telefone: "+5561999990000",
        whatsappURL: try #require(URL(string: "https://wa.me/5561999990000")),
        visivelAte: visivelAte
    )
}

private func criarTurnoExemplo(
    id: UUID = UUID(),
    funcao: String = "Garçom",
    local: String = "Bar da Quadra",
    inicio: Date,
    fim: Date,
    valor: Dinheiro = Dinheiro(centavos: 15000),
    contatoVisivelAte: Date,
    contato: Contato? = nil
) throws -> Turno {
    let vaga = VagaResumo(id: UUID(), funcao: funcao, local: local, regiaoAdministrativa: "Plano Piloto", periodo: try Periodo(inicio: inicio, fim: fim), valor: valor)
    let reputacao = Reputacao(positivas: 10, total: 10, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0)
    let contraparte = PerfilPublico(id: UUID(), tipo: .estabelecimento, nome: "Bar da Quadra", reputacao: reputacao)
    return Turno(
        id: id,
        posicaoID: UUID(),
        vaga: vaga,
        contraparte: contraparte,
        contatoVisivelAte: contatoVisivelAte,
        verificacao: .pendente,
        valorAcordado: valor,
        podeAvaliar: false,
        contato: contato
    )
}

private func criarVagaCompleta(de turno: Turno, observacoes: String?) throws -> Vaga {
    Vaga(
        id: turno.vaga.id,
        estabelecimento: turno.contraparte,
        funcao: Funcao(id: UUID(), nome: "Garçom", categoria: "SALA"),
        periodo: turno.vaga.periodo,
        local: turno.vaga.local,
        regiaoAdministrativa: turno.vaga.regiaoAdministrativa,
        ponto: try Coordenada(latitude: -15.7, longitude: -47.8),
        valor: turno.valorAcordado,
        posicoes: 1,
        posicoesAbertas: 0,
        inclusos: Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: false),
        responsavelLocal: "Renata",
        traje: nil,
        participaRateio: false,
        observacoes: observacoes,
        modo: .urgencia,
        estado: .preenchida,
        publicadoEm: turno.vaga.periodo.inicio
    )
}

private final class RelogioSimulado: Relogio, @unchecked Sendable {
    var agora: Date
    init(_ agora: Date) { self.agora = agora }
}

private final class RepositorioTurnosDuble: TurnoRepositorio, @unchecked Sendable {
    var onLer: (@Sendable () async throws -> LeituraDeTurnos)?

    init(onLer: (@Sendable () async throws -> LeituraDeTurnos)? = nil) {
        self.onLer = onLer
    }

    func ler() async throws -> LeituraDeTurnos {
        if let onLer { return try await onLer() }
        return LeituraDeTurnos(turnos: [], origem: .rede)
    }

    func meusTurnos() async throws -> [Turno] {
        try await ler().turnos
    }
}

private final class ApiClienteDuble: ApiClienteEncaminhador, @unchecked Sendable {
    var onContatoDoTurno: (@Sendable (UUID) async throws -> Contato)?
    var onDetalheDaVaga: (@Sendable (UUID) async throws -> Vaga)?
    var onMeusTurnos: (@Sendable () async throws -> [Turno])?

    override func detalheDaVaga(id: UUID) async throws -> Vaga {
        if let onDetalheDaVaga { return try await onDetalheDaVaga(id) }
        return try await base.detalheDaVaga(id: id)
    }

    override func meusTurnos() async throws -> [Turno] {
        if let onMeusTurnos { return try await onMeusTurnos() }
        return try await base.meusTurnos()
    }
    override func contatoDoTurno(id: UUID) async throws -> Contato {
        if let onContatoDoTurno { return try await onContatoDoTurno(id) }
        return try await base.contatoDoTurno(id: id)
    }

    var onAvisarACaminho: (@Sendable (UUID) async throws -> ResultadoACaminho)?
    override func avisarACaminho(turnoID: UUID) async throws -> ResultadoACaminho {
        if let onAvisarACaminho { return try await onAvisarACaminho(turnoID) }
        return try await base.avisarACaminho(turnoID: turnoID)
    }
}

@MainActor
@Suite("Meu turno do profissional (#109): detalhe, Como chegar e modo avião")
struct MeuTurnoViewModelTests {

    @Test("O app não chama contato_do_turno nem usa o contato que o turno ainda traga de uma versão antiga")
    func naoChamaContatoDoTurno() async throws {
        let agora = dataReferencia()
        let fim = agora.addingTimeInterval(4 * 3_600)
        let visivelAte = fim.addingTimeInterval(7 * 24 * 3_600)
        let legado = try criarContatoExemplo(visivelAte: visivelAte)
        let turno = try criarTurnoExemplo(inicio: agora, fim: fim, contatoVisivelAte: visivelAte, contato: legado)
        let api = ApiClienteDuble()
        api.onContatoDoTurno = { _ in
            Issue.record("contato_do_turno não deve ser chamado")
            return legado
        }

        let vm = MeuTurnoViewModel(turno: turno, api: api, relogio: RelogioSimulado(agora))
        await vm.carregar()

        // Nem o nome do contato legado serve de "quem recebe": vale a contraparte.
        #expect(vm.quemRecebeExibicao == "Bar da Quadra")
        #expect(vm.detalheCarregado)
    }

    @Test("Com o prazo do contato vencido ou com erro de rede, Meu turno segue igual e sem nada de contato")
    func prazoVencidoOuSemRedeNaoMudaOTurno() async throws {
        let agora = dataReferencia()
        let fim = agora.addingTimeInterval(4 * 3_600)
        let visivelAte = fim.addingTimeInterval(7 * 24 * 3_600)
        let turno = try criarTurnoExemplo(
            funcao: "Cozinheiro", local: "CLN 408 Bloco B", inicio: agora, fim: fim,
            valor: Dinheiro(centavos: 20000), contatoVisivelAte: visivelAte
        )
        let api = ApiClienteDuble()
        api.onDetalheDaVaga = { _ in throw ErroDaApi(codigo: .semRede) }

        // Oito dias depois do fim: antes, o contato "expirava" e a tela dizia isso.
        let vm = MeuTurnoViewModel(turno: turno, api: api, relogio: RelogioSimulado(fim.addingTimeInterval(8 * 24 * 3_600)))
        await vm.carregar()

        #expect(vm.turno.vaga.funcao == "Cozinheiro")
        #expect(vm.turno.vaga.local == "CLN 408 Bloco B")
        #expect(vm.turno.valorAcordado == Dinheiro(centavos: 20000))
        #expect(vm.observacoesDaVaga == nil)
        #expect(vm.urlMapas != nil)
        #expect(vm.detalheCarregado)
    }

    @Test("Como chegar: as observações da vaga vêm do detalhe, sem espaços nas pontas")
    func observacoesDoComoChegar() async throws {
        let agora = dataReferencia()
        let fim = agora.addingTimeInterval(4 * 3_600)
        let turno = try criarTurnoExemplo(inicio: agora, fim: fim, contatoVisivelAte: fim)
        let api = ApiClienteDuble()
        api.onDetalheDaVaga = { _ in try criarVagaCompleta(de: turno, observacoes: "  Entrada pela portaria lateral.\n") }

        let vm = MeuTurnoViewModel(turno: turno, api: api, relogio: RelogioSimulado(agora))
        #expect(vm.observacoesDaVaga == nil)
        #expect(!vm.detalheCarregado)

        await vm.carregar()
        #expect(vm.observacoesDaVaga == "Entrada pela portaria lateral.")
        #expect(vm.detalheCarregado)
    }

    @Test("Como chegar: observações em branco ou ausentes não aparecem")
    func observacoesEmBrancoSomem() async throws {
        let agora = dataReferencia()
        let fim = agora.addingTimeInterval(4 * 3_600)
        let turno = try criarTurnoExemplo(inicio: agora, fim: fim, contatoVisivelAte: fim)

        for observacoes in [nil, "", "   \n "] as [String?] {
            let api = ApiClienteDuble()
            api.onDetalheDaVaga = { _ in try criarVagaCompleta(de: turno, observacoes: observacoes) }
            let vm = MeuTurnoViewModel(turno: turno, api: api, relogio: RelogioSimulado(agora))
            await vm.carregar()
            #expect(vm.observacoesDaVaga == nil)
        }
    }

    @Test("Quem recebe prioriza o responsável local e depois a contraparte")
    func quemRecebePrioridade() async throws {
        let agora = dataReferencia()
        let fim = agora.addingTimeInterval(4 * 3_600)
        let turno = try criarTurnoExemplo(inicio: agora, fim: fim, contatoVisivelAte: fim)
        let api = ApiClienteDuble()
        api.onDetalheDaVaga = { _ in try criarVagaCompleta(de: turno, observacoes: nil) }

        let vm = MeuTurnoViewModel(turno: turno, api: api, relogio: RelogioSimulado(agora))
        #expect(vm.quemRecebeExibicao == "Bar da Quadra") // Antes de carregar detalhe da vaga

        await vm.carregar()
        #expect(vm.quemRecebeExibicao == "Renata") // Após carregar detalhe da vaga
    }

    @Test("Meus turnos carrega turnos com sucesso da rede")
    func meusTurnosCarregaDaRede() async throws {
        let agora = dataReferencia()
        let fim = agora.addingTimeInterval(4 * 3_600)
        let turno = try criarTurnoExemplo(inicio: agora, fim: fim, contatoVisivelAte: fim)

        let repo = RepositorioTurnosDuble(onLer: {
            LeituraDeTurnos(turnos: [turno], origem: .rede)
        })
        let vm = MeusTurnosViewModel(repositorio: repo)
        #expect(vm.estado == .ociosa)

        await vm.carregar()
        #expect(vm.estado == .carregada(turnos: [turno], origem: .rede))
        #expect(vm.origem == .rede)
        #expect(vm.turnos.count == 1)
    }

    @Test("Meus turnos em modo avião lê do cache e exibe dados anteriores")
    func meusTurnosModoAviaoLeDoCache() async throws {
        let agora = dataReferencia()
        let fim = agora.addingTimeInterval(4 * 3_600)
        let turno = try criarTurnoExemplo(inicio: agora, fim: fim, contatoVisivelAte: fim)

        let repo = RepositorioTurnosDuble(onLer: {
            LeituraDeTurnos(turnos: [turno], origem: .cache)
        })
        let vm = MeusTurnosViewModel(repositorio: repo)

        await vm.carregar()
        #expect(vm.estado == .carregada(turnos: [turno], origem: .cache))
        #expect(vm.origem == .cache)
        #expect(vm.turnos.count == 1)
    }

    @Test("Meus turnos falha quando sem rede e sem cache")
    func meusTurnosFalhaSemRedeSemCache() async throws {
        let repo = RepositorioTurnosDuble(onLer: {
            throw ErroDaApi(codigo: .semRede)
        })
        let vm = MeusTurnosViewModel(repositorio: repo)

        await vm.carregar()
        #expect(vm.estado == .falha(TextosDoProfissional.Lista.semConexaoMensagem))
    }

    @Test("Meus turnos atualizar chama repositório novamente")
    func meusTurnosAtualizar() async throws {
        let agora = dataReferencia()
        let fim = agora.addingTimeInterval(4 * 3_600)
        let turno = try criarTurnoExemplo(inicio: agora, fim: fim, contatoVisivelAte: fim)

        final class Contador: @unchecked Sendable {
            private let trava = NSLock()
            private var _valor = 0
            var valor: Int { trava.withLock { _valor } }
            func incrementar() { trava.withLock { _valor += 1 } }
        }
        let contador = Contador()

        let repo = RepositorioTurnosDuble(onLer: {
            contador.incrementar()
            return LeituraDeTurnos(turnos: [turno], origem: .rede)
        })
        let vm = MeusTurnosViewModel(repositorio: repo)

        await vm.carregar()
        #expect(contador.valor == 1)

        await vm.atualizar()
        #expect(contador.valor == 2)
        #expect(vm.turnos.count == 1)
    }

    @Test("O view model da avaliação é um só por turno: o redesenho da tela (detalhe que chega, fila que muda) não apaga a resposta escolhida")
    func avaliacaoViewModelEstavel() async throws {
        let agora = dataReferencia()
        let base = try criarTurnoExemplo(inicio: agora.addingTimeInterval(-6 * 3600), fim: agora.addingTimeInterval(-3600), contatoVisivelAte: agora.addingTimeInterval(86_400))
        // Presença verificada e avaliação liberada pelo servidor: é o turno que a tela deixa avaliar.
        let turno = Turno(id: base.id, posicaoID: base.posicaoID, vaga: base.vaga, contraparte: base.contraparte, contatoVisivelAte: base.contatoVisivelAte,
                          verificacao: .verificado, valorAcordado: base.valorAcordado, podeAvaliar: true, avaliacaoInformada: true)
        let vm = MeuTurnoViewModel(turno: turno, api: ApiClienteEmMemoria(), contaID: UUID(),
                                   armazenamentoAvaliacoes: ArmazenamentoAvaliacoesEmMemoria(), relogio: RelogioSimulado(agora))
        let primeiro = try #require(vm.criarAvaliacaoViewModel())
        primeiro.resposta = true
        await vm.carregarRecusasDaFila() // o que um redesenho da tela dispara
        let segundo = try #require(vm.criarAvaliacaoViewModel())
        #expect(primeiro === segundo)
        #expect(segundo.resposta == true)
    }

    // MARK: - Estou a caminho e cancelamento (US14, RN12)

    @Test("Janela do aviso Estou a caminho: antes, limites inferior/superior, dentro e depois")
    func janelaDoAvisoACaminho() async throws {
        let agora = dataReferencia()
        let relogio = RelogioSimulado(agora)
        let inicio = agora.addingTimeInterval(3 * 3600) // daqui a 3 horas
        let fim = inicio.addingTimeInterval(4 * 3600)
        let turno = try criarTurnoExemplo(inicio: inicio, fim: fim, contatoVisivelAte: fim)
        let api = ApiClienteEmMemoria()

        let vm = MeuTurnoViewModel(turno: turno, api: api, relogio: relogio)

        // 1. Antes da janela: 3h e 1s antes do início
        relogio.agora = inicio.addingTimeInterval(-3 * 3600 - 1)
        #expect(!vm.podeAvisarACaminho)

        // 2. Limite inferior: exatamente 3h antes
        relogio.agora = inicio.addingTimeInterval(-3 * 3600)
        #expect(vm.podeAvisarACaminho)

        // 3. Dentro da janela: 1h antes do início
        relogio.agora = inicio.addingTimeInterval(-1 * 3600)
        #expect(vm.podeAvisarACaminho)

        // 4. Limite superior: exatamente 15 minutos após o início
        relogio.agora = inicio.addingTimeInterval(15 * 60)
        #expect(vm.podeAvisarACaminho)

        // 5. Depois da janela: 15 minutos e 1s após o início
        relogio.agora = inicio.addingTimeInterval(15 * 60 + 1)
        #expect(!vm.podeAvisarACaminho)
    }

    @Test("Turno já avisado não oferece o botão Estou a caminho novamente")
    func turnoJaAvisadoNaoPodeAvisarDeNovo() async throws {
        let agora = dataReferencia()
        let relogio = RelogioSimulado(agora)
        let inicio = agora.addingTimeInterval(1 * 3600)
        let fim = inicio.addingTimeInterval(4 * 3600)
        let base = try criarTurnoExemplo(inicio: inicio, fim: fim, contatoVisivelAte: fim)
        let turnoAvisado = base.com(aCaminhoEm: agora.addingTimeInterval(-600))
        let vm = MeuTurnoViewModel(turno: turnoAvisado, api: ApiClienteEmMemoria(), relogio: relogio)

        #expect(!vm.podeAvisarACaminho)
        #expect(vm.aCaminhoEm != nil)
    }

    @Test("Turno com check-in não oferece Estou a caminho nem permite cancelar")
    func turnoComCheckinNaoAvisaENaoCancela() async throws {
        let agora = dataReferencia()
        let relogio = RelogioSimulado(agora)
        let inicio = agora.addingTimeInterval(1 * 3600)
        let fim = inicio.addingTimeInterval(4 * 3600)
        let checkin = Presenca(instante: agora, tipo: .geolocalizado, distanciaMetros: 50)
        let base = try criarTurnoExemplo(inicio: inicio, fim: fim, contatoVisivelAte: fim)
        let turnoComCheckin = Turno(
            id: base.id, posicaoID: base.posicaoID, vaga: base.vaga, contraparte: base.contraparte,
            contatoVisivelAte: base.contatoVisivelAte, checkin: checkin,
            verificacao: .verificado, valorAcordado: base.valorAcordado, podeAvaliar: false
        )
        let vm = MeuTurnoViewModel(turno: turnoComCheckin, api: ApiClienteEmMemoria(), relogio: relogio)

        #expect(!vm.podeAvisarACaminho)
        #expect(!vm.podeCancelar)
    }

    @Test("Aviso a caminho com erro fora da janela exibe mensagem do Guia de Voz e não oferece tentar de novo")
    func avisoForaDaJanelaExibeGuiaDeVoz() async throws {
        let agora = dataReferencia()
        let relogio = RelogioSimulado(agora)
        let inicio = agora.addingTimeInterval(1 * 3600)
        let fim = inicio.addingTimeInterval(4 * 3600)
        let turno = try criarTurnoExemplo(inicio: inicio, fim: fim, contatoVisivelAte: fim)
        let api = ApiClienteDuble()
        api.onAvisarACaminho = { _ in throw ErroDaApi(codigo: .aCaminhoForaDaJanela) }

        let vm = MeuTurnoViewModel(turno: turno, api: api, relogio: relogio)
        #expect(vm.podeAvisarACaminho)

        await vm.avisarACaminho()
        #expect(vm.mensagemErroACaminho == TextosDoProfissional.Turnos.erroACaminhoForaDaJanela)
        #expect(!vm.podeTentarAvisarDeNovo)
    }

    @Test("Aviso a caminho sem rede exibe mensagem recuperável com Tentar de novo")
    func avisoSemRedeExibeMensagemRecuperavel() async throws {
        let agora = dataReferencia()
        let relogio = RelogioSimulado(agora)
        let inicio = agora.addingTimeInterval(1 * 3600)
        let fim = inicio.addingTimeInterval(4 * 3600)
        let turno = try criarTurnoExemplo(inicio: inicio, fim: fim, contatoVisivelAte: fim)
        let api = ApiClienteDuble()
        api.onAvisarACaminho = { _ in throw ErroDaApi(codigo: .semRede) }

        let vm = MeuTurnoViewModel(turno: turno, api: api, relogio: relogio)
        await vm.avisarACaminho()

        #expect(vm.mensagemErroACaminho == TextosDoProfissional.Turnos.erroACaminhoSemRede)
        #expect(vm.podeTentarAvisarDeNovo)
        #expect(!vm.podeExibirBotaoACaminho, "Após falha de rede, o botão Estou a caminho deve ser ocultado para manter apenas Tentar de novo")

        // Sucesso na segunda tentativa
        let gravadoEm = agora.addingTimeInterval(10)
        api.onAvisarACaminho = { id in ResultadoACaminho(turnoID: id, aCaminhoEm: gravadoEm) }
        await vm.avisarACaminho()

        #expect(vm.aCaminhoEm == gravadoEm)
        #expect(vm.mensagemErroACaminho == nil)
        #expect(!vm.podeAvisarACaminho)
        #expect(!vm.podeExibirBotaoACaminho)
    }

    @Test("Toque duplo em avisarACaminho dispara apenas uma chamada à API")
    func toqueDuploAvisaApenasUmaVez() async throws {
        final class Contador: @unchecked Sendable {
            private let lock = NSLock()
            private var contagem = 0
            func incrementar() {
                lock.lock()
                contagem += 1
                lock.unlock()
            }
            var valor: Int {
                lock.lock()
                defer { lock.unlock() }
                return contagem
            }
        }

        let agora = dataReferencia()
        let relogio = RelogioSimulado(agora)
        let inicio = agora.addingTimeInterval(1 * 3600)
        let fim = inicio.addingTimeInterval(4 * 3600)
        let turno = try criarTurnoExemplo(inicio: inicio, fim: fim, contatoVisivelAte: fim)
        let api = ApiClienteDuble()
        let gravadoEm = agora.addingTimeInterval(5)
        let contador = Contador()
        api.onAvisarACaminho = { id in
            contador.incrementar()
            try? await Task.sleep(nanoseconds: 50_000_000)
            return ResultadoACaminho(turnoID: id, aCaminhoEm: gravadoEm)
        }

        let vm = MeuTurnoViewModel(turno: turno, api: api, relogio: relogio)
        async let t1: Void = vm.avisarACaminho()
        async let t2: Void = vm.avisarACaminho()
        _ = await (t1, t2)

        #expect(contador.valor == 1)
        #expect(vm.aCaminhoEm == gravadoEm)
    }
}

/// Quanto o `dormir` do teste recebeu: a espera até o fim previsto.
private final class EsperaRegistrada: @unchecked Sendable {
    private let trava = NSLock()
    private var _valores: [TimeInterval] = []
    var valores: [TimeInterval] { trava.withLock { _valores } }
    func registrar(_ valor: TimeInterval) { trava.withLock { _valores.append(valor) } }
}

private actor LeiturasContadas {
    private(set) var valor = 0
    func somar() { valor += 1 }
}

@MainActor
@Suite("Avaliação libera no horário: aviso de espera e cartão no fim previsto (#672)")
struct AvaliacaoLiberaNoHorarioDoProfissionalTests {
    /// 05:00 em São Paulo (1_800_000_000 é 08:00 UTC); o fim previsto é 07:00.
    private let agora = dataReferencia()

    private func turno(
        verificacao: Verificacao = .verificado,
        comCheckout: Bool = true,
        servidorLibera: Bool? = nil
    ) throws -> Turno {
        let base = try criarTurnoExemplo(
            inicio: agora.addingTimeInterval(-3_600), fim: agora.addingTimeInterval(2 * 3_600), contatoVisivelAte: agora.addingTimeInterval(86_400)
        )
        return Turno(
            id: base.id, posicaoID: base.posicaoID, vaga: base.vaga, contraparte: base.contraparte, contatoVisivelAte: base.contatoVisivelAte,
            checkin: Presenca(instante: agora.addingTimeInterval(-3_000), tipo: .geolocalizado, distanciaMetros: 20),
            checkout: comCheckout ? Presenca(instante: agora.addingTimeInterval(-60), tipo: .geolocalizado, distanciaMetros: 20) : nil,
            verificacao: verificacao, valorAcordado: base.valorAcordado,
            podeAvaliar: servidorLibera ?? false, avaliacaoInformada: servidorLibera == nil ? nil : true
        )
    }

    private func viewModel(_ turno: Turno, relogio: RelogioSimulado, api: any ApiCliente = ApiClienteEmMemoria()) -> MeuTurnoViewModel {
        MeuTurnoViewModel(
            turno: turno, api: api, contaID: UUID(),
            armazenamentoAvaliacoes: ArmazenamentoAvaliacoesEmMemoria(), relogio: relogio
        )
    }

    @Test("Antes do fim, com presença verificada e check-out feito: mostra a hora do fim e não abre o cartão")
    func antesDoFim() throws {
        let vm = viewModel(try turno(), relogio: RelogioSimulado(agora))
        let fim = agora.addingTimeInterval(2 * 3_600)
        #expect(vm.podeAvaliar == false)
        #expect(vm.liberacaoDaAvaliacao == fim)
        #expect(TextosDoProfissional.Avaliacao.liberaAs(FormatadorFrila().hora(fim)) == "A avaliação libera às 07:00")
    }

    @Test("No instante do fim e depois dele: o cartão abre e o aviso some")
    func noFimEDepois() throws {
        let fim = agora.addingTimeInterval(2 * 3_600)
        let relogio = RelogioSimulado(fim)
        let vm = viewModel(try turno(), relogio: relogio)
        #expect(vm.podeAvaliar)
        #expect(vm.liberacaoDaAvaliacao == nil)
        relogio.agora = fim.addingTimeInterval(1_800)
        #expect(vm.podeAvaliar)
        #expect(vm.liberacaoDaAvaliacao == nil)
    }

    @Test("Um segundo antes do fim ainda espera")
    func umSegundoAntes() throws {
        let fim = agora.addingTimeInterval(2 * 3_600)
        let vm = viewModel(try turno(), relogio: RelogioSimulado(fim.addingTimeInterval(-1)))
        #expect(vm.podeAvaliar == false)
        #expect(vm.liberacaoDaAvaliacao == fim)
    }

    @Test("Presença não verificada (check-in manual sem confirmação): nem hora nem cartão")
    func presencaNaoVerificada() throws {
        let relogio = RelogioSimulado(agora)
        let vm = viewModel(try turno(verificacao: .pendente), relogio: relogio)
        #expect(vm.podeAvaliar == false)
        #expect(vm.liberacaoDaAvaliacao == nil)
        relogio.agora = agora.addingTimeInterval(3 * 3_600)
        #expect(vm.podeAvaliar == false)
        #expect(vm.liberacaoDaAvaliacao == nil)
    }

    @Test("Sem check-out ainda: o turno segue em andamento e não mostra o aviso")
    func semCheckout() throws {
        let vm = viewModel(try turno(comCheckout: false), relogio: RelogioSimulado(agora))
        #expect(vm.liberacaoDaAvaliacao == nil)
    }

    @Test("Turno cancelado não mostra aviso")
    func cancelado() throws {
        let base = try turno()
        let cancelado = Turno(
            id: base.id, posicaoID: base.posicaoID, vaga: base.vaga, contraparte: base.contraparte, contatoVisivelAte: base.contatoVisivelAte,
            checkin: base.checkin, checkout: base.checkout, verificacao: .verificado, valorAcordado: base.valorAcordado,
            podeAvaliar: false, estado: .cancelada
        )
        let vm = viewModel(cancelado, relogio: RelogioSimulado(agora))
        #expect(vm.liberacaoDaAvaliacao == nil)
    }

    @Test("Turno já avaliado por este lado mostra a resposta, e não o aviso de espera")
    func jaAvaliado() throws {
        let base = try turno()
        let avaliado = base.com(avaliacao: Avaliacao(turnoID: base.id, resposta: true, criadaEm: agora))
        let vm = viewModel(avaliado, relogio: RelogioSimulado(agora))
        #expect(vm.liberacaoDaAvaliacao == nil)
    }

    @Test("Com a tela aberta, quando o fim passa o cartão aparece sozinho: o turno é relido e o servidor confirma")
    func cartaoApareceNoFim() async throws {
        let fim = agora.addingTimeInterval(2 * 3_600)
        let relogio = RelogioSimulado(agora)
        let inicial = try turno(servidorLibera: false)
        // O servidor só diz `pode_avaliar` depois do fim previsto.
        let liberado = Turno(
            id: inicial.id, posicaoID: inicial.posicaoID, vaga: inicial.vaga, contraparte: inicial.contraparte,
            contatoVisivelAte: inicial.contatoVisivelAte, checkin: inicial.checkin, checkout: inicial.checkout,
            verificacao: .verificado, valorAcordado: inicial.valorAcordado, podeAvaliar: true, avaliacaoInformada: true
        )
        let api = ApiClienteDuble()
        api.onMeusTurnos = { [liberado] in [liberado] }
        let vm = viewModel(inicial, relogio: relogio, api: api)
        #expect(vm.podeAvaliar == false)
        #expect(vm.liberacaoDaAvaliacao == fim)

        let esperas = EsperaRegistrada()
        await vm.aguardarLiberacaoDaAvaliacao { espera in
            esperas.registrar(espera)
            relogio.agora = fim
        }

        #expect(esperas.valores == [2 * 3_600])
        #expect(vm.turno.podeAvaliar)
        #expect(vm.podeAvaliar)
        #expect(vm.liberacaoDaAvaliacao == nil)
    }

    @Test("Se o fim já passou ao abrir a tela, não há espera nenhuma")
    func fimJaPassou() async throws {
        let relogio = RelogioSimulado(agora.addingTimeInterval(3 * 3_600))
        let vm = viewModel(try turno(), relogio: relogio)
        let esperas = EsperaRegistrada()
        await vm.aguardarLiberacaoDaAvaliacao { esperas.registrar($0) }
        #expect(esperas.valores.isEmpty)
        #expect(vm.podeAvaliar)
    }

    @Test("Tela fechada antes do fim: a espera cancelada não reavalia nem relê")
    func esperaCancelada() async throws {
        let relogio = RelogioSimulado(agora)
        let leituras = LeiturasContadas()
        let api = ApiClienteDuble()
        api.onMeusTurnos = { await leituras.somar(); return [] }
        let vm = viewModel(try turno(), relogio: relogio, api: api)
        let tarefa = Task { @MainActor in
            await vm.aguardarLiberacaoDaAvaliacao { _ in
                withUnsafeCurrentTask { $0?.cancel() }
            }
        }
        await tarefa.value
        #expect(await leituras.valor == 0)
        #expect(vm.podeAvaliar == false)
    }
}
