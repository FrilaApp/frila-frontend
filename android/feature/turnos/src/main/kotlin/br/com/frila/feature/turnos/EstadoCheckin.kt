package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.ComprovanteCheckin

/** Status do check-in presencial de um turno (RF13/RN06/RN22). */
enum class StatusCheckin { OCIOSO, REGISTRANDO, VERIFICADO, MANUAL_PENDENTE, ERRO }

/** Estado da ação de check-in de um turno específico. */
data class EstadoCheckin(
    val status: StatusCheckin = StatusCheckin.OCIOSO,
    val mensagemErro: String? = null,
    val comprovante: ComprovanteCheckin? = null,
)
