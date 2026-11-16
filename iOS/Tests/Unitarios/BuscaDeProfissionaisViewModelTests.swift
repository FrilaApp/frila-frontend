import Foundation
import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

/// Dublê pequeno da busca: serve as páginas por cursor, conta o que recebeu e falha sob comando.
private actor FonteDaBuscaFalsa: FonteDaBuscaDeProfissionais {
    var buscaLigada = true
    var total: Int
    var erroNaBusca: ErroDaApi?
    var erroNaPaginaSeguinte: ErroDaApi?
    var erroNaChamada: [UUID: ErroDaApi] = [:]
    var recorrenciaPendente: Set<UUID> = []
    /// O servidor cria a chamada e a resposta se perde (volta ilegível).
    var perdeResposta: Set<UUID> = []
    /// O servidor cria a chamada e demora além do prazo de 15 s do app para responder.
    var atrasaAlemDoPrazo: Set<UUID> = []
    /// Idempotência pela chave, antes de tudo (como o backend): a mesma chave devolve a chamada já criada.
    private var chamadasPorChave: [UUID: Chamada] = [:]
    private(set) var filtrosRecebidos: [FiltroBuscaProfissionais] = []
    private(set) var cursoresRecebidos: [String?] = []
    private(set) var limitesRecebidos: [Int?] = []
    private(set) var pedidos: [PedidoChamada] = []
    private(set) var consultasDaConfiguracao = 0

    init(total: Int) { self.total = total }

    func ajustar(buscaLigada: Bool? = nil, erroNaBusca: ErroDaApi? = nil, erroNaPaginaSeguinte: ErroDaApi? = nil,
                 erroNaChamada: [UUID: ErroDaApi]? = nil, recorrenciaPendente: Set<UUID>? = nil,
                 perdeResposta: Set<UUID>? = nil, atrasaAlemDoPrazo: Set<UUID>? = nil) {
        if let buscaLigada { self.buscaLigada = buscaLigada }
        self.erroNaBusca = erroNaBusca
        self.erroNaPaginaSeguinte = erroNaPaginaSeguinte
        if let erroNaChamada { self.erroNaChamada = erroNaChamada }
        if let recorrenciaPendente { self.recorrenciaPendente = recorrenciaPendente }
        if let perdeResposta { self.perdeResposta = perdeResposta }
        if let atrasaAlemDoPrazo { self.atrasaAlemDoPrazo = atrasaAlemDoPrazo }
    }

    func configuracaoDoApp() async throws -> ConfiguracaoApp {
        consultasDaConfiguracao += 1
        return ConfiguracaoApp(versaoMinima: "1.0", versaoRecomendada: "1.0", mensagem: nil,
                               urlDaLoja: URL(string: "https://example.com")!,
                               recursos: RecursosDoApp(chamadaDireta: true, buscaProfissionais: buscaLigada))
    }

    func buscarProfissionais(_ filtro: FiltroBuscaProfissionais, cursor: String?, limite: Int?) async throws -> PaginaBuscaProfissionais {
        filtrosRecebidos.append(filtro)
        cursoresRecebidos.append(cursor)
        limitesRecebidos.append(limite)
        if let erroNaBusca { throw erroNaBusca }
        if cursor != nil, let erroNaPaginaSeguinte { throw erroNaPaginaSeguinte }
        let inicio = cursor.flatMap(Int.init) ?? 0
        let fim = min(inicio + (limite ?? 20), total)
        let itens = (inicio..<max(inicio, fim)).map { Self.cartao($0, horario: filtro.horario != nil) }
        // O servidor devolve cursor enquanto há mais (mesmo além de 200, para o app provar que para).
        return PaginaBuscaProfissionais(itens: itens, proximoCursor: fim < total ? String(fim) : nil)
    }

    func chamarProfissional(_ pedido: PedidoChamada) async throws -> Chamada {
        pedidos.append(pedido)
        // O erro de agora é antes de chegar ao servidor (nada é criado).
        if let erro = erroNaChamada[pedido.profissionalID] { throw erro }
        if let existente = chamadasPorChave[pedido.chave] { return existente }
        if recorrenciaPendente.contains(pedido.profissionalID), !pedido.confirmoRecorrencia {
            throw ErroDaApi(codigo: .recorrenciaNaoConfirmada)
        }
        // Pelo trabalho, o servidor cria uma vaga; pelo vaga_id, a chamada entra nela.
        let chamada = Chamada(id: UUID(), vagaID: pedido.vagaID ?? UUID(), profissionalID: pedido.profissionalID,
                              estabelecimentoID: pedido.estabelecimentoID, recado: pedido.recado,
                              expiraEm: Date(timeIntervalSince1970: 2_000_000_000), criadaEm: Date(timeIntervalSince1970: 1_900_000_000))
        chamadasPorChave[pedido.chave] = chamada
        if perdeResposta.contains(pedido.profissionalID) { throw ErroDaApi(codigo: .respostaInvalida) }
        if atrasaAlemDoPrazo.contains(pedido.profissionalID) { try await Task.sleep(for: .seconds(20)) }
        return chamada
    }

    static func id(_ n: Int) -> UUID { UUID(uuidString: String(format: "A0000000-0000-0000-0000-%012d", n))! }

    static func cartao(_ n: Int, horario: Bool) -> CartaoProfissional {
        let funcao = Funcao(id: funcaoID, nome: "Garçom", categoria: "Salão")
        // O selo vem do servidor: aqui, só os pares estão disponíveis. A ordem NÃO é reordenada pelo VM.
        return CartaoProfissional(
            id: id(n), nome: "Pessoa \(n)",
            servico: ServicoNoPerfil(funcao: funcao, servico: ServicoOferecido(funcaoID: funcaoID, unidade: .diaria, valorCentavos: 15_000)),
            distanciaFaixa: .ate5km,
            reputacao: Reputacao(positivas: (n * 3) % 5, total: 5, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0),
            disponivelNoHorario: horario ? n % 2 == 0 : nil)
    }

    static let funcaoID = UUID(uuidString: "F0000000-0000-0000-0000-000000000001")!
}

@Suite("Busca de profissionais: view model")
@MainActor
struct BuscaDeProfissionaisViewModelTests {
    private let casaID = UUID(uuidString: "C0000000-0000-0000-0000-000000000001")!
    private let funcaoID = FonteDaBuscaFalsa.funcaoID
    private let inicio = Date(timeIntervalSince1970: 1_900_000_000)

    private func preparar(total: Int) -> (FonteDaBuscaFalsa, BuscaDeProfissionaisViewModel) {
        let fonte = FonteDaBuscaFalsa(total: total)
        let vm = BuscaDeProfissionaisViewModel(fonte: fonte, estabelecimentoID: casaID)
        vm.funcaoID = funcaoID
        return (fonte, vm)
    }

    private func trabalho(valor: Int = 20_000) throws -> PublicacaoVaga {
        PublicacaoVaga(
            estabelecimentoID: casaID, funcaoID: funcaoID,
            periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(4 * 3600)),
            local: "Rua Teste", regiaoAdministrativa: "Asa Sul", ponto: try Coordenada(latitude: -15.8, longitude: -47.9),
            valor: Dinheiro(centavos: valor), posicoes: 1, inclusos: Inclusos(refeicao: false, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Casa", chave: UUID())
    }

    private func enviada(_ resultado: ResultadoDaChamadaDaBusca?) -> Chamada? {
        if case let .enviada(chamada) = resultado { return chamada }
        return nil
    }

    // MARK: Filtros e estados

    @Test("Sem serviço escolhido a busca não sai")
    func servicoObrigatorio() async {
        let (fonte, vm) = preparar(total: 5)
        vm.funcaoID = nil
        #expect(!vm.podeBuscar)
        await vm.buscar()
        #expect(vm.estado == .ocioso)
        #expect(await fonte.filtrosRecebidos.isEmpty)
    }

    @Test("Os filtros de serviço, região e horário vão ao servidor; sem região nem horário vão nulos")
    func filtrosNaBusca() async throws {
        let (fonte, vm) = preparar(total: 3)
        await vm.buscar()
        vm.regiaoID = 7
        vm.horario = try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(4 * 3600))
        await vm.buscar()
        let filtros = await fonte.filtrosRecebidos
        try #require(filtros.count >= 2)
        #expect(filtros[0] == FiltroBuscaProfissionais(estabelecimentoID: casaID, funcaoID: funcaoID))
        #expect(filtros[1].regiaoID == 7)
        #expect(filtros[1].horario == vm.horario)
        #expect(await fonte.limitesRecebidos == [20, 20])
        #expect(vm.estado == .resultados)
    }

    @Test("O selo disponível no horário vem do servidor e a ordem do servidor é mantida")
    func seloEOrdem() async throws {
        let (_, vm) = preparar(total: 6)
        vm.horario = try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(4 * 3600))
        await vm.buscar()
        #expect(vm.resultados.map(\.id) == (0..<6).map(FonteDaBuscaFalsa.id))
        #expect(vm.resultados.map(\.disponivelNoHorario) == [true, false, true, false, true, false])
        // Reputação não ordena (D2): o 5º tem reputação menor que o 4º e continua depois.
        try #require(vm.resultados.count >= 5)
        #expect(vm.resultados[4].reputacao.positivas < vm.resultados[3].reputacao.positivas)
    }

    @Test("Sem horário no filtro o selo não existe")
    func semHorarioSemSelo() async {
        let (_, vm) = preparar(total: 2)
        await vm.buscar()
        #expect(vm.resultados.allSatisfy { $0.disponivelNoHorario == nil })
    }

    @Test("Busca vazia vira estado vazio e oferece Publicar para todos com os filtros")
    func vazioPublicaParaTodos() async throws {
        let (_, vm) = preparar(total: 0)
        vm.regiaoID = 3
        vm.horario = try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(5 * 3600))
        #expect(vm.rascunhoParaPublicarParaTodos == nil)
        await vm.buscar()
        #expect(vm.estado == .vazio)
        let rascunho = try #require(vm.rascunhoParaPublicarParaTodos)
        #expect(rascunho == RascunhoDeVagaDaBusca(estabelecimentoID: casaID, funcaoID: funcaoID, regiaoID: 3, horario: vm.horario))
    }

    @Test("Com resultados não há Publicar para todos")
    func comResultadosSemRascunho() async {
        let (_, vm) = preparar(total: 2)
        await vm.buscar()
        #expect(vm.rascunhoParaPublicarParaTodos == nil)
    }

    @Test("Chave buscaProfissionais desligada: recurso indisponível e nenhuma busca no servidor")
    func chaveDesligada() async {
        let (fonte, vm) = preparar(total: 5)
        await fonte.ajustar(buscaLigada: false)
        await vm.buscar()
        #expect(vm.estado == .indisponivel)
        #expect(await fonte.filtrosRecebidos.isEmpty)
        await fonte.ajustar(buscaLigada: true)
        await vm.buscar()
        #expect(vm.estado == .resultados)
    }

    @Test("recurso_desligado do servidor também vira indisponível")
    func recursoDesligadoDoServidor() async {
        let (fonte, vm) = preparar(total: 5)
        await fonte.ajustar(erroNaBusca: ErroDaApi(codigo: .semPermissao, detalhes: "recurso_desligado"))
        await vm.buscar()
        #expect(vm.estado == .indisponivel)
    }

    @Test("429 vira a mensagem de limite e some o resultado antigo")
    func limiteDeBuscas() async {
        let (fonte, vm) = preparar(total: 5)
        await vm.buscar()
        #expect(vm.resultados.count == 5)
        await fonte.ajustar(erroNaBusca: ErroDaApi(codigo: .limiteExcedido))
        await vm.buscar()
        #expect(vm.estado == .erro(TextosBuscaDeProfissionais.limiteDeBuscas))
        #expect(vm.resultados.isEmpty)
    }

    @Test("Outro erro vira a mensagem genérica")
    func erroGenerico() async {
        let (fonte, vm) = preparar(total: 5)
        await fonte.ajustar(erroNaBusca: ErroDaApi(codigo: .semRede))
        await vm.buscar()
        #expect(vm.estado == .erro(TextosBuscaDeProfissionais.erro))
    }

    // MARK: Paginação

    @Test("Páginas de 20 até o fim, sem repetir ninguém")
    func paginacao() async {
        let (fonte, vm) = preparar(total: 45)
        await vm.buscar()
        #expect(vm.resultados.count == 20)
        #expect(vm.temMais)
        await vm.carregarMais()
        await vm.carregarMais()
        #expect(vm.resultados.count == 45)
        #expect(!vm.temMais)
        #expect(Set(vm.resultados.map(\.id)).count == 45)
        await vm.carregarMais() // no fim, não pede nada
        #expect(await fonte.cursoresRecebidos == [nil, "20", "40"])
        #expect(await fonte.limitesRecebidos == [20, 20, 20])
    }

    @Test("A paginação mantém o filtro da busca mesmo que a tela mexa nos campos")
    func paginacaoComOMesmoFiltro() async throws {
        let (fonte, vm) = preparar(total: 45)
        await vm.buscar()
        vm.regiaoID = 99
        await vm.carregarMais()
        let filtros = await fonte.filtrosRecebidos
        try #require(filtros.count >= 2)
        #expect(filtros[1] == filtros[0])
    }

    @Test("Para em 200 resultados mesmo que o servidor tenha mais")
    func tetoDe200() async {
        let (fonte, vm) = preparar(total: 250)
        await vm.buscar()
        for _ in 0..<15 { await vm.carregarMais() }
        #expect(vm.resultados.count == 200)
        #expect(!vm.temMais)
        #expect(await fonte.cursoresRecebidos.count == 10) // a 1ª busca e 9 páginas a mais
    }

    @Test("Falha ao carregar mais mantém o que já veio e deixa tentar de novo")
    func falhaAoCarregarMais() async {
        let (fonte, vm) = preparar(total: 45)
        await vm.buscar()
        await fonte.ajustar(erroNaPaginaSeguinte: ErroDaApi(codigo: .semRede))
        await vm.carregarMais()
        #expect(vm.resultados.count == 20)
        #expect(vm.estado == .resultados)
        #expect(vm.erroAoCarregarMais == TextosBuscaDeProfissionais.erroAoCarregarMais)
        await fonte.ajustar()
        await vm.carregarMais()
        #expect(vm.resultados.count == 40)
        #expect(vm.erroAoCarregarMais == nil)
    }

    @Test("cursor_invalido refaz a busca da primeira página")
    func cursorInvalido() async {
        let (fonte, vm) = preparar(total: 45)
        await vm.buscar()
        await fonte.ajustar(erroNaPaginaSeguinte: ErroDaApi(codigo: .cursorInvalido))
        await vm.carregarMais()
        #expect(await fonte.cursoresRecebidos == [nil, "20", nil])
        #expect(vm.resultados.count == 20)
        #expect(vm.estado == .resultados)
    }

    // MARK: Seleção e chamada

    @Test("Até 3 selecionados: o 4º não entra e liga o aviso; desmarcar libera a vaga")
    func limiteDeTres() async throws {
        let (_, vm) = preparar(total: 6)
        await vm.buscar()
        let ids = vm.resultados.map(\.id)
        try #require(ids.count >= 4)
        #expect(vm.alternarSelecao(ids[0]))
        #expect(vm.alternarSelecao(ids[1]))
        #expect(vm.alternarSelecao(ids[2]))
        #expect(!vm.alternarSelecao(ids[3]))
        #expect(vm.selecionados == Array(ids[0...2]))
        #expect(vm.avisoDeLimiteDeSelecao == TextosBuscaDeProfissionais.limiteDeSelecao)
        #expect(vm.alternarSelecao(ids[1])) // desmarca
        #expect(vm.avisoDeLimiteDeSelecao == nil)
        #expect(vm.alternarSelecao(ids[3]))
        #expect(vm.selecionados == [ids[0], ids[2], ids[3]])
    }

    @Test("Quem não está na lista não entra na seleção")
    func foraDaLista() async {
        let (_, vm) = preparar(total: 2)
        await vm.buscar()
        #expect(!vm.alternarSelecao(UUID()))
        #expect(vm.selecionados.isEmpty)
    }

    @Test("Chamar 3: a 1ª leva o trabalho e as outras 2 o vaga_id dela, cada uma com a sua chave")
    func chamarTres() async throws {
        let (fonte, vm) = preparar(total: 5)
        await vm.buscar()
        vm.resultados.prefix(3).forEach { vm.alternarSelecao($0.id) }
        await vm.chamar(trabalho: try trabalho(), recado: "Pode vir cedo?")
        let pedidos = await fonte.pedidos
        try #require(pedidos.count >= 3)
        #expect(pedidos.map(\.profissionalID) == vm.selecionados)
        #expect(Set(pedidos.map(\.chave)).count == 3)
        let primeiroSelecionado = try #require(vm.selecionados.first)
        let vagaID = try #require(enviada(vm.resultadosDaChamada[primeiroSelecionado])).vagaID
        #expect(pedidos[0].trabalho != nil && pedidos[0].vagaID == nil)
        #expect(pedidos.dropFirst().allSatisfy { $0.vagaID == vagaID && $0.trabalho == nil })
        #expect(vm.selecionados.allSatisfy { enviada(vm.resultadosDaChamada[$0])?.vagaID == vagaID })
        #expect(pedidos.allSatisfy { $0.recado == "Pode vir cedo?" && !$0.confirmoRecorrencia })
        #expect(vm.selecionados.allSatisfy { if case .enviada = vm.resultadosDaChamada[$0] { true } else { false } })
        #expect(!vm.mostrarJ7)
    }

    @Test("A região do filtro vai em cada pedido; sem região, vai nulo")
    func regiaoNoPedido() async throws {
        let (fonte, vm) = preparar(total: 2)
        vm.regiaoID = 7
        await vm.buscar()
        vm.alternarSelecao(try #require(vm.resultados.first).id)
        await vm.chamar(trabalho: try trabalho())
        vm.regiaoID = nil
        await vm.buscar()
        vm.alternarSelecao(try #require(vm.resultados.first).id)
        await vm.chamar(trabalho: try trabalho(valor: 21_000)) // outro trabalho: outra vaga
        let pedidos = await fonte.pedidos
        #expect(pedidos.map(\.regiaoID) == [7, nil])
        #expect(pedidos.allSatisfy { $0.trabalho != nil })
    }

    @Test("Sem selecionado, chamar não envia nada")
    func chamarSemSelecao() async throws {
        let (fonte, vm) = preparar(total: 2)
        await vm.buscar()
        await vm.chamar(trabalho: try trabalho())
        #expect(await fonte.pedidos.isEmpty)
    }

    @Test("Uma falha não derruba as outras chamadas; reenviar só tenta quem falhou, com a mesma chave")
    func falhaParcial() async throws {
        let (fonte, vm) = preparar(total: 3)
        await vm.buscar()
        let ids = vm.resultados.map(\.id)
        try #require(ids.count >= 2)
        ids.forEach { vm.alternarSelecao($0) }
        await fonte.ajustar(erroNaChamada: [ids[1]: ErroDaApi(codigo: .chamadaJaAberta)])
        await vm.chamar(trabalho: try trabalho())
        #expect(vm.resultadosDaChamada[ids[1]] == .erro(TextosChamadaDireta.jaAberta))
        let primeiraChave = try #require(await fonte.pedidos.first { $0.profissionalID == ids[1] }).chave
        let vagaID = try #require(enviada(vm.resultadosDaChamada[ids[0]])).vagaID
        await fonte.ajustar(erroNaChamada: [:])
        await vm.chamar(trabalho: try trabalho())
        let pedidos = await fonte.pedidos
        #expect(pedidos.count == 4) // só o 2º foi reenviado
        #expect(pedidos.last?.profissionalID == ids[1])
        #expect(pedidos.last?.chave == primeiraChave)
        #expect(pedidos.last?.vagaID == vagaID) // a vaga já existe: entra nela
        if case .enviada = vm.resultadosDaChamada[ids[1]] {} else { Issue.record("o 2º deveria ter sido enviado") }
    }

    @Test("J7: não reenvia sozinho; só a confirmação explícita reenvia o mesmo pedido com confirmoRecorrencia")
    func recorrencia() async throws {
        let (fonte, vm) = preparar(total: 2)
        await vm.buscar()
        let ids = vm.resultados.map(\.id)
        try #require(ids.count >= 2)
        ids.forEach { vm.alternarSelecao($0) }
        await fonte.ajustar(recorrenciaPendente: [ids[0]])
        await vm.chamar(trabalho: try trabalho(), confirmoRecorrencia: true) // sem recusa antes: não envia
        #expect(await fonte.pedidos.isEmpty)
        await vm.chamar(trabalho: try trabalho())
        #expect(vm.mostrarJ7)
        #expect(vm.resultadosDaChamada[ids[0]] == .pedeConfirmacaoDeRecorrencia)
        #expect(await fonte.pedidos.count == 2)
        await vm.chamar(trabalho: try trabalho(), confirmoRecorrencia: true)
        let pedidos = await fonte.pedidos
        #expect(pedidos.count == 3) // só o pendente
        try #require(pedidos.count >= 3)
        #expect(pedidos[2].profissionalID == ids[0])
        // O 2º virou a 1ª chamada e criou a vaga; a confirmação do 1º entra nela, com a mesma chave.
        #expect(pedidos[1].trabalho != nil)
        #expect(pedidos[2].chave == pedidos[0].chave)
        #expect(pedidos[2].vagaID == enviada(vm.resultadosDaChamada[ids[1]])?.vagaID)
        #expect(!pedidos[0].confirmoRecorrencia && pedidos[2].confirmoRecorrencia)
        #expect(!vm.mostrarJ7)
    }

    @Test("Se o servidor recusa a 1ª, a próxima vira a 1ª e leva o trabalho; o reenvio da recusada entra na vaga, com a mesma chave")
    func primeiraFalha() async throws {
        let (fonte, vm) = preparar(total: 3)
        await vm.buscar()
        let ids = vm.resultados.map(\.id)
        try #require(ids.count >= 2)
        ids.forEach { vm.alternarSelecao($0) }
        // Recusa definitiva (o servidor não criou nada): promove o próximo. Sem rede é incerto e para (outro teste).
        await fonte.ajustar(erroNaChamada: [ids[0]: ErroDaApi(codigo: .profissionalIndisponivel)])
        await vm.chamar(trabalho: try trabalho())
        var pedidos = await fonte.pedidos
        try #require(pedidos.count >= 3)
        #expect(vm.resultadosDaChamada[ids[0]] == .erro(TextosChamadaDireta.indisponivel))
        #expect(pedidos[0].trabalho != nil && pedidos[1].trabalho != nil)
        let vagaID = try #require(enviada(vm.resultadosDaChamada[ids[1]])).vagaID
        #expect(pedidos[2].vagaID == vagaID && pedidos[2].trabalho == nil)
        await fonte.ajustar(erroNaChamada: [:])
        await vm.chamar(trabalho: try trabalho())
        pedidos = await fonte.pedidos
        #expect(pedidos.count == 4)
        try #require(pedidos.count >= 4)
        #expect(pedidos[3].profissionalID == ids[0])
        #expect(pedidos[3].chave == pedidos[0].chave)
        #expect(pedidos[3].vagaID == vagaID)
        #expect(ids.allSatisfy { enviada(vm.resultadosDaChamada[$0])?.vagaID == vagaID })
    }

    @Test("J7 de quem foi pelo vaga_id reenvia com o mesmo vaga_id e a mesma chave")
    func recorrenciaPeloVagaID() async throws {
        let (fonte, vm) = preparar(total: 2)
        await vm.buscar()
        let ids = vm.resultados.map(\.id)
        try #require(ids.count >= 2)
        ids.forEach { vm.alternarSelecao($0) }
        await fonte.ajustar(recorrenciaPendente: [ids[1]])
        await vm.chamar(trabalho: try trabalho())
        #expect(vm.resultadosDaChamada[ids[1]] == .pedeConfirmacaoDeRecorrencia)
        await vm.chamar(trabalho: try trabalho(), confirmoRecorrencia: true)
        let pedidos = await fonte.pedidos
        #expect(pedidos.count == 3)
        try #require(pedidos.count >= 3)
        let vagaID = try #require(enviada(vm.resultadosDaChamada[ids[0]])).vagaID
        #expect(pedidos[1].vagaID == vagaID && !pedidos[1].confirmoRecorrencia)
        #expect(pedidos[2] == pedidos[1].confirmando(true))
        #expect(enviada(vm.resultadosDaChamada[ids[1]])?.vagaID == vagaID)
    }

    @Test("Todos falham: nenhum leva vaga_id; no reenvio, o 1º leva o trabalho com a mesma chave e o 2º entra na vaga dele")
    func todosFalham() async throws {
        let (fonte, vm) = preparar(total: 2)
        await vm.buscar()
        let ids = vm.resultados.map(\.id)
        try #require(ids.count >= 2)
        ids.forEach { vm.alternarSelecao($0) }
        let erro = ErroDaApi(codigo: .limiteDeChamadas)
        await fonte.ajustar(erroNaChamada: [ids[0]: erro, ids[1]: erro])
        await vm.chamar(trabalho: try trabalho())
        await fonte.ajustar(erroNaChamada: [:])
        await vm.chamar(trabalho: try trabalho())
        let pedidos = await fonte.pedidos
        #expect(pedidos.count == 4)
        try #require(pedidos.count >= 4)
        #expect(pedidos.prefix(3).allSatisfy { $0.vagaID == nil })
        #expect(pedidos[2] == pedidos[0])
        #expect(pedidos[3].chave == pedidos[1].chave)
        #expect(pedidos[3].vagaID == enviada(vm.resultadosDaChamada[ids[0]])?.vagaID)
    }

    // MARK: Uma vaga por trabalho (B1) e pedido incerto que leva o trabalho (I1)

    private func vagas(_ vm: BuscaDeProfissionaisViewModel, _ ids: [UUID]) -> Set<UUID> {
        Set(ids.compactMap { enviada(vm.resultadosDaChamada[$0])?.vagaID })
    }

    @Test("Dois trabalhos seguidos na mesma busca, 3 selecionados cada: 2 vagas, uma por trabalho")
    func doisTrabalhosNaMesmaBusca() async throws {
        let (fonte, vm) = preparar(total: 6)
        await vm.buscar()
        let ids = vm.resultados.map(\.id)
        ids.prefix(3).forEach { vm.alternarSelecao($0) }
        await vm.chamar(trabalho: try trabalho())
        ids.prefix(3).forEach { vm.alternarSelecao($0) } // desmarca
        ids.suffix(3).forEach { vm.alternarSelecao($0) }
        await vm.chamar(trabalho: try trabalho(valor: 21_000))
        let pedidos = await fonte.pedidos
        #expect(pedidos.count == 6)
        try #require(pedidos.count >= 6)
        #expect(pedidos.map { $0.trabalho != nil } == [true, false, false, true, false, false])
        let primeira = try #require(vagas(vm, Array(ids.prefix(3))).first)
        let segunda = try #require(vagas(vm, Array(ids.suffix(3))).first)
        #expect(vagas(vm, ids) == [primeira, segunda])
        #expect(primeira != segunda)
        #expect(pedidos[1].vagaID == primeira && pedidos[2].vagaID == primeira)
        #expect(pedidos[4].vagaID == segunda && pedidos[5].vagaID == segunda)
    }

    @Test("Nova busca guarda a vaga: o mesmo trabalho entra pelo vaga_id da vaga que já existe; outro trabalho abre outra")
    func novaBuscaGuardaAVaga() async throws {
        let (fonte, vm) = preparar(total: 9)
        await vm.buscar()
        vm.resultados.prefix(3).forEach { vm.alternarSelecao($0.id) }
        await vm.chamar(trabalho: try trabalho())
        let primeira = try #require(vagas(vm, vm.selecionados).first)
        await vm.buscar()
        try #require(vm.resultados.count >= 6)
        vm.resultados[3...5].forEach { vm.alternarSelecao($0.id) }
        await vm.chamar(trabalho: try trabalho(valor: 21_000))
        let segunda = try #require(vagas(vm, vm.selecionados).first)
        await vm.buscar()
        vm.resultados.suffix(3).forEach { vm.alternarSelecao($0.id) }
        await vm.chamar(trabalho: try trabalho())
        let pedidos = await fonte.pedidos
        #expect(pedidos.count == 9)
        // Só dois pedidos levam o trabalho completo: um por trabalho. A 3ª busca, com o 1º trabalho, entra na vaga dele.
        #expect(pedidos.map { $0.trabalho != nil } == [true, false, false, true, false, false, false, false, false])
        #expect(primeira != segunda)
        #expect(pedidos.suffix(3).allSatisfy { $0.vagaID == primeira && $0.trabalho == nil })
        #expect(vagas(vm, vm.selecionados) == [primeira])
    }

    @Test("Nova busca com a vaga do trabalho encerrada: o servidor barra e o mesmo trabalho não abre outra sozinho; outro trabalho abre")
    func vagaDoTrabalhoEncerradaNaoAbreOutra() async throws {
        let (fonte, vm) = preparar(total: 6)
        await vm.buscar()
        vm.resultados.prefix(3).forEach { vm.alternarSelecao($0.id) }
        await vm.chamar(trabalho: try trabalho())
        let primeira = try #require(vagas(vm, vm.selecionados).first)
        await vm.buscar()
        let novos = Array(vm.resultados.suffix(3).map(\.id))
        try #require(novos.count >= 3)
        novos.forEach { vm.alternarSelecao($0) }
        await fonte.ajustar(erroNaChamada: [novos[0]: ErroDaApi(codigo: .vagaEncerrada),
                                            novos[1]: ErroDaApi(codigo: .limiteDeChamadas, detalhes: "por_vaga"),
                                            novos[2]: ErroDaApi(codigo: .vagaEncerrada)])
        await vm.chamar(trabalho: try trabalho())
        var pedidos = await fonte.pedidos
        #expect(pedidos.suffix(3).allSatisfy { $0.vagaID == primeira && $0.trabalho == nil })
        #expect(novos.allSatisfy { if case .erro = vm.resultadosDaChamada[$0] { true } else { false } })
        #expect(!vm.travadoPeloIncerto) // recusa definitiva não trava

        // A pessoa muda o trabalho: aí começa ciclo novo, numa vaga nova.
        await fonte.ajustar(erroNaChamada: [:])
        await vm.buscar()
        vm.alternarSelecao(try #require(vm.resultados.first).id)
        await vm.chamar(trabalho: try trabalho(valor: 22_000))
        pedidos = await fonte.pedidos
        #expect(pedidos.last?.trabalho != nil && pedidos.last?.vagaID == nil)
        #expect(pedidos.filter { $0.trabalho != nil }.count == 2)
    }

    @Test("A 1ª passa do prazo de 15 s: p-2 e p-3 nem saem; o reenvio repete a chave da 1ª e os outros entram pelo vaga_id",
          .timeLimit(.minutes(1)))
    func primeiraIncertaPeloPrazo() async throws {
        let (fonte, vm) = preparar(total: 3)
        await vm.buscar()
        let ids = vm.resultados.map(\.id)
        try #require(ids.count >= 3)
        ids.forEach { vm.alternarSelecao($0) }
        await fonte.ajustar(atrasaAlemDoPrazo: [ids[0]])
        await vm.chamar(trabalho: try trabalho())
        var pedidos = await fonte.pedidos
        #expect(pedidos.map(\.profissionalID) == [ids[0]]) // nenhum pedido de p-2/p-3, com ou sem o trabalho
        #expect(vm.resultadosDaChamada[ids[0]] == .erro(TextosChamadaDireta.erro))
        #expect(vm.resultadosDaChamada[ids[1]] == .naoEnviada && vm.resultadosDaChamada[ids[2]] == .naoEnviada)
        #expect(vm.podeReenviar)

        await fonte.ajustar(atrasaAlemDoPrazo: [])
        await vm.chamar(trabalho: try trabalho())
        pedidos = await fonte.pedidos
        #expect(pedidos.map(\.profissionalID) == [ids[0], ids[0], ids[1], ids[2]])
        try #require(pedidos.count >= 2)
        #expect(pedidos[1] == pedidos[0]) // a mesma chave e o mesmo trabalho: o servidor devolve a chamada já criada
        let vagaID = try #require(enviada(vm.resultadosDaChamada[ids[0]])).vagaID
        #expect(pedidos.suffix(2).allSatisfy { $0.vagaID == vagaID && $0.trabalho == nil })
        #expect(vagas(vm, ids) == [vagaID])
        #expect(!vm.podeReenviar)
    }

    @Test("1ª recusada e 2ª incerta levando o trabalho: a rodada para e, no reenvio, a 2ª vai antes de todos")
    func primeiraRecusadaSegundaIncerta() async throws {
        let (fonte, vm) = preparar(total: 3)
        await vm.buscar()
        let ids = vm.resultados.map(\.id)
        try #require(ids.count >= 3)
        ids.forEach { vm.alternarSelecao($0) }
        await fonte.ajustar(erroNaChamada: [ids[0]: ErroDaApi(codigo: .limiteDeChamadas)], perdeResposta: [ids[1]])
        await vm.chamar(trabalho: try trabalho())
        var pedidos = await fonte.pedidos
        #expect(pedidos.map(\.profissionalID) == [ids[0], ids[1]])
        #expect(pedidos.allSatisfy { $0.trabalho != nil })
        #expect(vm.resultadosDaChamada[ids[2]] == .naoEnviada)

        await fonte.ajustar(erroNaChamada: [:], perdeResposta: [])
        await vm.chamar(trabalho: try trabalho())
        pedidos = await fonte.pedidos
        #expect(pedidos.map(\.profissionalID) == [ids[0], ids[1], ids[1], ids[0], ids[2]])
        try #require(pedidos.count >= 5)
        #expect(pedidos[2] == pedidos[1])
        let vagaID = try #require(enviada(vm.resultadosDaChamada[ids[1]])).vagaID
        #expect(pedidos[3].chave == pedidos[0].chave && pedidos[3].vagaID == vagaID && pedidos[3].trabalho == nil)
        #expect(pedidos[4].vagaID == vagaID && pedidos[4].trabalho == nil)
        #expect(vagas(vm, ids) == [vagaID])
    }

    @Test("J7 do p-1 com o p-2 incerto levando o trabalho: a confirmação não manda o p-1 com o trabalho; ele espera o p-2 e entra pelo vaga_id")
    func confirmacaoJ7EsperaOIncerto() async throws {
        let (fonte, vm) = preparar(total: 3)
        await vm.buscar()
        let ids = vm.resultados.map(\.id)
        try #require(ids.count >= 3)
        ids.forEach { vm.alternarSelecao($0) }
        await fonte.ajustar(recorrenciaPendente: [ids[0]], perdeResposta: [ids[1]])
        await vm.chamar(trabalho: try trabalho())
        #expect(vm.resultadosDaChamada[ids[0]] == .pedeConfirmacaoDeRecorrencia)
        #expect(vm.resultadosDaChamada[ids[2]] == .naoEnviada)
        #expect(vm.mostrarJ7)

        // Confirma o J7 com o p-2 ainda sem resposta: só o p-2 sai (repetido), o p-1 não sai.
        await fonte.ajustar(erroNaChamada: [ids[1]: ErroDaApi(codigo: .semRede)], perdeResposta: [])
        await vm.chamar(trabalho: try trabalho(), confirmoRecorrencia: true)
        var pedidos = await fonte.pedidos
        #expect(pedidos.map(\.profissionalID) == [ids[0], ids[1], ids[1]])
        try #require(pedidos.count >= 3)
        #expect(pedidos[2] == pedidos[1])
        #expect(vm.resultadosDaChamada[ids[0]] == .pedeConfirmacaoDeRecorrencia)
        #expect(vm.mostrarJ7)

        // O p-2 resolve (a mesma chave devolve a chamada já criada) e só então o p-1 confirmado entra pelo vaga_id.
        await fonte.ajustar(erroNaChamada: [:])
        await vm.chamar(trabalho: try trabalho(), confirmoRecorrencia: true)
        pedidos = await fonte.pedidos
        #expect(pedidos.map(\.profissionalID) == [ids[0], ids[1], ids[1], ids[1], ids[0]])
        try #require(pedidos.count >= 5)
        #expect(pedidos[3] == pedidos[1]) // sem a confirmação J7, que é só do p-1
        let vagaID = try #require(enviada(vm.resultadosDaChamada[ids[1]])).vagaID
        #expect(pedidos[4].chave == pedidos[0].chave && pedidos[4].vagaID == vagaID && pedidos[4].trabalho == nil)
        #expect(pedidos[4].confirmoRecorrencia)
        #expect(!vm.mostrarJ7)

        await vm.chamar(trabalho: try trabalho())
        pedidos = await fonte.pedidos
        #expect(pedidos.last?.profissionalID == ids[2] && pedidos.last?.vagaID == vagaID)
        #expect(pedidos.filter { $0.trabalho != nil && $0.profissionalID == ids[0] }.count == 1) // só o recusado pelo J7
        #expect(vagas(vm, ids) == [vagaID])
    }

    // MARK: Trava do incerto que levou o trabalho (IMPORTANTES 1 e 2 do Lince G no #780)

    @Test("Incerto que levou o trabalho trava a seleção: não desmarca, não troca, não acrescenta; o Tentar de novo fecha com 1 vaga")
    func incertoTravaASelecao() async throws {
        let (fonte, vm) = preparar(total: 4)
        await vm.buscar()
        let ids = vm.resultados.map(\.id)
        try #require(ids.count >= 4)
        ids.prefix(3).forEach { vm.alternarSelecao($0) }
        await fonte.ajustar(perdeResposta: [ids[0]])
        await vm.chamar(trabalho: try trabalho())
        #expect(vm.travadoPeloIncerto)
        // O caminho do Lince: troca o p-1 pelo p-4 (desmarca e marca). Nada muda.
        #expect(!vm.alternarSelecao(ids[0]))
        #expect(!vm.alternarSelecao(ids[1]))
        #expect(!vm.alternarSelecao(ids[3]))
        #expect(vm.selecionados == Array(ids.prefix(3)))

        await fonte.ajustar(perdeResposta: [])
        await vm.chamar(trabalho: try trabalho())
        let pedidos = await fonte.pedidos
        #expect(pedidos.map(\.profissionalID) == [ids[0], ids[0], ids[1], ids[2]])
        try #require(pedidos.count >= 2)
        #expect(pedidos[1] == pedidos[0])
        #expect(pedidos.filter { $0.trabalho != nil }.map(\.chave) == [pedidos[0].chave, pedidos[0].chave])
        let vagaID = try #require(enviada(vm.resultadosDaChamada[ids[0]])).vagaID
        #expect(vagas(vm, Array(ids.prefix(3))) == [vagaID])
        // Resolvido, a seleção volta a mudar.
        #expect(!vm.travadoPeloIncerto)
        #expect(vm.alternarSelecao(ids[0]))
    }

    @Test("Incerto sozinho na seleção: acrescentar alguém também fica travado")
    func incertoTravaAcrescentar() async throws {
        let (fonte, vm) = preparar(total: 3)
        await vm.buscar()
        let ids = vm.resultados.map(\.id)
        try #require(ids.count >= 2)
        vm.alternarSelecao(ids[0])
        await fonte.ajustar(perdeResposta: [ids[0]])
        await vm.chamar(trabalho: try trabalho())
        #expect(!vm.alternarSelecao(ids[1]))
        #expect(vm.selecionados == [ids[0]])
    }

    @Test("Incerto que levou o trabalho bloqueia buscar() e a página seguinte; nada sai e nada se apaga")
    func incertoBloqueiaBuscar() async throws {
        let (fonte, vm) = preparar(total: 45)
        await vm.buscar()
        let ids = vm.resultados.map(\.id)
        try #require(ids.count >= 4)
        ids.prefix(3).forEach { vm.alternarSelecao($0) }
        await fonte.ajustar(perdeResposta: [ids[0]])
        await vm.chamar(trabalho: try trabalho())
        #expect(!vm.podeBuscar)
        await vm.buscar()
        await vm.carregarMais()
        #expect(await fonte.cursoresRecebidos == [nil]) // nem busca nova nem página seguinte
        #expect(vm.selecionados == Array(ids.prefix(3)))
        #expect(vm.resultadosDaChamada[ids[1]] == .naoEnviada)
        #expect(vm.podeReenviar)

        await fonte.ajustar(perdeResposta: [])
        await vm.chamar(trabalho: try trabalho())
        var pedidos = await fonte.pedidos
        try #require(pedidos.count >= 2)
        #expect(pedidos.filter { $0.trabalho != nil }.count == 2 && pedidos[1] == pedidos[0])
        let vagaID = try #require(enviada(vm.resultadosDaChamada[ids[0]])).vagaID
        // Resolvido: a busca volta, e o mesmo trabalho com outra pessoa entra na mesma vaga.
        #expect(vm.podeBuscar)
        await vm.buscar()
        vm.alternarSelecao(ids[3])
        await vm.chamar(trabalho: try trabalho())
        pedidos = await fonte.pedidos
        #expect(pedidos.last?.profissionalID == ids[3] && pedidos.last?.vagaID == vagaID && pedidos.last?.trabalho == nil)
    }

    @Test("cursor_invalido refaz a busca e guarda o incerto, a chave dele e a vaga do trabalho")
    func cursorInvalidoGuardaIncertoEChave() async throws {
        let (fonte, vm) = preparar(total: 45)
        await vm.buscar()
        let ids = vm.resultados.map(\.id)
        try #require(ids.count >= 3)
        vm.alternarSelecao(ids[0])
        vm.alternarSelecao(ids[1])
        // O p-2 vai pelo vaga_id e fica incerto: não trava (a vaga existe), mas a chave dele precisa sobreviver.
        await fonte.ajustar(perdeResposta: [ids[1]])
        await vm.chamar(trabalho: try trabalho())
        let vagaID = try #require(enviada(vm.resultadosDaChamada[ids[0]])).vagaID
        let chaveIncerta = try #require(await fonte.pedidos.last).chave
        #expect(!vm.travadoPeloIncerto)

        await fonte.ajustar(erroNaPaginaSeguinte: ErroDaApi(codigo: .cursorInvalido), perdeResposta: [])
        await vm.carregarMais()
        #expect(await fonte.cursoresRecebidos == [nil, "20", nil]) // refez a 1ª página
        #expect(vm.selecionados.isEmpty)

        vm.alternarSelecao(ids[1])
        vm.alternarSelecao(ids[2])
        await vm.chamar(trabalho: try trabalho())
        let pedidos = await fonte.pedidos
        #expect(pedidos.count == 4)
        try #require(pedidos.count >= 4)
        #expect(pedidos[2].profissionalID == ids[1] && pedidos[2].chave == chaveIncerta && pedidos[2].vagaID == vagaID)
        #expect(pedidos[3].profissionalID == ids[2] && pedidos[3].vagaID == vagaID && pedidos[3].trabalho == nil)
        #expect(pedidos.filter { $0.trabalho != nil }.count == 1)
        #expect(vagas(vm, [ids[1], ids[2]]) == [vagaID])
    }

    @Test("Nova busca zera a seleção e o resultado das chamadas")
    func novaBuscaZeraSelecao() async throws {
        let (_, vm) = preparar(total: 3)
        await vm.buscar()
        vm.alternarSelecao(try #require(vm.resultados.first).id)
        await vm.buscar()
        #expect(vm.selecionados.isEmpty)
    }

    // MARK: Integração com o dublê do cenário .buscaDeProfissionais (relógio fixo)

    private struct RelogioFixoDaBusca: Relogio {
        let agora = Date(timeIntervalSince1970: 1_900_000_000)
    }

    /// O dublê com a conta de quem contrata, a casa, o serviço do exemplo (o primeiro do catálogo) e a região 1.
    private func prepararNoDuble() async throws -> (api: ApiClienteEmMemoria, casaID: UUID, funcaoID: UUID, regiao: RegiaoAdministrativa) {
        let api = ApiClienteEmMemoria(cenario: .buscaDeProfissionais, relogio: RelogioFixoDaBusca())
        let casaID = try #require(try await api.meusEstabelecimentos().first).id
        let funcaoID = try #require(try await api.funcoes().first).id
        let regiao = try #require(try await api.regioesAdministrativas().first { $0.id == 1 })
        return (api, casaID, funcaoID, regiao)
    }

    @Test("Dublê: buscar traz os resultados na ordem do servidor e carregarMais vai até o fim, sem repetir")
    func integracaoOrdemEPaginacao() async throws {
        let (api, casaID, funcaoID, regiao) = try await prepararNoDuble()
        let filtro = FiltroBuscaProfissionais(estabelecimentoID: casaID, funcaoID: funcaoID, regiaoID: regiao.id)
        let primeira = try await api.buscarProfissionais(filtro, cursor: nil, limite: 20)
        let cursor = try #require(primeira.proximoCursor)
        let segunda = try await api.buscarProfissionais(filtro, cursor: cursor, limite: 20)
        let esperados = (primeira.itens + segunda.itens).map(\.id)
        #expect(primeira.itens.count == 20)
        #expect(!segunda.itens.isEmpty && !segunda.temMais)

        let vm = BuscaDeProfissionaisViewModel(api: api, estabelecimentoID: casaID)
        vm.funcaoID = funcaoID
        vm.regiaoID = regiao.id
        await vm.buscar()
        #expect(vm.estado == .resultados)
        #expect(vm.resultados.count == 20)
        #expect(vm.temMais)
        await vm.carregarMais()
        #expect(!vm.temMais)
        #expect(vm.resultados.map(\.id) == esperados)
        #expect(Set(vm.resultados.map(\.id)).count == esperados.count)
        // Quem o servidor tira da lista (pausado, sem aceite, sem região) não aparece.
        #expect(!vm.resultados.map(\.id).contains(ApiClienteEmMemoria.IDsDaBusca.pausado))
        #expect(!vm.resultados.map(\.id).contains(ApiClienteEmMemoria.IDsDaBusca.naoAceita))
        #expect(!vm.resultados.map(\.id).contains(ApiClienteEmMemoria.IDsDaBusca.semRegiao))
    }

    @Test("Dublê: selecionar 3 e chamar cria 3 chamadas numa vaga só: a 1ª com o regiaoID do filtro, as outras pelo vaga_id")
    func integracaoChamarTres() async throws {
        let (api, casaID, funcaoID, regiao) = try await prepararNoDuble()
        let casa = try await api.meuEstabelecimento(id: casaID)
        let vm = BuscaDeProfissionaisViewModel(api: api, estabelecimentoID: casaID)
        vm.funcaoID = funcaoID
        vm.regiaoID = regiao.id
        await vm.buscar()
        let escolhidos = Array(vm.resultados.prefix(4).map(\.id))
        #expect(escolhidos.count == 4)
        escolhidos.forEach { vm.alternarSelecao($0) }
        #expect(vm.selecionados == Array(escolhidos.prefix(3))) // o 4º não entrou

        let agora = RelogioFixoDaBusca().agora
        let trabalho = PublicacaoVaga(
            estabelecimentoID: casaID, funcaoID: funcaoID,
            periodo: try Periodo(inicio: agora.addingTimeInterval(24 * 3600), fim: agora.addingTimeInterval(28 * 3600)),
            local: casa.endereco, regiaoAdministrativa: regiao.nome, ponto: casa.ponto, valor: Dinheiro(centavos: 20_000),
            posicoes: 1, inclusos: Inclusos(refeicao: false, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: casa.nome, chave: UUID())
        await vm.chamar(trabalho: trabalho)

        let pedidos = await api.pedidosChamadaRecebidos
        #expect(pedidos.map(\.profissionalID) == vm.selecionados)
        #expect(pedidos.first?.regiaoID == regiao.id)
        #expect(Set(pedidos.map(\.chave)).count == 3)
        for id in vm.selecionados {
            if case .enviada = vm.resultadosDaChamada[id] {} else { Issue.record("a chamada de \(id) não foi enviada: \(String(describing: vm.resultadosDaChamada[id]))") }
        }
        // Uma vaga só para as 3 chamadas: a 1ª criou, as outras entraram nela pelo vaga_id.
        let vagas = Set(vm.selecionados.compactMap { enviada(vm.resultadosDaChamada[$0])?.vagaID })
        #expect(vagas.count == 1)
        #expect(pedidos.dropFirst().allSatisfy { $0.vagaID == vagas.first })
    }

    @Test("Dublê: filtro sem ninguém vira vazio e oferece Publicar para todos já preenchido")
    func integracaoVazio() async throws {
        let (api, casaID, funcaoID, regiao) = try await prepararNoDuble()
        // O exemplo só tem gente no primeiro serviço do catálogo: qualquer outro volta vazio.
        let outraFuncaoID = try #require(try await api.funcoes().first { $0.id != funcaoID }).id
        let horario = try Periodo(inicio: RelogioFixoDaBusca().agora.addingTimeInterval(48 * 3600),
                                  fim: RelogioFixoDaBusca().agora.addingTimeInterval(52 * 3600))
        let vm = BuscaDeProfissionaisViewModel(api: api, estabelecimentoID: casaID)
        vm.funcaoID = outraFuncaoID
        vm.regiaoID = regiao.id
        vm.horario = horario
        await vm.buscar()
        #expect(vm.estado == .vazio)
        #expect(vm.resultados.isEmpty)
        #expect(vm.rascunhoParaPublicarParaTodos == RascunhoDeVagaDaBusca(
            estabelecimentoID: casaID, funcaoID: outraFuncaoID, regiaoID: regiao.id, horario: horario))
    }
}
