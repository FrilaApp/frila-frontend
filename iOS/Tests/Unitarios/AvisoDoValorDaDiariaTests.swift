@testable import FrilaApresentacao
import FrilaDominio
import Testing

/// B-124: R$ 50 a R$ 2.000 é só referência de aviso. A função pura da faixa e os textos exatos; o que cada tela faz com
/// o aviso (mostrar sem travar) está na suíte de cada tela.
@Suite("Valor da diária fora da faixa de referência: só avisa (B-124)")
struct AvisoDoValorDaDiariaTests {
    @Test("A referência é de 5000 a 200000 centavos")
    func referencia() {
        #expect(ReferenciaDaDiaria.minimoEmCentavos == 5_000)
        #expect(ReferenciaDaDiaria.maximoEmCentavos == 200_000)
    }

    @Test("Abaixo de R$ 50: muito baixo", arguments: [1, 4_999])
    func abaixo(centavos: Int) {
        #expect(ReferenciaDaDiaria.avaliar(centavos: centavos) == .abaixo)
        #expect(AvisoDoValorDaDiaria.texto(centavos: centavos) == "Valor muito baixo.")
    }

    @Test("De R$ 50 a R$ 2.000, com as duas bordas: nenhum aviso", arguments: [5_000, 5_001, 14_000, 199_999, 200_000])
    func dentro(centavos: Int) {
        #expect(ReferenciaDaDiaria.avaliar(centavos: centavos) == nil)
        #expect(AvisoDoValorDaDiaria.texto(centavos: centavos) == nil)
    }

    @Test("Acima de R$ 2.000: muito alto, confira", arguments: [200_001, 100_000_000])
    func acima(centavos: Int) {
        #expect(ReferenciaDaDiaria.avaliar(centavos: centavos) == .acima)
        #expect(AvisoDoValorDaDiaria.texto(centavos: centavos) == "Valor muito alto, confira.")
    }

    @Test("Zero e negativo não ganham aviso novo: a regra do valor obrigatório já cuida deles", arguments: [0, -1, -5_000])
    func zeroOuNegativo(centavos: Int) {
        #expect(ReferenciaDaDiaria.avaliar(centavos: centavos) == nil)
        #expect(AvisoDoValorDaDiaria.texto(centavos: centavos) == nil)
    }
}
