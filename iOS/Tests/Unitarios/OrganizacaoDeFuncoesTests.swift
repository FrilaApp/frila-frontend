import Foundation
@testable import FrilaApresentacao
import FrilaDominio
import Testing

@Suite("Lista de funções do profissional: agrupamento, busca e resumo")
struct OrganizacaoDeFuncoesTests {
    private func funcao(_ numero: Int, _ nome: String, _ categoria: String) -> Funcao {
        Funcao(id: UUID(uuidString: String(format: "20000000-0000-0000-0000-%012d", numero))!, nome: nome, categoria: categoria)
    }

    private var catalogo: [Funcao] {
        [
            funcao(1, "Garçom", "Salão"),
            funcao(2, "Bartender", "Bar"),
            funcao(3, "Cumim", "salao "),
            funcao(4, "Barista", "Bar"),
            funcao(5, "Zelador", "Limpeza"),
            funcao(6, "Ajudante", "")
        ]
    }

    @Test("agrupa pela categoria sem diferença de caixa, acento ou espaço, e ordena categorias e funções")
    func agrupaEOrdena() {
        let grupos = OrganizacaoDeFuncoes.agrupar(catalogo, categoriaVazia: "Outras funções")
        #expect(grupos.map(\.categoria) == ["Bar", "Limpeza", "Salão", "Outras funções"])
        #expect(grupos[0].funcoes.map(\.nome) == ["Barista", "Bartender"])
        #expect(grupos[2].funcoes.map(\.nome) == ["Cumim", "Garçom"])
    }

    @Test("a categoria vazia fica por último, em Outras funções")
    func categoriaVaziaNoFim() {
        let grupos = OrganizacaoDeFuncoes.agrupar(catalogo, categoriaVazia: "Outras funções")
        #expect(grupos.last?.categoria == "Outras funções")
        #expect(grupos.last?.funcoes.map(\.nome) == ["Ajudante"])
    }

    @Test("a busca ignora acento e caixa e mantém só as categorias com resultado")
    func buscaSemAcentoNemCaixa() {
        let grupos = OrganizacaoDeFuncoes.agrupar(catalogo, busca: "  GARCOM ", categoriaVazia: "Outras funções")
        #expect(grupos.count == 1)
        #expect(grupos.first?.categoria == "Salão")
        #expect(grupos.first?.funcoes.map(\.nome) == ["Garçom"])
    }

    @Test("a busca sem resultado devolve nenhum grupo")
    func buscaSemResultado() {
        #expect(OrganizacaoDeFuncoes.agrupar(catalogo, busca: "astronauta", categoriaVazia: "Outras funções").isEmpty)
    }

    @Test("funções com o mesmo nome continuam distintas: a identidade é o UUID")
    func mesmoNomeNaoFunde() {
        let duas = [funcao(10, "Auxiliar", "Salão"), funcao(11, "Auxiliar", "Cozinha")]
        let grupos = OrganizacaoDeFuncoes.agrupar(duas, categoriaVazia: "Outras funções")
        #expect(grupos.count == 2)
        #expect(grupos.flatMap(\.funcoes).count == 2)
    }

    @Test("só conta como escolhida a função que está no catálogo ativo")
    func escolhidasVisiveisIgnoramIdsForaDoCatalogo() {
        let fora = UUID()
        let escolhidas = OrganizacaoDeFuncoes.escolhidasVisiveis(
            catalogo,
            selecionadas: [catalogo[0].id, catalogo[1].id, fora]
        )
        #expect(escolhidas.map(\.nome) == ["Bartender", "Garçom"])
    }

    @Test("o resumo mostra as duas primeiras em ordem alfabética e quantas ficam de fora")
    func resumoDoCartaoFechado() {
        let tres = OrganizacaoDeFuncoes.escolhidasVisiveis(catalogo, selecionadas: [catalogo[0].id, catalogo[1].id, catalogo[3].id])
        #expect(OrganizacaoDeFuncoes.resumo(tres) == "Barista, Bartender e mais 1")
        #expect(OrganizacaoDeFuncoes.resumo(Array(tres.prefix(2))) == "Barista, Bartender")
        #expect(OrganizacaoDeFuncoes.resumo([]) == nil)
    }

    @Test("o contador usa singular e plural")
    func contador() {
        #expect(TextosDoProfissional.Perfil.funcoesSelecionadas(1) == "1 função selecionada")
        #expect(TextosDoProfissional.Perfil.funcoesSelecionadas(3) == "3 funções selecionadas")
    }
}
