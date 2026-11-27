package br.com.frila.core.rede

import kotlinx.serialization.EncodeDefault
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Corpo de `POST /functions/v1/autenticar-senha` (contrato 0.2.112). */
@OptIn(ExperimentalSerializationApi::class)
@Serializable
data class AutenticarSenhaRequisicaoDto(
    @SerialName("email") val email: String,
    @SerialName("senha") val senha: String,
    @EncodeDefault @SerialName("plataforma") val plataforma: String = "android",
    @SerialName("device_token") val deviceToken: String? = null,
)

/** Resposta 200 de `POST /functions/v1/autenticar-senha` (contrato 0.2.112). */
@Serializable
data class AutenticarSenhaRespostaDto(
    @SerialName("status") val status: String,
    @SerialName("sessao") val sessao: SessaoDto? = null,
    @SerialName("precisa_definir_senha") val precisaDefinirSenha: Boolean? = null,
    @SerialName("dispositivo_expira_em") val dispositivoExpiraEm: String? = null,
    @SerialName("desafio_id") val desafioId: String? = null,
    @SerialName("expira_em") val expiraEm: String? = null,
    @SerialName("descartar_device_token") val descartarDeviceToken: Boolean? = null,
    @SerialName("reenviar_em_segundos") val reenviarEmSegundos: Int? = null,
)

/** Corpo de `POST /functions/v1/confirmar-dispositivo-otp` (contrato 0.2.112). */
@OptIn(ExperimentalSerializationApi::class)
@Serializable
data class ConfirmarDispositivoOtpRequisicaoDto(
    @SerialName("tipo") val tipo: String,
    @SerialName("desafio_id") val desafioId: String? = null,
    @SerialName("email") val email: String? = null,
    @SerialName("codigo") val codigo: String,
    @EncodeDefault @SerialName("plataforma") val plataforma: String = "android",
    @SerialName("lembrar_dispositivo") val lembrarDispositivo: Boolean,
)

/** Resposta 200 de `POST /functions/v1/confirmar-dispositivo-otp` (contrato 0.2.112). */
@Serializable
data class ConfirmarDispositivoOtpRespostaDto(
    @SerialName("sessao") val sessao: SessaoDto,
    @SerialName("precisa_definir_senha") val precisaDefinirSenha: Boolean? = null,
    @SerialName("device_token") val deviceToken: String? = null,
    @SerialName("dispositivo_expira_em") val dispositivoExpiraEm: String? = null,
)

/** Corpo de `POST /functions/v1/reenviar-dispositivo-otp` (contrato 0.2.112). */
@Serializable
data class ReenviarDispositivoOtpRequisicaoDto(
    @SerialName("desafio_id") val desafioId: String,
)

/** Resposta 200 de `POST /functions/v1/reenviar-dispositivo-otp` (contrato 0.2.112). */
@Serializable
data class ReenviarDispositivoOtpRespostaDto(
    @SerialName("ok") val ok: Boolean,
    @SerialName("desafio_id") val desafioId: String,
    @SerialName("expira_em") val expiraEm: String? = null,
    @SerialName("reenviar_em_segundos") val reenviarEmSegundos: Int? = null,
)

/** Corpo de `POST /functions/v1/definir-senha` (contrato 0.2.112). */
@Serializable
data class DefinirSenhaRequisicaoDto(
    @SerialName("nova_senha") val novaSenha: String,
    @SerialName("manter_dispositivo_atual") val manterDispositivoAtual: Boolean,
    @SerialName("device_token_atual") val deviceTokenAtual: String? = null,
    @SerialName("refresh_token") val refreshToken: String? = null,
)

/** Resposta 200 de `POST /functions/v1/definir-senha` (contrato 0.2.112). */
@Serializable
data class DefinirSenhaRespostaDto(
    @SerialName("ok") val ok: Boolean,
    @SerialName("precisa_definir_senha") val precisaDefinirSenha: Boolean? = null,
    @SerialName("dispositivos_revogados") val dispositivosRevogados: Int? = null,
    @SerialName("sessao") val sessao: SessaoDto? = null,
)

/** Corpo vazio de `POST /functions/v1/revogar-dispositivos` (contrato 0.2.112). */
@Serializable
class RevogarDispositivosRequisicaoDto

/** Resposta 200 de `POST /functions/v1/revogar-dispositivos` (contrato 0.2.112). */
@Serializable
data class RevogarDispositivosRespostaDto(
    @SerialName("ok") val ok: Boolean,
    @SerialName("dispositivos_revogados") val dispositivosRevogados: Int,
)

/** Resposta 200 de `/rest/v1/rpc/estado_autenticacao` (contrato 0.2.112, schema `EstadoAutenticacao`). */
@Serializable
data class EstadoAutenticacaoDto(
    @SerialName("autenticado") val autenticado: Boolean,
    @SerialName("dispositivo_verificado") val dispositivoVerificado: Boolean,
    @SerialName("precisa_definir_senha") val precisaDefinirSenha: Boolean,
    @SerialName("tem_conta") val temConta: Boolean,
)
