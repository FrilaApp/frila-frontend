package br.com.frila.core.dominio.regra

import java.time.Instant
import java.time.format.DateTimeParseException
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Test

/**
 * O servidor devolve instantes com `+00:00` (Postgres) e o cliente tem de ler os mesmos formatos que
 * o iOS lê (`iOS/Sources/Dados/DTOsContrato.swift`, `ContratoAPI.instante`). `Instant.parse` só aceita
 * deslocamento a partir do Java 12: no Android 9 a 11 (minSdk 28) ele lança exceção. Estes testes
 * rodam no Java 17, onde `Instant.parse` também passaria; a prova do defeito é em aparelho API 28 a 30.
 */
class InstanteDoServidorTest {

    private val esperado = Instant.parse("2026-11-25T12:31:00Z")

    @Test
    fun `le instante terminado em Z`() {
        assertEquals(esperado, instanteDoServidor("2026-11-25T12:31:00Z"))
    }

    @Test
    fun `le instante com deslocamento zero como o Postgres devolve`() {
        assertEquals(esperado, instanteDoServidor("2026-11-25T12:31:00+00:00"))
    }

    @Test
    fun `le instante com fracao de segundo e deslocamento`() {
        assertEquals(
            Instant.parse("2026-11-25T12:31:00.123456Z"),
            instanteDoServidor("2026-11-25T12:31:00.123456+00:00"),
        )
    }

    @Test
    fun `converte deslocamento de Brasilia para o mesmo instante`() {
        assertEquals(esperado, instanteDoServidor("2026-11-25T09:31:00-03:00"))
    }

    @Test
    fun `texto que nao e instante lanca a mesma excecao de antes`() {
        assertThrows(DateTimeParseException::class.java) { instanteDoServidor("25/11/2026 09:31") }
    }
}
