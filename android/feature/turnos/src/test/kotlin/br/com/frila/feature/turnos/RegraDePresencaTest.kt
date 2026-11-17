package br.com.frila.feature.turnos

import java.time.Instant
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** L1-4: a regra do iOS (`RegraDePresenca`) que o check-out usa. */
class RegraDePresencaTest {

    private val fim = Instant.parse("2026-11-02T03:00:00Z")

    @Test
    fun `check-out so com check-in feito e check-out ainda nao feito`() {
        assertTrue(RegraDePresenca.podeFazerCheckout(checkinFeito = true, checkoutFeito = false, fim = fim, agora = fim.minusSeconds(3600)))
        assertFalse(RegraDePresenca.podeFazerCheckout(checkinFeito = false, checkoutFeito = false, fim = fim, agora = fim))
        assertFalse(RegraDePresenca.podeFazerCheckout(checkinFeito = true, checkoutFeito = true, fim = fim, agora = fim))
    }

    @Test
    fun `check-out vale ate 60 minutos depois do fim, sem tolerancia`() {
        assertTrue(RegraDePresenca.podeFazerCheckout(true, false, fim, fim.plusSeconds(60 * 60)))
        assertFalse(RegraDePresenca.podeFazerCheckout(true, false, fim, fim.plusSeconds(60 * 60 + 1)))
    }

    @Test
    fun `sem o fim do turno o servidor decide e o botao fica`() {
        assertTrue(RegraDePresenca.podeFazerCheckout(true, false, null, fim))
    }
}
