package br.com.frila.core.rede

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Corpo de `POST /rest/v1/rpc/validar_codigo_checkin` (0.2.68; `required: [turno_id, codigo, distancia_m]` em
 * `iOS/Contrato/openapi.yaml`). `distancia_m` é obrigatório e aceita nulo: o campo sai sempre (`null` quando o aparelho
 * não tem localização), por isso não tem valor padrão. O código nunca vai a log.
 */
@Serializable
data class ValidarCodigoCheckinDto(
    @SerialName("turno_id") val turnoId: String,
    /** Os 6 dígitos lidos ou digitados (`^[0-9]{6}$`). */
    @SerialName("codigo") val codigo: String,
    @SerialName("distancia_m") val distanciaM: Int?,
)
