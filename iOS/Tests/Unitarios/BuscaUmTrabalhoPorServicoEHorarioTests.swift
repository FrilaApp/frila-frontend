import Foundation
import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

/// Servidor de mentira para os MENORES 2, 3 e 4 da revisão do #807. Idempotente pela chave; como o real (0.2.95), recusa
/// com `409 trabalho_ja_aberto` o trabalho (serviço, horário e valor) que já tem vaga aberta, e serve os termos dela.
/// Garçom: pessoas 1 e 2. Bartender: pessoas 2 e 3 (a 2 oferece os dois serviços).
private actor ServidorDaBusca: FonteDaBuscaDeProfissionais {
    private(set) var pedidos: [PedidoChamada] = []
    private var porChave: [UUID: Chamada] = [:]
    /// As vagas abertas por trabalho (serviço e horário): o 409 aponta a do mesmo trabalho.
    private var abertas: [(funcaoID: UUID, periodo: Periodo, vagaID: UUID)] = []
    private var segura: Bool
    private let perdeAoAbrir: Bool
    /// Cria a chamada dessas pessoas e perde a resposta (uma vez por pessoa).
    private var perder: Set<UUID>
    private var esperandoChamada: [CheckedContinuation<Void, Never>] = []
    /// A página seguinte (com cursor) fica presa até `soltarPagina` e termina com este erro.
    private var paginaPresa: CheckedContinuation<Void, Never>?
    private var erroDaPagina: ErroDaApi?
    private(set) var paginasSeguintesPedidas = 0
    private let comMaisPaginas: Bool

    init(segura: Bool = false, perdeAoAbrir: Bool = true, perder: Set<UUID> = [], comMaisPaginas: Bool = false) {
        self.segura = segura
        self.perdeAoAbrir = perdeAoAbrir
        self.perder = perder
        self.comMaisPaginas = comMaisPaginas
    }

    func vagasCriadas() -> Set<UUID> { Set(abertas.map(\.vagaID)) }

    func abrir() {
        segura = false
        esperandoChamada.forEach { $0.resume() }
        esperandoChamada = []
    }

    func soltarPagina(com erro: ErroDaApi) {
        erroDaPagina = erro
        paginaPresa?.resume()
        paginaPresa = nil
    }

    func configuracaoDoApp() async throws -> ConfiguracaoApp {
        ConfiguracaoApp(versaoMinima: "1.0", versaoRecomendada: "1.0", mensagem: nil, urlDaLoja: URL(string: "https://example.com")!,
                        recursos: RecursosDoApp(chamadaDireta: true, buscaProfissionais: true))
    }

    func buscarProfissionais(_ filtro: FiltroBuscaProfissionais, cursor: String?, limite: Int?) async throws -> PaginaBuscaProfissionais {
        if cursor != nil {
            paginasSeguintesPedidas += 1
            await withCheckedContinuation { paginaPresa = $0 }
            throw erroDaPagina ?? ErroDaApi(codigo: .cursorInvalido)
        }
        let base = filtro.funcaoID == DadosDaBusca.garcom ? 1 : 2
        return PaginaBuscaProfissionais(itens: [DadosDaBusca.pessoa(base, funcaoID: filtro.funcaoID),
                                                DadosDaBusca.pessoa(base + 1, funcaoID: filtro.funcaoID)],
                                        proximoCursor: comMaisPaginas ? "pagina-2" : nil)
    }

    func aceitarTermos(versao: String) async throws -> AceiteDeTermos { throw ErroDaApi(codigo: .respostaInvalida) }

    func chamarProfissional(_ pedido: PedidoChamada) async throws -> Chamada {
        pedidos.append(pedido)
        if let existente = porChave[pedido.chave] { return existente }
        let vagaID: UUID
        if let trabalho = pedido.trabalho {
            if let aberta = abertas.first(where: { $0.funcaoID == trabalho.funcaoID && $0.periodo == trabalho.periodo }) {
                throw ErroDaApi(codigo: .trabalhoJaAberto, detalhes: aberta.vagaID.uuidString.lowercased())
            }
            vagaID = UUID()
            abertas.append((trabalho.funcaoID, trabalho.periodo, vagaID))
        } else if let pelaVaga = pedido.vagaID {
            vagaID = pelaVaga
        } else {
            throw ErroDaApi(codigo: .naoEncontrado)
        }
        let chamada = Chamada(id: UUID(), vagaID: vagaID, profissionalID: pedido.profissionalID,
                              estabelecimentoID: pedido.estabelecimentoID, recado: pedido.recado,
                              expiraEm: Date(timeIntervalSince1970: 2_000_000_000), criadaEm: Date(timeIntervalSince1970: 1_900_000_000))
        porChave[pedido.chave] = chamada
        if perder.remove(pedido.profissionalID) != nil { throw ErroDaApi(codigo: .respostaInvalida) }
        guard segura else { return chamada }
        await withCheckedContinuation { esperandoChamada.append($0) }
        if perdeAoAbrir { throw ErroDaApi(codigo: .respostaInvalida) }
        return chamada
    }

    func paginaDeMinhasChamadas(estado: EstadoChamada?, cursor: String?, limite: Int?) async throws -> PaginaChamadas {
        PaginaChamadas(itens: abertas.map { aberta in
            ChamadaResumo(id: aberta.vagaID, vagaID: aberta.vagaID, profissionalID: DadosDaBusca.id(900),
                          estabelecimentoID: DadosDaBusca.id(901), estado: .aberta,
                          expiraEm: Date(timeIntervalSince1970: 2_000_000_000), criadaEm: Date(timeIntervalSince1970: 1_900_000_000),
                          funcao: Funcao(id: aberta.funcaoID, nome: "Garçom", categoria: "Salão"),
                          inicioEm: aberta.periodo.inicio, fimEm: aberta.periodo.fim, valorCentavos: DadosDaBusca.valor,
                          outraParte: DadosDaBusca.perfil)
        })
    }

    func detalheChamada(id: UUID) async throws -> ChamadaDetalhe {
        guard let aberta = abertas.first(where: { $0.vagaID == id }) else { throw ErroDaApi(codigo: .naoEncontrado) }
        return ChamadaDetalhe(id: id, vagaID: id, profissionalID: DadosDaBusca.id(900), estabelecimentoID: DadosDaBusca.id(901),
                              estado: .aberta, expiraEm: Date(timeIntervalSince1970: 2_000_000_000),
                              criadaEm: Date(timeIntervalSince1970: 1_900_000_000),
                              funcao: Funcao(id: aberta.funcaoID, nome: "Garçom", categoria: "Salão"),
                              inicioEm: aberta.periodo.inicio, fimEm: aberta.periodo.fim, valorCentavos: DadosDaBusca.valor,
                              outraParte: DadosDaBusca.perfil, regiaoAdministrativa: "Asa Sul", incluiRefeicao: false,
                              incluiTransporte: false, exigeMaterialProprio: false)
    }
}

private enum DadosDaBusca {
    static let garcom = UUID(uuidString: "F0000000-0000-0000-0000-000000000011")!
    static let bartender = UUID(uuidString: "F0000000-0000-0000-0000-000000000012")!
    static let valor = 20_000

    static func id(_ n: Int) -> UUID { UUID(uuidString: String(format: "D0000000-0000-0000-0000-%012d", n))! }

    static let perfil = PerfilPublico(id: id(900), tipo: .profissional, nome: "Pessoa 900",
                                      reputacao: Reputacao(positivas: 0, total: 0, taxaComparecimento: nil,
                                                           turnosConsiderados: 0, turnosRealizados: 0))

    static func pessoa(_ n: Int, funcaoID: UUID) -> CartaoProfissional {
        let funcao = Funcao(id: funcaoID, nome: funcaoID == garcom ? "Garçom" : "Bartender", categoria: "Salão")
        return CartaoProfissional(
            id: id(n), nome: "Pessoa \(n)",
            servico: ServicoNoPerfil(funcao: funcao, servico: ServicoOferecido(funcaoID: funcao.id, unidade: .diaria, valorCentavos: 15_000)),
            distanciaFaixa: .ate5km,
            reputacao: Reputacao(positivas: 1, total: 5, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0),
            disponivelNoHorario: nil)
    }
}

/// MENORES 2, 3 e 4 da revisão do #807 (Lince G) e a nota da função. A regra: a busca guarda um trabalho por serviço e
/// horário buscados; outro serviço ou outro horário abre a folha e a sua vaga; o mesmo serviço no mesmo horário nunca
/// abre a 2ª (a busca reenvia o guardado e, numa busca nova, o `409 trabalho_ja_aberto` do servidor aponta a vaga aberta).
@Suite("Busca: um trabalho por serviço e horário (MENORES 2 a 4 do #807)")
@MainActor
struct BuscaUmTrabalhoPorServicoEHorarioTests {
    private let casaID = UUID(uuidString: "C0000000-0000-0000-0000-000000000011")!
    private let sexta = Date(timeIntervalSince1970: 1_900_000_000)
    private var sabado: Date { sexta.addingTimeInterval(24 * 3600) }

    private func periodo(_ inicio: Date) throws -> Periodo { try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(4 * 3600)) }

    private func trabalho(_ funcaoID: UUID = DadosDaBusca.garcom, inicio: Date) throws -> PublicacaoVaga {
        PublicacaoVaga(
            estabelecimentoID: casaID, funcaoID: funcaoID, periodo: try periodo(inicio),
            local: "Rua Teste", regiaoAdministrativa: "Asa Sul", ponto: try Coordenada(latitude: -15.8, longitude: -47.9),
            valor: Dinheiro(centavos: DadosDaBusca.valor), posicoes: 1,
            inclusos: Inclusos(refeicao: false, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Casa", chave: UUID())
    }

    private func buscar(_ vm: BuscaDeProfissionaisViewModel, _ funcaoID: UUID = DadosDaBusca.garcom, em inicio: Date?) async throws {
        vm.funcaoID = funcaoID
        vm.horario = try inicio.map(periodo)
        await vm.buscar()
        try #require(vm.estado == .resultados)
    }

    private func enviada(_ resultado: ResultadoDaChamadaDaBusca?) -> Chamada? {
        if case let .enviada(chamada) = resultado { return chamada }
        return nil
    }

    // MARK: - MENOR 2: outro horário é outro trabalho

    @Test("Mesmo serviço, OUTRO horário buscado: abre a folha, e quem foi buscado para o sábado vai com o trabalho do sábado, numa vaga própria")
    func outroHorarioAbreAFolhaEUmaVagaPropria() async throws {
        let servidor = ServidorDaBusca()
        let vm = BuscaDeProfissionaisViewModel(fonte: servidor, estabelecimentoID: casaID)
        try await buscar(vm, em: sexta)
        let um = DadosDaBusca.id(1), dois = DadosDaBusca.id(2)
        vm.alternarSelecao(um)
        await vm.chamar(trabalho: try trabalho(inicio: sexta))
        let daSexta = try #require(enviada(vm.resultadosDaChamada[um])).vagaID

        try await buscar(vm, em: sabado)
        #expect(!vm.temEnvioRegistrado, "outro horário: a tela abre a folha")
        #expect(vm.trabalhoEnviado == nil)
        vm.alternarSelecao(dois)
        await vm.chamar(trabalho: try trabalho(inicio: sabado))

        let pedido = try #require(await servidor.pedidos.last)
        #expect(pedido.profissionalID == dois)
        let doHorario = try periodo(sabado)
        #expect(pedido.vagaID == nil && pedido.trabalho?.periodo == doHorario, "vai o trabalho do sábado")
        let doSabado = try #require(enviada(vm.resultadosDaChamada[dois])).vagaID
        #expect(doSabado != daSexta)
        #expect(await servidor.vagasCriadas().count == 2, "uma vaga por horário")
    }

    @Test("De volta ao horário da sexta na mesma tela: sem folha, reenvia o trabalho guardado da sexta pela vaga dela (sem 2ª vaga)")
    func voltarAoMesmoHorarioReusaAVaga() async throws {
        let servidor = ServidorDaBusca()
        let vm = BuscaDeProfissionaisViewModel(fonte: servidor, estabelecimentoID: casaID)
        let um = DadosDaBusca.id(1), dois = DadosDaBusca.id(2)
        try await buscar(vm, em: sexta)
        vm.alternarSelecao(um)
        let daSexta = try trabalho(inicio: sexta)
        await vm.chamar(trabalho: daSexta)
        let vagaDaSexta = try #require(enviada(vm.resultadosDaChamada[um])).vagaID
        try await buscar(vm, em: sabado)
        vm.alternarSelecao(um)
        await vm.chamar(trabalho: try trabalho(inicio: sabado))

        try await buscar(vm, em: sexta)
        #expect(vm.temEnvioRegistrado && vm.trabalhoEnviado == daSexta, "o mesmo serviço e horário: sem folha")
        vm.alternarSelecao(dois)
        await vm.reenviar()
        let pedido = try #require(await servidor.pedidos.last)
        #expect(pedido.profissionalID == dois && pedido.vagaID == vagaDaSexta && pedido.trabalho == nil)
        #expect(await servidor.vagasCriadas().count == 2)
    }

    @Test("Mesmo serviço e horário numa busca NOVA (fechar e abrir): o 409 trabalho_ja_aberto aponta a vaga aberta e a pessoa entra nela")
    func mesmoHorarioEmBuscaNovaCaiNo409() async throws {
        let servidor = ServidorDaBusca()
        let primeira = BuscaDeProfissionaisViewModel(fonte: servidor, estabelecimentoID: casaID)
        try await buscar(primeira, em: sexta)
        primeira.alternarSelecao(DadosDaBusca.id(1))
        await primeira.chamar(trabalho: try trabalho(inicio: sexta))
        let vaga = try #require(enviada(primeira.resultadosDaChamada[DadosDaBusca.id(1)])).vagaID

        let nova = BuscaDeProfissionaisViewModel(fonte: servidor, estabelecimentoID: casaID)
        try await buscar(nova, em: sexta)
        #expect(!nova.temEnvioRegistrado)
        nova.alternarSelecao(DadosDaBusca.id(2))
        await nova.chamar(trabalho: try trabalho(inicio: sexta))

        let pedidos = await servidor.pedidos
        #expect(pedidos.count == 3, "o trabalho (recusado pelo 409) e depois o vaga_id")
        #expect(pedidos.last?.vagaID == vaga && pedidos.last?.trabalho == nil)
        #expect(enviada(nova.resultadosDaChamada[DadosDaBusca.id(2)])?.vagaID == vaga)
        #expect(await servidor.vagasCriadas().count == 1, "sem 2ª vaga")
    }

    @Test("Fechar durante um envio que termina BEM: a próxima abertura começa uma busca limpa (nada pendente para guardar)")
    func fecharDuranteEnvioQueTerminaBemRecomeca() async throws {
        let servidor = ServidorDaBusca(segura: true, perdeAoAbrir: false)
        let casaID = casaID
        let guarda = GuardaDaBuscaDeProfissionais { BuscaDeProfissionaisViewModel(fonte: servidor, estabelecimentoID: casaID) }
        let vm = guarda.aoAbrir()
        try await buscar(vm, em: sexta)
        vm.alternarSelecao(DadosDaBusca.id(1))
        let doGarcom = try trabalho(inicio: sexta)
        let envio = Task { await vm.chamar(trabalho: doGarcom) }
        while await servidor.pedidos.isEmpty { try await Task.sleep(for: .milliseconds(5)) }
        guarda.aoFechar()
        #expect(guarda.viewModel === vm, "com o pedido em voo, o view model fica")
        await servidor.abrir()
        await envio.value
        #expect(!vm.enviando && !vm.travadoPeloIncerto)

        let reaberto = guarda.aoAbrir()
        #expect(reaberto !== vm, "nada pendente: a busca reaberta é nova")
        #expect(!reaberto.temEnvioRegistrado && reaberto.resultados.isEmpty)
    }

    @Test("Fechar durante um envio que termina INCERTO: a busca reaberta é a MESMA, travada, com a chave do pedido")
    func fecharDuranteEnvioQueTerminaIncertoGuarda() async throws {
        let servidor = ServidorDaBusca(segura: true, perdeAoAbrir: true)
        let casaID = casaID
        let guarda = GuardaDaBuscaDeProfissionais { BuscaDeProfissionaisViewModel(fonte: servidor, estabelecimentoID: casaID) }
        let vm = guarda.aoAbrir()
        try await buscar(vm, em: sexta)
        vm.alternarSelecao(DadosDaBusca.id(1))
        let doGarcom = try trabalho(inicio: sexta)
        let envio = Task { await vm.chamar(trabalho: doGarcom) }
        while await servidor.pedidos.isEmpty { try await Task.sleep(for: .milliseconds(5)) }
        guarda.aoFechar()
        await servidor.abrir()
        await envio.value
        #expect(vm.travadoPeloIncerto)

        let reaberto = guarda.aoAbrir()
        #expect(reaberto === vm && reaberto.travadoPeloIncerto)
        await reaberto.reenviar()
        let pedidos = await servidor.pedidos
        #expect(pedidos.count == 2 && pedidos[0].chave == pedidos[1].chave, "o reenvio usa a mesma chave")
        #expect(await servidor.vagasCriadas().count == 1)
    }

    // MARK: - MENOR 3: o incerto é da busca em que saiu

    @Test("Incerto pelo vaga_id do garçom e a MESMA pessoa na busca de bartender: ela vai chamada para bartender; de volta ao garçom, repete a chave antiga")
    func incertoDoGarcomNaoVazaParaOBartender() async throws {
        let servidor = ServidorDaBusca(perder: [DadosDaBusca.id(2)])
        let vm = BuscaDeProfissionaisViewModel(fonte: servidor, estabelecimentoID: casaID)
        let um = DadosDaBusca.id(1), dois = DadosDaBusca.id(2), tres = DadosDaBusca.id(3)
        try await buscar(vm, em: nil)
        vm.alternarSelecao(um)
        vm.alternarSelecao(dois)
        await vm.chamar(trabalho: try trabalho(inicio: sexta))
        let vagaDoGarcom = try #require(enviada(vm.resultadosDaChamada[um])).vagaID
        #expect(!vm.travadoPeloIncerto, "incerto pelo vaga_id não trava")
        let pedidoPerdido = try #require(await servidor.pedidos.last { $0.profissionalID == dois })

        try await buscar(vm, DadosDaBusca.bartender, em: nil)
        vm.alternarSelecao(dois)
        vm.alternarSelecao(tres)
        #expect(!vm.temEnvioRegistrado)
        let antes = await servidor.pedidos.count
        await vm.chamar(trabalho: try trabalho(DadosDaBusca.bartender, inicio: sexta))
        let rodada = Array(await servidor.pedidos.dropFirst(antes))
        let daDois = try #require(rodada.first { $0.profissionalID == dois })
        #expect(daDois.vagaID != vagaDoGarcom, "a pessoa 2 não repete o pedido da vaga do garçom")
        #expect(daDois.chave != pedidoPerdido.chave)
        #expect(daDois.trabalho?.funcaoID == DadosDaBusca.bartender, "ela leva o trabalho do bartender (é a 1ª da rodada)")
        let vagaDoBartender = try #require(enviada(vm.resultadosDaChamada[dois])).vagaID
        #expect(vagaDoBartender != vagaDoGarcom)

        try await buscar(vm, em: nil)
        vm.alternarSelecao(dois)
        await vm.reenviar()
        let deVolta = try #require(await servidor.pedidos.last)
        #expect(deVolta.profissionalID == dois && deVolta.chave == pedidoPerdido.chave, "a mesma chave descobre a chamada do garçom")
        #expect(enviada(vm.resultadosDaChamada[dois])?.vagaID == vagaDoGarcom)
        #expect(await servidor.vagasCriadas().count == 2)
    }

    // MARK: - MENOR 4: Chamar espera a página em voo

    @Test("Com a página seguinte em voo, Chamar fica desligado e nada sai; o cursor_invalido dela não tira ninguém da seleção")
    func chamarEsperaAPaginaComCursorInvalido() async throws {
        let servidor = ServidorDaBusca(comMaisPaginas: true)
        let vm = BuscaDeProfissionaisViewModel(fonte: servidor, estabelecimentoID: casaID)
        try await buscar(vm, em: sexta)
        let um = DadosDaBusca.id(1)
        vm.alternarSelecao(um)
        let pagina = Task { await vm.carregarMais() }
        while await servidor.paginasSeguintesPedidas == 0 { try await Task.sleep(for: .milliseconds(5)) }
        #expect(vm.carregandoMais && !vm.podeChamar)
        await vm.chamar(trabalho: try trabalho(inicio: sexta))
        #expect(await servidor.pedidos.isEmpty, "nada sai com a página em voo")

        await servidor.soltarPagina(com: ErroDaApi(codigo: .cursorInvalido))
        await pagina.value
        #expect(vm.selecionados == [um] && vm.podeChamar && !vm.travadoPeloIncerto)
        await vm.chamar(trabalho: try trabalho(inicio: sexta))
        #expect(await servidor.pedidos.count == 1)
    }

    @Test("Com a página seguinte em voo, Chamar fica desligado; o termos_pendentes dela limpa a lista sem deixar nada travado")
    func chamarEsperaAPaginaComTermosPendentes() async throws {
        let servidor = ServidorDaBusca(comMaisPaginas: true)
        let vm = BuscaDeProfissionaisViewModel(fonte: servidor, estabelecimentoID: casaID)
        try await buscar(vm, em: sexta)
        vm.alternarSelecao(DadosDaBusca.id(1))
        let pagina = Task { await vm.carregarMais() }
        while await servidor.paginasSeguintesPedidas == 0 { try await Task.sleep(for: .milliseconds(5)) }
        await vm.chamar(trabalho: try trabalho(inicio: sexta))
        #expect(await servidor.pedidos.isEmpty)

        await servidor.soltarPagina(com: ErroDaApi(codigo: .termosPendentes))
        await pagina.value
        #expect(vm.estado == .termosPendentes && !vm.travadoPeloIncerto && !vm.enviando)
    }

    // MARK: - Nota: o 1º envio é do serviço da busca

    @Test("O 1º envio com um trabalho de OUTRO serviço não sai (a busca é de garçom; o trabalho, de bartender)")
    func primeiroEnvioComOutraFuncaoNaoSai() async throws {
        let servidor = ServidorDaBusca()
        let vm = BuscaDeProfissionaisViewModel(fonte: servidor, estabelecimentoID: casaID)
        try await buscar(vm, em: sexta)
        vm.alternarSelecao(DadosDaBusca.id(1))
        await vm.chamar(trabalho: try trabalho(DadosDaBusca.bartender, inicio: sexta))
        #expect(await servidor.pedidos.isEmpty)
        #expect(!vm.temEnvioRegistrado && vm.resultadosDaChamada.isEmpty)
    }
}
