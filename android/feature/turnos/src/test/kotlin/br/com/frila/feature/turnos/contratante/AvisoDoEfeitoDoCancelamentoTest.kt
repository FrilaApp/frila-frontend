package br.com.frila.feature.turnos.contratante

import java.time.Duration
import java.time.Instant
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * O efeito do cancelamento da posição, dito antes do toque (Vmfnk4gQ, fatia 2): paridade com `TextosDoCancelamento.aviso` do iOS, lado do
 * contratante e alvo posição. Antes do início a posição reabre; a partir dele (`antecedência <= 0`) não reabre e o turno fica descoberto.
 */
class AvisoDoEfeitoDoCancelamentoTest {

    private val agora = Instant.parse("2026-11-27T12:00:00Z")

    private val reabre = "A posição volta a ser oferecida a outros profissionais, e quem estava confirmado será avisado."
    private val naoReabre = "A posição não será reaberta: o turno fica descoberto, e quem estava confirmado será avisado."
    private val semFalta = "Não conta como falta para o profissional."

    private fun aviso(antecedencia: Duration) = avisoDoEfeitoDoCancelamento(agora.plus(antecedencia), agora)

    @Test
    fun `antes do inicio a posicao reabre, com o tempo que falta em horas inteiras`() {
        assertEquals("Faltam 5 h para o início. $reabre $semFalta", aviso(Duration.ofHours(5)))
    }

    @Test
    fun `a 23 h 30 min o aviso diz 23 h, nunca 24 h`() {
        assertEquals("Faltam 23 h para o início. $reabre $semFalta", aviso(Duration.ofMinutes(23 * 60 + 30)))
    }

    @Test
    fun `abaixo de uma hora diz menos de 1 h, e com exatamente 1 h diz 1 h`() {
        assertEquals("Faltam menos de 1 h para o início. $reabre $semFalta", aviso(Duration.ofMinutes(59)))
        assertEquals("Faltam 1 h para o início. $reabre $semFalta", aviso(Duration.ofHours(1)))
    }

    @Test
    fun `no instante do inicio ja nao reabre, e depois dele tambem`() {
        val comecou = "O turno já começou. $naoReabre $semFalta"
        assertEquals(comecou, aviso(Duration.ZERO))
        assertEquals(comecou, aviso(Duration.ofMinutes(-30)))
    }

    @Test
    fun `um segundo antes do inicio ainda reabre`() {
        val texto = aviso(Duration.ofSeconds(1))
        assertTrue(texto.contains(reabre), texto)
        assertFalse(texto.contains("não será reaberta"), texto)
    }

    @Test
    fun `sem o inicio so diz o que vale nos dois casos, sem prometer reabertura`() {
        val texto = avisoDoEfeitoDoCancelamento(null, agora)
        assertEquals("Quem estava confirmado será avisado. $semFalta", texto)
        assertFalse(texto.contains("reaberta") || texto.contains("oferecida"), texto)
    }

    @Test
    fun `nenhum caso diz que o cancelamento da casa conta como falta`() {
        listOf(Duration.ofHours(30), Duration.ofMinutes(10), Duration.ZERO, Duration.ofHours(-2)).forEach {
            assertTrue(aviso(it).endsWith(semFalta), aviso(it))
        }
    }
}
