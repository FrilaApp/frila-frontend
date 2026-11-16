package br.com.frila.core.rede

import kotlinx.serialization.EncodeDefault
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement

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
    /** URL assinada (1 h) da foto aprovada; só vem para leitor com vínculo (0.2.54). Ausente vale sem foto. */
    @SerialName("foto_url") val fotoUrl: String? = null,
    /** Identificador opaco da foto exibida, o que `denunciar.midia_id` recebe (0.2.54). */
    @SerialName("foto_id") val fotoId: String? = null,
    /**
     * Perfil rico (0.2.53) e `no_frila_desde` (0.2.88). Todos opcionais: a Equipe e as vagas ignoram.
     * `nome` vem só com primeiro nome e inicial do sobrenome para a casa sem candidatura, turno ou equipe
     * com o profissional (0.2.88).
     */
    @SerialName("apresentacao") val apresentacao: String? = null,
    @SerialName("experiencia_faixa") val experienciaFaixa: String? = null,
    @SerialName("onde_trabalhei") val ondeTrabalhei: String? = null,
    @SerialName("cursos") val cursos: List<String>? = null,
    @SerialName("idiomas") val idiomas: List<String>? = null,
    @SerialName("servicos") val servicos: List<ServicoNoPerfilDto>? = null,
    @SerialName("regioes") val regioes: List<RegiaoAdministrativaDto>? = null,
    @SerialName("atende_todo_df") val atendeTodoDf: Boolean? = null,
    @SerialName("no_frila_desde") val noFrilaDesde: String? = null,
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

/**
 * Resumo da vaga retornado em `/rpc/meus_turnos` e `/rpc/minhas_candidaturas` (schema `VagaResumo`,
 * MEDIDO em `iOS/Contrato/openapi.yaml:4455`).
 */
@Serializable
data class VagaResumoDto(
    @SerialName("id") val id: String,
    @SerialName("funcao") val funcao: String,
    @SerialName("local") val local: String,
    @SerialName("regiao_administrativa") val regiaoAdministrativa: String,
    @SerialName("inicio_em") val inicioEm: String,
    @SerialName("fim_em") val fimEm: String,
    @SerialName("valor_centavos") val valorCentavos: Long,
    @SerialName("ponto") val ponto: CoordenadaDto? = null,
)

/**
 * Cancelamento de um turno lido em `/rpc/meus_turnos` (schema `CancelamentoDoTurno`, MEDIDO em
 * `iOS/Contrato/openapi.yaml:4702`, RN12). Sem `motivo` (decisão de produto de 02/10/2026).
 */
@Serializable
data class CancelamentoDoTurnoDto(
    @SerialName("causa") val causa: String,
    @SerialName("falta") val falta: Boolean,
    @SerialName("cancelada_em") val canceladaEm: String,
)

/**
 * Avaliação que o chamador já deu a este turno (schema `Avaliacao`, MEDIDO em
 * `iOS/Contrato/openapi.yaml:4749`). O contrato exige `turno_id` e `resposta`; aqui ficam
 * defensivamente opcionais com default para servidor mais antigo que ainda não mande o campo.
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
 * Resposta de `/rpc/meus_turnos` (schema `Turno`, MEDIDO em `iOS/Contrato/openapi.yaml:4613` e
 * gerado por `privado.turno_em_json`).
 * RN12: turno cancelado continua na lista, com `estado: cancelada` e objeto `cancelamento`.
 */
@Serializable
data class TurnoDto(
    @SerialName("id") val id: String,
    @SerialName("posicao_id") val posicaoId: String,
    @SerialName("vaga") val vaga: VagaResumoDto,
    @SerialName("contraparte") val contraparte: PerfilPublicoDto,
    @SerialName("contato_visivel_ate") val contatoVisivelAte: String,
    @SerialName("a_caminho_em") val aCaminhoEm: String? = null,
    @SerialName("checkin_em") val checkinEm: String? = null,
    @SerialName("checkin_tipo") val checkinTipo: String? = null,
    @SerialName("checkin_distancia_m") val checkinDistanciaM: Int? = null,
    @SerialName("checkin_confirmado_em") val checkinConfirmadoEm: String? = null,
    @SerialName("checkout_em") val checkoutEm: String? = null,
    @SerialName("checkout_distancia_m") val checkoutDistanciaM: Int? = null,
    @SerialName("verificacao") val verificacao: String,
    @SerialName("valor_acordado_centavos") val valorAcordadoCentavos: Long,
    @SerialName("pode_avaliar") val podeAvaliar: Boolean,
    @SerialName("estado") val estado: String? = null,
    @SerialName("avaliacao") val avaliacao: AvaliacaoDto? = null,
    @SerialName("cancelamento") val cancelamento: CancelamentoDoTurnoDto? = null,
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

/**
 * Corpo de `POST /rest/v1/rpc/abrir_suporte` (RF12/RF23, UC14). Só a categoria normativa vai
 * ao backend — nunca relato de texto livre nem foto (RN15).
 */
@Serializable
data class AbrirSuporteDto(
    @SerialName("turno_id") val turnoId: String,
    @SerialName("categoria") val categoria: String,
    @SerialName("chave") val chave: String,
)

/**
 * Resposta de `/rpc/abrir_suporte` (schema `Protocolo`, MEDIDO em
 * `iOS/Contrato/openapi.yaml:4921`). `tipo` é sempre `"suporte"` para esta chamada.
 */
@Serializable
data class ProtocoloDto(
    @SerialName("ocorrencia_id") val ocorrenciaId: String,
    @SerialName("tipo") val tipo: String,
    @SerialName("criada_em") val criadaEm: String,
    @SerialName("prazo_resposta_ate") val prazoRespostaAte: String,
)

/**
 * Corpo de `POST /rest/v1/rpc/bloquear` (RF26, UC17). Imediato, sem depender da Equipe Frila, e
 * idempotente. `alvo_id` é o `id` do `PerfilPublico`, nunca o id de conta (RN10).
 */
@Serializable
data class BloquearDto(
    @SerialName("alvo_tipo") val alvoTipo: String,
    @SerialName("alvo_id") val alvoId: String,
)

/**
 * Corpo de `POST /rest/v1/rpc/desbloquear` (contrato 0.2.51, decisão A8, RF26). O par é o mesmo
 * que `/rpc/bloquear` recebe: `alvo_id` é o `id` do `PerfilPublico`, nunca o id de conta (RN10).
 */
@Serializable
data class DesbloquearDto(
    @SerialName("alvo_tipo") val alvoTipo: String,
    @SerialName("alvo_id") val alvoId: String,
)

/**
 * Resposta de `/rpc/desbloquear` (schema `Bloqueio`). Devolve o par recebido e o `criado_em` do
 * bloqueio que deixou de valer; na chamada repetida, o instante da chamada.
 */
@Serializable
data class BloqueioDto(
    @SerialName("alvo_tipo") val alvoTipo: String,
    @SerialName("alvo_id") val alvoId: String,
    @SerialName("criado_em") val criadoEm: String,
)

/** Item de `/rpc/listar_bloqueios` (schema `ItemBloqueio`, contrato 0.2.51). Sem id de conta (RN10). */
@Serializable
data class ItemBloqueioDto(
    @SerialName("alvo_tipo") val alvoTipo: String,
    @SerialName("alvo_id") val alvoId: String,
    @SerialName("nome") val nome: String,
    @SerialName("criado_em") val criadoEm: String,
)

/**
 * Resposta de `/rpc/minha_identidade_status` e de `/rpc/confirmar_envio_verificacao` (schema
 * `StatusVerificacao`, RN14, contrato 0.2.50). `motivo` e `prazo_envio_ate` são nulos sem exigência
 * aberta; o cliente não decide nada a partir do prazo (VP-72).
 */
@Serializable
data class StatusVerificacaoDto(
    @SerialName("status_verificacao") val statusVerificacao: String,
    @SerialName("motivo") val motivo: String? = null,
    @SerialName("prazo_envio_ate") val prazoEnvioAte: String? = null,
    @SerialName("identidade_verificada") val identidadeVerificada: Boolean,
)

/** Corpo de `POST /rest/v1/rpc/solicitar_upload_verificacao` (RN14): `rg` ou `cnh`. */
@Serializable
data class SolicitarUploadVerificacaoDto(
    @SerialName("documento_tipo") val documentoTipo: String,
)

/** Uma URL assinada de upload, por parte do documento (`frente`, `verso` ou `selfie`). */
@Serializable
data class ParteUploadDto(
    @SerialName("parte") val parte: String,
    @SerialName("url") val url: String,
)

/**
 * Resposta de `/rpc/solicitar_upload_verificacao` (schema `UploadVerificacao`, RN14): URLs
 * assinadas válidas por 2 horas (`expira_em`). A URL é opaca para o cliente (VP-71).
 */
@Serializable
data class UploadVerificacaoDto(
    @SerialName("expira_em") val expiraEm: String,
    @SerialName("partes") val partes: List<ParteUploadDto>,
)

/**
 * Corpo de `POST /rest/v1/rpc/denunciar` (RF26, UC17). `chamada_id` é opcional desde o contrato
 * 0.2.71 (CD-S13): associa a denúncia à chamada direta, que precisa existir e envolver o
 * denunciante e o alvo (`422 campo_invalido`, `details: chamada_id`). Sem chamada, o campo segue
 * como `null`, que o contrato aceita (`oneOf: Uuid | null`). `midia_id` (0.2.54) não é modelado
 * aqui: o contrato não aceita `null` nele e nenhuma tela do Android denuncia foto ainda.
 * `alvo_id` é o `id` do `PerfilPublico`, nunca o id de conta (RN10).
 */
@Serializable
data class DenunciarDto(
    @SerialName("alvo_tipo") val alvoTipo: String,
    @SerialName("alvo_id") val alvoId: String,
    @SerialName("turno_id") val turnoId: String? = null,
    @SerialName("motivo") val motivo: String,
    @SerialName("relato") val relato: String,
    @SerialName("chave") val chave: String,
    @SerialName("chamada_id") val chamadaId: String? = null,
)

/** Corpo de `POST /rest/v1/rpc/sair_da_equipe` (contrato 0.2.72, LGPD art. 18). */
@Serializable
data class SairDaEquipeDto(
    @SerialName("estabelecimento_id") val estabelecimentoId: String,
)

/**
 * Item de `/rpc/meus_estabelecimentos` (schema `EstabelecimentoDaConta`, contrato 0.2.73):
 * `papel` é o de quem chama em cada casa. `tipo` e `reputacao` são opcionais no contrato.
 */
@Serializable
data class EstabelecimentoDaContaDto(
    @SerialName("id") val id: String,
    @SerialName("nome") val nome: String,
    @SerialName("papel") val papel: String,
    @SerialName("tipo") val tipo: String? = null,
    @SerialName("reputacao") val reputacao: ReputacaoDto? = null,
)

/** Corpo de `POST /rest/v1/rpc/convidar_membro` (0.2.73, RF21): só o administrador convida. */
@Serializable
data class ConvidarMembroDto(
    @SerialName("estabelecimento_id") val estabelecimentoId: String,
    @SerialName("email") val email: String,
    @SerialName("papel") val papel: String,
)

/** Resposta de `/rpc/convidar_membro`: o `token` é opaco (64 hex), de uso único, válido por 7 dias. */
@Serializable
data class ConviteMembroDto(
    @SerialName("convite_id") val conviteId: String,
    @SerialName("token") val token: String,
    @SerialName("expira_em") val expiraEm: String,
    @SerialName("estabelecimento_id") val estabelecimentoId: String? = null,
    @SerialName("email") val email: String? = null,
    @SerialName("papel") val papel: String? = null,
)

/** Corpo de `POST /rest/v1/rpc/aceitar_convite_membro`. */
@Serializable
data class AceitarConviteMembroDto(
    @SerialName("token") val token: String,
)

/** Resposta de `/rpc/aceitar_convite_membro`; `status` é `membro_adicionado`. Todos os campos são opcionais no contrato. */
@Serializable
data class MembroAdicionadoDto(
    @SerialName("status") val status: String? = null,
    @SerialName("membro_id") val membroId: String? = null,
    @SerialName("estabelecimento_id") val estabelecimentoId: String? = null,
    @SerialName("usuario_id") val usuarioId: String? = null,
    @SerialName("papel") val papel: String? = null,
)

/** Corpo de `POST /rest/v1/rpc/remover_membro`; `membro_id` aceita o id do membro ou do usuário. */
@Serializable
data class RemoverMembroDto(
    @SerialName("estabelecimento_id") val estabelecimentoId: String,
    @SerialName("membro_id") val membroId: String,
)

/** Resposta de `/rpc/remover_membro`; `status` é `membro_removido`. */
@Serializable
data class MembroRemovidoDto(
    @SerialName("status") val status: String? = null,
    @SerialName("removido") val removido: Boolean? = null,
    @SerialName("estabelecimento_id") val estabelecimentoId: String? = null,
    @SerialName("membro_id") val membroId: String? = null,
    @SerialName("usuario_id") val usuarioId: String? = null,
)

/** Corpo de `POST /rest/v1/rpc/transferir_administracao`; `novo_admin_id` aceita o id do membro ou do usuário. */
@Serializable
data class TransferirAdministracaoDto(
    @SerialName("estabelecimento_id") val estabelecimentoId: String,
    @SerialName("novo_admin_id") val novoAdminId: String,
)

/** Resposta de `/rpc/transferir_administracao`; `status` é `administracao_transferida`. */
@Serializable
data class AdministracaoTransferidaDto(
    @SerialName("status") val status: String? = null,
    @SerialName("estabelecimento_id") val estabelecimentoId: String? = null,
    @SerialName("novo_admin_id") val novoAdminId: String? = null,
    @SerialName("novo_admin_usuario_id") val novoAdminUsuarioId: String? = null,
    @SerialName("papel") val papel: String? = null,
)

/**
 * Corpo de `POST /rest/v1/rpc/equipe_de_confianca`. O contrato descreve esta leitura em GET com
 * `?estabelecimento_id=`, mas a função é `plpgsql` sem `STABLE` (VOLATILE por padrão), e o PostgREST
 * só aceita função volátil em POST, que o iOS também usa (`SupabaseApiCliente.rpc`).
 */
@Serializable
data class EstabelecimentoParametrosDto(
    @SerialName("estabelecimento_id") val estabelecimentoId: String,
)

/** Schema `MembroDaEquipe`: corpo e resposta de `/rpc/remover_da_equipe` (e `/rpc/incluir_na_equipe`). */
@Serializable
data class MembroDaEquipeDto(
    @SerialName("estabelecimento_id") val estabelecimentoId: String,
    @SerialName("profissional_id") val profissionalId: String,
)

/**
 * Corpo de `POST /rest/v1/rpc/cadastrar_estabelecimento` (schema `NovoEstabelecimento`, RF02, UC10).
 * `documento` é CPF (11) ou CNPJ (14), só dígitos. `tipo` leva a chave de fio (`food_service`,
 * `evento`, `varejo`, `logistica`, `servico_domestico`, `outro`). A coordenada vai aninhada em `ponto`.
 */
@Serializable
data class NovoEstabelecimentoDto(
    @SerialName("nome") val nome: String,
    @SerialName("documento") val documento: String,
    @SerialName("tipo") val tipo: String,
    @SerialName("endereco") val endereco: String,
    @SerialName("regiao_administrativa") val regiaoAdministrativa: String,
    @SerialName("ponto") val ponto: CoordenadaDto,
)

/**
 * Resposta de `/rpc/cadastrar_estabelecimento` (schema `Estabelecimento`): o chamador entra como
 * `administrador`. É o único lugar em que o `documento` volta (RN15).
 */
@Serializable
data class EstabelecimentoDto(
    @SerialName("id") val id: String,
    @SerialName("nome") val nome: String,
    @SerialName("documento") val documento: String,
    @SerialName("tipo") val tipo: String,
    @SerialName("endereco") val endereco: String,
    @SerialName("regiao_administrativa") val regiaoAdministrativa: String,
    @SerialName("ponto") val ponto: CoordenadaDto,
    @SerialName("papel") val papel: String,
)

/**
 * Corpo de `/rpc/publicar_vaga` (schema `NovaVaga`, RN02). Instantes em UTC ISO-8601 (RN18); o
 * valor é em centavos por posição. `modo` vale `urgencia` ou `selecao`. `chave` é gerada uma vez
 * por publicação: reenviar com a mesma chave devolve a mesma vaga. A coordenada vai aninhada em `ponto`.
 */
@Serializable
data class NovaVagaDto(
    @SerialName("estabelecimento_id") val estabelecimentoId: String,
    @SerialName("funcao_id") val funcaoId: String,
    @SerialName("inicio_em") val inicioEm: String,
    @SerialName("fim_em") val fimEm: String,
    @SerialName("local") val local: String,
    @SerialName("regiao_administrativa") val regiaoAdministrativa: String,
    @SerialName("ponto") val ponto: CoordenadaDto,
    @SerialName("valor_centavos") val valorCentavos: Long,
    @SerialName("posicoes") val posicoes: Int,
    @SerialName("inclui_refeicao") val incluiRefeicao: Boolean,
    @SerialName("inclui_transporte") val incluiTransporte: Boolean,
    @SerialName("exige_material_proprio") val exigeMaterialProprio: Boolean,
    @SerialName("responsavel_local") val responsavelLocal: String,
    @SerialName("traje") val traje: String? = null,
    @SerialName("participa_rateio") val participaRateio: Boolean? = null,
    @SerialName("observacoes") val observacoes: String? = null,
    @SerialName("modo") val modo: String,
    @SerialName("alerta_antecedencia_min") val alertaAntecedenciaMin: Int = 180,
    @SerialName("chave") val chave: String,
)

/** Resposta de `/rpc/publicar_vaga` (schema `VagaPublicada`): a vaga e uma posição por unidade pedida. */
@Serializable
data class VagaPublicadaDto(
    @SerialName("vaga_id") val vagaId: String,
    @SerialName("posicoes") val posicoes: List<String>,
)

/**
 * Resposta de `/rpc/meu_estabelecimento` (schema `MeuEstabelecimento`): o cadastro como um membro o lê,
 * sem o `documento` (RN15). Traz o endereço, a Região Administrativa e o ponto que preenchem a
 * publicação de uma vaga; `papel` é o de quem chama.
 */
@Serializable
data class MeuEstabelecimentoDto(
    @SerialName("id") val id: String,
    @SerialName("nome") val nome: String,
    @SerialName("tipo") val tipo: String,
    @SerialName("endereco") val endereco: String,
    @SerialName("regiao_administrativa") val regiaoAdministrativa: String,
    @SerialName("ponto") val ponto: CoordenadaDto,
    @SerialName("papel") val papel: String,
)

/**
 * Parâmetro de `/rpc/candidatos_da_vaga`. O contrato o descreve em GET com `vaga_id` na query; o app o
 * envia em POST com o corpo (função volátil só aceita POST no PostgREST), como `equipe_de_confianca`.
 */
@Serializable
data class CandidatosDaVagaParametrosDto(
    @SerialName("vaga_id") val vagaId: String,
)

/**
 * Item de `/rpc/candidatos_da_vaga` (schema `Candidato`, contrato 0.2.73), em ordem de chegada (RN06).
 * `da_equipe` (0.2.38) só alimenta o selo "da sua equipe", nunca a ordem; ausente vale `false`.
 */
@Serializable
data class CandidatoDto(
    @SerialName("candidatura_id") val candidaturaId: String,
    @SerialName("profissional") val profissional: PerfilPublicoDto,
    @SerialName("criada_em") val criadaEm: String,
    @SerialName("da_equipe") val daEquipe: Boolean = false,
)

/** Corpo de `POST /rest/v1/rpc/escolher_candidato` (RF09/RN19): a candidatura que a casa escolhe. */
@Serializable
data class EscolherCandidatoDto(
    @SerialName("candidatura_id") val candidaturaId: String,
)

/**
 * Resposta de `/rpc/escolher_candidato` (schema `ResultadoConfirmacao`): o profissional confirmado,
 * com `estado = confirmada`. `contato` foi descontinuado na 0.2.49: ausente e nulo valem o mesmo.
 */
@Serializable
data class ResultadoConfirmacaoDto(
    @SerialName("estado") val estado: String,
    @SerialName("posicao_id") val posicaoId: String,
    @SerialName("turno_id") val turnoId: String,
    @SerialName("contato") val contato: ContatoDto? = null,
)

/**
 * Parâmetros de `/rpc/painel_estabelecimento`. O contrato os descreve em GET com query; o app os envia
 * em POST com o corpo (função volátil só aceita POST no PostgREST), como `equipe_de_confianca`. `de` e
 * `ate` vão em ISO-8601 UTC (RN18).
 */
@Serializable
data class PainelParametrosDto(
    @SerialName("estabelecimento_id") val estabelecimentoId: String,
    @SerialName("de") val de: String,
    @SerialName("ate") val ate: String,
)

/**
 * Resposta de `/rpc/painel_estabelecimento` (schema `Painel`, RF20/UC07): as vagas do estabelecimento na
 * janela pedida e os turnos com check-in manual esperando a confirmação da casa.
 */
@Serializable
data class PainelDto(
    @SerialName("estabelecimento_id") val estabelecimentoId: String,
    @SerialName("vagas") val vagas: List<VagaNoPainelDto>,
    @SerialName("checkins_pendentes") val checkinsPendentes: List<String>,
)

/**
 * Uma vaga no painel (schema `VagaNoPainel`). `modo` vale `urgencia` ou `selecao`; `estado`, `publicada`,
 * `preenchida`, `encerrada` ou `cancelada`. `republicavel_em_urgencia` (0.2.41) ausente vale nulo.
 */
@Serializable
data class VagaNoPainelDto(
    @SerialName("vaga") val vaga: VagaResumoDto,
    @SerialName("republicavel_em_urgencia") val republicavelEmUrgencia: Int? = null,
    @SerialName("modo") val modo: String,
    @SerialName("estado") val estado: String,
    @SerialName("oculta") val oculta: Boolean,
    @SerialName("alerta_vaga_vazia") val alertaVagaVazia: Boolean,
    @SerialName("candidatos_pendentes") val candidatosPendentes: Int,
    @SerialName("posicoes") val posicoes: List<PosicaoNoPainelDto>,
)

/**
 * Uma posição no painel (schema `PosicaoNoPainel`). `estado` vale `aberta`, `confirmada`, `cumprida` ou
 * `cancelada`. Os campos do check-in e do cancelamento (0.2.31) são opcionais no contrato.
 */
@Serializable
data class PosicaoNoPainelDto(
    @SerialName("id") val id: String,
    @SerialName("estado") val estado: String,
    @SerialName("profissional") val profissional: PerfilPublicoDto? = null,
    @SerialName("turno_id") val turnoId: String? = null,
    @SerialName("verificacao") val verificacao: String? = null,
    @SerialName("em_atraso") val emAtraso: Boolean,
    @SerialName("a_caminho_em") val aCaminhoEm: String? = null,
    @SerialName("checkin_em") val checkinEm: String? = null,
    @SerialName("checkin_tipo") val checkinTipo: String? = null,
    @SerialName("checkin_confirmado_em") val checkinConfirmadoEm: String? = null,
    @SerialName("cancelamento") val cancelamento: CancelamentoDaPosicaoDto? = null,
)

/** Por que uma posição que tinha profissional foi cancelada (schema `CancelamentoDaPosicao`, RN12). */
@Serializable
data class CancelamentoDaPosicaoDto(
    @SerialName("causa") val causa: String,
    @SerialName("falta") val falta: Boolean,
    @SerialName("motivo") val motivo: String? = null,
    @SerialName("cancelada_em") val canceladaEm: String,
)

/** Corpo de `POST /rest/v1/rpc/confirmar_checkin_manual` (RF13/RN22): o turno cujo check-in manual a casa confirma. */
@Serializable
data class ConfirmarCheckinManualDto(
    @SerialName("turno_id") val turnoId: String,
)

// ---------------------------------------------------------------------------------------------
// Contratação direta e busca de profissionais (contrato 0.2.88, frila-documentacao#259).
// Campos opcionais de corpo de requisição usam `@EncodeDefault(NEVER)`: ausente e `null` não
// significam o mesmo no contrato (ex.: `pausado_ate: null` tira a pausa; ausente mantém).
// ---------------------------------------------------------------------------------------------

/** Região administrativa do DF, do catálogo fechado (schema `RegiaoAdministrativa`, RN44). */
@Serializable
data class RegiaoAdministrativaDto(
    @SerialName("id") val id: Int,
    @SerialName("numero") val numero: String,
    @SerialName("nome") val nome: String,
    @SerialName("ativo") val ativo: Boolean? = null,
)

/** Especialidade fechada de uma função (schema `Especialidade`, RN44). */
@Serializable
data class EspecialidadeDto(
    @SerialName("id") val id: String,
    @SerialName("funcao_id") val funcaoId: String,
    @SerialName("nome") val nome: String,
    @SerialName("ativo") val ativo: Boolean? = null,
)

/**
 * Um serviço como sai nas leituras (schema `ServicoNoPerfil`). `unidade` vale `hora`, `diaria`, `evento`,
 * `pacote`, `por_pessoa` ou `a_combinar`; `leva_material`, `sim`, `nao` ou `depende`.
 */
@Serializable
data class ServicoNoPerfilDto(
    @SerialName("funcao") val funcao: FuncaoDto,
    @SerialName("unidade") val unidade: String,
    @SerialName("valor_centavos") val valorCentavos: Long? = null,
    @SerialName("valor_max_centavos") val valorMaxCentavos: Long? = null,
    @SerialName("horas_incluidas") val horasIncluidas: Int? = null,
    @SerialName("minimo_horas") val minimoHoras: Int? = null,
    @SerialName("duracao_tipica_h") val duracaoTipicaH: Int? = null,
    @SerialName("ate_pessoas") val atePessoas: Int? = null,
    @SerialName("minimo_pessoas") val minimoPessoas: Int? = null,
    @SerialName("descricao_pacote") val descricaoPacote: String? = null,
    @SerialName("inclui") val inclui: String? = null,
    @SerialName("leva_material") val levaMaterial: String? = null,
    @SerialName("especialidades") val especialidades: List<EspecialidadeDto>? = null,
)

/** Um serviço na entrada de `definir_servicos` (schema `ServicoOferecido`); só vai o que a unidade pede. */
@OptIn(ExperimentalSerializationApi::class)
@Serializable
data class ServicoOferecidoDto(
    @SerialName("funcao_id") val funcaoId: String,
    @SerialName("unidade") val unidade: String,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("valor_centavos") val valorCentavos: Long? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("valor_max_centavos") val valorMaxCentavos: Long? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("horas_incluidas") val horasIncluidas: Int? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("minimo_horas") val minimoHoras: Int? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("duracao_tipica_h") val duracaoTipicaH: Int? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("ate_pessoas") val atePessoas: Int? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("minimo_pessoas") val minimoPessoas: Int? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("descricao_pacote") val descricaoPacote: String? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("inclui") val inclui: String? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("leva_material") val levaMaterial: String? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("especialidade_ids") val especialidadeIds: List<String>? = null,
)

/** Corpo de `POST /rest/v1/rpc/definir_servicos`: **substitui** o conjunto (`servicos: []` limpa), até 10. */
@Serializable
data class DefinirServicosDto(
    @SerialName("servicos") val servicos: List<ServicoOferecidoDto>,
)

/**
 * Preferências para receber chamadas (schema `PreferenciaChamadas`, RN30/RN43/RN40).
 * `pendencias_para_busca` lista o que ainda impede de aparecer na busca: `sem_servico_com_preco`,
 * `sem_regiao`, `pausado` ou `sem_aparelho_atualizado`.
 */
@Serializable
data class PreferenciaChamadasDto(
    @SerialName("aceita_de_quem_ja_trabalhou") val aceitaDeQuemJaTrabalhou: Boolean,
    @SerialName("pausado_ate") val pausadoAte: String? = null,
    @SerialName("antecedencia_minima_h") val antecedenciaMinimaH: Int,
    @SerialName("aceita_de") val aceitaDe: String,
    @SerialName("aceita_chamadas") val aceitaChamadas: Boolean? = null,
    @SerialName("pendencias_para_busca") val pendenciasParaBusca: List<String> = emptyList(),
)

/**
 * Corpo de `POST /rest/v1/rpc/definir_preferencia_chamadas`: campo enviado substitui, omitido fica como está.
 * [pausadoAte] é um [JsonElement] para separar "ausente" (`null` do Kotlin: não mexe) de `JsonNull`
 * (tira a pausa) e de uma data `AAAA-MM-DD`. Ligar [aceitaChamadas] exige [versaoTextoBusca].
 */
@OptIn(ExperimentalSerializationApi::class)
@Serializable
data class DefinirPreferenciaChamadasDto(
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("aceita_de_quem_ja_trabalhou") val aceitaDeQuemJaTrabalhou: Boolean? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("pausado_ate") val pausadoAte: JsonElement? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("antecedencia_minima_h") val antecedenciaMinimaH: Int? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("aceita_de") val aceitaDe: String? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("aceita_chamadas") val aceitaChamadas: Boolean? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("versao_texto_busca") val versaoTextoBusca: String? = null,
)

/** Resposta de `meu_perfil_detalhado` e `definir_servicos` (schema `PerfilProfissionalDetalhado`). */
@Serializable
data class PerfilProfissionalDetalhadoDto(
    @SerialName("id") val id: String,
    @SerialName("usuario_id") val usuarioId: String,
    @SerialName("funcoes") val funcoes: List<FuncaoDto> = emptyList(),
    @SerialName("ponto_base") val pontoBase: CoordenadaDto? = null,
    @SerialName("disponibilidades") val disponibilidades: List<JanelaDeDisponibilidadeDto> = emptyList(),
    @SerialName("reputacao") val reputacao: ReputacaoDto,
    @SerialName("apresentacao") val apresentacao: String? = null,
    @SerialName("onde_trabalhei") val ondeTrabalhei: String? = null,
    @SerialName("experiencia_faixa") val experienciaFaixa: String? = null,
    @SerialName("cursos") val cursos: List<String> = emptyList(),
    @SerialName("idiomas") val idiomas: List<String> = emptyList(),
    @SerialName("servicos") val servicos: List<ServicoNoPerfilDto> = emptyList(),
    @SerialName("regioes") val regioes: List<RegiaoAdministrativaDto> = emptyList(),
    @SerialName("atende_todo_df") val atendeTodoDf: Boolean = false,
    @SerialName("preferencia_chamadas") val preferenciaChamadas: PreferenciaChamadasDto? = null,
)

/** Parâmetro de `perfil_publico` (o id do profissional ou do estabelecimento). Vai em POST, como `candidatos_da_vaga`. */
@Serializable
data class PerfilPublicoParametrosDto(
    @SerialName("id") val id: String,
)

/**
 * Um resultado de `buscar_profissionais` (schema `CartaoProfissional`, CD-B07). Sem foto, sem telefone, sem
 * sobrenome completo. `disponivel_no_horario` só vem com horário e quando a grade cobre o horário inteiro.
 * `distancia_faixa`: `ate_5_km`, `de_5_a_15_km` ou `mais_de_15_km`.
 */
@Serializable
data class CartaoProfissionalDto(
    @SerialName("id") val id: String,
    @SerialName("nome") val nome: String,
    @SerialName("servico") val servico: ServicoNoPerfilDto,
    @SerialName("regioes") val regioes: List<RegiaoAdministrativaDto> = emptyList(),
    @SerialName("atende_todo_df") val atendeTodoDf: Boolean = false,
    @SerialName("distancia_faixa") val distanciaFaixa: String,
    @SerialName("reputacao") val reputacao: ReputacaoDto,
    @SerialName("disponivel_no_horario") val disponivelNoHorario: Boolean? = null,
    /** Link de 1 h (`ler-midia`, miniatura de 320 px) da foto aprovada, sem cabeçalho; ausente sem foto (0.2.90, CD-B07). */
    @SerialName("foto_url") val fotoUrl: String? = null,
    /** Identificador opaco da foto, o que `denunciar.midia_id` recebe (0.2.90). */
    @SerialName("foto_id") val fotoId: String? = null,
)

/**
 * Corpo de `POST /rest/v1/rpc/buscar_profissionais`. `inicio_em` e `fim_em` vão sempre juntos; [cursor] é opaco
 * (nunca offset) e as páginas seguintes não contam na cota; [limite] de 1 a 20 (padrão 20 no servidor).
 */
@OptIn(ExperimentalSerializationApi::class)
@Serializable
data class BuscarProfissionaisDto(
    @SerialName("estabelecimento_id") val estabelecimentoId: String,
    @SerialName("funcao_id") val funcaoId: String,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("regiao_id") val regiaoId: Int? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("inicio_em") val inicioEm: String? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("fim_em") val fimEm: String? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("cursor") val cursor: String? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("limite") val limite: Int? = null,
)

/** Resposta de `buscar_profissionais`: até 20 cartões e o cursor da próxima página (`null` na última). */
@Serializable
data class PaginaDeProfissionaisDto(
    @SerialName("itens") val itens: List<CartaoProfissionalDto>,
    @SerialName("proximo_cursor") val proximoCursor: String? = null,
)

/** Uma chamada (schema `Chamada`). `estado`: `aberta`, `aceita`, `recusada`, `expirada`, `cancelada` ou `encerrada`. */
@Serializable
data class ChamadaDto(
    @SerialName("id") val id: String,
    @SerialName("vaga_id") val vagaId: String,
    @SerialName("profissional_id") val profissionalId: String,
    @SerialName("estabelecimento_id") val estabelecimentoId: String,
    @SerialName("estado") val estado: String,
    @SerialName("recado") val recado: String? = null,
    @SerialName("motivo_recusa") val motivoRecusa: String? = null,
    @SerialName("expira_em") val expiraEm: String,
    @SerialName("respondida_em") val respondidaEm: String? = null,
    @SerialName("criada_em") val criadaEm: String,
)

/** A chamada com o essencial do trabalho, para listas (schema `ChamadaResumo`: `Chamada` mais os campos abaixo). */
@Serializable
data class ChamadaResumoDto(
    @SerialName("id") val id: String,
    @SerialName("vaga_id") val vagaId: String,
    @SerialName("profissional_id") val profissionalId: String,
    @SerialName("estabelecimento_id") val estabelecimentoId: String,
    @SerialName("estado") val estado: String,
    @SerialName("recado") val recado: String? = null,
    @SerialName("motivo_recusa") val motivoRecusa: String? = null,
    @SerialName("expira_em") val expiraEm: String,
    @SerialName("respondida_em") val respondidaEm: String? = null,
    @SerialName("criada_em") val criadaEm: String,
    @SerialName("funcao") val funcao: FuncaoDto,
    @SerialName("inicio_em") val inicioEm: String,
    @SerialName("fim_em") val fimEm: String,
    @SerialName("valor_centavos") val valorCentavos: Long,
    @SerialName("outra_parte") val outraParte: PerfilPublicoDto,
)

/**
 * A chamada por inteiro (schema `ChamadaDetalhe`). `local`, `ponto`, `responsavel_local` e `turno_id` só vêm com
 * `estado = aceita` (RN36); antes, o profissional decide pela região e pela faixa de distância. Nunca telefone.
 */
@Serializable
data class ChamadaDetalheDto(
    @SerialName("id") val id: String,
    @SerialName("vaga_id") val vagaId: String,
    @SerialName("profissional_id") val profissionalId: String,
    @SerialName("estabelecimento_id") val estabelecimentoId: String,
    @SerialName("estado") val estado: String,
    @SerialName("recado") val recado: String? = null,
    @SerialName("motivo_recusa") val motivoRecusa: String? = null,
    @SerialName("expira_em") val expiraEm: String,
    @SerialName("respondida_em") val respondidaEm: String? = null,
    @SerialName("criada_em") val criadaEm: String,
    @SerialName("funcao") val funcao: FuncaoDto,
    @SerialName("inicio_em") val inicioEm: String,
    @SerialName("fim_em") val fimEm: String,
    @SerialName("valor_centavos") val valorCentavos: Long,
    @SerialName("outra_parte") val outraParte: PerfilPublicoDto,
    @SerialName("tipo_estabelecimento") val tipoEstabelecimento: String? = null,
    @SerialName("conta_nova") val contaNova: Boolean? = null,
    @SerialName("regiao_administrativa") val regiaoAdministrativa: String,
    @SerialName("distancia_faixa") val distanciaFaixa: String? = null,
    @SerialName("inclui_refeicao") val incluiRefeicao: Boolean,
    @SerialName("inclui_transporte") val incluiTransporte: Boolean,
    @SerialName("exige_material_proprio") val exigeMaterialProprio: Boolean,
    @SerialName("local") val local: String? = null,
    @SerialName("ponto") val ponto: CoordenadaDto? = null,
    @SerialName("responsavel_local") val responsavelLocal: String? = null,
    @SerialName("turno_id") val turnoId: String? = null,
)

/** Resposta de `responder_chamada` (schema `ResultadoChamada`): no aceite traz o turno e o que a RN36 libera. */
@Serializable
data class ResultadoChamadaDto(
    @SerialName("chamada") val chamada: ChamadaDto,
    @SerialName("turno_id") val turnoId: String? = null,
    @SerialName("local") val local: String? = null,
    @SerialName("ponto") val ponto: CoordenadaDto? = null,
    @SerialName("responsavel_local") val responsavelLocal: String? = null,
)

/**
 * Corpo de `POST /rest/v1/rpc/chamar_profissional`. Ou [vagaId] (mais alguém para o mesmo trabalho, até 3
 * abertas) ou os campos da RN02, nunca os dois; [regiaoId] é o da busca e a vaga direta o guarda (0.2.88).
 * [confirmoRecorrencia] só depois de `409 recorrencia_nao_confirmada` (J7, RN45). [chave] é a de idempotência.
 */
@OptIn(ExperimentalSerializationApi::class)
@Serializable
data class ChamarProfissionalDto(
    @SerialName("chave") val chave: String,
    @SerialName("profissional_id") val profissionalId: String,
    @SerialName("estabelecimento_id") val estabelecimentoId: String,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("vaga_id") val vagaId: String? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("funcao_id") val funcaoId: String? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("inicio_em") val inicioEm: String? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("fim_em") val fimEm: String? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("local") val local: String? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("regiao_administrativa") val regiaoAdministrativa: String? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("regiao_id") val regiaoId: Int? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("ponto") val ponto: CoordenadaDto? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("valor_centavos") val valorCentavos: Long? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("inclui_refeicao") val incluiRefeicao: Boolean? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("inclui_transporte") val incluiTransporte: Boolean? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("exige_material_proprio") val exigeMaterialProprio: Boolean? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("responsavel_local") val responsavelLocal: String? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("recado") val recado: String? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("confirmo_recorrencia") val confirmoRecorrencia: Boolean? = null,
)

/** Corpo de `POST /rest/v1/rpc/responder_chamada`: `resposta` vale `aceitar` ou `recusar`. */
@OptIn(ExperimentalSerializationApi::class)
@Serializable
data class ResponderChamadaDto(
    @SerialName("chamada_id") val chamadaId: String,
    @SerialName("resposta") val resposta: String,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("motivo_recusa") val motivoRecusa: String? = null,
)

/** Corpo de `POST /rest/v1/rpc/cancelar_chamada`. */
@Serializable
data class CancelarChamadaDto(
    @SerialName("chamada_id") val chamadaId: String,
)

/** Parâmetro de `detalhe_chamada`. Vai em POST. */
@Serializable
data class DetalheChamadaParametrosDto(
    @SerialName("chamada_id") val chamadaId: String,
)

/** Parâmetros de `minhas_chamadas` (estado, cursor e limite de 1 a 20). Vão em POST. */
@OptIn(ExperimentalSerializationApi::class)
@Serializable
data class MinhasChamadasParametrosDto(
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("estado") val estado: String? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("cursor") val cursor: String? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("limite") val limite: Int? = null,
)

/** Resposta de `minhas_chamadas`: até 20 chamadas, da mais nova para a mais antiga, e o cursor seguinte. */
@Serializable
data class PaginaDeChamadasDto(
    @SerialName("itens") val itens: List<ChamadaResumoDto>,
    @SerialName("proximo_cursor") val proximoCursor: String? = null,
)

/** Corpo de `POST /rest/v1/rpc/publicar_a_partir_da_chamada`: [modo] vale `urgencia` (padrão) ou `selecao`. */
@OptIn(ExperimentalSerializationApi::class)
@Serializable
data class PublicarAPartirDaChamadaDto(
    @SerialName("vaga_id") val vagaId: String,
    @SerialName("chave") val chave: String,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("modo") val modo: String? = null,
)

/**
 * Corpo de `POST /rest/v1/rpc/aceitar_termos` (contrato 0.2.90): a versão dos Termos que a tela exibiu, no formato
 * `AAAA-MM-DD`, só uma versão PUBLICADA (hoje `2026-11-13`; o servidor mantém a lista). O instante do aceite é do servidor; o app não manda data.
 */
@Serializable
data class AceitarTermosDto(
    @SerialName("termos_versao") val termosVersao: String,
)

/** Resposta de `aceitar_termos`: o aceite em vigor (repetir a mesma versão devolve o que já existe). */
@Serializable
data class AceiteDeTermosDto(
    @SerialName("termos_versao") val termosVersao: String,
    @SerialName("aceito_em") val aceitoEm: String,
)
