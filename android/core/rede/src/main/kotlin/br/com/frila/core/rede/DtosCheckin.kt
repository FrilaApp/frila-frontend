package br.com.frila.core.rede

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// DTOs do check-in por código (contrato 0.2.68). Ficam fora do `Dtos.kt` para não disputar a fila D.

/** Corpo de `POST /rest/v1/rpc/gerar_codigo_checkin` (0.2.68): o turno cujo código de chegada a casa pede. */
@Serializable
data class GerarCodigoCheckinDto(
    @SerialName("turno_id") val turnoId: String,
)

/**
 * Resposta de `/rpc/gerar_codigo_checkin` (schema `CodigoDeCheckin`, MEDIDO em
 * `iOS/Contrato/openapi.yaml:8409`, 0.2.68). O código vale só para a casa dona do turno e nunca vai a log.
 * `segundosRestantes` é a validade contada pelo servidor na resposta (0 a 300): a tela conta a partir dele, não do
 * relógio do aparelho.
 */
@Serializable
data class CodigoDeCheckinDto(
    @SerialName("turno_id") val turnoId: String,
    /** Seis dígitos, com zeros à esquerda preservados: por isso é texto. */
    @SerialName("codigo") val codigo: String,
    @SerialName("expira_em") val expiraEm: String,
    @SerialName("segundos_restantes") val segundosRestantes: Int,
)
