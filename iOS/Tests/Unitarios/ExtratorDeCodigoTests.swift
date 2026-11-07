import Foundation
@testable import FrilaApresentacao
import FrilaDados
import Testing

struct ExtratorDeCodigoTests {
    @Test("Só dígitos")
    func soDigitos() {
        #expect(ExtratorDeCodigo.extrair(de: "123456") == "123456")
    }

    @Test("Com sujeira ao redor")
    func comSujeira() {
        #expect(ExtratorDeCodigo.extrair(de: "Seu código: 123456") == "123456")
        #expect(ExtratorDeCodigo.extrair(de: "  \n123456\n ") == "123456")
        #expect(ExtratorDeCodigo.extrair(de: "Código 123456. Vale por 10 minutos.") == "123456")
    }

    @Test("Espaço e traço dentro do código")
    func separadores() {
        #expect(ExtratorDeCodigo.extrair(de: "123 456") == "123456")
        #expect(ExtratorDeCodigo.extrair(de: "123-456") == "123456")
        #expect(ExtratorDeCodigo.extrair(de: "Código: 12 34 56") == "123456")
    }

    @Test("Vazio ou sem números")
    func vazio() {
        #expect(ExtratorDeCodigo.extrair(de: "") == nil)
        #expect(ExtratorDeCodigo.extrair(de: "   ") == nil)
        #expect(ExtratorDeCodigo.extrair(de: "sem código aqui") == nil)
    }

    @Test("Dígitos de menos ou de mais")
    func tamanhoErrado() {
        #expect(ExtratorDeCodigo.extrair(de: "12345") == nil)
        #expect(ExtratorDeCodigo.extrair(de: "1234567") == nil)
        #expect(ExtratorDeCodigo.extrair(de: "12345678") == nil)
    }

    @Test("Vários números: aceita só quando há um código possível")
    func variosNumeros() {
        #expect(ExtratorDeCodigo.extrair(de: "Pedido 12345678, código 123456") == "123456")
        #expect(ExtratorDeCodigo.extrair(de: "Código 123456, expira em 10 min") == "123456")
        #expect(ExtratorDeCodigo.extrair(de: "123456 e depois 123456") == "123456")
        #expect(ExtratorDeCodigo.extrair(de: "123456 ou 654321") == nil)
    }
}

@MainActor
struct ColarCodigoTests {
    private func criar() -> CodigoViewModel {
        CodigoViewModel(api: ApiClienteEmMemoria(cenario: .primeiroAcesso), email: "novo@frila.app")
    }

    @Test("Colar preenche o campo com o código extraído")
    func preenche() {
        let vm = criar()
        vm.colar(["Seu código: 123-456"])
        #expect(vm.codigo == "123456")
        #expect(vm.codigoValido)
        #expect(vm.avisoDeColagem == nil)
    }

    @Test("Sem código válido: não preenche e avisa")
    func semCodigo() {
        let vm = criar()
        vm.codigo = "12"
        vm.colar(["nada por aqui"])
        #expect(vm.codigo == "12")
        #expect(vm.avisoDeColagem != nil)
    }

    @Test("Lista vazia avisa e um colar bom depois limpa o aviso")
    func listaVazia() {
        let vm = criar()
        vm.colar([])
        #expect(vm.avisoDeColagem != nil)
        vm.colar(["654321"])
        #expect(vm.avisoDeColagem == nil)
        #expect(vm.codigo == "654321")
    }
}
