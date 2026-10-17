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
@Suite("Meu turno do profissional (#109): detalhe, contato e modo avião")
struct MeuTurnoViewModelTests {

    @Test("Contato aparece após confirmação e fica visível até 7 dias")
    func contatoVisivelAposConfirmacao() async throws {
        let agora = dataReferencia()
        let fim = agora.addingTimeInterval(4 * 3_600)
        let visivelAte = fim.addingTimeInterval(7 * 24 * 3_600)
        let contato = try criarContatoExemplo(visivelAte: visivelAte)
        let turno = try criarTurnoExemplo(inicio: agora, fim: fim, contatoVisivelAte: visivelAte, contato: contato)
        let api = ApiClienteDuble()
        api.onContatoDoTurno = { _ in contato }

        let vm = MeuTurnoViewModel(turno: turno, api: api, relogio: RelogioSimulado(agora))
        #expect(vm.contato != nil)
        #expect(!vm.contatoExpirado)
        #expect(vm.urlWhatsApp != nil)

        await vm.carregar()
        #expect(vm.contato?.nome == "Marcos Lima")
        #expect(!vm.contatoExpirado)
    }

    @Test("Contato expira e some 7 dias depois do turno")
    func contatoExpiraApos7Dias() async throws {
        let inicio = dataReferencia()
        let fim = inicio.addingTimeInterval(4 * 3_600)
        let visivelAte = fim.addingTimeInterval(7 * 24 * 3_600)
        let contato = try criarContatoExemplo(visivelAte: visivelAte)
        let turno = try criarTurnoExemplo(inicio: inicio, fim: fim, contatoVisivelAte: visivelAte, contato: contato)

        let relogioAposExpiracao = RelogioSimulado(fim.addingTimeInterval(8 * 24 * 3_600))
        let api = ApiClienteDuble()
        api.onContatoDoTurno = { _ in contato }

        let vm = MeuTurnoViewModel(turno: turno, api: api, relogio: relogioAposExpiracao)
        #expect(vm.contato == nil)
        #expect(vm.contatoExpirado)
        #expect(vm.urlWhatsApp == nil)

        await vm.carregar()
        #expect(vm.contato == nil)
        #expect(vm.contatoExpirado)
    }

    @Test("403 contato_expirado esconde o contato com explicação")
    func contatoExpirado403() async throws {
        let agora = dataReferencia()
        let fim = agora.addingTimeInterval(4 * 3_600)
        let visivelAte = fim.addingTimeInterval(7 * 24 * 3_600)
        let turno = try criarTurnoExemplo(inicio: agora, fim: fim, contatoVisivelAte: visivelAte, contato: nil)

        let api = ApiClienteDuble()
        api.onContatoDoTurno = { _ in throw ErroDaApi(codigo: .contatoExpirado) }

        let vm = MeuTurnoViewModel(turno: turno, api: api, relogio: RelogioSimulado(agora))
        #expect(!vm.contatoExpirado)

        await vm.carregar()
        #expect(vm.contato == nil)
        #expect(vm.contatoExpirado)
        #expect(vm.urlWhatsApp == nil)
    }

    @Test("Botão do WhatsApp abre a conversa com o número certo e mensagem pronta")
    func botaoWhatsAppComMensagemPronta() async throws {
        let agora = dataReferencia()
        let fim = agora.addingTimeInterval(8 * 3_600)
        let visivelAte = fim.addingTimeInterval(7 * 24 * 3_600)
        let contato = try criarContatoExemplo(visivelAte: visivelAte)
        let turno = try criarTurnoExemplo(
            funcao: "Garçom",
            local: "Bar da Quadra",
            inicio: agora,
            fim: fim,
            contatoVisivelAte: visivelAte,
            contato: contato
        )
        let vm = MeuTurnoViewModel(turno: turno, api: ApiClienteDuble(), relogio: RelogioSimulado(agora))

        let url = try #require(vm.urlWhatsApp)
        #expect(url.host() == "wa.me")
        #expect(url.path().contains("5561999990000"))

        let componentes = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let textoMensagem = componentes.queryItems?.first(where: { $0.name == "text" })?.value ?? ""
        #expect(textoMensagem.contains("Garçom"))
        #expect(textoMensagem.contains("Bar da Quadra"))
        #expect(textoMensagem.contains("Olá! Sou o profissional do turno"))
    }

    @Test("Em modo avião, o turno confirmado continua legível com endereço, horário, função, valor e contato")
    func modoAviaoPreservaTurnoEContato() async throws {
        let agora = dataReferencia()
        let fim = agora.addingTimeInterval(4 * 3_600)
        let visivelAte = fim.addingTimeInterval(7 * 24 * 3_600)
        let contato = try criarContatoExemplo(visivelAte: visivelAte)
        let turno = try criarTurnoExemplo(
            funcao: "Cozinheiro",
            local: "CLN 408 Bloco B",
            inicio: agora,
            fim: fim,
            valor: Dinheiro(centavos: 20000),
            contatoVisivelAte: visivelAte,
            contato: contato
        )

        let api = ApiClienteDuble()
        api.onContatoDoTurno = { _ in throw ErroDaApi(codigo: .semRede) }

        let vm = MeuTurnoViewModel(turno: turno, api: api, relogio: RelogioSimulado(agora))
        await vm.carregar()

        #expect(vm.turno.vaga.funcao == "Cozinheiro")
        #expect(vm.turno.vaga.local == "CLN 408 Bloco B")
        #expect(vm.turno.valorAcordado == Dinheiro(centavos: 20000))
        #expect(vm.turno.vaga.periodo.inicio == agora)
        #expect(vm.turno.vaga.periodo.fim == fim)
        #expect(vm.contato?.telefone == "+5561999990000")
        #expect(!vm.contatoExpirado)
    }

    @Test("Em modo avião, contato expira se o relógio passar de 7 dias")
    func modoAviaoContatoExpiraSeDataPassou() async throws {
        let agora = dataReferencia()
        let fim = agora.addingTimeInterval(4 * 3_600)
        let visivelAte = fim.addingTimeInterval(7 * 24 * 3_600)
        let contato = try criarContatoExemplo(visivelAte: visivelAte)
        let turno = try criarTurnoExemplo(inicio: agora, fim: fim, contatoVisivelAte: visivelAte, contato: contato)

        let relogioAposExpiracao = RelogioSimulado(fim.addingTimeInterval(8 * 24 * 3_600))
        let api = ApiClienteDuble()
        api.onContatoDoTurno = { _ in throw ErroDaApi(codigo: .semRede) }

        let vm = MeuTurnoViewModel(turno: turno, api: api, relogio: relogioAposExpiracao)
        await vm.carregar()

        #expect(vm.contato == nil)
        #expect(vm.contatoExpirado)
    }

    @Test("Quem recebe prioriza responsável local, depois contato e depois contraparte")
    func quemRecebePrioridade() async throws {
        let agora = dataReferencia()
        let fim = agora.addingTimeInterval(4 * 3_600)
        let visivelAte = fim.addingTimeInterval(7 * 24 * 3_600)
        let contato = try criarContatoExemplo(visivelAte: visivelAte)
        let turno = try criarTurnoExemplo(inicio: agora, fim: fim, contatoVisivelAte: visivelAte, contato: contato)

        let api = ApiClienteDuble()
        let vagaCompleta = Vaga(
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
            observacoes: nil,
            modo: .urgencia,
            estado: .preenchida,
            publicadoEm: agora
        )
        api.onDetalheDaVaga = { _ in vagaCompleta }

        let vm = MeuTurnoViewModel(turno: turno, api: api, relogio: RelogioSimulado(agora))
        #expect(vm.quemRecebeExibicao == "Marcos Lima") // Antes de carregar detalhe da vaga

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

    @Test("O view model da avaliação é um só por turno: o redesenho da tela (contato que chega, fila que muda) não apaga a resposta escolhida")
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
