package br.com.frila.app.desempenho

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Testes unitários do medidor de inicialização a frio (cold start) (Cartão 53, RNF04).
 */
class MedidorDeColdStartTest {

    @Before
    @After
    fun limparEstado() {
        MedidorDeColdStart.resetarParaTestes()
    }

    @Test
    fun `marcarPrimeiroQuadro calcula duracao exata entre inicio e conclusao`() {
        val inicio = 1000L
        val fim = 1380L

        MedidorDeColdStart.iniciar(inicioMillis = inicio)
        val duracao = MedidorDeColdStart.marcarPrimeiroQuadro(fimMillis = fim)

        assertNotNull("Duração não deve ser nula após início", duracao)
        assertEquals(380L, duracao)
    }

    @Test
    fun `marcarPrimeiroQuadro nao duplica medicao em chamadas subsequentes`() {
        val inicio = 1000L
        MedidorDeColdStart.iniciar(inicioMillis = inicio)

        val primeiraMedicao = MedidorDeColdStart.marcarPrimeiroQuadro(fimMillis = 1400L)
        val segundaMedicao = MedidorDeColdStart.marcarPrimeiroQuadro(fimMillis = 1500L)

        assertEquals(400L, primeiraMedicao)
        assertNull("Segunda chamada deve retornar null para evitar métricas duplicadas", segundaMedicao)
    }

    @Test
    fun `marcarPrimeiroQuadro sem iniciar retorna null defensivamente`() {
        val medicao = MedidorDeColdStart.marcarPrimeiroQuadro(fimMillis = 2000L)
        assertNull("Sem chamada de iniciar, deve retornar null", medicao)
    }

    @Test
    fun `formatarMensagem produz texto padronizado para o logcat`() {
        val mensagem = MedidorDeColdStart.formatarMensagem(250L)
        assertEquals("Cold start concluído até o primeiro quadro: 250ms", mensagem)
    }

    @Test
    fun `duracao negativa por inconsistencia de clock e truncada para zero`() {
        MedidorDeColdStart.iniciar(inicioMillis = 5000L)
        val duracao = MedidorDeColdStart.marcarPrimeiroQuadro(fimMillis = 4000L)
        assertEquals(0L, duracao)
    }
}
