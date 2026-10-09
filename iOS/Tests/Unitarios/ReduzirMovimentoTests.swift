import FrilaApresentacao
import SwiftUI
import Testing

/// Critério 71.4 do cartão #71: Com Reduzir Movimento ligado, nenhuma animação de deslocamento.
/// Ponto único de decisão FrilaMovimento.animacao(_:reduzir:).
@Suite("Reduzir Movimento (#71.4)")
struct ReduzirMovimentoTests {

    @Test("Com reduzir ligado, retorno é nil para qualquer animação")
    func animacaoComReduzirLigadoRetornaNil() {
        #expect(FrilaMovimento.animacao(reduzir: true) == nil)
        #expect(FrilaMovimento.animacao(.easeInOut(duration: 0.2), reduzir: true) == nil)
        #expect(FrilaMovimento.animacao(.linear, reduzir: true) == nil)
        #expect(FrilaMovimento.animacao(.bouncy, reduzir: true) == nil)
    }

    @Test("Com reduzir desligado, retorno devolve a animação solicitada")
    func animacaoComReduzirDesligadoRetornaNaoNulo() {
        #expect(FrilaMovimento.animacao(reduzir: false) != nil)
        #expect(FrilaMovimento.animacao(.easeInOut(duration: 0.2), reduzir: false) != nil)
        #expect(FrilaMovimento.animacao(.linear, reduzir: false) != nil)
        #expect(FrilaMovimento.animacao(.bouncy, reduzir: false) != nil)
    }
}
