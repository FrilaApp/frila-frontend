import Foundation
import FrilaApresentacao
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
    private(set) var filtrosRecebidos: [FiltroBuscaProfissionais] = []
    private(set) var cursoresRecebidos: [String?] = []
    private(set) var limitesRecebidos: [Int?] = []
    private(set) var pedidos: [PedidoChamada] = []
    private(set) var consultasDaConfiguracao = 0

    init(total: Int) { self.total = total }

    func ajustar(buscaLigada: Bool? = nil, erroNaBusca: ErroDaApi? = nil, erroNaPaginaSeguinte: ErroDaApi? = nil,
                 erroNaChamada: [UUID: ErroDaApi]? = nil, recorrenciaPendente: Set<UUID>? = nil) {
        if let buscaLigada { self.buscaLigada = buscaLigada }
        self.erroNaBusca = erroNaBusca
        self.erroNaPaginaSeguinte = erroNaPaginaSeguinte
        if let erroNaChamada { self.erroNaChamada = erroNaChamada }
        if let recorrenciaPendente { self.recorrenciaPendente = recorrenciaPendente }
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
        if let erro = erroNaChamada[pedido.profissionalID] { throw erro }
        if recorrenciaPendente.contains(pedido.profissionalID), !pedido.confirmoRecorrencia {
            throw ErroDaApi(codigo: .recorrenciaNaoConfirmada)
        }
        return Chamada(id: UUID(), vagaID: UUID(), profissionalID: pedido.profissionalID,
                       estabelecimentoID: pedido.trabalho.estabelecimentoID, recado: pedido.recado,
                       expiraEm: Date(timeIntervalSince1970: 2_000_000_000), criadaEm: Date(timeIntervalSince1970: 1_900_000_000))
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

    private func trabalho() throws -> PublicacaoVaga {
        PublicacaoVaga(
            estabelecimentoID: casaID, funcaoID: funcaoID,
            periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(4 * 3600)),
            local: "Rua Teste", regiaoAdministrativa: "Asa Sul", ponto: try Coordenada(latitude: -15.8, longitude: -47.9),
            valor: Dinheiro(centavos: 20_000), posicoes: 1, inclusos: Inclusos(refeicao: false, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Casa", chave: UUID())
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
    func paginacaoComOMesmoFiltro() async {
        let (fonte, vm) = preparar(total: 45)
        await vm.buscar()
        vm.regiaoID = 99
        await vm.carregarMais()
        let filtros = await fonte.filtrosRecebidos
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
    func limiteDeTres() async {
        let (_, vm) = preparar(total: 6)
        await vm.buscar()
        let ids = vm.resultados.map(\.id)
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

    @Test("Chamar 3 cria uma chamada para cada, cada uma com a sua chave, pela chamarProfissional")
    func chamarTres() async throws {
        let (fonte, vm) = preparar(total: 5)
        await vm.buscar()
        vm.resultados.prefix(3).forEach { vm.alternarSelecao($0.id) }
        await vm.chamar(trabalho: try trabalho(), recado: "Pode vir cedo?")
        let pedidos = await fonte.pedidos
        #expect(pedidos.map(\.profissionalID) == vm.selecionados)
        #expect(Set(pedidos.map(\.trabalho.chave)).count == 3)
        #expect(pedidos.allSatisfy { $0.recado == "Pode vir cedo?" && !$0.confirmoRecorrencia })
        #expect(vm.selecionados.allSatisfy { if case .enviada = vm.resultadosDaChamada[$0] { true } else { false } })
        #expect(!vm.mostrarJ7)
    }

    @Test("A região do filtro vai em cada pedido; sem região, vai nulo")
    func regiaoNoPedido() async throws {
        let (fonte, vm) = preparar(total: 2)
        vm.regiaoID = 7
        await vm.buscar()
        vm.alternarSelecao(vm.resultados[0].id)
        await vm.chamar(trabalho: try trabalho())
        vm.regiaoID = nil
        await vm.buscar()
        vm.alternarSelecao(vm.resultados[0].id)
        await vm.chamar(trabalho: try trabalho())
        #expect(await fonte.pedidos.map(\.regiaoID) == [7, nil])
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
        ids.forEach { vm.alternarSelecao($0) }
        await fonte.ajustar(erroNaChamada: [ids[1]: ErroDaApi(codigo: .chamadaJaAberta)])
        await vm.chamar(trabalho: try trabalho())
        #expect(vm.resultadosDaChamada[ids[1]] == .erro(TextosChamadaDireta.jaAberta))
        let primeiraChave = try #require(await fonte.pedidos.first { $0.profissionalID == ids[1] }).trabalho.chave
        await fonte.ajustar(erroNaChamada: [:])
        await vm.chamar(trabalho: try trabalho())
        let pedidos = await fonte.pedidos
        #expect(pedidos.count == 4) // só o 2º foi reenviado
        #expect(pedidos.last?.profissionalID == ids[1])
        #expect(pedidos.last?.trabalho.chave == primeiraChave)
        if case .enviada = vm.resultadosDaChamada[ids[1]] {} else { Issue.record("o 2º deveria ter sido enviado") }
    }

    @Test("J7: não reenvia sozinho; só a confirmação explícita reenvia o mesmo pedido com confirmoRecorrencia")
    func recorrencia() async throws {
        let (fonte, vm) = preparar(total: 2)
        await vm.buscar()
        let ids = vm.resultados.map(\.id)
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
        #expect(pedidos[2].profissionalID == ids[0])
        #expect(pedidos[2].trabalho == pedidos[0].trabalho)
        #expect(!pedidos[0].confirmoRecorrencia && pedidos[2].confirmoRecorrencia)
        #expect(!vm.mostrarJ7)
    }

    @Test("Nova busca zera a seleção e o resultado das chamadas")
    func novaBuscaZeraSelecao() async throws {
        let (_, vm) = preparar(total: 3)
        await vm.buscar()
        vm.alternarSelecao(vm.resultados[0].id)
        await vm.buscar()
        #expect(vm.selecionados.isEmpty)
    }
}
