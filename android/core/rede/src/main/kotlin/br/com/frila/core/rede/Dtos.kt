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

/** Corpo de `POST /auth/v1/token?grant_type=refresh_token`. */
@Serializable
data class RenovarTokenDto(
    @SerialName("refresh_token") val refreshToken: String,
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

/**
 * Avaliação que o chamador já deu a este turno (schema `Avaliacao`, MEDIDO em
 * `iOS/Contrato/openapi.yaml:4749`). O contrato exige `turno_id` e `resposta`; aqui ficam
 * defensivamente opcionais com default — mesmo padrão já usado em `TurnoDto.checkin`/`avaliacao`
 * para servidor mais antigo que ainda não mande o campo.
 */
@Serializable
data class AvaliacaoDto(
    @SerialName("turno_id") val turnoId: String? = null,
    @SerialName("resposta") val resposta: Boolean = false,
    @SerialName("criada_em") val criadaEm: String,
)

/** Corpo de `/rpc/avaliar`: avaliação binária (RN07) — "Você trabalharia nesse local de novo?". */
@Serializable
data class AvaliarDto(
    @SerialName("turno_id") val turnoId: String,
    @SerialName("resposta") val resposta: Boolean,
)

/** Corpo de `/rpc/cancelar_posicao` (RN12). */
@Serializable
data class CancelarPosicaoDto(
    @SerialName("posicao_id") val posicaoId: String,
    @SerialName("motivo") val motivo: String,
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
    @SerialName("pode_avaliar") val podeAvaliar: Boolean? = null,
)

/** Envelope de erro PostgREST/Supabase: só `code` é mapeado para domínio; `message` é log, nunca tela. */
@Serializable
data class ErroPostgrestDto(
    @SerialName("code") val code: String,
    @SerialName("message") val message: String,
    @SerialName("details") val details: String? = null,
    @SerialName("hint") val hint: String? = null,
)

/**
 * Corpo de `/rpc/fazer_checkin` (schema `RegistroDePresenca`, MEDIDO em
 * `iOS/Contrato/openapi.yaml:4573`). `distanciaM` nulo quando o aparelho não tem localização no
 * momento do toque (sem sinal, permissão negada, GPS impreciso) — RN22: o app nunca manda a
 * coordenada, só a distância já calculada no aparelho.
 */
@Serializable
data class RegistroDePresencaDto(
    @SerialName("turno_id") val turnoId: String,
    @SerialName("distancia_m") val distanciaM: Int?,
    @SerialName("registrado_em") val registradoEm: String,
)

/**
 * Resposta de `/rpc/fazer_checkin` (schema `ResultadoRegistro`, MEDIDO em
 * `iOS/Contrato/openapi.yaml:4587`). `tipo`: `geolocalizado` ou `manual`. `verificacao`:
 * `pendente`, `verificado` ou `nao_verificado` — só `verificado` conta a favor da taxa de
 * comparecimento (RN06/RN22).
 */
@Serializable
data class ResultadoRegistroDto(
    @SerialName("turno_id") val turnoId: String,
    @SerialName("tipo") val tipo: String,
    @SerialName("verificacao") val verificacao: String,
    @SerialName("registrado_em") val registradoEm: String,
    @SerialName("distancia_m") val distanciaM: Int? = null,
)

/** Coordenada geográfica de rede (schema `Coordenada`, MEDIDO em `iOS/Contrato/openapi.yaml:3825`). */
@Serializable
data class CoordenadaDto(
    @SerialName("latitude") val latitude: Double,
    @SerialName("longitude") val longitude: Double,
)

/**
 * Janela semanal de disponibilidade (schema `JanelaDeDisponibilidade`, MEDIDO em
 * `iOS/Contrato/openapi.yaml:4017`). `dia_semana`: 0 = domingo. As chaves no fio são
 * `hora_inicio`/`hora_fim`, não `inicio`/`fim` — só o nome Kotlin da propriedade é curto.
 */
@Serializable
data class JanelaDeDisponibilidadeDto(
    @SerialName("dia_semana") val diaSemana: Int,
    @SerialName("hora_inicio") val inicio: String,
    @SerialName("hora_fim") val fim: String,
)

/**
 * Perfil de profissional do chamador (schema `PerfilProfissional`, MEDIDO em
 * `iOS/Contrato/openapi.yaml:4065`), resposta de `/rpc/meu_perfil_profissional` (RF03/RF16).
 */
@Serializable
data class PerfilProfissionalDto(
    @SerialName("id") val id: String,
    @SerialName("usuario_id") val usuarioId: String,
    @SerialName("funcoes") val funcoes: List<FuncaoDto> = emptyList(),
    @SerialName("ponto_base") val pontoBase: CoordenadaDto? = null,
    @SerialName("disponibilidades") val disponibilidades: List<JanelaDeDisponibilidadeDto> = emptyList(),
    @SerialName("reputacao") val reputacao: ReputacaoDto,
)

/**
 * Corpo de `POST /functions/v1/excluir-conta`. `confirmar: true` é a única confirmação
 * aceita — o contrato declara `enum: [true]` (RF25).
 */
@Serializable
data class ConfirmarExclusaoDto(
    @SerialName("confirmar") val confirmar: Boolean = true,
)

/**
 * Resposta de `/functions/v1/excluir-conta` (schema `ExclusaoDeConta`, MEDIDO em
 * `iOS/Contrato/openapi.yaml:5296`). `dadosApagadosAte`: até 15 dias depois do pedido (RF25),
 * limite para purga de backups/retenção LGPD.
 */
@Serializable
data class ExclusaoDeContaDto(
    @SerialName("perfil_removido_em") val perfilRemovidoEm: String,
    @SerialName("dados_apagados_ate") val dadosApagadosAte: String,
    @SerialName("turnos_cancelados") val turnosCancelados: Int,
)
