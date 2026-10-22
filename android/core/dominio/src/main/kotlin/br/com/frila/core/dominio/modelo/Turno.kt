package br.com.frila.core.dominio.modelo

import java.time.LocalDateTime

/** Estado de execução de um turno já confirmado para um profissional. */
enum class EstadoTurno {
    AGENDADO,
    A_CAMINHO,
    EM_ANDAMENTO,
    CONCLUIDO,
    CANCELADO,
}

/** Turno confirmado de um profissional numa vaga, com janelas de check-in/check-out. */
data class Turno(
    val id: String,
    val vagaId: String,
    val profissionalId: String,
    val inicio: LocalDateTime,
    val fim: LocalDateTime,
    val estado: EstadoTurno,
    val checkinEm: LocalDateTime? = null,
    val checkoutEm: LocalDateTime? = null,
) {
    init {
        require(!fim.isBefore(inicio)) { "fim ($fim) não pode ser anterior a inicio ($inicio)" }
    }

    fun sobrepoeCom(outro: Turno): Boolean =
        inicio.isBefore(outro.fim) && outro.inicio.isBefore(fim)
}
