import Foundation
@testable import FrilaApresentacao
import Testing
import UIKit

@Suite("Anúncios de avisos e erros (#71)")
struct AnunciosDeAcessibilidadeTests {
    @Test("Erro e alerta interrompem; informação aguarda", arguments: [AvisoFrila.Tom.erro, .alerta, .informativo])
    func prioridade(_ tom: AvisoFrila.Tom) {
        let anuncio = AnuncioDeAcessibilidade(texto: "Mensagem", tom: tom)
        #expect(anuncio.mensagem.accessibilitySpeechAnnouncementPriority == (tom == .informativo ? .low : .high))
        #expect(String(anuncio.mensagem.characters) == "Mensagem")
    }

    @Test("Aparecer anuncia uma vez, inclusive após redesenhos")
    func aparicao() {
        var controle = ControleDoAnuncio()
        let anuncio = AnuncioDeAcessibilidade(texto: "Confira os números.", tom: .erro)
        #expect(controle.atualizar(anuncio) == nil)
        #expect(controle.aparecer(anuncio) == anuncio)
        #expect(controle.atualizar(anuncio) == nil)
        #expect(controle.aparecer(anuncio) == nil)
        controle.desaparecer()
        #expect(controle.atualizar(anuncio) == nil)
        #expect(controle.aparecer(anuncio) == anuncio)
    }

    @Test("Erro que surge, muda e é retirado permite novo anúncio")
    func erroDeCampo() {
        var controle = ControleDoAnuncio()
        let primeiro = AnuncioDeAcessibilidade(texto: "Campo obrigatório", tom: .erro)
        let segundo = AnuncioDeAcessibilidade(texto: "Campo inválido", tom: .erro)
        #expect(controle.aparecer(nil) == nil)
        #expect(controle.atualizar(primeiro) == primeiro)
        #expect(controle.atualizar(primeiro) == nil)
        #expect(controle.atualizar(segundo) == segundo)
        #expect(controle.atualizar(nil) == nil)
        #expect(controle.atualizar(segundo) == segundo)
    }

    @Test("Mensagem vazia não é falada", arguments: ["", " \n\t"])
    func vazio(_ texto: String) {
        var controle = ControleDoAnuncio()
        #expect(controle.aparecer(.init(texto: texto, tom: .erro)) == nil)
    }

    @Test("Mudança de tom mantém o texto e atualiza a prioridade")
    func mudancaDeTom() {
        var controle = ControleDoAnuncio()
        let informativo = AnuncioDeAcessibilidade(texto: "Aguarde", tom: .informativo)
        let alerta = AnuncioDeAcessibilidade(texto: "Aguarde", tom: .alerta)
        #expect(controle.aparecer(informativo) == informativo)
        #expect(controle.atualizar(alerta) == alerta)
        #expect(controle.atualizar(alerta) == nil)
    }

    @Test("Localização e interpolação são resolvidas sem sintaxe Markdown no anúncio")
    func localizado() {
        let quantidade = 3
        let conteudo = ConteudoDoAnuncio.localizado("**Confira** os \(quantidade) números.")
        let resolvido = conteudo.resolver(locale: Locale(identifier: "pt_BR"))
        #expect(String(resolvido.characters) == "Confira os 3 números.")
        #expect(resolvido.runs.first?.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)
    }

    @Test("Texto literal preserva exatamente o que a tela exibe")
    func literal() {
        let texto = "Erro **literal**.\nConfira os números."
        let resolvido = ConteudoDoAnuncio.literal(texto).resolver(locale: Locale(identifier: "pt_BR"))
        #expect(String(resolvido.characters) == texto)
        #expect(resolvido.runs.first?.inlinePresentationIntent == nil)
    }
}
