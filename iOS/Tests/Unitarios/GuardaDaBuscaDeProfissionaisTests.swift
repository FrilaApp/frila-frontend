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

    private struct FonteQueSemprePerdeAResposta: FonteDaBuscaDeProfissionais {
        let cartoes: [CartaoProfissional]
        func configuracaoDoApp() async throws -> ConfiguracaoApp {
            ConfiguracaoApp(versaoMinima: "1.0", versaoRecomendada: "1.0", mensagem: nil, urlDaLoja: URL(string: "https://example.com")!,
                            recursos: RecursosDoApp(chamadaDireta: true, buscaProfissionais: true))
        }
        func buscarProfissionais(_ filtro: FiltroBuscaProfissionais, cursor: String?, limite: Int?) async throws -> PaginaBuscaProfissionais {
            PaginaBuscaProfissionais(itens: cartoes, proximoCursor: nil)
        }
        func chamarProfissional(_ pedido: PedidoChamada) async throws -> Chamada { throw ErroDaApi(codigo: .respostaInvalida) }
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
        #expect(!guarda.naoPodeFechar)
        guarda.aoFechar()
        #expect(guarda.viewModel == nil)
        #expect(guarda.aoAbrir() !== primeiro)
    }

    @Test("Com envio incerto, fechar e abrir de novo devolve o MESMO view model: a trava, o trabalho e a chave seguem")
    func incertoSobreviveAoFechar() async throws {
        let guarda = guarda(FonteQueSemprePerdeAResposta(cartoes: [pessoa(1), pessoa(2)]))
        let vm = guarda.aoAbrir()
        vm.funcaoID = UUID(uuidString: "F0000000-0000-0000-0000-000000000001")!
        await vm.buscar()
        try #require(vm.resultados.count >= 2)
        vm.resultados.forEach { vm.alternarSelecao($0.id) }
        let primeiro = try trabalho()
        await vm.chamar(trabalho: primeiro)
        #expect(vm.travadoPeloIncerto)
        #expect(guarda.naoPodeFechar, "enquanto incerto, a folha não fecha (botão nem gesto)")

        guarda.aoFechar()
        let reaberto = guarda.aoAbrir()
        #expect(reaberto === vm)
        #expect(reaberto.travadoPeloIncerto)
        #expect(reaberto.trabalhoEnviado == primeiro)
        #expect(reaberto.selecionados.count == 2)
    }
}
