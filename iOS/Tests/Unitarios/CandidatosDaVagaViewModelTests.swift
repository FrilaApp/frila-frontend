import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

/// Relógio que o teste avança: a seleção fecha 24 horas antes do início (RN24).
private final class RelogioDeTeste: Relogio, @unchecked Sendable {
    private let trava = NSLock()
    private var _agora: Date
    init(_ agora: Date) { _agora = agora }
    var agora: Date { trava.withLock { _agora } }
    func avancar(para instante: Date) { trava.withLock { _agora = instante } }
}

/// O que a rede pode fazer com a escolha e com as leituras, por cima do dublê em memória.
private final class ApiDaSelecao: ApiClienteEncaminhador, @unchecked Sendable {
    enum Escolha {
        /// Vai para o dublê.
        case normal
        /// Não sai do aparelho: o dublê nem é chamado.
        case semRede
        /// O servidor escolhe, mas a resposta se perde no caminho.
        case respostaPerdida
    }

    private let trava = NSLock()
    private var _escolha = Escolha.normal
    private var _falhaNosCandidatos: ErroDaApi?
    private var _falhaNoPainel: ErroDaApi?
    private var _escolhasEnviadas = 0

    var escolha: Escolha {
        get { trava.withLock { _escolha } }
        set { trava.withLock { _escolha = newValue } }
    }

    var falhaNosCandidatos: ErroDaApi? {
        get { trava.withLock { _falhaNosCandidatos } }
        set { trava.withLock { _falhaNosCandidatos = newValue } }
    }

    var falhaNoPainel: ErroDaApi? {
        get { trava.withLock { _falhaNoPainel } }
        set { trava.withLock { _falhaNoPainel = newValue } }
    }

    /// Quantas escolhas a tela mandou, cheguem ou não ao servidor.
    var escolhasEnviadas: Int { trava.withLock { _escolhasEnviadas } }

    override func candidatosDaVaga(id: UUID) async throws -> [Candidato] {
        if let falha = falhaNosCandidatos { throw falha }
        return try await base.candidatosDaVaga(id: id)
    }

    override func painelEstabelecimento(id: UUID, periodo: Periodo) async throws -> Painel {
        if let falha = falhaNoPainel { throw falha }
        return try await base.painelEstabelecimento(id: id, periodo: periodo)
    }

    override func escolherCandidato(candidaturaID: UUID) async throws -> ResultadoConfirmacao {
        trava.withLock { _escolhasEnviadas += 1 }
        switch escolha {
        case .normal:
            return try await base.escolherCandidato(candidaturaID: candidaturaID)
        case .semRede:
            throw ErroDaApi(codigo: .semRede)
        case .respostaPerdida:
            _ = try await base.escolherCandidato(candidaturaID: candidaturaID)
            // Queda no meio da chamada: o cliente não sabe se o servidor escolheu.
            throw ErroDaApi(codigo: .desconhecido, codigoOriginal: "NSURLErrorNetworkConnectionLost")
        }
    }
}

/// Uma vaga de seleção com candidatos, a tela de candidatos dela e o painel que a tela relê.
@MainActor
private struct Cena {
    let base: ApiClienteEmMemoria
    let api: ApiDaSelecao
    let relogio: RelogioDeTeste
    let vagaID: UUID
    let inicio: Date
    let viewModel: CandidatosDaVagaViewModel

    static let hora: TimeInterval = 3_600
    static let agora = Date(timeIntervalSince1970: 1_800_000_000)

    /// O cenário do esquema Local, com os quatro candidatos de `candidatos.json` e uma posição.
    static func doCenario(_ cenario: ApiClienteEmMemoria.Cenario = .selecaoComCandidatos) async throws -> Cena {
        let relogio = RelogioDeTeste(agora)
        let base = ApiClienteEmMemoria(cenario: cenario, relogio: relogio)
        let vaga = try #require(try await base.vagasAbertas().first)
        return Cena(base: base, relogio: relogio, vagaID: vaga.id, inicio: vaga.periodo.inicio)
    }

    /// Uma vaga publicada pela casa da fixture, com a quantidade de posições pedida e uma
    /// candidatura de cada profissional.
    static func publicada(
        posicoes: Int = 1, candidatos: [PerfilPublico], cenario: ApiClienteEmMemoria.Cenario = .sucesso
    ) async throws -> Cena {
        let relogio = RelogioDeTeste(agora)
        let base = ApiClienteEmMemoria(cenario: cenario, relogio: relogio)
        let casa = try #require(try await base.meusEstabelecimentos().first)
        let funcao = try #require(try await base.funcoes().first)
        let inicio = agora.addingTimeInterval(72 * hora)
        let vagaID = try await base.publicarVaga(PublicacaoVaga(
            estabelecimentoID: casa.id, funcaoID: funcao.id,
            periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(4 * hora)),
            local: "CLS 405, Asa Sul, Brasília - DF", regiaoAdministrativa: "Plano Piloto",
            ponto: try Coordenada(latitude: -15.8121, longitude: -47.8997), valor: Dinheiro(centavos: 12000),
            posicoes: posicoes, inclusos: Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Marina", modo: .selecao, chave: UUID()
        )).vagaID
        // Um minuto entre as candidaturas: a ordem da lista é a de chegada.
        for (indice, candidato) in candidatos.enumerated() {
            relogio.avancar(para: agora.addingTimeInterval(TimeInterval(indice + 1) * 60))
            try await base.receberCandidatura(vagaID: vagaID, de: candidato)
        }
        return Cena(base: base, relogio: relogio, vagaID: vagaID, inicio: inicio)
    }

    private init(base: ApiClienteEmMemoria, relogio: RelogioDeTeste, vagaID: UUID, inicio: Date) {
        let api = ApiDaSelecao(base: base)
        self.base = base
        self.api = api
        self.relogio = relogio
        self.vagaID = vagaID
        self.inicio = inicio
        viewModel = CandidatosDaVagaViewModel(vagaID: vagaID, api: api, relerVaga: { try? await Self.vagaNoPainel(api, vagaID: vagaID) })
    }

    /// A vaga como o painel a mostra: é o que Minhas vagas lê depois de cada escolha.
    static func vagaNoPainel(_ api: any ApiCliente, vagaID: UUID) async throws -> VagaNoPainel {
        let casa = try #require(try await api.meusEstabelecimentos().first)
        let periodo = try Periodo(inicio: agora.addingTimeInterval(-hora), fim: agora.addingTimeInterval(400 * hora))
        return try #require(try await api.painelEstabelecimento(id: casa.id, periodo: periodo).vagas.first { $0.vaga.id == vagaID })
    }

    func vagaNoPainel() async throws -> VagaNoPainel { try await Self.vagaNoPainel(base, vagaID: vagaID) }

    func candidato(_ nome: String) throws -> Candidato {
        try #require(viewModel.candidatos.first { $0.profissional.nome == nome })
    }

    /// O toque em "Escolher" e a confirmação no alerta, até a resposta chegar.
    func escolher(_ nome: String) async throws {
        viewModel.pedirEscolha(try candidato(nome))
        await viewModel.confirmarEscolha()?.value
    }

    static func perfil(_ numero: Int, _ nome: String) -> PerfilPublico {
        PerfilPublico(
            id: UUID(uuidString: "81000000-0000-0000-0000-00000000000\(numero)")!, tipo: .profissional, nome: nome, funcoes: ["Garçom"],
            reputacao: Reputacao(positivas: 3, total: 4, taxaComparecimento: 0.75, turnosConsiderados: 4, turnosRealizados: 3)
        )
    }
}

@MainActor
@Suite("Candidatos da vaga em seleção: lista e escolha (#10)")
struct CandidatosDaVagaViewModelTests {
    // MARK: Lista

    @Test("A lista traz os candidatos por ordem de chegada, com o perfil e a reputação de cada um")
    func carrega() async throws {
        let cena = try await Cena.doCenario()
        #expect(cena.viewModel.estado == .carregando)

        await cena.viewModel.carregar()

        #expect(cena.viewModel.candidatos.map(\.profissional.nome) == ["Ana Cunha", "Bruno Tavares", "Carla Menezes", "Diego Rocha"])
        #expect(try cena.candidato("Ana Cunha").profissional.reputacao.positivas == 7)
        #expect(try cena.candidato("Carla Menezes").profissional.reputacao.semHistorico)
        #expect(cena.viewModel.resultado == nil && cena.viewModel.falha == nil && !cena.viewModel.desatualizada)
    }

    @Test("O selo da equipe (da_equipe, 0.2.38) marca só quem está na equipe da casa e não reordena a lista")
    func seloDaEquipeNaoReordena() async throws {
        let cena = try await Cena.doCenario(.selecaoComCandidatoDaEquipe)
        await cena.viewModel.carregar()

        // Bruno é da equipe e continua em segundo: a ordem é a de chegada (RN06, D7).
        #expect(cena.viewModel.candidatos.map(\.profissional.nome) == ["Ana Cunha", "Bruno Tavares", "Carla Menezes", "Diego Rocha"])
        #expect(cena.viewModel.candidatos.map(\.daEquipe) == [false, true, false, false])
        #expect(cena.viewModel.candidatos.map(\.criadaEm) == cena.viewModel.candidatos.map(\.criadaEm).sorted())
        #expect(TextosDosCandidatos.daEquipe == "Da sua equipe")
        // A escolha de quem é da equipe é a de sempre.
        try await cena.escolher("Bruno Tavares")
        #expect(cena.viewModel.resultado == .confirmado(nome: "Bruno Tavares", vagaPreenchida: true))
    }

    @Test("O prazo de escolha é 24 horas antes do início, no fuso de São Paulo (MS-RF02, D2)")
    func prazoDeEscolha() throws {
        let inicio = try #require(ISO8601DateFormatter().date(from: "2026-10-10T18:00:00Z"))
        #expect(RegraDaSelecao.prazoDeEscolha(inicio: inicio) == inicio.addingTimeInterval(-24 * Cena.hora))
        #expect(TextosDosCandidatos.prazoDeEscolha(inicio: inicio) == "Escolha até 09/10/2026 às 15:00, quando a vaga fecha.")
    }

    @Test("Reposição em urgência (D4 e D5): a vaga de seleção com posição aberta a 24 h ou menos do início não espera escolha")
    func reposicaoEmUrgencia() throws {
        let agora = Cena.agora
        #expect(SituacaoDaSelecao(try vaga(estado: .publicada, posicoes: [.aberta], inicioEmHoras: 20), agora: agora) == .reposicaoEmUrgencia)
        #expect(SituacaoDaSelecao(try vaga(estado: .publicada, posicoes: [.aberta], inicioEmHoras: 24), agora: agora) == .reposicaoEmUrgencia)
        #expect(SituacaoDaSelecao(try vaga(estado: .publicada, posicoes: [.aberta], inicioEmHoras: 24.02), agora: agora) == .aberta)
        // Sem posição aberta não há reposição: a vaga cheia dentro das 24 h é seleção concluída.
        #expect(SituacaoDaSelecao(try vaga(estado: .preenchida, posicoes: [.confirmada], inicioEmHoras: 20), agora: agora) == .concluida)
        // A posição aberta de uma vaga de urgência é só urgência.
        #expect(SituacaoDaSelecao(try vaga(estado: .publicada, posicoes: [.aberta], modo: .urgencia, inicioEmHoras: 20), agora: agora) == .aberta)
        #expect(!SituacaoDaSelecao.reposicaoEmUrgencia.listaCandidatos)
        #expect(RotuloDaSelecao.detalhe(try vaga(estado: .publicada, posicoes: [.aberta], inicioEmHoras: 20), agora: agora) == "reposição em urgência")
    }

    @Test("A seleção que fechou com posição aberta diz quantas ficaram sem escolha (D1)")
    func concluidaComPosicoesFechadas() throws {
        #expect(SituacaoDaSelecao.posicoesFechadasSemEscolha(try vaga(estado: .preenchida, posicoes: [.confirmada])) == 0)
        #expect(SituacaoDaSelecao.posicoesFechadasSemEscolha(try vaga(estado: .preenchida, posicoes: [.confirmada, .cancelada])) == 1)
        #expect(SituacaoDaSelecao.posicoesFechadasSemEscolha(try vaga(estado: .preenchida, posicoes: [.confirmada, .cancelada, .cancelada])) == 2)
        #expect(TextosDosCandidatos.concluida(posicoesFechadas: 0) == TextosDosCandidatos.concluida)
        #expect(TextosDosCandidatos.concluida(posicoesFechadas: 1).hasPrefix("A seleção fechou 24 horas antes do início com 1 posição sem escolha."))
        #expect(TextosDosCandidatos.concluida(posicoesFechadas: 2).hasPrefix("A seleção fechou 24 horas antes do início com 2 posições sem escolha."))
    }

    @Test("Posição reposta: a mais de 24 h a tela da casa volta a esperar escolha; a 24 h ou menos diz reposição em urgência, e a do profissional diz urgência")
    func reposicaoNasTelasDosDoisLados() async throws {
        let cena = try await Cena.publicada(posicoes: 1, candidatos: [Cena.perfil(1, "Ana Cunha")])
        await cena.viewModel.carregar()
        try await cena.escolher("Ana Cunha")
        let posicao = try #require(try await cena.vagaNoPainel().posicoes.first { $0.estado == .confirmada }).id

        // A 30 h do início: a posição reaberta volta a ser seleção.
        cena.relogio.avancar(para: cena.inicio.addingTimeInterval(-30 * Cena.hora))
        let reabertura = try await cena.base.cancelarPosicao(id: posicao, motivo: "Imprevisto de agenda.")
        #expect(reabertura.reaberta && reabertura.novaPosicaoID != nil)
        var vaga = try await cena.vagaNoPainel()
        #expect(SituacaoDaSelecao(vaga, agora: cena.relogio.agora) == .aberta)
        #expect(try await cena.base.detalheDaVaga(id: cena.vagaID).modoEfetivo(em: cena.relogio.agora) == .selecao)
        #expect(try await cena.base.candidatar(vagaID: cena.vagaID).estado == .pendente)

        // A 20 h do início, a candidatura pendente já expirou e a vaga fechou (RN24); outra escolha
        // cancela de novo, e agora a posição é reposta em urgência.
        cena.relogio.avancar(para: cena.inicio.addingTimeInterval(-25 * Cena.hora))
        await cena.viewModel.carregar()
        let pendente = try #require(cena.viewModel.candidatos.first)
        cena.viewModel.pedirEscolha(pendente)
        await cena.viewModel.confirmarEscolha()?.value
        #expect(cena.viewModel.resultado == .confirmado(nome: pendente.profissional.nome, vagaPreenchida: true))
        cena.relogio.avancar(para: cena.inicio.addingTimeInterval(-20 * Cena.hora))
        let segunda = try #require(try await cena.vagaNoPainel().posicoes.first { $0.estado == .confirmada }).id
        let urgencia = try await cena.base.cancelarPosicao(id: segunda, motivo: "Imprevisto de agenda.")
        #expect(urgencia.reaberta && urgencia.novaPosicaoID != nil)
        vaga = try await cena.vagaNoPainel()
        #expect(vaga.estado == .publicada && vaga.posicoesAbertas == 1)
        #expect(SituacaoDaSelecao(vaga, agora: cena.relogio.agora) == .reposicaoEmUrgencia)
        #expect(RotuloDaSelecao.detalhe(vaga, agora: cena.relogio.agora) == "reposição em urgência")
        #expect(try await cena.base.detalheDaVaga(id: cena.vagaID).modoEfetivo(em: cena.relogio.agora) == .urgencia)
        // O agendador não a fecha, e o primeiro que aceita é confirmado na hora, na posição reposta.
        #expect(await cena.base.fecharSelecoes() == 0)
        let confirmada = try await cena.base.candidatar(vagaID: cena.vagaID)
        #expect(confirmada.estado == .confirmada && confirmada.turnoID != nil && confirmada.posicaoID == urgencia.novaPosicaoID)
    }

    @Test("Vaga sem candidato carrega vazia, e não como falha")
    func vazio() async throws {
        let cena = try await Cena.publicada(candidatos: [])
        await cena.viewModel.carregar()
        #expect(cena.viewModel.estado == .carregados([]))
    }

    @Test("Sem rede a lista diz que está sem conexão; outra falha é erro; tentar de novo recupera")
    func falhasDaLeitura() async throws {
        let cena = try await Cena.doCenario()

        cena.api.falhaNosCandidatos = ErroDaApi(codigo: .semRede)
        await cena.viewModel.carregar()
        #expect(cena.viewModel.estado == .semConexao)

        cena.api.falhaNosCandidatos = ErroDaApi(codigo: .desconhecido)
        await cena.viewModel.carregar()
        #expect(cena.viewModel.estado == .falha)

        cena.api.falhaNosCandidatos = nil
        await cena.viewModel.carregar()
        #expect(cena.viewModel.candidatos.count == 4)
    }

    @Test("Com candidatos na tela, a releitura que falha não os apaga: avisa que podem estar desatualizados")
    func releituraQueFalha() async throws {
        let cena = try await Cena.doCenario()
        await cena.viewModel.carregar()

        cena.api.falhaNosCandidatos = ErroDaApi(codigo: .semRede)
        await cena.viewModel.carregar()

        #expect(cena.viewModel.candidatos.count == 4)
        #expect(cena.viewModel.desatualizada)

        cena.api.falhaNosCandidatos = nil
        await cena.viewModel.carregar()
        #expect(!cena.viewModel.desatualizada)
    }

    // MARK: Critério 1 — escolher confirma só ele e libera os outros

    @Test("Com 4 candidatos e uma posição, escolher um confirma só ele; a lista esvazia e o painel mostra quem ficou")
    func escolher() async throws {
        let cena = try await Cena.doCenario()
        await cena.viewModel.carregar()

        try await cena.escolher("Bruno Tavares")

        #expect(cena.viewModel.resultado == .confirmado(nome: "Bruno Tavares", vagaPreenchida: true))
        #expect(cena.viewModel.falha == nil)
        #expect(cena.viewModel.candidatos.isEmpty)
        #expect(cena.viewModel.escolhendo == nil && cena.viewModel.escolhaEmConfirmacao == nil)
        let vaga = try await cena.vagaNoPainel()
        #expect(vaga.estado == .preenchida && vaga.candidatosPendentes == 0)
        #expect(vaga.posicoes.map(\.profissional?.nome) == ["Bruno Tavares"])
        #expect(await cena.base.chamadasAEscolherCandidato == 1)
        #expect(TextosDosCandidatos.resultado(try #require(cena.viewModel.resultado)).contains("Os outros candidatos foram avisados"))
    }

    @Test("Com duas posições, a primeira escolha deixa os outros na lista, e a vaga segue publicada")
    func escolherComPosicaoSobrando() async throws {
        let cena = try await Cena.publicada(posicoes: 2, candidatos: [Cena.perfil(1, "Ana Cunha"), Cena.perfil(2, "Bruno Tavares"), Cena.perfil(3, "Carla Menezes")])
        await cena.viewModel.carregar()

        try await cena.escolher("Ana Cunha")

        #expect(cena.viewModel.resultado == .confirmado(nome: "Ana Cunha", vagaPreenchida: false))
        #expect(cena.viewModel.candidatos.map(\.profissional.nome) == ["Bruno Tavares", "Carla Menezes"])
        #expect(try await cena.vagaNoPainel().estado == .publicada)
    }

    @Test("Escolher pede confirmação: sem o toque no alerta, nada é enviado; desistir limpa o pedido")
    func pedeConfirmacao() async throws {
        let cena = try await Cena.doCenario()
        await cena.viewModel.carregar()

        #expect(cena.viewModel.confirmarEscolha() == nil)
        cena.viewModel.pedirEscolha(try cena.candidato("Ana Cunha"))
        #expect(cena.viewModel.escolhaEmConfirmacao?.profissional.nome == "Ana Cunha")
        cena.viewModel.desistirDaEscolha()
        #expect(cena.viewModel.escolhaEmConfirmacao == nil)
        #expect(cena.viewModel.confirmarEscolha() == nil)

        #expect(cena.api.escolhasEnviadas == 0)
        #expect(cena.viewModel.candidatos.count == 4)
    }

    @Test("Com uma escolha em voo, outro toque não pede nem envia uma segunda")
    func umaEscolhaPorVez() async throws {
        let cena = try await Cena.publicada(posicoes: 2, candidatos: [Cena.perfil(1, "Ana Cunha"), Cena.perfil(2, "Bruno Tavares")])
        await cena.viewModel.carregar()
        let bruno = try cena.candidato("Bruno Tavares")

        cena.viewModel.pedirEscolha(try cena.candidato("Ana Cunha"))
        let emVoo = try #require(cena.viewModel.confirmarEscolha())
        #expect(cena.viewModel.escolhendo != nil)
        cena.viewModel.pedirEscolha(bruno)
        #expect(cena.viewModel.escolhaEmConfirmacao == nil)
        #expect(cena.viewModel.confirmarEscolha() == nil)
        await emVoo.value

        #expect(cena.api.escolhasEnviadas == 1)
        #expect(cena.viewModel.candidatos.map(\.profissional.nome) == ["Bruno Tavares"])
    }

    // MARK: Critério 4 — a escolha que perde a corrida

    @Test("Escolha que perde a corrida pela última posição explica, recarrega e mostra quem a outra pessoa confirmou")
    func perdeACorrida() async throws {
        let cena = try await Cena.doCenario(.escolhaPerdeCorrida)
        await cena.viewModel.carregar()

        try await cena.escolher("Ana Cunha")

        #expect(cena.viewModel.falha == .posicaoJaPreenchida)
        #expect(cena.viewModel.resultado == nil)
        // A lista foi relida: ninguém mais espera, e a posição ficou com o candidato da outra escolha.
        #expect(cena.viewModel.candidatos.isEmpty && !cena.viewModel.desatualizada)
        let vaga = try await cena.vagaNoPainel()
        #expect(vaga.estado == .preenchida)
        #expect(vaga.posicoes.map(\.profissional?.nome) == ["Bruno Tavares"])
        #expect(TextosDosCandidatos.falha(.posicaoJaPreenchida, desatualizada: false) == "Outra pessoa da sua equipe preencheu a última posição antes. Atualizamos a lista.")
    }

    @Test("Se a releitura depois da corrida perdida falha, a tela não diz que atualizou")
    func perdeACorridaSemConseguirReler() async throws {
        let cena = try await Cena.doCenario(.escolhaPerdeCorrida)
        await cena.viewModel.carregar()
        cena.api.falhaNosCandidatos = ErroDaApi(codigo: .semRede)

        try await cena.escolher("Ana Cunha")

        #expect(cena.viewModel.falha == .posicaoJaPreenchida)
        #expect(cena.viewModel.desatualizada)
        #expect(TextosDosCandidatos.falha(.posicaoJaPreenchida, desatualizada: true) == "Outra pessoa da sua equipe preencheu a última posição antes.")
    }

    // MARK: Sem rede e resposta perdida: a escolha não é idempotente

    @Test("Sem rede, a escolha não sai do aparelho nem fica em fila: é mensagem, e tentar de novo funciona")
    func semRede() async throws {
        let cena = try await Cena.doCenario()
        await cena.viewModel.carregar()
        cena.api.escolha = .semRede

        try await cena.escolher("Diego Rocha")

        #expect(cena.viewModel.falha == .semConexao)
        #expect(cena.viewModel.resultado == nil)
        #expect(cena.viewModel.candidatos.count == 4)
        #expect(await cena.base.chamadasAEscolherCandidato == 0)

        // A rede voltou e nada foi reenviado sozinho: só o novo toque da pessoa escolhe.
        cena.api.escolha = .normal
        #expect(await cena.base.chamadasAEscolherCandidato == 0)
        try await cena.escolher("Diego Rocha")
        #expect(cena.viewModel.resultado == .confirmado(nome: "Diego Rocha", vagaPreenchida: true))
        #expect(cena.viewModel.falha == nil)
        #expect(cena.api.escolhasEnviadas == 2)
    }

    @Test("Resposta perdida depois de o servidor escolher: a tela relê o painel e mostra a confirmação, sem pedir outra escolha")
    func respostaPerdida() async throws {
        let cena = try await Cena.doCenario()
        await cena.viewModel.carregar()
        cena.api.escolha = .respostaPerdida

        try await cena.escolher("Carla Menezes")

        #expect(cena.viewModel.resultado == .confirmado(nome: "Carla Menezes", vagaPreenchida: true))
        #expect(cena.viewModel.falha == nil)
        #expect(cena.viewModel.candidatos.isEmpty)
        #expect(cena.api.escolhasEnviadas == 1)
    }

    @Test("Segunda tentativa de uma escolha que já valeu recebe candidatura_indisponivel, e o painel mostra que ela está confirmada")
    func segundaTentativaDaEscolhaQueJaValeu() async throws {
        let cena = try await Cena.publicada(posicoes: 2, candidatos: [Cena.perfil(1, "Ana Cunha"), Cena.perfil(2, "Bruno Tavares")])
        await cena.viewModel.carregar()
        // A resposta se perde, e as releituras também: a tela não tem como saber que a escolha valeu.
        cena.api.escolha = .respostaPerdida
        cena.api.falhaNosCandidatos = ErroDaApi(codigo: .semRede)
        cena.api.falhaNoPainel = ErroDaApi(codigo: .semRede)

        try await cena.escolher("Ana Cunha")

        #expect(cena.viewModel.resultado == nil)
        #expect(cena.viewModel.falha == .api(ErroDaApi(codigo: .desconhecido, codigoOriginal: "NSURLErrorNetworkConnectionLost")))
        #expect(cena.viewModel.desatualizada)
        #expect(cena.viewModel.candidatos.count == 2)

        // A rede volta, e a pessoa toca de novo no mesmo candidato, que continua na lista velha.
        cena.api.escolha = .normal
        cena.api.falhaNosCandidatos = nil
        cena.api.falhaNoPainel = nil
        try await cena.escolher("Ana Cunha")

        // O servidor responde 409, porque já tinha escolhido; o painel prova que a escolha valeu.
        #expect(cena.viewModel.resultado == .confirmado(nome: "Ana Cunha", vagaPreenchida: false))
        #expect(cena.viewModel.falha == nil)
        #expect(cena.viewModel.candidatos.map(\.profissional.nome) == ["Bruno Tavares"])
        #expect(try await cena.vagaNoPainel().posicoes.filter { $0.estado == .confirmada }.count == 1)
    }

    @Test("Outra pessoa da casa escolhe o mesmo candidato um instante antes: o 409 é candidatura_indisponivel, e a tela relê e mostra que ele está confirmado")
    func mesmoCandidatoEscolhidoPorOutraPessoa() async throws {
        let cena = try await Cena.doCenario()
        await cena.viewModel.carregar()
        // A conferência da candidatura já aceita vem antes da vaga cheia: quem perde a corrida pelo
        // mesmo candidato não ouve `posicao_ja_preenchida`.
        _ = try await cena.base.escolherCandidato(candidaturaID: try cena.candidato("Carla Menezes").candidaturaID)

        try await cena.escolher("Carla Menezes")

        #expect(cena.viewModel.resultado == .confirmado(nome: "Carla Menezes", vagaPreenchida: true))
        #expect(cena.viewModel.falha == nil)
        #expect(cena.viewModel.candidatos.isEmpty)
        #expect(cena.api.escolhasEnviadas == 1)
    }

    @Test("Nenhuma recusa da seleção usa o texto padrão do erro, que fala com quem procura vaga", arguments: [
        FalhaDaEscolha.posicaoJaPreenchida, .candidaturaIndisponivel(nome: "Ana Cunha"), .selecaoEncerrada,
        .turnoSobreposto(nome: "Ana Cunha"), .inelegivel(nome: "Ana Cunha"), .vagaOculta, .semConexao,
    ])
    func textosPropriosDaSelecao(falha: FalhaDaEscolha) {
        let padrao = Set([CodigoErroAPI.posicaoJaPreenchida, .candidaturaIndisponivel, .vagaEncerrada, .inelegivel, .vagaOculta, .semRede, .desconhecido]
            .map { MensagemDoErroAPI.texto(ErroDaApi(codigo: $0)) })
        for desatualizada in [false, true] {
            #expect(!padrao.contains(TextosDosCandidatos.falha(falha, desatualizada: desatualizada)))
        }
    }

    // MARK: Recusas do servidor

    @Test("Candidato que retirou a candidatura antes da escolha: a tela explica e a lista é relida sem ele")
    func candidaturaRetirada() async throws {
        let cena = try await Cena.publicada(candidatos: [Cena.perfil(2, "Bruno Tavares")])
        // A conta do dublê se candidata e aparece para a casa com o perfil de exemplo, Ana Cunha.
        let minha = try await cena.base.candidatar(vagaID: cena.vagaID).candidaturaID
        await cena.viewModel.carregar()
        #expect(cena.viewModel.candidatos.count == 2)
        _ = try await cena.base.retirarCandidatura(id: minha)

        try await cena.escolher("Ana Cunha")

        #expect(cena.viewModel.falha == .candidaturaIndisponivel(nome: "Ana Cunha"))
        #expect(cena.viewModel.resultado == nil)
        #expect(cena.viewModel.candidatos.map(\.profissional.nome) == ["Bruno Tavares"])
        #expect(try await cena.vagaNoPainel().estado == .publicada)
    }

    @Test("A 24 horas do início a seleção já fechou: a escolha é recusada como seleção encerrada")
    func selecaoFechada() async throws {
        let cena = try await Cena.doCenario()
        await cena.viewModel.carregar()
        cena.relogio.avancar(para: cena.inicio.addingTimeInterval(-24 * Cena.hora))

        try await cena.escolher("Ana Cunha")

        #expect(cena.viewModel.falha == .selecaoEncerrada)
        #expect(cena.viewModel.resultado == nil)
        #expect(try await cena.vagaNoPainel().posicoes.allSatisfy { $0.estado != .confirmada })
    }

    @Test("Candidato inelegível: turno no mesmo horário ou conta suspensa; a lista fica como está para escolher outro", arguments: [
        (ApiClienteEmMemoria.Cenario.inelegivel, FalhaDaEscolha.turnoSobreposto(nome: "Ana Cunha")),
        (ApiClienteEmMemoria.Cenario.inelegivelSuspenso, FalhaDaEscolha.inelegivel(nome: "Ana Cunha")),
    ])
    func inelegivel(cenario: ApiClienteEmMemoria.Cenario, falha: FalhaDaEscolha) async throws {
        let cena = try await Cena.publicada(candidatos: [Cena.perfil(1, "Ana Cunha"), Cena.perfil(2, "Bruno Tavares")], cenario: cenario)
        await cena.viewModel.carregar()

        try await cena.escolher("Ana Cunha")

        #expect(cena.viewModel.falha == falha)
        #expect(cena.viewModel.candidatos.count == 2)
        #expect(TextosDosCandidatos.falha(falha, desatualizada: false).contains("Escolha outro candidato."))
    }

    @Test("Vaga ocultada pela moderação: a escolha é recusada, e os candidatos continuam na lista")
    func vagaOculta() async throws {
        let cena = try await Cena.doCenario()
        await cena.viewModel.carregar()
        await cena.base.moderar(vagaID: cena.vagaID, oculta: true)

        try await cena.escolher("Ana Cunha")

        #expect(cena.viewModel.falha == .vagaOculta)
        #expect(cena.viewModel.candidatos.count == 4)
        #expect(try await cena.vagaNoPainel().oculta)
    }

    // MARK: O que o painel diz da seleção

    private func vaga(
        estado: EstadoVaga, oculta: Bool = false, pendentes: Int = 0, posicoes: [EstadoPosicao], modo: ModoPreenchimento = .selecao,
        inicioEmHoras: Double = 72
    ) throws -> VagaNoPainel {
        let inicio = Cena.agora.addingTimeInterval(inicioEmHoras * Cena.hora)
        let resumo = VagaResumo(
            id: UUID(), funcao: "Garçom", local: "CLS 405", regiaoAdministrativa: "Plano Piloto",
            periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(4 * Cena.hora)), valor: Dinheiro(centavos: 12000)
        )
        return VagaNoPainel(
            vaga: resumo, modo: modo, estado: estado, oculta: oculta, alertaVagaVazia: false, candidatosPendentes: pendentes,
            posicoes: posicoes.map { estado in
                PosicaoNoPainel(
                    id: UUID(), estado: estado, profissional: estado == .aberta || estado == .cancelada ? nil : Cena.perfil(1, "Ana Cunha"),
                    turnoID: nil, verificacao: nil, emAtraso: false
                )
            }
        )
    }

    @Test("A situação da seleção sai do painel: aberta, oculta, concluída, fechada sem escolha ou encerrada")
    func situacao() throws {
        #expect(SituacaoDaSelecao(try vaga(estado: .publicada, posicoes: [.aberta])) == .aberta)
        #expect(SituacaoDaSelecao(try vaga(estado: .publicada, oculta: true, posicoes: [.aberta])) == .oculta)
        #expect(SituacaoDaSelecao(try vaga(estado: .preenchida, posicoes: [.confirmada])) == .concluida)
        // Critério 2: fechou 24 h antes sem ninguém escolhido.
        #expect(SituacaoDaSelecao(try vaga(estado: .encerrada, posicoes: [.cancelada])) == .fechadaSemEscolha)
        #expect(SituacaoDaSelecao(try vaga(estado: .encerrada, posicoes: [.cumprida, .cancelada])) == .encerrada)
        #expect(SituacaoDaSelecao(try vaga(estado: .cancelada, posicoes: [.cancelada])) == .encerrada)

        #expect(SituacaoDaSelecao.aberta.listaCandidatos && SituacaoDaSelecao.oculta.listaCandidatos)
        #expect(!SituacaoDaSelecao.concluida.listaCandidatos && !SituacaoDaSelecao.fechadaSemEscolha.listaCandidatos)
    }

    @Test("Vaga ocultada durante a escolha: com o painel relido, o aviso da vaga oculta aparece uma vez só")
    func vagaOcultaSemAvisoRepetido() {
        // O painel relido já diz que a vaga está oculta, com o mesmo texto da recusa.
        #expect(!SecaoDeCandidatos.mostraFalha(.vagaOculta, situacao: .oculta))
        #expect(TextosDosCandidatos.falha(.vagaOculta, desatualizada: false) == TextosDosCandidatos.vagaOculta)
        // Se a releitura falhou, a situação continua aberta, e a recusa é o único aviso.
        #expect(SecaoDeCandidatos.mostraFalha(.vagaOculta, situacao: .aberta))
        // As outras recusas aparecem em qualquer situação.
        #expect(SecaoDeCandidatos.mostraFalha(.posicaoJaPreenchida, situacao: .oculta))
        #expect(SecaoDeCandidatos.mostraFalha(.semConexao, situacao: .oculta))
    }

    @Test("Posição cancelada sem profissional: fechada sem escolha quando a seleção fechou sozinha, cancelada quando a casa cancelou a vaga")
    func posicaoCanceladaEmSelecao() async throws {
        #expect(TextosDosCandidatos.posicaoCancelada(vaga: .encerrada) == "Posição fechada sem escolha")
        #expect(TextosDosCandidatos.posicaoCancelada(vaga: .preenchida) == "Posição fechada sem escolha")
        #expect(TextosDosCandidatos.posicaoCancelada(vaga: .cancelada) == "Esta posição foi cancelada.")

        // A casa cancela a vaga de seleção: a posição aberta continua no painel, como cancelada.
        let cena = try await Cena.doCenario()
        _ = try await cena.base.cancelarVaga(id: cena.vagaID, motivo: "O evento foi desmarcado.")
        let vaga = try await cena.vagaNoPainel()
        #expect(vaga.estado == .cancelada)
        #expect(vaga.posicoes.map(\.estado) == [.cancelada])
        #expect(vaga.posicoes.allSatisfy { $0.profissional == nil })
        #expect(SituacaoDaSelecao(vaga) == .encerrada)
    }

    @Test("O cartão de Minhas vagas diz quantos candidatos esperam a escolha, e como a seleção terminou")
    func rotuloDoCartao() throws {
        #expect(RotuloDaSelecao.detalhe(try vaga(estado: .publicada, pendentes: 0, posicoes: [.aberta])) == "nenhum candidato ainda")
        #expect(RotuloDaSelecao.detalhe(try vaga(estado: .publicada, pendentes: 1, posicoes: [.aberta])) == "1 candidato aguardando sua escolha")
        #expect(RotuloDaSelecao.detalhe(try vaga(estado: .publicada, pendentes: 4, posicoes: [.aberta])) == "4 candidatos aguardando sua escolha")
        #expect(RotuloDaSelecao.detalhe(try vaga(estado: .preenchida, posicoes: [.confirmada])) == "seleção concluída")
        #expect(RotuloDaSelecao.detalhe(try vaga(estado: .encerrada, posicoes: [.cancelada])) == "fechou sem escolha")
    }

    @Test("Todo texto da tela de candidatos e do modo em Publicar vaga está no catálogo pt-BR")
    func textosNoCatalogo() throws {
        let raiz = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        struct Catalogo: Decodable {
            struct Entrada: Decodable {}
            let strings: [String: Entrada]
        }
        let catalogo = try JSONDecoder().decode(Catalogo.self, from: Data(contentsOf: raiz.appending(path: "Resources/Localizable.xcstrings")))
        // Lê os literais do código, e não uma lista copiada: texto novo sem entrada no catálogo falha aqui.
        let literal = /String\(localized: "([^"]+)"/
        var faltando: [String] = []
        for (arquivo, filtro) in [("CandidatosDaVaga.swift", "static let"), ("PublicarVaga.swift", "static let modo")] {
            let fonte = try String(contentsOf: raiz.appending(path: "Sources/Apresentacao/Fluxos/Contratante/\(arquivo)"), encoding: .utf8)
            let linhas = fonte.split(separator: "\n").filter { $0.contains(filtro) }
            let textos = linhas.flatMap { $0.matches(of: literal).map { String($0.output.1) } }
            #expect(!textos.isEmpty, "nenhum texto encontrado em \(arquivo)")
            faltando += textos.filter { catalogo.strings[$0] == nil }
        }
        #expect(faltando.isEmpty, "textos fora do catálogo: \(faltando)")
        #expect(catalogo.strings[TextosRepublicarVaga.selecaoSemAntecedencia] != nil)
    }

    @Test("Cenário selecao-encerrada-sem-escolha: o painel mostra a seleção fechada sem escolha, sem candidato para escolher")
    func cenarioFechadoSemEscolha() async throws {
        let relogio = RelogioDeTeste(Cena.agora)
        let base = ApiClienteEmMemoria(cenario: .selecaoEncerradaSemEscolha, relogio: relogio)
        let casa = try #require(try await base.meusEstabelecimentos().first)
        let periodo = try Periodo(inicio: Cena.agora.addingTimeInterval(-Cena.hora), fim: Cena.agora.addingTimeInterval(400 * Cena.hora))
        let vaga = try #require(try await base.painelEstabelecimento(id: casa.id, periodo: periodo).vagas.first)

        #expect(SituacaoDaSelecao(vaga) == .fechadaSemEscolha)
        #expect(RotuloDaSelecao.detalhe(vaga) == "fechou sem escolha")
        #expect(try await base.candidatosDaVaga(id: vaga.vaga.id).isEmpty)
    }
}
