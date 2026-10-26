package br.com.frila.feature.turnos

import java.time.Duration
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CalculadorContagemRegressivaTest {

    private val inicioTurno: Instant = Instant.parse("2026-11-01T20:00:00Z")
    private val fimTurno: Instant = Instant.parse("2026-11-02T02:00:00Z")

    @Test
    fun `calcula contagem quando faltam horas para a janela de checkin`() {
        // Abertura da janela é 19:00:00Z (60 min antes). Às 17:30:00Z, faltam 1h 30min.
        val instanteAtual = Instant.parse("2026-11-01T17:30:00Z")
        val estado = CalculadorContagemRegressiva.calcular(
            inicioTurno = inicioTurno,
            fimTurno = fimTurno,
            instanteAtual = instanteAtual,
        )

        assertTrue(estado is EstadoContagemRegressiva.AguardandoJanela)
        val aguardando = estado as EstadoContagemRegressiva.AguardandoJanela
        assertEquals(Duration.ofMinutes(90), aguardando.tempoRestante)
        assertEquals("1h 30min", aguardando.textoFormatado)
    }

    @Test
    fun `retorna JanelaAberta exatamente quando atinge 60 minutos antes do inicio`() {
        val instanteAbertura = Instant.parse("2026-11-01T19:00:00Z")
        val estado = CalculadorContagemRegressiva.calcular(
            inicioTurno = inicioTurno,
            fimTurno = fimTurno,
            instanteAtual = instanteAbertura,
        )

        assertEquals(EstadoContagemRegressiva.JanelaAberta, estado)
    }

    @Test
    fun `retorna JanelaAberta quando ja esta dentro da janela de checkin`() {
        val instanteDentroDaJanela = Instant.parse("2026-11-01T19:45:00Z")
        val estado = CalculadorContagemRegressiva.calcular(
            inicioTurno = inicioTurno,
            fimTurno = fimTurno,
            instanteAtual = instanteDentroDaJanela,
        )

        assertEquals(EstadoContagemRegressiva.JanelaAberta, estado)
    }

    @Test
    fun `retorna TurnoFinalizado quando o instante atual ultrapassa o fim do turno`() {
        val instanteAposFim = Instant.parse("2026-11-02T02:05:00Z")
        val estado = CalculadorContagemRegressiva.calcular(
            inicioTurno = inicioTurno,
            fimTurno = fimTurno,
            instanteAtual = instanteAposFim,
        )

        assertEquals(EstadoContagemRegressiva.TurnoFinalizado, estado)
    }

    @Test
    fun `trata relogio alterado e duracoes negativas defensivamente`() {
        val instanteNoFuturo = Instant.parse("2026-11-01T20:30:00Z")
        val estado = CalculadorContagemRegressiva.calcular(
            inicioTurno = inicioTurno,
            fimTurno = fimTurno,
            instanteAtual = instanteNoFuturo,
        )

        assertEquals(EstadoContagemRegressiva.JanelaAberta, estado)
    }

    @Test
    fun `formata duracoes em dias horas minutos e segundos`() {
        assertEquals("2d 4h", CalculadorContagemRegressiva.formatarTempoRestante(Duration.ofHours(52)))
        assertEquals("3h 15min", CalculadorContagemRegressiva.formatarTempoRestante(Duration.ofMinutes(195)))
        assertEquals("4min 20s", CalculadorContagemRegressiva.formatarTempoRestante(Duration.ofSeconds(260)))
        assertEquals("45s", CalculadorContagemRegressiva.formatarTempoRestante(Duration.ofSeconds(45)))
    }
}
