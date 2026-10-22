package br.com.frila.core.dominio.modelo

import java.time.LocalDateTime

/** Estado de uma candidatura de um profissional a uma vaga. */
enum class EstadoCandidatura {
    PENDENTE,
    ACEITA,
    RECUSADA,
    RETIRADA,
}

/** Candidatura de um profissional a uma vaga. */
data class Candidatura(
    val id: String,
    val vagaId: String,
    val profissionalId: String,
    val estado: EstadoCandidatura,
    val criadaEm: LocalDateTime,
)
