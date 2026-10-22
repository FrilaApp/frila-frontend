package br.com.frila.core.rede

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * DTOs de `/rpc/vagas_abertas`, contra o schema `VagaNaLista` do contrato OpenAPI 0.2.45
 * (`iOS/Contrato/openapi.yaml`, MEDIDO: schema `VagaNaLista`, linha 4369).
 */
@Serializable
data class FuncaoDto(
    @SerialName("id") val id: String,
    @SerialName("nome") val nome: String,
    @SerialName("categoria") val categoria: String,
)

@Serializable
data class ReputacaoDto(
    @SerialName("positivas") val positivas: Int,
    @SerialName("total") val total: Int,
    @SerialName("taxa_comparecimento") val taxaComparecimento: Double? = null,
    @SerialName("turnos_considerados") val turnosConsiderados: Int,
    @SerialName("turnos_realizados") val turnosRealizados: Int,
)

@Serializable
data class PerfilPublicoDto(
    @SerialName("id") val id: String,
    @SerialName("tipo") val tipo: String,
    @SerialName("nome") val nome: String,
    @SerialName("funcoes") val funcoes: List<String>? = null,
    @SerialName("reputacao") val reputacao: ReputacaoDto,
)

@Serializable
data class InclusosDto(
    @SerialName("inclui_refeicao") val incluiRefeicao: Boolean,
    @SerialName("inclui_transporte") val incluiTransporte: Boolean,
    @SerialName("exige_material_proprio") val exigeMaterialProprio: Boolean,
)

@Serializable
data class VagaAbertaDto(
    @SerialName("id") val id: String,
    @SerialName("funcao") val funcao: FuncaoDto,
    @SerialName("estabelecimento") val estabelecimento: PerfilPublicoDto,
    @SerialName("inicio_em") val inicioEm: String,
    @SerialName("fim_em") val fimEm: String,
    @SerialName("local") val local: String,
    @SerialName("regiao_administrativa") val regiaoAdministrativa: String,
    @SerialName("distancia_km") val distanciaKm: Double,
    @SerialName("valor_centavos") val valorCentavos: Long,
    @SerialName("posicoes_abertas") val posicoesAbertas: Int,
    @SerialName("inclusos") val inclusos: InclusosDto,
    @SerialName("modo") val modo: String,
)

/** Corpo de `POST /auth/v1/otp`: solicitação de código por e-mail. */
@Serializable
data class EntrarOtpDto(
    @SerialName("email") val email: String,
)

/** Corpo de `POST /auth/v1/verify` (type: email): verificação do código de 6 dígitos. */
@Serializable
data class VerificarOtpDto(
    @SerialName("email") val email: String,
    @SerialName("token") val codigo: String,
    @SerialName("type") val tipo: String = "email",
)

/** Resposta de sessão autenticada: `access_token`, `refresh_token`, `token_type`, `expires_in`. */
@Serializable
data class SessaoDto(
    @SerialName("access_token") val accessToken: String,
    @SerialName("refresh_token") val refreshToken: String,
    @SerialName("token_type") val tokenType: String,
    @SerialName("expires_in") val expiresIn: Long,
)

/** Envelope de erro PostgREST/Supabase: só `code` é mapeado para domínio; `message` é log, nunca tela. */
@Serializable
data class ErroPostgrestDto(
    @SerialName("code") val code: String,
    @SerialName("message") val message: String,
    @SerialName("details") val details: String? = null,
    @SerialName("hint") val hint: String? = null,
)
