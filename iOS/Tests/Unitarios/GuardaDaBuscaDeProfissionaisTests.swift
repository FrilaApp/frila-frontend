import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

/// IMPORTANTE 2 do Lince N no #790: a folha da busca é recriada a cada abertura, e o view model (com a trava do envio
/// incerto) precisa sobreviver a fechar e abrir de novo. A guarda decide quando ele fica.
@Suite("Busca de profissionais: guarda do view model fora da folha")
@MainActor
struct GuardaDaBuscaDeProfissionaisTests {
    private let casaID = UUID(uuidString: "C0000000-0000-0000-0000-000000000001")!
    private let inicio = Date(timeIntervalSince1970: 1_900_000_000)

    private func trabalho() throws -> PublicacaoVaga {
        let funcaoID = UUID(uuidString: "F0000000-0000-0000-0000-000000000001")!
        return PublicacaoVaga(
            estabelecimentoID: casaID, funcaoID: funcaoID,
            periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(4 * 3600)),
            local: "Rua Teste", regiaoAdministrativa: "Asa Sul", ponto: try Coordenada(latitude: -15.8, longitude: -47.9),
            valor: Dinheiro(centavos: 20_000), posicoes: 1, inclusos: Inclusos(refeicao: false, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Casa", chave: UUID())
    }

    private func pessoa(_ n: Int) -> CartaoProfissional {
        let funcao = Funcao(id: UUID(uuidString: "F0000000-0000-0000-0000-000000000001")!, nome: "Garçom", categoria: "Salão")
        return CartaoProfissional(
            id: UUID(uuidString: String(format: "A0000000-0000-0000-0000-%012d", n))!, nome: "Pessoa \(n)",
            servico: ServicoNoPerfil(funcao: funcao, servico: ServicoOferecido(funcaoID: funcao.id, unidade: .diaria, valorCentavos: 15_000)),
            distanciaFaixa: .ate5km, reputacao: Reputacao(positivas: 1, total: 5, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0),
            disponivelNoHorario: nil)
    }

    /// Os pedidos que chegaram à fonte, na ordem: é por eles que o teste vê se a chave de cada um se repetiu.
    private actor RegistroDePedidos {
        private(set) var pedidos: [PedidoChamada] = []
        func guardar(_ pedido: PedidoChamada) { pedidos.append(pedido) }
    }

    private struct FonteQueSemprePerdeAResposta: FonteDaBuscaDeProfissionais {
        let cartoes: [CartaoProfissional]
        let registro = RegistroDePedidos()
        func configuracaoDoApp() async throws -> ConfiguracaoApp {
            ConfiguracaoApp(versaoMinima: "1.0", versaoRecomendada: "1.0", mensagem: nil, urlDaLoja: URL(string: "https://example.com")!,
                            recursos: RecursosDoApp(chamadaDireta: true, buscaProfissionais: true))
        }
        func buscarProfissionais(_ filtro: FiltroBuscaProfissionais, cursor: String?, limite: Int?) async throws -> PaginaBuscaProfissionais {
            PaginaBuscaProfissionais(itens: cartoes, proximoCursor: nil)
        }
        func chamarProfissional(_ pedido: PedidoChamada) async throws -> Chamada {
            await registro.guardar(pedido)
            throw ErroDaApi(codigo: .respostaInvalida)
        }
    }

    private func guarda(_ fonte: any FonteDaBuscaDeProfissionais) -> GuardaDaBuscaDeProfissionais {
        let casaID = casaID
        return GuardaDaBuscaDeProfissionais { BuscaDeProfissionaisViewModel(fonte: fonte, estabelecimentoID: casaID) }
    }

    @Test("Sem envio incerto, fechar descarta o view model e a próxima abertura começa limpa")
    func semIncertoRecomeca() async throws {
        let guarda = guarda(FonteQueSemprePerdeAResposta(cartoes: [pessoa(1)]))
        let primeiro = guarda.aoAbrir()
        #expect(guarda.aoAbrir() === primeiro, "abrir de novo sem fechar devolve o mesmo")
        guarda.aoFechar()
        #expect(guarda.viewModel == nil)
        #expect(guarda.aoAbrir() !== primeiro)
    }

    @Test("Com envio incerto, fechar (livre) e abrir de novo devolve o MESMO view model: a trava, o trabalho e a chave seguem")
    func incertoSobreviveAoFechar() async throws {
        let fonte = FonteQueSemprePerdeAResposta(cartoes: [pessoa(1), pessoa(2)])
        let guarda = guarda(fonte)
        let vm = guarda.aoAbrir()
        vm.funcaoID = UUID(uuidString: "F0000000-0000-0000-0000-000000000001")!
        await vm.buscar()
        try #require(vm.resultados.count >= 2)
        vm.resultados.forEach { vm.alternarSelecao($0.id) }
        let primeiro = try trabalho()
        await vm.chamar(trabalho: primeiro)
        #expect(vm.travadoPeloIncerto)
        // O pedido que levou o trabalho ficou incerto: a rodada para nele (o 2º nem sai).
        let primeiraRodada = await fonte.registro.pedidos
        try #require(primeiraRodada.count == 1)

        // Fechar é livre com o envio incerto: a guarda segura o view model em vez de a folha prender a pessoa.
        guarda.aoFechar()
        #expect(guarda.viewModel === vm)
        let reaberto = guarda.aoAbrir()
        #expect(reaberto === vm)
        #expect(reaberto.travadoPeloIncerto, "reaberta, a busca mostra o pendente com Tentar de novo")
        #expect(reaberto.trabalhoEnviado == primeiro)
        #expect(reaberto.selecionados.count == 2)

        // O "Tentar de novo" depois de reabrir repete o MESMO pedido, com a mesma chave (o servidor devolve a vaga, se
        // a criou): uma chave nova abriria uma 2ª vaga para o mesmo trabalho.
        await reaberto.reenviar()
        let segundaRodada = Array(await fonte.registro.pedidos.dropFirst(primeiraRodada.count))
        #expect(segundaRodada == primeiraRodada, "mesma pessoa, mesmo trabalho e mesma chave")
    }
}
