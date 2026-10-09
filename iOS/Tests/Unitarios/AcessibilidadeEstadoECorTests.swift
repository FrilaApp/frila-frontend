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

    @Test("RespostaSimNao exibe checkmark apenas na opção selecionada")
    func respostaSimNaoCheckmark() {
        #expect(RespostaSimNao.exibeCheckmark(opcao: true, resposta: true))
        #expect(!RespostaSimNao.exibeCheckmark(opcao: false, resposta: true))
        #expect(!RespostaSimNao.exibeCheckmark(opcao: true, resposta: false))
        #expect(RespostaSimNao.exibeCheckmark(opcao: false, resposta: false))
        #expect(!RespostaSimNao.exibeCheckmark(opcao: true, resposta: nil))
        #expect(!RespostaSimNao.exibeCheckmark(opcao: false, resposta: nil))
    }

    @Test("AvisoFrila inclui prefixo no rótulo de acessibilidade conforme o tom")
    func avisoFrilaRotuloPorTom() {
        let texto = "Mensagem de teste"
        #expect(AvisoFrila.rotuloAcessibilidade(texto: texto, tom: .alerta) == "Alerta: \(texto)")
        #expect(AvisoFrila.rotuloAcessibilidade(texto: texto, tom: .erro) == "Erro: \(texto)")
        #expect(AvisoFrila.rotuloAcessibilidade(texto: texto, tom: .informativo) == texto)
    @Test("FrilaMovimento.animacao respeita preferência de Reduzir Movimento (71.4)")
    func animacaoRespeitaReduzirMovimento() {
        #expect(FrilaMovimento.animacao(reduzir: true) == nil)
        #expect(FrilaMovimento.animacao(.easeInOut(duration: 0.2), reduzir: true) == nil)
        #expect(FrilaMovimento.animacao(reduzir: false) != nil)
        #expect(FrilaMovimento.animacao(.easeInOut(duration: 0.2), reduzir: false) != nil)
    }
}
