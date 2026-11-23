package br.com.frila.core.rede

import kotlinx.serialization.EncodeDefault
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Dicionário fechado do contrato; metadados aceitam apenas identificadores (RN15). */
@Serializable
enum class EventoDeTelemetria {
    @SerialName("app_aberto") APP_ABERTO,
    @SerialName("cadastro_concluido") CADASTRO_CONCLUIDO,
    @SerialName("permissao_push_negada") PERMISSAO_PUSH_NEGADA,
    @SerialName("vaga_vista") VAGA_VISTA,
    @SerialName("vaga_detalhe_aberto") VAGA_DETALHE_ABERTO,
    @SerialName("candidatura_enviada") CANDIDATURA_ENVIADA,
    @SerialName("candidatura_retirada") CANDIDATURA_RETIRADA,
    @SerialName("checkin_tentado") CHECKIN_TENTADO,
    @SerialName("checkin_concluido") CHECKIN_CONCLUIDO,
    @SerialName("checkout_concluido") CHECKOUT_CONCLUIDO,
    @SerialName("avaliacao_enviada") AVALIACAO_ENVIADA,
    @SerialName("contato_aberto") CONTATO_ABERTO,
    @SerialName("acao_enfileirada_offline") ACAO_ENFILEIRADA_OFFLINE,
    @SerialName("atualizacao_obrigatoria_exibida") ATUALIZACAO_OBRIGATORIA_EXIBIDA,
}

@OptIn(ExperimentalSerializationApi::class)
@Serializable
data class RegistroDeEventoDto(
    @SerialName("evento") val evento: EventoDeTelemetria,
    @EncodeDefault(EncodeDefault.Mode.NEVER)
    @SerialName("vaga_id") val vagaId: String? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER)
    @SerialName("turno_id") val turnoId: String? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER)
    @SerialName("ocorrido_em") val ocorridoEm: String? = null,
)

@Serializable
data class EventoRegistradoDto(@SerialName("registrado") val registrado: Boolean)
