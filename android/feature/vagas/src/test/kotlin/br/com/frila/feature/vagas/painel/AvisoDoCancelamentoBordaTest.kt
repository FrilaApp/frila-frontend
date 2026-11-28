package br.com.frila.feature.vagas.painel

import java.time.Instant
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

/**
 * Cartão WrA2wkX0 (item 286): a borda de 1 h do aviso de "Cancelar vaga". O teste antigo cobre 23 h 30, 30 min, o próprio início e o nulo,
 * mas não 1 h exata: `<` virar `<=` passava. O iOS mostra "1 h" com 1 h exata (`TextosDoCancelamento.swift:83`, `antecedencia >= 3600`).
 * Fora: o cancelamento da posição.
 *
 * JUnit: nenhum método devolve valor (um `@Test` que devolve valor é ignorado).
 */
class AvisoDoCancelamentoBordaTest {

    private val agora: Instant = Instant.parse("2026-11-10T15:00:00Z")

    private fun aviso(segundos: Long) = avisoDoCancelamento(agora.plusSeconds(segundos), agora)

    private fun faltam(tempo: String) = "Faltam $tempo para o início. ${TextosCancelarVaga.EFEITO}"

    @Test
    fun `com 1 h exata o aviso diz 1 h`() {
        assertEquals(faltam("1 h"), aviso(3600))
    }

    @Test
    fun `com 1 s a menos que 1 h o aviso diz menos de 1 h`() {
        assertEquals(faltam("menos de 1 h"), aviso(3599))
    }

    @Test
    fun `com 1 s a mais que 1 h continua 1 h`() {
        assertEquals(faltam("1 h"), aviso(3601))
    }

    @Test
    fun `as horas sao inteiras para baixo na borda de cada hora`() {
        assertEquals(faltam("1 h"), aviso(7199))
        assertEquals(faltam("2 h"), aviso(7200))
        assertEquals(faltam("23 h"), aviso(24 * 3600 - 1))
        assertEquals(faltam("24 h"), aviso(24 * 3600))
    }

    @Test
    fun `no ultimo segundo antes do inicio ainda diz menos de 1 h, e no proprio inicio diz que comecou`() {
        assertEquals(faltam("menos de 1 h"), aviso(1))
        assertEquals("O turno já começou. ${TextosCancelarVaga.EFEITO_COMECADA}", aviso(0))
        assertEquals("O turno já começou. ${TextosCancelarVaga.EFEITO_COMECADA}", aviso(-1))
    }
}
