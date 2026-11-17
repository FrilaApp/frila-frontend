package br.com.frila.core.rede

import kotlinx.serialization.EncodeDefault
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// DTOs da mídia do perfil (foto, L1-0b; contrato 0.2.54 a 0.2.82). Ficam fora do `Dtos.kt` para não disputar a fila D.
// `tipo`, `estado` e `motivo_recusa` são texto: valor novo do servidor não derruba a leitura.

/**
 * Corpo de `POST /rest/v1/rpc/solicitar_upload_midia` (0.2.54). O app envia JPEG sem EXIF, lado maior até 1600 px e até
 * 5 MB (`bytes`). Nesta versão só `tipo = foto_perfil`. [estabelecimentoId] só para a foto ou o logo da casa (exige ser membro);
 * omitido sai do corpo.
 */
@OptIn(ExperimentalSerializationApi::class)
@Serializable
data class SolicitarUploadMidiaDto(
    @SerialName("tipo") val tipo: String,
    @SerialName("mime") val mime: String,
    @SerialName("bytes") val bytes: Int,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("estabelecimento_id") val estabelecimentoId: String? = null,
)

/**
 * Resposta de `solicitar_upload_midia`. [uploadUrl] é de **uso único**, vale 2 h e aponta para a Edge Function `enviar-midia`
 * (0.2.63): o app faz `PUT` com o JPEG, sem o token da sessão. A URL leva um token e **nunca** vai a log, texto de erro nem relatório.
 */
@Serializable
data class UploadMidiaDto(
    @SerialName("midia_id") val midiaId: String,
    @SerialName("upload_url") val uploadUrl: String,
    @SerialName("expira_em") val expiraEm: String,
)

/** Corpo de `POST /rest/v1/rpc/confirmar_upload_midia`. Idempotente: confirmar de novo devolve o estado atual. */
@Serializable
data class ConfirmarUploadMidiaDto(
    @SerialName("midia_id") val midiaId: String,
)

/** Corpo de `POST /rest/v1/rpc/remover_midia`. Idempotente, e funciona mesmo com `recursos.foto_de_perfil` desligado. */
@Serializable
data class RemoverMidiaDto(
    @SerialName("midia_id") val midiaId: String,
)

/** Corpo de `POST /rest/v1/rpc/pedir_nova_analise_midia`: uma vez por foto `recusada` ou `nao_publicada`. */
@Serializable
data class PedirNovaAnaliseMidiaDto(
    @SerialName("midia_id") val midiaId: String,
)

/**
 * A mídia como o dono a vê (schema `Midia`, 0.2.54). Nunca traz o caminho no Storage nem o código fino do motivo.
 * [estado]: `enviando`, `em_analise`, `aprovada`, `recusada`, `nao_publicada` ou `removida`; [url] é o link de leitura de 1 h
 * da miniatura, só da foto `aprovada`, com a chave ligada e só quando `minhas_midias` é chamada por `POST`.
 */
@Serializable
data class MidiaDto(
    @SerialName("id") val id: String,
    @SerialName("tipo") val tipo: String,
    @SerialName("estado") val estado: String,
    @SerialName("motivo_recusa") val motivoRecusa: String? = null,
    @SerialName("pode_pedir_nova_analise") val podePedirNovaAnalise: Boolean,
    @SerialName("url") val url: String? = null,
    @SerialName("estabelecimento_id") val estabelecimentoId: String? = null,
    @SerialName("enviada_em") val enviadaEm: String? = null,
    @SerialName("decidida_em") val decididaEm: String? = null,
)
