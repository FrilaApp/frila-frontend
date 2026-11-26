package br.com.frila.core.dominio.regra

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource

class ReferenciaValorDiariaTest {

    @ParameterizedTest
    @ValueSource(longs = [1L, 4_999L])
    fun `valores positivos abaixo de 50 reais devolvem aviso de valor muito baixo`(centavos: Long) {
        assertEquals(AvisoValorDiaria.MUITO_BAIXO, ReferenciaValorDiaria.avaliar(centavos))
    }

    @ParameterizedTest
    @ValueSource(longs = [5_000L, 200_000L])
    fun `limites inclusivos da faixa de referencia nao geram aviso`(centavos: Long) {
        assertNull(ReferenciaValorDiaria.avaliar(centavos))
    }

    @ParameterizedTest
    @ValueSource(longs = [200_001L, 100_000_000L])
    fun `valores acima de 2000 reais devolvem aviso de valor muito alto`(centavos: Long) {
        assertEquals(AvisoValorDiaria.MUITO_ALTO, ReferenciaValorDiaria.avaliar(centavos))
    }

    @ParameterizedTest
    @ValueSource(longs = [0L, -1L, -5_000L])
    fun `zero e negativos nao geram aviso novo`(centavos: Long) {
        assertNull(ReferenciaValorDiaria.avaliar(centavos))
    }

    @Test
    fun `nulo nao gera aviso novo`() {
        assertNull(ReferenciaValorDiaria.avaliar(null))
    }
}
