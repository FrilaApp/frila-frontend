package br.com.frila.feature.turnos

import br.com.frila.feature.turnos.RegraDePresenca.DecisaoDoEnvioDoCodigo
import java.time.Instant
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** L1-4: as regras do iOS (`RegraDePresenca`) que o código e o check-out usam. */
class RegraDePresencaTest {

    @Test
    fun `o raio do codigo e de 50 metros, o do contrato 0_2_76`() {
        assertEquals(50, RegraDePresenca.RAIO_DO_CODIGO_METROS)
    }

    @Test
    fun `sem localizacao o codigo nao e enviado e a distancia nao e inventada`() {
        assertEquals(DecisaoDoEnvioDoCodigo.SemLocalizacao, RegraDePresenca.decisaoDoEnvioDoCodigo(null))
    }

    @Test
    fun `ate 50 metros o codigo e liberado, inclusive os 50`() {
        assertEquals(DecisaoDoEnvioDoCodigo.Liberado, RegraDePresenca.decisaoDoEnvioDoCodigo(0))
        assertEquals(DecisaoDoEnvioDoCodigo.Liberado, RegraDePresenca.decisaoDoEnvioDoCodigo(50))
    }

    @Test
    fun `acima de 50 metros pede para chegar mais perto, sem gastar tentativa`() {
        assertEquals(DecisaoDoEnvioDoCodigo.ChegueMaisPerto(51), RegraDePresenca.decisaoDoEnvioDoCodigo(51))
        assertEquals(DecisaoDoEnvioDoCodigo.ChegueMaisPerto(1200), RegraDePresenca.decisaoDoEnvioDoCodigo(1200))
    }

    @Test
    fun `so seis digitos ASCII valem como codigo`() {
        assertTrue(RegraDePresenca.formatoDoCodigoValido("049215"))
        assertTrue(RegraDePresenca.formatoDoCodigoValido("000000"))
        for (ruim in listOf("", "12345", "1234567", "12345a", "12 456", " 49215", "٠٤٩٢١٥", "１２３４５６")) {
            assertFalse(RegraDePresenca.formatoDoCodigoValido(ruim), "'$ruim'")
        }
    }

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
