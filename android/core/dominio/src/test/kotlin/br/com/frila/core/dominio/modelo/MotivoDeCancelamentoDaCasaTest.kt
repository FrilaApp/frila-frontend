package br.com.frila.core.dominio.modelo

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

/**
 * F6CBghxY: a borda do mínimo do motivo livre da casa ([MotivoDeCancelamentoDaCasa.MINIMO_DO_MOTIVO], 3 caracteres, como o iOS
 * `count >= 3`). Os testes das telas só usam "ab" e frases longas; aqui ficam os 3 caracteres exatos e o trim antes da conta.
 */
class MotivoDeCancelamentoDaCasaTest {

    private val outro = MotivoDeCancelamentoDaCasa.OUTRO

    @Test
    fun `o minimo e de 3 caracteres`() {
        assertEquals(3, MotivoDeCancelamentoDaCasa.MINIMO_DO_MOTIVO)
    }

    @Test
    fun `outro motivo com exatamente 3 caracteres e aceito e vai ao servidor`() {
        assertEquals("Fim", outro.textoParaOServidor("Fim"))
    }

    @Test
    fun `outro motivo com 2 caracteres e recusado`() {
        assertNull(outro.textoParaOServidor("ok"))
    }

    @Test
    fun `os espacos em volta nao contam e nao vao ao servidor`() {
        assertEquals("Fim", outro.textoParaOServidor("  Fim  "))
        assertNull(outro.textoParaOServidor("  ok  "))
    }
}
