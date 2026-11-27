package br.com.frila.feature.chamadas.casa

import br.com.frila.core.dominio.modelo.Dinheiro
import br.com.frila.feature.chamadas.profissional.FormatoChamada
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

/**
 * Cartão ghos6ChH: os dois formatadores de R$ das chamadas (casa e profissional) escrevem o mesmo texto de
 * [Dinheiro.formatado], com o espaço não separável depois do "R$" e o sinal antes do símbolo nos negativos.
 */
class DinheiroDasChamadasTest {

    private val tabela = listOf(0L, 5L, 150_000L, 123_456L, -150L)

    @Test
    fun `dinheiro da casa escreve o mesmo texto de Dinheiro formatado`() {
        for (centavos in tabela) {
            assertEquals(Dinheiro(centavos).formatado(), dinheiro(centavos), "$centavos")
        }
    }

    @Test
    fun `dinheiro do profissional escreve o mesmo texto de Dinheiro formatado`() {
        for (centavos in tabela) {
            assertEquals(Dinheiro(centavos).formatado(), FormatoChamada.dinheiro(centavos), "$centavos")
        }
    }

    @Test
    fun `o texto e o de pt-BR com espaco nao separavel, e o negativo leva o sinal antes do simbolo`() {
        assertEquals("R$ 1.500,00", dinheiro(150_000))
        assertEquals("-R$ 1,50", dinheiro(-150))
    }
}
