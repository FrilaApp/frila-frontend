package br.com.frila.feature.vagas.publicacao

import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.CsvSource

class HorarioDaVagaTest {

    @ParameterizedTest
    @CsvSource("140,14000", "140.,14000", "'140,5',14050", "140.50,14050", "'R$ 1.400,00',140000", "0.01,1", "  75  ,7500")
    fun `lerCentavos aceita reais com virgula ou ponto`(texto: String, esperado: Long) {
        assertEquals(esperado, lerCentavos(texto))
    }

    @ParameterizedTest
    @CsvSource("''", "0", "0,00", "abc", "'10,555'", "1.2.3", "-5", "1234567890", "'.'", "'1e3'")
    fun `lerCentavos recusa o que nao e valor positivo com ate duas casas`(texto: String?) {
        assertNull(lerCentavos(texto ?: ""))
    }

    @Test
    fun `formatarReais usa ponto de milhar e virgula decimal`() {
        assertEquals("R$ 1.260,00", formatarReais(126_000))
        assertEquals("R$ 0,05", formatarReais(5))
        assertEquals("R$ 140,50", formatarReais(14_050))
        assertEquals("R$ 1.234.567,89", formatarReais(123_456_789))
    }

    @Test
    fun `formatarDuracao escreve horas e minutos`() {
        assertEquals("6 h", formatarDuracao(Duration.ofHours(6)))
        assertEquals("1 h 30 min", formatarDuracao(Duration.ofMinutes(90)))
        assertEquals("45 min", formatarDuracao(Duration.ofMinutes(45)))
    }

    @Test
    fun `data e hora sao mostradas no fuso de Brasilia`() {
        val instante = Instant.parse("2026-11-11T02:30:00Z")

        assertEquals("10/11/2026", formatarData(instante))
        assertEquals("23:30", formatarHora(instante))
    }

    @Test
    fun `trocarData mantem a hora local e trocarHora mantem o dia local`() {
        val instante = Instant.parse("2026-11-10T21:30:00Z") // 18:30 em Brasília
        val quinze = Instant.parse("2026-11-15T00:00:00Z").toEpochMilli() // o que o DatePicker devolve para 15/11

        assertEquals(Instant.parse("2026-11-15T21:30:00Z"), trocarData(instante, quinze))
        assertEquals(Instant.parse("2026-11-10T23:05:00Z"), trocarHora(instante, 20, 5))
    }

    @Test
    fun `o seletor de data recebe o dia local mesmo quando o instante ja virou o dia em UTC`() {
        val instante = Instant.parse("2026-11-11T02:30:00Z") // 10/11 às 23:30 em Brasília

        assertEquals(Instant.parse("2026-11-10T00:00:00Z").toEpochMilli(), dataParaSeletorUtcMs(instante))
        assertEquals(instante, trocarData(instante, dataParaSeletorUtcMs(instante)))
    }

    @Test
    fun `trocarData respeita o fuso informado`() {
        val utc = ZoneId.of("UTC")
        val instante = Instant.parse("2026-11-10T21:30:00Z")

        assertEquals(Instant.parse("2026-11-12T21:30:00Z"), trocarData(instante, Instant.parse("2026-11-12T00:00:00Z").toEpochMilli(), utc))
    }
}
