import FrilaApresentacao
import FrilaDominio
import SwiftUI
import Testing

/// Critério 4 do #71: Nenhum estado comunicado exclusivamente por cor.
/// Garante que componentes de estado sempre exponham descrição textual ou valor de acessibilidade,
/// além da representação visual por ícone ou forma.
@Suite("Acessibilidade de estados e cores (#71)")
struct AcessibilidadeEstadoECorTests {

    @Test("FiltroPill comunica seleção por texto além de cor")
    func filtroPillValorAcessibilidade() {
        #expect(FiltroPill.valorAcessibilidade(selecionado: true) == "filtro ativo")
        #expect(FiltroPill.valorAcessibilidade(selecionado: false).isEmpty)
    }

    @Test("SeloReputacao expõe texto descritivo para ambos os estados")
    func seloReputacaoDescricaoTextual() {
        let comHistorico = Reputacao(
            positivas: 18,
            total: 20,
            taxaComparecimento: 0.95,
            turnosConsiderados: 20,
            turnosRealizados: 19
        )
        let semHistorico = Reputacao(
            positivas: 0,
            total: 0,
            taxaComparecimento: nil,
            turnosConsiderados: 0,
            turnosRealizados: 0
        )

        let descComHistorico = SeloReputacao.descricao(comHistorico)
        let descSemHistorico = SeloReputacao.descricao(semHistorico)

        #expect(!descComHistorico.isEmpty)
        #expect(descComHistorico.contains("18 de 20 chamariam de novo"))

        #expect(!descSemHistorico.isEmpty)
        #expect(descSemHistorico == "Sem histórico")

        #expect(SeloReputacao.descricaoComparecimento(comHistorico)?.contains("Compareceu a 19 de 20 turnos") == true)
        #expect(SeloReputacao.descricaoComparecimento(semHistorico) == nil)
    }
}
