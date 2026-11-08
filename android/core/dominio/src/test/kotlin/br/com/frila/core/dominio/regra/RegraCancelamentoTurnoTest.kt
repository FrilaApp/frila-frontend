package br.com.frila.core.dominio.regra

import br.com.frila.core.dominio.modelo.MotivoCancelamento
import br.com.frila.core.dominio.modelo.RegraCancelamentoTurno
import java.time.Instant
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class RegraCancelamentoTurnoTest {

    private val inicio = Instant.parse("2026-11-02T12:00:00Z")

    @Test
    fun `antecedencia inferior a 24 horas conta como falta`() {
        val agora = Instant.parse("2026-11-01T12:00:01Z")

        assertTrue(RegraCancelamentoTurno.contaComoFalta(inicio, agora))
    }

    @Test
    fun `antecedencia de exatamente 24 horas nao conta como falta`() {
        val agora = Instant.parse("2026-11-01T12:00:00Z")

        assertFalse(RegraCancelamentoTurno.contaComoFalta(inicio, agora))
    }

    @Test
    fun `antecedencia superior a 24 horas nao conta como falta`() {
        val agora = Instant.parse("2026-10-31T12:00:00Z")

        assertFalse(RegraCancelamentoTurno.contaComoFalta(inicio, agora))
    }

    @Test
    fun `somente outro exige detalhes livres`() {
        assertTrue(MotivoCancelamento.OUTRO.exigeDetalhes)
        assertTrue(MotivoCancelamento.entries.filterNot { it == MotivoCancelamento.OUTRO }.none { it.exigeDetalhes })
    }
}
