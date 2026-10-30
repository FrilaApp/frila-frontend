package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.Sessao
import io.ktor.client.HttpClient
import io.ktor.client.HttpClientConfig
import io.ktor.client.call.body
import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.network.sockets.ConnectTimeoutException
import io.ktor.client.network.sockets.SocketTimeoutException
import io.ktor.client.plugins.HttpRequestRetry
import io.ktor.client.plugins.HttpRequestTimeoutException
import io.ktor.client.plugins.HttpResponseValidator
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.plugins.api.createClientPlugin
import io.ktor.client.plugins.auth.Auth
import io.ktor.client.plugins.auth.providers.BearerTokens
import io.ktor.client.plugins.auth.providers.RefreshTokensParams
import io.ktor.client.plugins.auth.providers.bearer
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.plugins.defaultRequest
import io.ktor.client.plugins.logging.LogLevel
import io.ktor.client.plugins.logging.Logging
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.ContentType
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import io.ktor.serialization.kotlinx.json.json
import java.io.IOException
import java.net.UnknownHostException
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import kotlinx.coroutines.CancellationException

/** Erro de API com o código fechado de domínio e os dados crus da resposta. */
class ErroDaApi(
    val codigo: CodigoErroAPI,
    val codigoOriginal: String,
    val detalhes: String?,
    val mensagemCrua: String,
) : Exception("ErroDaApi(codigo=$codigo, codigoOriginal=$codigoOriginal)")

/** Fornece o token de acesso atual para cada requisição (nulo quando não há sessão). */
fun interface ProvedorDeToken {
    fun tokenDeAcesso(): String?
}

/**
 * Cliente HTTP para o backend Supabase do Frila. Timeouts e headers iguais ao iOS
 * (15s por requisição, 60s para o conjunto); mapeia o envelope de erro PostgREST (`code`)
 * para [CodigoErroAPI] do `:core:dominio`.
 */
class ClienteSupabase(
    val baseUrl: String,
    private val apiKey: String,
    private val provedorDeToken: ProvedorDeToken = ProvedorDeToken { null },
    private val armazenamentoDeSessao: ArmazenamentoDeSessao? = null,
    /** RNF01/RNF04: fail-fast pré-voo e interrupção de retry quando a conectividade cai. */
    private val monitorDeConectividade: MonitorDeConectividade? = null,
    engine: HttpClientEngine? = null,
    json: Json = jsonFrila,
) {
    val http: HttpClient = if (engine != null) {
        HttpClient(engine) { configurar(json) }
    } else {
        HttpClient { configurar(json) }
    }

    private fun HttpClientConfig<*>.configurar(json: Json) {
        install(ContentNegotiation) { json(json) }
        // RNF01/RNF04: fail-fast pré-voo — se já sabemos que estamos offline, aborta em 0ms
        // sem tentar o engine, sem esperar timeout nem acionar retry. `onRequest` roda antes de
        // qualquer I/O de verdade (fase `Before` do pipeline de envio).
        install(
            createClientPlugin("FailFastSemConectividade") {
                onRequest { _, _ ->
                    if (monitorDeConectividade?.estaConectado == false) {
                        throw ErroDaApi(
                            codigo = CodigoErroAPI.SEM_REDE,
                            codigoOriginal = "sem_rede",
                            detalhes = null,
                            mensagemCrua = "Sem conexão com a internet",
                        )
                    }
                }
            },
        )
        install(Auth) {
            bearer {
                loadTokens {
                    armazenamentoDeSessao?.obterSessao()?.paraBearerTokens()
                        ?: provedorDeToken.tokenDeAcesso()?.let { BearerTokens(it, "") }
                }
                refreshTokens {
                    renovarTokens(this)
                }
            }
        }
        install(Logging) { level = LogLevel.INFO }
        install(HttpTimeout) {
            connectTimeoutMillis = TIMEOUT_CONEXAO_MS
            requestTimeoutMillis = TIMEOUT_REQUISICAO_MS
            socketTimeoutMillis = TIMEOUT_SOCKET_MS
        }
        install(HttpRequestRetry) {
            maxRetries = MAX_TENTATIVAS_RETRY
            exponentialDelay(base = 2.0, maxDelayMs = RETRY_DELAY_MAXIMO_MS, randomizationMs = RETRY_JITTER_MS)

            // RNF01 + idempotência estrita: só GET (leitura) pode retentar sozinho. Mutações
            // (POST de candidatar, fazer_checkin, avaliar, cancelar, excluir-conta, ...) nunca
            // podem ser retentadas automaticamente — duplicaria o efeito colateral no backend.
            retryIf { requisicao, resposta ->
                requisicao.method == HttpMethod.Get &&
                    resposta.status.value in STATUS_TRANSITORIOS &&
                    monitorDeConectividade?.estaConectado != false
            }
            retryOnExceptionIf { requisicao, causa ->
                requisicao.method == HttpMethod.Get &&
                    causa.isFalhaTransitoriaDeRede() &&
                    monitorDeConectividade?.estaConectado != false
            }
        }
        // RNF01: converte falhas de conectividade (sem resposta HTTP nenhuma) em ErroDaApi
        // com CodigoErroAPI.SEM_REDE, a mesma exceção que os ViewModels já tratam para
        // mensagem amigável (ex.: PerfilViewModel.mensagemDeErro) — sem isto, essas exceções
        // cruas do Ktor/JVM derrubavam a tela em vez de cair no `catch (erro: ErroDaApi)`.
        HttpResponseValidator {
            handleResponseExceptionWithRequest { causa, _ ->
                if (causa is CancellationException) return@handleResponseExceptionWithRequest
                if (causa.isFalhaTransitoriaDeRede()) {
                    throw ErroDaApi(
                        codigo = CodigoErroAPI.SEM_REDE,
                        codigoOriginal = "sem_rede",
                        detalhes = null,
                        mensagemCrua = causa.message ?: "Falha de conectividade",
                    )
                }
            }
        }
        defaultRequest {
            header("apikey", apiKey)
            tokenDeAcessoAtual()?.let { token ->
                header("Authorization", "Bearer $token")
            }
        }
    }

    private fun tokenDeAcessoAtual(): String? =
        armazenamentoDeSessao?.obterSessao()?.accessToken ?: provedorDeToken.tokenDeAcesso()

    private suspend fun renovarTokens(parametros: RefreshTokensParams): BearerTokens? {
        val armazenamento = armazenamentoDeSessao ?: return null
        val sessaoAtual = armazenamento.obterSessao() ?: return null

        return try {
            val resposta = parametros.client.post(urlCompleta(CAMINHO_RENOVACAO)) {
                with(parametros) { markAsRefreshTokenRequest() }
                contentType(ContentType.Application.Json)
                setBody(RenovarTokenDto(refreshToken = sessaoAtual.refreshToken))
            }
            if (!resposta.status.isSuccess()) {
                armazenamento.limparSessao()
                return null
            }

            val renovada = resposta.body<SessaoDto>()
            val sessaoPersistida = renovada.paraSessao(vinculoId = sessaoAtual.vinculoId)
            armazenamento.salvarSessao(sessaoPersistida)
            sessaoPersistida.paraBearerTokens()
        } catch (erro: CancellationException) {
            throw erro
        } catch (_: Exception) {
            armazenamento.limparSessao()
            null
        }
    }

    fun urlCompleta(caminho: String): String = "$baseUrl$caminho"

    /** Monta a URL de uma RPC do Supabase: `/rest/v1/rpc/<nome>` (POST escreve, GET lê). */
    fun urlRpc(nome: String): String = urlCompleta("/rest/v1/rpc/$nome")

    /**
     * Monta a URL de uma Edge Function do Supabase: `/functions/v1/<nome>`. Usada por operações
     * que precisam de privilégio além do RLS do PostgREST — ex.: `excluir-conta` apaga a
     * credencial em `auth.users`, o que só a Edge Function pode fazer (RF25/RN15/UC16).
     */
    fun urlFunction(nome: String): String = urlCompleta("/functions/v1/$nome")

    /**
     * Decodifica a resposta em [T] se 2xx; se não, decodifica o envelope de erro PostgREST
     * e lança [ErroDaApi] com o `code` já mapeado para [CodigoErroAPI] (desconhecido vira
     * [CodigoErroAPI.DESCONHECIDO], nunca derruba o parse do envelope).
     */
    suspend inline fun <reified T> corpoOuErro(resposta: HttpResponse): T {
        if (resposta.status.isSuccess()) {
            return resposta.body()
        }
        val envelope = resposta.body<ErroPostgrestDto>()
        throw ErroDaApi(
            codigo = mapearCodigo(envelope.code, resposta.status),
            codigoOriginal = envelope.code,
            detalhes = envelope.details,
            mensagemCrua = envelope.message,
        )
    }

    companion object {
        const val TIMEOUT_CONEXAO_MS = 10_000L
        const val TIMEOUT_REQUISICAO_MS = 15_000L
        const val TIMEOUT_SOCKET_MS = 30_000L
        const val MAX_TENTATIVAS_RETRY = 3
        const val RETRY_DELAY_MAXIMO_MS = 4_000L
        const val RETRY_JITTER_MS = 500L

        /** HTTP 502/503/504: falha transitória do servidor/proxy, não do pedido em si (RNF01). */
        val STATUS_TRANSITORIOS = setOf(
            HttpStatusCode.BadGateway.value,
            HttpStatusCode.ServiceUnavailable.value,
            HttpStatusCode.GatewayTimeout.value,
        )

        private const val CAMINHO_RENOVACAO = "/auth/v1/token?grant_type=refresh_token"

        val jsonFrila: Json = Json {
            ignoreUnknownKeys = true
            isLenient = true
            // MEDIDO: kotlinx.serialization omite por padrão um campo cujo valor bate com o
            // default da data class (`encodeDefaults = false`). Vários DTOs de corpo de
            // requisição têm default só por conveniência no client (ex.: `plataforma =
            // "android"`, `tipo = "email"`), mas o contrato exige o campo presente
            // (`required: [token_fcm, plataforma]` em `/rpc/registrar_dispositivo`). Sem isto,
            // o corpo saía faltando um campo obrigatório sempre que o chamador usava o default.
            encodeDefaults = true
        }

        /**
         * Mapeia o `code` cru do envelope PostgREST para [CodigoErroAPI], reusando o próprio
         * serializer do enum (as mesmas anotações `@SerialName` de `:core:dominio`) em vez de
         * duplicar a tabela de nomes aqui. `PGRST301` (JWT expirado) não é snake_case do
         * domínio e não está no enum: tratado como não-autenticado, igual ao iOS
         * (`iOS/Sources/Dados/DecodificadorErroAPI.swift`).
         */
        fun mapearCodigo(codeCru: String, status: HttpStatusCode): CodigoErroAPI {
            if (codeCru == "PGRST301" || status == HttpStatusCode.Unauthorized) {
                return CodigoErroAPI.NAO_AUTENTICADO
            }
            return try {
                jsonFrila.decodeFromString(CodigoErroAPI.serializer(), "\"$codeCru\"")
            } catch (_: SerializationException) {
                CodigoErroAPI.DESCONHECIDO
            }
        }
    }
}

private fun Sessao.paraBearerTokens(): BearerTokens = BearerTokens(
    accessToken = accessToken,
    refreshToken = refreshToken,
)

/**
 * Falha de conectividade/timeout transitória (RNF01): nunca inclui [CancellationException] —
 * essa precisa propagar intacta para a coroutine ser cancelada normalmente, não virar erro de
 * rede. Tipos cobertos: timeout de conexão/socket/requisição, host inalcançável e falhas de IO
 * genéricas do engine (conexão caiu no meio, etc.).
 */
private fun Throwable.isFalhaTransitoriaDeRede(): Boolean = when (this) {
    is CancellationException -> false
    is ConnectTimeoutException,
    is SocketTimeoutException,
    is HttpRequestTimeoutException,
    is UnknownHostException,
    is IOException,
    -> true
    else -> false
}

private fun SessaoDto.paraSessao(vinculoId: String?): Sessao = Sessao(
    accessToken = accessToken,
    refreshToken = refreshToken,
    tokenType = tokenType,
    expiresIn = expiresIn,
    vinculoId = vinculoId,
)
