package br.com.frila.app

import android.content.Context
import br.com.frila.core.designsystem.componentes.TextosAtualizacaoObrigatoria
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject

/**
 * Quanto o app espera por `configuracao_do_app` antes de seguir. Com 3 s o dev estourava em rede lenta
 * e todas as chaves ficavam desligadas em silêncio (achado F do QA da busca, F-036.10).
 */
const val TEMPO_MAXIMO_CONFIGURACAO_MS = 10_000L

/**
 * Quanto a primeira tela espera pela configuração quando não há nenhuma guardada para esta versão do app. Com configuração guardada
 * a tela abre na hora. Passado o prazo a tela abre com as chaves desligadas e a resposta, quando chega (até
 * [TEMPO_MAXIMO_CONFIGURACAO_MS]), vale do mesmo jeito, inclusive para bloquear uma versão abaixo da mínima (#795).
 */
const val TEMPO_MAXIMO_ABERTURA_MS = 2_000L

/** Guarda a última configuração pública recebida, por plataforma e versão do app. */
interface CacheDeConfiguracaoDoApp {
    fun ler(plataforma: String, versaoApp: String?): ConfiguracaoDoAppDto?
    fun gravar(versaoApp: String?, configuracao: ConfiguracaoDoAppDto)
}

/**
 * Guarda a configuração em `SharedPreferences`: é config pública (versão mínima e chaves), sem dado pessoal.
 * A chave inclui a versão do app, então uma atualização do app descarta o que foi guardado pela versão anterior.
 */
class CacheDeConfiguracaoDoAppPreferencias(contexto: Context) : CacheDeConfiguracaoDoApp {
    private val preferencias = contexto.applicationContext
        .getSharedPreferences(NOME_DO_ARQUIVO, Context.MODE_PRIVATE)

    override fun ler(plataforma: String, versaoApp: String?): ConfiguracaoDoAppDto? {
        val texto = preferencias.getString(chave(plataforma, versaoApp), null) ?: return null
        return try {
            configuracaoDoAppDeJson(Json.parseToJsonElement(texto).jsonObject)
        } catch (_: Exception) {
            null // guardado corrompido nunca derruba o app: vale como "sem guardado"
        }
    }

    override fun gravar(versaoApp: String?, configuracao: ConfiguracaoDoAppDto) {
        preferencias.edit()
            .putString(chave(configuracao.plataforma, versaoApp), configuracao.paraJson().toString())
            .apply()
    }

    private fun chave(plataforma: String, versaoApp: String?) = "$plataforma|${versaoApp.orEmpty()}"

    private companion object {
        const val NOME_DO_ARQUIVO = "configuracao_do_app"
    }
}

internal fun ConfiguracaoDoAppDto.paraJson(): JsonObject = buildJsonObject {
    put("plataforma", JsonPrimitive(plataforma))
    put("versao_minima", JsonPrimitive(versaoMinima))
    versaoRecomendada?.let { put("versao_recomendada", JsonPrimitive(it)) }
    urlDaLoja?.let { put("url_da_loja", JsonPrimitive(it)) }
    mensagem?.let { put("mensagem", JsonPrimitive(it)) }
    put(
        "recursos",
        buildJsonObject {
            put("foto_de_perfil", JsonPrimitive(recursos.fotoDePerfil))
            put("chamada_direta", JsonPrimitive(recursos.chamadaDireta))
            put("perfil_rico", JsonPrimitive(recursos.perfilRico))
            put("checkin_por_codigo", JsonPrimitive(recursos.checkinPorCodigo))
            put("busca_profissionais", JsonPrimitive(recursos.buscaProfissionais))
        },
    )
    reenviarOtpEmSegundos?.takeIf { it > 0 }?.let { put("reenviar_otp_em_segundos", JsonPrimitive(it)) }
}

/** Estado da configuração aplicada pelo portão de versão e pelas chaves de recurso do app. */
internal data class EstadoDaConfiguracaoDoApp(
    val versaoMinima: String? = null,
    val mensagemBloqueio: String = TextosAtualizacaoObrigatoria.MENSAGEM_PADRAO,
    val fotoDePerfil: Boolean = false,
    val chamadaDireta: Boolean = false,
    val perfilRico: Boolean = false,
    val checkinPorCodigo: Boolean = false,
    val buscaProfissionais: Boolean = false,
    val reenviarOtpEmSegundos: Int? = null,
)

/** Converte o DTO no estado aplicado em tela, voltando para [TextosAtualizacaoObrigatoria.MENSAGEM_PADRAO] quando `mensagem` vier nula ou em branco. */
internal fun ConfiguracaoDoAppDto.paraEstado(): EstadoDaConfiguracaoDoApp = EstadoDaConfiguracaoDoApp(
    versaoMinima = versaoMinima,
    mensagemBloqueio = mensagem?.takeIf { it.isNotBlank() } ?: TextosAtualizacaoObrigatoria.MENSAGEM_PADRAO,
    fotoDePerfil = recursos.fotoDePerfil,
    chamadaDireta = recursos.chamadaDireta,
    perfilRico = recursos.perfilRico,
    checkinPorCodigo = recursos.checkinPorCodigo,
    buscaProfissionais = recursos.buscaProfissionais,
    reenviarOtpEmSegundos = reenviarOtpEmSegundos?.takeIf { it > 0 },
)

/** A última configuração guardada para esta plataforma e versão, ou `null` (sem guardado ou guardado ilegível). */
suspend fun lerConfiguracaoGuardada(
    cache: CacheDeConfiguracaoDoApp,
    versaoApp: String?,
    plataforma: String = "android",
    dispatcherIo: CoroutineDispatcher = Dispatchers.IO,
): ConfiguracaoDoAppDto? = withContext(dispatcherIo) {
    try {
        cache.ler(plataforma, versaoApp)
    } catch (_: Exception) {
        null
    }
}

/**
 * Pede a configuração com prazo de [tempoMaximoMs]. Deu certo: guarda em [cache] e devolve. Estourou o prazo ou
 * falhou (rede, 5xx, corpo inválido): devolve a última guardada para esta plataforma e versão. Sem rede e sem
 * guardado devolve `null` (o chamador mantém todas as chaves desligadas, como antes).
 */
suspend fun obterConfiguracaoDoApp(
    cache: CacheDeConfiguracaoDoApp,
    versaoApp: String?,
    plataforma: String = "android",
    tempoMaximoMs: Long = TEMPO_MAXIMO_CONFIGURACAO_MS,
    dispatcherIo: CoroutineDispatcher = Dispatchers.IO,
    consulta: suspend () -> ConfiguracaoDoAppDto,
): ConfiguracaoDoAppDto? {
    val recebida = try {
        withTimeoutOrNull(tempoMaximoMs) { consulta() }
    } catch (cancelamento: CancellationException) {
        throw cancelamento
    } catch (_: Exception) {
        null
    }
    return withContext(dispatcherIo) {
        if (recebida != null) {
            try {
                cache.gravar(versaoApp, recebida)
            } catch (_: Exception) {
                // não guardar é só perder o fallback; nunca atrapalha a entrada
            }
            recebida
        } else {
            try {
                cache.ler(plataforma, versaoApp)
            } catch (_: Exception) {
                null
            }
        }
    }
}

/**
 * Coordena a abertura sem espera (#795): aplica a guardada na hora (ou libera após [TEMPO_MAXIMO_ABERTURA_MS]) e aplica a
 * resposta do servidor quando chegar, sobrescrevendo versão mínima, mensagem e chaves de recurso.
 */
internal suspend fun carregarConfiguracaoNaAbertura(
    cache: CacheDeConfiguracaoDoApp,
    versaoApp: String?,
    aoAplicar: (EstadoDaConfiguracaoDoApp) -> Unit,
    aoLiberarAbertura: () -> Unit,
    dispatcherIo: CoroutineDispatcher = Dispatchers.IO,
    consulta: suspend () -> ConfiguracaoDoAppDto,
) = coroutineScope {
    val abertura = launch {
        val guardada = lerConfiguracaoGuardada(cache, versaoApp, dispatcherIo = dispatcherIo)
        if (guardada != null) aoAplicar(guardada.paraEstado()) else delay(TEMPO_MAXIMO_ABERTURA_MS)
        aoLiberarAbertura()
    }
    try {
        val configuracao = obterConfiguracaoDoApp(
            cache = cache,
            versaoApp = versaoApp,
            dispatcherIo = dispatcherIo,
            consulta = consulta,
        )
        abertura.cancel() // a resposta chegou: a guardada não pode mais sobrescrevê-la
        if (configuracao != null) aoAplicar(configuracao.paraEstado())
    } catch (cancelamento: CancellationException) {
        throw cancelamento
    } catch (_: Exception) {
        // Falha transitória de rede ou offline nunca bloqueia o acesso
    } finally {
        abertura.cancel()
        aoLiberarAbertura()
    }
}
