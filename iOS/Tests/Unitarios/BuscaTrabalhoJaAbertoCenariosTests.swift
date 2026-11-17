import Foundation
import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

/// Os cenários da revisão do #803 (P-027), com dublê próprio, na ordem do contrato 0.2.95: chave,
/// `trabalho_ja_aberto`, J7, criação. A revisão pediu que entrassem no PR; os do J7 seguem a ordem decidida
/// (a folha dos termos vem antes do alerta do J7).
private actor FonteDosCenarios: FonteDaBuscaDeProfissionais {
    private(set) var pedidos: [PedidoChamada] = []
    private(set) var leituras = 0
    private var porChave: [UUID: Chamada] = [:]
    private var aberta: UUID?
    private var termos: [UUID: (valor: Int, inclusos: Inclusos)] = [:]
    private var j7: Set<UUID> = []
    private var perdeRespostaPelaVaga: Set<UUID> = []
    private var leiturasQueFalham = 0
    let total: Int

    init(total: Int) { self.total = total }

    func abrir(_ vaga: UUID, valor: Int = 20_000,
               inclusos: Inclusos = Inclusos(refeicao: false, transporte: false, exigeMaterialProprio: false)) {
        aberta = vaga
        termos[vaga] = (valor, inclusos)
    }
    func pedirJ7(_ ids: Set<UUID>) { j7 = ids }
    func perderRespostaPelaVaga(_ ids: Set<UUID>) { perdeRespostaPelaVaga = ids }
    func falharLeituras(_ n: Int) { leiturasQueFalham = n }

    func configuracaoDoApp() async throws -> ConfiguracaoApp {
        ConfiguracaoApp(versaoMinima: "1.0", versaoRecomendada: "1.0", mensagem: nil, urlDaLoja: URL(string: "https://example.com")!,
                        recursos: RecursosDoApp(chamadaDireta: true, buscaProfissionais: true))
    }

    func buscarProfissionais(_ filtro: FiltroBuscaProfissionais, cursor: String?, limite: Int?) async throws -> PaginaBuscaProfissionais {
        PaginaBuscaProfissionais(itens: (0..<total).map(Self.cartao), proximoCursor: nil)
    }

    func aceitarTermos(versao: String) async throws -> AceiteDeTermos {
        AceiteDeTermos(termosVersao: versao, aceitoEm: Date(timeIntervalSince1970: 1_900_000_000))
    }

    func chamarProfissional(_ pedido: PedidoChamada) async throws -> Chamada {
        pedidos.append(pedido)
        if let existente = porChave[pedido.chave] { return existente }
        if let aberta, pedido.vagaID != aberta {
            throw ErroDaApi(codigo: .trabalhoJaAberto, detalhes: aberta.uuidString.lowercased())
        }
        if j7.contains(pedido.profissionalID), !pedido.confirmoRecorrencia { throw ErroDaApi(codigo: .recorrenciaNaoConfirmada) }
        let chamada = Chamada(id: UUID(), vagaID: pedido.vagaID ?? UUID(), profissionalID: pedido.profissionalID,
                              estabelecimentoID: pedido.estabelecimentoID, recado: pedido.recado,
                              expiraEm: Date(timeIntervalSince1970: 2_000_000_000), criadaEm: Date(timeIntervalSince1970: 1_900_000_000))
        porChave[pedido.chave] = chamada
        if pedido.vagaID != nil, perdeRespostaPelaVaga.contains(pedido.profissionalID) { throw ErroDaApi(codigo: .respostaInvalida) }
        return chamada
    }

    func paginaDeMinhasChamadas(estado: EstadoChamada?, cursor: String?, limite: Int?) async throws -> PaginaChamadas {
        leituras += 1
        if leiturasQueFalham > 0 {
            leiturasQueFalham -= 1
            throw ErroDaApi(codigo: .semRede)
        }
        return PaginaChamadas(itens: termos.map { vaga, t in
            ChamadaResumo(id: vaga, vagaID: vaga, profissionalID: Self.id(900), estabelecimentoID: Self.id(901), estado: .aberta,
                          expiraEm: Date(timeIntervalSince1970: 2_000_000_000), criadaEm: Date(timeIntervalSince1970: 1_900_000_000),
                          funcao: Self.funcao, inicioEm: Date(timeIntervalSince1970: 1_900_000_000),
                          fimEm: Date(timeIntervalSince1970: 1_900_014_400), valorCentavos: t.valor, outraParte: Self.perfil)
        })
    }

    func detalheChamada(id: UUID) async throws -> ChamadaDetalhe {
        guard let t = termos[id] else { throw ErroDaApi(codigo: .naoEncontrado) }
        return ChamadaDetalhe(id: id, vagaID: id, profissionalID: Self.id(900), estabelecimentoID: Self.id(901), estado: .aberta,
                              expiraEm: Date(timeIntervalSince1970: 2_000_000_000), criadaEm: Date(timeIntervalSince1970: 1_900_000_000),
                              funcao: Self.funcao, inicioEm: Date(timeIntervalSince1970: 1_900_000_000),
                              fimEm: Date(timeIntervalSince1970: 1_900_014_400), valorCentavos: t.valor,
                              outraParte: Self.perfil, regiaoAdministrativa: "Asa Sul", incluiRefeicao: t.inclusos.refeicao,
                              incluiTransporte: t.inclusos.transporte, exigeMaterialProprio: t.inclusos.exigeMaterialProprio)
    }

    static func id(_ n: Int) -> UUID { UUID(uuidString: String(format: "B0000000-0000-0000-0000-%012d", n))! }
    static let funcaoID = UUID(uuidString: "F0000000-0000-0000-0000-000000000002")!
    static let funcao = Funcao(id: funcaoID, nome: "Garçom", categoria: "Salão")
    static let perfil = PerfilPublico(id: id(900), tipo: .profissional, nome: "Pessoa 900",
                                      reputacao: Reputacao(positivas: 0, total: 0, taxaComparecimento: nil,
                                                           turnosConsiderados: 0, turnosRealizados: 0))
    static func cartao(_ n: Int) -> CartaoProfissional {
        CartaoProfissional(
            id: id(n), nome: "Pessoa \(n)",
            servico: ServicoNoPerfil(funcao: funcao, servico: ServicoOferecido(funcaoID: funcaoID, unidade: .diaria, valorCentavos: 15_000)),
            distanciaFaixa: .ate5km,
            reputacao: Reputacao(positivas: 0, total: 5, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0),
            disponivelNoHorario: nil)
    }
}

@Suite("Busca: cenários do 409 trabalho_ja_aberto (revisão do #803)")
@MainActor
struct BuscaTrabalhoJaAbertoCenariosTests {
    private let casaID = UUID(uuidString: "C0000000-0000-0000-0000-000000000002")!
    private let inicio = Date(timeIntervalSince1970: 1_900_000_000)
    private let outrosInclusos = Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: false)

    private func preparar(total: Int) async -> (FonteDosCenarios, BuscaDeProfissionaisViewModel, [UUID]) {
        let fonte = FonteDosCenarios(total: total)
        let vm = BuscaDeProfissionaisViewModel(fonte: fonte, estabelecimentoID: casaID)
        vm.funcaoID = FonteDosCenarios.funcaoID
        await vm.buscar()
        return (fonte, vm, vm.resultados.map(\.id))
    }

    private func trabalho() throws -> PublicacaoVaga {
        PublicacaoVaga(
            estabelecimentoID: casaID, funcaoID: FonteDosCenarios.funcaoID,
            periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(4 * 3600)),
            local: "Rua Teste", regiaoAdministrativa: "Asa Sul", ponto: try Coordenada(latitude: -15.8, longitude: -47.9),
            valor: Dinheiro(centavos: 20_000), posicoes: 1,
            inclusos: Inclusos(refeicao: false, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Casa", chave: UUID())
    }

    private func enviada(_ resultado: ResultadoDaChamadaDaBusca?) -> Chamada? {
        if case let .enviada(chamada) = resultado { return chamada }
        return nil
    }

    /// Quem espera o J7 fica depois de quem recebe o 409 com termos diferentes (outro aparelho abriu o mesmo trabalho
    /// entre duas rodadas). Devolve quem espera o J7, o outro, a vaga aberta e quantos pedidos saíram até ali.
    private func j7EsperandoAtrasDosTermos() async throws
        -> (FonteDosCenarios, BuscaDeProfissionaisViewModel, comJ7: UUID, outro: UUID, aberta: UUID, naRodada: Int) {
        let (fonte, vm, ids) = await preparar(total: 2)
        try #require(ids.count == 2)
        let comJ7 = ids[0], outro = ids[1]
        await fonte.pedirJ7([comJ7])
        vm.alternarSelecao(comJ7)
        await vm.chamar(trabalho: try trabalho())
        #expect(vm.resultadosDaChamada[comJ7] == .pedeConfirmacaoDeRecorrencia)
        #expect(vm.mostrarJ7)
        vm.mostrarJ7 = false // a casa fecha o alerta
        // A seleção muda: o outro entra antes de quem espera o J7.
        vm.alternarSelecao(comJ7)
        vm.alternarSelecao(outro)
        vm.alternarSelecao(comJ7)
        #expect(vm.selecionados == [outro, comJ7])
        let aberta = UUID()
        await fonte.abrir(aberta, valor: 25_000, inclusos: outrosInclusos)
        await vm.reenviar()
        let naRodada = await fonte.pedidos.count
        return (fonte, vm, comJ7, outro, aberta, naRodada)
    }

    @Test("409 com termos iguais e o pedido pelo vaga_id fica incerto: a rodada segue, não trava, e o reenvio usa a MESMA chave")
    func reenvioIncertoPelaVagaUsaAMesmaChave() async throws {
        let (fonte, vm, ids) = await preparar(total: 2)
        try #require(ids.count == 2)
        ids.forEach { vm.alternarSelecao($0) }
        let aberta = UUID()
        await fonte.abrir(aberta)
        await fonte.perderRespostaPelaVaga([ids[0]])
        await vm.chamar(trabalho: try trabalho())
        var pedidos = await fonte.pedidos
        #expect(pedidos.map(\.profissionalID) == [ids[0], ids[0], ids[1]])
        try #require(pedidos.count == 3)
        #expect(pedidos[0].trabalho != nil)
        #expect(pedidos[1].vagaID == aberta && pedidos[1].chave != pedidos[0].chave)
        #expect(pedidos[2].vagaID == aberta && pedidos[2].trabalho == nil)
        #expect(enviada(vm.resultadosDaChamada[ids[1]])?.vagaID == aberta)
        if case .erro = vm.resultadosDaChamada[ids[0]] {} else { Issue.record("esperava erro para o incerto") }
        #expect(!vm.travadoPeloIncerto)
        #expect(vm.podeReenviar)

        await fonte.perderRespostaPelaVaga([])
        await vm.reenviar()
        pedidos = await fonte.pedidos
        try #require(pedidos.count == 4)
        #expect(pedidos[3].profissionalID == ids[0])
        #expect(pedidos[3].vagaID == aberta && pedidos[3].trabalho == nil)
        #expect(pedidos[3].chave == pedidos[1].chave)
        #expect(enviada(vm.resultadosDaChamada[ids[0]])?.vagaID == aberta)
        #expect(pedidos.filter { $0.trabalho != nil }.count == 1)
    }

    @Test("Confirmar com 3 esperando manda 1 pedido por pessoa, todos pelo vaga_id, com chaves novas e distintas")
    func confirmarComTres() async throws {
        let (fonte, vm, ids) = await preparar(total: 3)
        try #require(ids.count == 3)
        ids.forEach { vm.alternarSelecao($0) }
        let aberta = UUID()
        await fonte.abrir(aberta, valor: 25_000)
        await vm.chamar(trabalho: try trabalho())
        let antes = await fonte.pedidos
        #expect(antes.count == 1 && antes[0].trabalho != nil)

        await vm.confirmarTermosDaVagaAberta()
        let depois = Array(await fonte.pedidos.dropFirst(1))
        #expect(depois.map(\.profissionalID) == ids)
        #expect(depois.allSatisfy { $0.vagaID == aberta && $0.trabalho == nil })
        #expect(Set(depois.map(\.chave)).count == 3)
        #expect(!depois.map(\.chave).contains(antes[0].chave))
        #expect(ids.allSatisfy { enviada(vm.resultadosDaChamada[$0])?.vagaID == aberta })
        #expect(!vm.mostrarTermosDaVagaAberta)
    }

    @Test("J7 pendente atrás dos termos diferentes: a folha dos termos vem primeiro e o alerta do J7 só volta depois de Confirmar")
    func j7DepoisDosTermosConfirmados() async throws {
        let (fonte, vm, comJ7, outro, aberta, naRodada) = try await j7EsperandoAtrasDosTermos()
        // Um aviso de cada vez: a folha dos termos, sem o alerta do J7.
        #expect(vm.mostrarTermosDaVagaAberta)
        #expect(!vm.mostrarJ7)
        #expect(vm.resultadosDaChamada[comJ7] == .pedeConfirmacaoDeRecorrencia)

        // Com os termos pendentes, a confirmação do J7 não manda nada.
        await vm.reenviar(confirmoRecorrencia: true)
        #expect(await fonte.pedidos.count == naRodada)

        // Confirmar os termos: os dois saem pela vaga aberta; quem tinha J7 vai SEM a confirmação e o servidor pede de novo.
        await vm.confirmarTermosDaVagaAberta()
        let depois = Array(await fonte.pedidos.dropFirst(naRodada))
        #expect(depois.allSatisfy { $0.vagaID == aberta && $0.trabalho == nil })
        #expect(depois.first { $0.profissionalID == comJ7 }?.confirmoRecorrencia == false)
        #expect(enviada(vm.resultadosDaChamada[outro])?.vagaID == aberta)
        #expect(vm.resultadosDaChamada[comJ7] == .pedeConfirmacaoDeRecorrencia)
        #expect(vm.mostrarJ7 && !vm.mostrarTermosDaVagaAberta)

        // Agora o J7 confirmado sai, pela vaga aberta.
        await vm.reenviar(confirmoRecorrencia: true)
        let ultimo = try #require(await fonte.pedidos.last)
        #expect(ultimo.profissionalID == comJ7 && ultimo.vagaID == aberta && ultimo.confirmoRecorrencia)
        #expect(enviada(vm.resultadosDaChamada[comJ7])?.vagaID == aberta)
        #expect(await fonte.pedidos.filter { $0.trabalho != nil && $0.confirmoRecorrencia }.isEmpty)
    }

    @Test("J7 pendente atrás dos termos diferentes: Cancelar os termos religa o alerta do J7, e confirmá-lo cai de novo nos termos, sem entrar na vaga aberta")
    func cancelarOsTermosReligaOJ7() async throws {
        let (fonte, vm, comJ7, _, aberta, naRodada) = try await j7EsperandoAtrasDosTermos()
        vm.cancelarTermosDaVagaAberta()
        #expect(vm.mostrarJ7 && !vm.mostrarTermosDaVagaAberta)
        #expect(vm.resultadosDaChamada[comJ7] == .pedeConfirmacaoDeRecorrencia)
        #expect(await fonte.pedidos.count == naRodada)

        // O J7 confirmado repete o trabalho: o servidor responde o mesmo 409, e a folha dos termos volta antes do alerta.
        await vm.reenviar(confirmoRecorrencia: true)
        #expect(await fonte.pedidos.dropFirst(naRodada).allSatisfy { $0.vagaID != aberta })
        #expect(vm.mostrarTermosDaVagaAberta && !vm.mostrarJ7)
    }

    @Test("A leitura falha para o 1º; o 2º manda o trabalho de novo (409 outra vez), lê e segue; nada é criado fora da vaga aberta")
    func leituraFalhaNoPrimeiro() async throws {
        let (fonte, vm, ids) = await preparar(total: 2)
        try #require(ids.count == 2)
        ids.forEach { vm.alternarSelecao($0) }
        let aberta = UUID()
        await fonte.abrir(aberta)
        await fonte.falharLeituras(1)
        await vm.chamar(trabalho: try trabalho())
        var pedidos = await fonte.pedidos
        #expect(pedidos.map(\.profissionalID) == [ids[0], ids[1], ids[1]])
        try #require(pedidos.count == 3)
        #expect(pedidos[0].trabalho != nil && pedidos[1].trabalho != nil)
        #expect(pedidos[2].vagaID == aberta)
        #expect(vm.resultadosDaChamada[ids[0]] == .erro(TextosChamadaDireta.erro))
        #expect(enviada(vm.resultadosDaChamada[ids[1]])?.vagaID == aberta)
        #expect(await fonte.leituras == 2)

        await vm.reenviar()
        pedidos = await fonte.pedidos
        try #require(pedidos.count == 4)
        // O 1º vai pela vaga que o 2º descobriu, com a chave que o 409 não gastou.
        #expect(pedidos[3].profissionalID == ids[0] && pedidos[3].vagaID == aberta)
        #expect(pedidos[3].chave == pedidos[0].chave)
        #expect(enviada(vm.resultadosDaChamada[ids[0]])?.vagaID == aberta)
    }

    @Test("Depois de Cancelar, chamar de novo repete o mesmo trabalho (DINHEIRO, #780), cai no mesmo 409 e volta a pedir a confirmação; nada sai pelo vaga_id")
    func cancelarEChamarDeNovo() async throws {
        let (fonte, vm, ids) = await preparar(total: 1)
        try #require(ids.count == 1)
        vm.alternarSelecao(ids[0])
        let aberta = UUID()
        await fonte.abrir(aberta, valor: 25_000)
        await vm.chamar(trabalho: try trabalho())
        vm.mostrarTermosDaVagaAberta = false
        #expect(vm.podeChamar && vm.temEnvioRegistrado)
        await vm.reenviar()
        let pedidos = await fonte.pedidos
        #expect(pedidos.count == 2)
        #expect(pedidos.allSatisfy { $0.trabalho != nil && $0.vagaID == nil })
        #expect(vm.mostrarTermosDaVagaAberta)
    }

    private struct RelogioFixo: Relogio {
        let agora = Date(timeIntervalSince1970: 1_900_000_000)
    }

    @Test("A fonte real (FonteDaBuscaPelaApi) encaminha minhas_chamadas e detalhe_chamada à API; não cai no padrão que falha")
    func fonteRealEncaminhaAsLeituras() async throws {
        let api = ApiClienteEmMemoria(cenario: .buscaDeProfissionais, relogio: RelogioFixo())
        let casaID = try #require(try await api.meusEstabelecimentos().first).id
        let funcaoID = try #require(try await api.funcoes().first).id
        let regiao = try #require(try await api.regioesAdministrativas().first { $0.id == 1 })
        let casa = try await api.meuEstabelecimento(id: casaID)
        let vm = BuscaDeProfissionaisViewModel(api: api, estabelecimentoID: casaID)
        vm.funcaoID = funcaoID
        vm.regiaoID = regiao.id
        await vm.buscar()
        let escolhido = try #require(vm.resultados.first).id
        vm.alternarSelecao(escolhido)
        let agora = RelogioFixo().agora
        let trabalho = PublicacaoVaga(
            estabelecimentoID: casaID, funcaoID: funcaoID,
            periodo: try Periodo(inicio: agora.addingTimeInterval(24 * 3600), fim: agora.addingTimeInterval(28 * 3600)),
            local: casa.endereco, regiaoAdministrativa: regiao.nome, ponto: casa.ponto, valor: Dinheiro(centavos: 20_000),
            posicoes: 1, inclusos: Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: casa.nome, chave: UUID())
        await vm.chamar(trabalho: trabalho)
        let chamada = try #require(enviada(vm.resultadosDaChamada[escolhido]))

        let fonte: any FonteDaBuscaDeProfissionais = FonteDaBuscaPelaApi(api: api)
        let abertas = try await fonte.paginaDeMinhasChamadas(estado: .aberta, cursor: nil, limite: nil).itens
        let item = try #require(abertas.first { $0.vagaID == chamada.vagaID })
        #expect(item.valorCentavos == 20_000)
        let detalhe = try await fonte.detalheChamada(id: item.id)
        #expect(detalhe.incluiRefeicao && !detalhe.incluiTransporte && !detalhe.exigeMaterialProprio)
    }
}
