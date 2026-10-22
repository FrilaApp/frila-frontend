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

/** Corpo de `POST /functions/v1/entrar-demonstracao`: modo demonstração da Google Play. */
@Serializable
data class EntrarDemonstracaoDto(
    @SerialName("email") val email: String,
    @SerialName("codigo") val codigo: String,
)

/** Resposta de sessão autenticada: `access_token`, `refresh_token`, `token_type`, `expires_in`. */
@Serializable
data class SessaoDto(
    @SerialName("access_token") val accessToken: String,
    @SerialName("refresh_token") val refreshToken: String,
    @SerialName("token_type") val tokenType: String,
    @SerialName("expires_in") val expiresIn: Long,
)

/** Corpo de `POST /rest/v1/rpc/candidatar`. */
@Serializable
data class CandidatarDto(
    @SerialName("vaga_id") val vagaId: String,
)

/** Contato da outra parte, devolvido só no modo urgência (confirmada) por `/rpc/candidatar` (RN10). */
@Serializable
data class ContatoDto(
    @SerialName("nome") val nome: String,
    @SerialName("telefone") val telefone: String,
    @SerialName("whatsapp_url") val whatsappUrl: String? = null,
    @SerialName("visivel_ate") val visivelAte: String? = null,
)

/**
 * Resposta de `/rpc/candidatar` (schema `ResultadoCandidatura`, MEDIDO em
 * `iOS/Contrato/openapi.yaml:2199`): `confirmada` no modo urgência (RN19, já com turno e
 * contato), `pendente` no modo seleção (`posicao_id`/`turno_id`/`contato` nulos até a escolha).
 */
@Serializable
data class ResultadoCandidaturaDto(
    @SerialName("estado") val estado: String,
    @SerialName("candidatura_id") val candidaturaId: String,
    @SerialName("posicao_id") val posicaoId: String? = null,
    @SerialName("turno_id") val turnoId: String? = null,
    @SerialName("contato") val contato: ContatoDto? = null,
)

/** Corpo de `POST /rest/v1/rpc/registrar_dispositivo` (RF06/RN15/RNF02). */
@Serializable
data class RegistrarDispositivoDto(
    @SerialName("token_fcm") val tokenFcm: String,
    @SerialName("plataforma") val plataforma: String = "android",
)

/**
 * Resposta de `/rpc/registrar_dispositivo` (schema `Dispositivo`, MEDIDO em
 * `iOS/Contrato/openapi.yaml:3200`). `vinculoId` é nulo quando o backend ainda não o devolve
 * (servidor anterior à 0.2.30) — ver `ValidadorIsolamentoConta` em `:core:seguranca`.
 */
@Serializable
data class DispositivoDto(
    @SerialName("plataforma") val plataforma: String,
    @SerialName("atualizado_em") val atualizadoEm: String,
    @SerialName("vinculo_id") val vinculoId: String? = null,
)

/** Checagem de presença de um turno (`feito_em`), com distância opcional do ponto esperado. */
@Serializable
data class CheckinDto(
    @SerialName("feito_em") val feitoEm: String,
    @SerialName("distancia_metros") val distanciaMetros: Double? = null,
)

/** Avaliação que o chamador já deu a este turno. */
@Serializable
data class AvaliacaoDto(
    @SerialName("positiva") val positiva: Boolean,
    @SerialName("criada_em") val criadaEm: String,
)

/**
 * Resposta de `/rpc/meus_turnos` (schema `Turno`, MEDIDO em `iOS/Contrato/openapi.yaml:2454`).
 * RN12: turno cancelado continua na lista, com `estado: cancelada` — o cancelamento não apaga
 * o registro do que foi combinado.
 */
@Serializable
data class TurnoDto(
    @SerialName("turno_id") val turnoId: String,
    @SerialName("vaga_id") val vagaId: String,
    @SerialName("posicao_id") val posicaoId: String,
    @SerialName("funcao") val funcao: FuncaoDto,
    @SerialName("contraparte") val contraparte: PerfilPublicoDto,
    @SerialName("inicio_em") val inicioEm: String,
    @SerialName("fim_em") val fimEm: String,
    @SerialName("valor_centavos") val valorCentavos: Long,
    @SerialName("estado") val estado: String,
    @SerialName("checkin") val checkin: CheckinDto? = null,
    @SerialName("avaliacao") val avaliacao: AvaliacaoDto? = null,
)

/** Envelope de erro PostgREST/Supabase: só `code` é mapeado para domínio; `message` é log, nunca tela. */
@Serializable
data class ErroPostgrestDto(
    @SerialName("code") val code: String,
    @SerialName("message") val message: String,
    @SerialName("details") val details: String? = null,
    @SerialName("hint") val hint: String? = null,
)
