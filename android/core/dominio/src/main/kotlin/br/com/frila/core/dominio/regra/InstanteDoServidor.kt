package br.com.frila.core.dominio.regra

import java.time.Instant
import java.time.OffsetDateTime

/**
 * Lê um instante ISO-8601 vindo do servidor: com `Z` ou com deslocamento (`+00:00`, como o Postgres
 * devolve), com ou sem fração de segundo. Use sempre esta função no lugar de `Instant.parse`, que só
 * aceita deslocamento a partir do Java 12 e por isso falha no Android 9 a 11.
 *
 * Texto inválido lança `DateTimeParseException`, como `Instant.parse`.
 */
fun instanteDoServidor(texto: String): Instant = OffsetDateTime.parse(texto).toInstant()
