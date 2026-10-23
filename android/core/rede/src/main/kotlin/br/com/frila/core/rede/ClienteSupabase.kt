package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.Sessao
import io.ktor.client.HttpClient
import io.ktor.client.HttpClientConfig
import io.ktor.client.call.body
import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.plugins.HttpTimeout
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
import io.ktor.http.HttpStatusCode
import io.ktor.http.ContentType
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import io.ktor.serialization.kotlinx.json.json
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
            requestTimeoutMillis = TIMEOUT_REQUISICAO_MS
            socketTimeoutMillis = TIMEOUT_SOCKET_MS
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
        const val TIMEOUT_REQUISICAO_MS = 15_000L
        const val TIMEOUT_SOCKET_MS = 60_000L
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

private fun SessaoDto.paraSessao(vinculoId: String?): Sessao = Sessao(
    accessToken = accessToken,
    refreshToken = refreshToken,
    tokenType = tokenType,
    expiresIn = expiresIn,
    vinculoId = vinculoId,
)
