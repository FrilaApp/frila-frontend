import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

/// Dados do teste fora da suíte (que é do MainActor), para a fonte falsa poder usá-los.
private enum Dados {
    static let garcom = UUID(uuidString: "F0000000-0000-0000-0000-000000000001")!
    static let bartender = UUID(uuidString: "F0000000-0000-0000-0000-000000000002")!

    static func pessoa(_ n: Int, funcaoID: UUID) -> CartaoProfissional {
        let funcao = Funcao(id: funcaoID, nome: funcaoID == garcom ? "Garçom" : "Bartender", categoria: "Salão")
        return CartaoProfissional(
            id: UUID(uuidString: String(format: "A0000000-0000-0000-0000-%012d", n))!, nome: "Pessoa \(n)",
            servico: ServicoNoPerfil(funcao: funcao, servico: ServicoOferecido(funcaoID: funcao.id, unidade: .diaria, valorCentavos: 15_000)),
            distanciaFaixa: .ate5km, reputacao: Reputacao(positivas: 1, total: 5, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0),
            disponivelNoHorario: nil)
    }
}

/// Os dois furos de 2ª vaga do Lince P2 no #790 (issue #798), com o repro dele invertido: fechar ou desmarcar durante o
/// 1º envio e buscar outro serviço depois do envio. DINHEIRO: nenhum caminho cria 2ª vaga para o mesmo trabalho.
@Suite("Busca de profissionais: sem 2ª vaga com envio em curso ou com outro serviço (#798)")
@MainActor
struct BuscaDeProfissionaisSemSegundaVagaTests {
    private let casaID = UUID(uuidString: "C0000000-0000-0000-0000-000000000001")!
    private let inicio = Date(timeIntervalSince1970: 1_900_000_000)

    private func trabalho(funcaoID: UUID, inicio: Date) throws -> PublicacaoVaga {
        PublicacaoVaga(
            estabelecimentoID: casaID, funcaoID: funcaoID,
            periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(4 * 3600)),
            local: "Rua Teste", regiaoAdministrativa: "Asa Sul", ponto: try Coordenada(latitude: -15.8, longitude: -47.9),
            valor: Dinheiro(centavos: 20_000), posicoes: 1, inclusos: Inclusos(refeicao: false, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Casa", chave: UUID())
    }

    /// O "servidor" do teste: idempotente pela chave, como o backend. Se mandado, segura a resposta até `abrir()` e então
    /// a perde (o servidor criou a chamada e a vaga, e a rede ruim levou a resposta).
    private actor Servidor {
        private(set) var pedidos: [PedidoChamada] = []
        private var segura: Bool
        private var esperando: [CheckedContinuation<Void, Never>] = []
        private var chamadasPorChave: [UUID: Chamada] = [:]

        init(segura: Bool) { self.segura = segura }

        /// As vagas diretas que o servidor criou (uma por pedido que levou o trabalho completo).
        func vagasCriadas() -> Set<UUID> { Set(chamadasPorChave.values.map(\.vagaID)) }

        func abrir() {
            segura = false
            esperando.forEach { $0.resume() }
            esperando = []
        }

        func chamar(_ pedido: PedidoChamada) async throws -> Chamada {
            pedidos.append(pedido)
            if let existente = chamadasPorChave[pedido.chave] { return existente }
            let chamada = Chamada(id: UUID(), vagaID: pedido.vagaID ?? UUID(), profissionalID: pedido.profissionalID,
                                  estabelecimentoID: pedido.estabelecimentoID, recado: pedido.recado,
                                  expiraEm: Date(timeIntervalSince1970: 2_000_000_000), criadaEm: Date(timeIntervalSince1970: 1_900_000_000))
            chamadasPorChave[pedido.chave] = chamada
            guard segura else { return chamada }
            await withCheckedContinuation { esperando.append($0) }
            throw ErroDaApi(codigo: .respostaInvalida)
        }
    }

    /// Garçom: pessoas 1 e 2. Bartender: pessoas 3 e 4. Sem o 409 da 0.2.95 (as leituras dos termos ficam no padrão que falha).
    private struct Fonte: FonteDaBuscaDeProfissionais {
        let servidor: Servidor
        func configuracaoDoApp() async throws -> ConfiguracaoApp {
            ConfiguracaoApp(versaoMinima: "1.0", versaoRecomendada: "1.0", mensagem: nil, urlDaLoja: URL(string: "https://example.com")!,
                            recursos: RecursosDoApp(chamadaDireta: true, buscaProfissionais: true))
        }
        func buscarProfissionais(_ filtro: FiltroBuscaProfissionais, cursor: String?, limite: Int?) async throws -> PaginaBuscaProfissionais {
            let base = filtro.funcaoID == Dados.garcom ? 1 : 3
            return PaginaBuscaProfissionais(itens: [Dados.pessoa(base, funcaoID: filtro.funcaoID),
                                                    Dados.pessoa(base + 1, funcaoID: filtro.funcaoID)],
                                            proximoCursor: nil)
        }
        func chamarProfissional(_ pedido: PedidoChamada) async throws -> Chamada { try await servidor.chamar(pedido) }
        func aceitarTermos(versao: String) async throws -> AceiteDeTermos { throw ErroDaApi(codigo: .respostaInvalida) }
    }

    /// Espera o 1º pedido chegar ao servidor (a resposta fica presa até `abrir()`).
    private func esperarOPedidoEmVoo(_ servidor: Servidor) async throws {
        while await servidor.pedidos.isEmpty { try await Task.sleep(for: .milliseconds(5)) }
    }

    @Test("Fechar a busca com o 1º envio EM CURSO: a guarda segura o view model e o Tentar de novo resolve com 1 vaga só",
          .timeLimit(.minutes(1)))
    func fecharComOPrimeiroEnvioEmCurso() async throws {
        let servidor = Servidor(segura: true)
        let fonte = Fonte(servidor: servidor)
        let casaID = casaID
        let guarda = GuardaDaBuscaDeProfissionais { BuscaDeProfissionaisViewModel(fonte: fonte, estabelecimentoID: casaID) }
        let vm = guarda.aoAbrir()
        vm.funcaoID = Dados.garcom
        await vm.buscar()
        let a = try #require(vm.resultados.first).id
        let b = try #require(vm.resultados.last).id
        try #require(a != b)
        vm.alternarSelecao(a)
        vm.alternarSelecao(b)

        // "Enviar chamadas" na folha: o pedido sai e a resposta demora (rede ruim).
        let primeiro = try trabalho(funcaoID: Dados.garcom, inicio: inicio)
        let envio = Task { await vm.chamar(trabalho: primeiro) }
        try await esperarOPedidoEmVoo(servidor)
        #expect(vm.enviando)
        #expect(!vm.travadoPeloIncerto, "com o pedido em voo ainda não há incerto")

        // A pessoa toca em "Fechar" (ou arrasta a folha) enquanto envia: onDismiss → aoFechar().
        guarda.aoFechar()
        #expect(guarda.viewModel === vm, "com um envio em curso a guarda segura o view model")

        // A resposta se perde: a trava nasce no view model que a guarda segura.
        await servidor.abrir()
        await envio.value
        #expect(vm.travadoPeloIncerto)

        // Reaberta, a busca é a mesma: a trava, o trabalho do 1º envio e as chaves seguem.
        let reaberto = guarda.aoAbrir()
        #expect(reaberto === vm)
        #expect(reaberto.travadoPeloIncerto && reaberto.temEnvioRegistrado)

        // "Tentar de novo": o incerto vai primeiro, com a mesma chave (o servidor devolve a chamada já criada), e a outra
        // pessoa entra na mesma vaga pelo vaga_id.
        await reaberto.reenviar()
        let pedidos = await servidor.pedidos
        try #require(pedidos.count == 3)
        let doIncerto = try #require(pedidos.first)
        let repetido = try #require(pedidos.dropFirst().first)
        let daOutra = try #require(pedidos.last)
        #expect(doIncerto.profissionalID == a && repetido == doIncerto, "mesma pessoa, mesmo trabalho e mesma chave")
        guard case let .enviada(chamadaDoIncerto) = reaberto.resultadosDaChamada[a] else {
            Issue.record("o Tentar de novo devia resolver o incerto")
            return
        }
        #expect(daOutra.profissionalID == b && daOutra.trabalho == nil && daOutra.vagaID == chamadaDoIncerto.vagaID)
        #expect(await servidor.vagasCriadas().count == 1, "1 vaga só para o trabalho")
        #expect(!reaberto.travadoPeloIncerto)
    }

    @Test("Durante o 1º envio a seleção não muda: o Tentar de novo resolve o incerto primeiro e a outra pessoa entra na mesma vaga",
          .timeLimit(.minutes(1)))
    func desmarcarDuranteOEnvio() async throws {
        let servidor = Servidor(segura: true)
        let vm = BuscaDeProfissionaisViewModel(fonte: Fonte(servidor: servidor), estabelecimentoID: casaID)
        vm.funcaoID = Dados.garcom
        await vm.buscar()
        let a = try #require(vm.resultados.first).id
        let b = try #require(vm.resultados.last).id
        try #require(a != b)
        vm.alternarSelecao(a)
        vm.alternarSelecao(b)
        let primeiro = try trabalho(funcaoID: Dados.garcom, inicio: inicio)
        let envio = Task { await vm.chamar(trabalho: primeiro) }
        try await esperarOPedidoEmVoo(servidor)
        #expect(vm.enviando)

        // A caixa de seleção fica barrada enquanto envia: desmarcar quem está em voo (ou o outro) não muda nada.
        #expect(!vm.alternarSelecao(a), "durante o envio a seleção não muda")
        #expect(!vm.alternarSelecao(b))
        #expect(vm.selecionados == [a, b])
        await servidor.abrir()
        await envio.value
        #expect(vm.travadoPeloIncerto)
        #expect(vm.selecionados == [a, b])

        // "Tentar de novo": o incerto está na seleção e vai primeiro, com a mesma chave; a outra pessoa entra pela vaga dele.
        await vm.reenviar()
        let pedidos = await servidor.pedidos
        try #require(pedidos.count == 3)
        let doIncerto = try #require(pedidos.first)
        let repetido = try #require(pedidos.dropFirst().first)
        let daOutra = try #require(pedidos.last)
        #expect(doIncerto.profissionalID == a && repetido == doIncerto, "mesma pessoa, mesmo trabalho e mesma chave")
        guard case let .enviada(chamadaDoIncerto) = vm.resultadosDaChamada[a] else {
            Issue.record("o Tentar de novo devia resolver o incerto")
            return
        }
        #expect(daOutra.profissionalID == b && daOutra.trabalho == nil && daOutra.vagaID == chamadaDoIncerto.vagaID)
        #expect(await servidor.vagasCriadas().count == 1, "1 vaga só para o trabalho")

        // Resolvido, a trava sai: a seleção e a busca voltam.
        #expect(!vm.travadoPeloIncerto && vm.podeBuscar)
    }

    @Test("Depois do envio do garçom, buscar bartender abre a folha e vai com a função dele; de volta ao garçom, entra na vaga do garçom",
          .timeLimit(.minutes(1)))
    func outroServicoNaoLevaOTrabalhoDoPrimeiro() async throws {
        let servidor = Servidor(segura: false)
        let vm = BuscaDeProfissionaisViewModel(fonte: Fonte(servidor: servidor), estabelecimentoID: casaID)
        vm.funcaoID = Dados.garcom
        await vm.buscar()
        let garcomEscolhido = try #require(vm.resultados.first).id
        vm.alternarSelecao(garcomEscolhido)
        let doGarcom = try trabalho(funcaoID: Dados.garcom, inicio: inicio)
        await vm.chamar(trabalho: doGarcom, recado: "Recado do garçom")
        guard case let .enviada(chamadaDoGarcom) = vm.resultadosDaChamada[garcomEscolhido] else {
            Issue.record("a chamada do garçom devia ter saído")
            return
        }
        #expect(vm.temEnvioRegistrado && vm.trabalhoEnviado == doGarcom)

        // A casa também precisa de um bartender: troca o serviço e busca de novo.
        vm.funcaoID = Dados.bartender
        await vm.buscar()
        let bartenderEscolhido = try #require(vm.resultados.first).id
        #expect(bartenderEscolhido != garcomEscolhido)
        vm.alternarSelecao(bartenderEscolhido)

        // O bartender ainda não teve envio: a tela abre a folha (não reenvia o trabalho do garçom).
        #expect(!vm.temEnvioRegistrado && vm.trabalhoEnviado == nil && vm.podeChamar)
        await vm.reenviar()
        #expect(await servidor.pedidos.count == 1, "sem envio do bartender, reenviar não manda nada")

        // A folha manda o trabalho do bartender, com a função dele e chave nova: é outro trabalho, outra vaga.
        let doBartender = try trabalho(funcaoID: Dados.bartender, inicio: inicio)
        await vm.chamar(trabalho: doBartender, recado: "Recado do bartender")
        var pedidos = await servidor.pedidos
        try #require(pedidos.count == 2)
        let pedidoDoBartender = try #require(pedidos.last)
        #expect(pedidoDoBartender.profissionalID == bartenderEscolhido && pedidoDoBartender.vagaID == nil)
        #expect(pedidoDoBartender.trabalho?.funcaoID == Dados.bartender)
        #expect(vm.trabalhoEnviado?.funcaoID == Dados.bartender && vm.recadoEnviado == "Recado do bartender")

        // De volta ao garçom: o serviço já teve envio, então o reenvio repete o trabalho do garçom e entra na vaga dele.
        vm.funcaoID = Dados.garcom
        await vm.buscar()
        let outroGarcom = try #require(vm.resultados.last).id
        #expect(outroGarcom != garcomEscolhido)
        vm.alternarSelecao(outroGarcom)
        #expect(vm.temEnvioRegistrado && vm.trabalhoEnviado == doGarcom && vm.recadoEnviado == "Recado do garçom")
        await vm.reenviar()
        pedidos = await servidor.pedidos
        try #require(pedidos.count == 3)
        let doOutroGarcom = try #require(pedidos.last)
        #expect(doOutroGarcom.profissionalID == outroGarcom && doOutroGarcom.trabalho == nil)
        #expect(doOutroGarcom.vagaID == chamadaDoGarcom.vagaID && doOutroGarcom.recado == "Recado do garçom")
        #expect(await servidor.vagasCriadas().count == 2, "uma vaga por serviço, nenhuma 2ª para o mesmo trabalho")
    }

    @Test("A folha usa o serviço da busca feita: trocar o seletor sem Buscar não muda o serviço nem o envio registrado")
    func folhaUsaOServicoDaBuscaFeita() async throws {
        let servidor = Servidor(segura: false)
        let vm = BuscaDeProfissionaisViewModel(fonte: Fonte(servidor: servidor), estabelecimentoID: casaID)
        #expect(vm.funcaoDaBusca == nil, "sem busca feita não há serviço para a folha")
        vm.funcaoID = Dados.garcom
        await vm.buscar()
        vm.alternarSelecao(try #require(vm.resultados.first).id)
        await vm.chamar(trabalho: try trabalho(funcaoID: Dados.garcom, inicio: inicio))

        // O seletor muda para bartender, sem Buscar: a lista ainda é a do garçom, e é dele o serviço da folha e do reenvio.
        vm.funcaoID = Dados.bartender
        #expect(vm.funcaoDaBusca == Dados.garcom)
        #expect(vm.temEnvioRegistrado && vm.trabalhoEnviado?.funcaoID == Dados.garcom)
    }
}
