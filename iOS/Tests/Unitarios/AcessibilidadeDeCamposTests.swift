import Foundation
import Testing
@testable import FrilaApresentacao

@Suite("Acessibilidade dos campos: erro lido como valor")
struct AcessibilidadeDeCamposTests {
    @Test("Sem erro, o campo mantém o valor padrão do sistema")
    func semErro() {
        #expect(ErroLidoComoValor.valor(texto: "abc", erro: nil) == nil)
        #expect(ErroLidoComoValor.valor(texto: "abc", erro: "") == nil)
    }

    @Test("Com erro, o valor traz o texto digitado e a mensagem")
    func comErro() {
        let valor = ErroLidoComoValor.valor(texto: "123", erro: "Código inválido")
        #expect(valor?.contains("123") == true)
        #expect(valor?.contains("Código inválido") == true)
    }

    @Test("Com erro e campo vazio, o valor é só a mensagem")
    func comErroVazio() {
        let valor = ErroLidoComoValor.valor(texto: "", erro: "Obrigatório")
        #expect(valor?.hasSuffix("Obrigatório") == true)
        #expect(valor?.hasPrefix(",") == false)
    }
}
