package br.com.frila.app

import android.content.Context
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
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
    consulta: suspend () -> ConfiguracaoDoAppDto,
): ConfiguracaoDoAppDto? {
    val recebida = try {
        withTimeoutOrNull(tempoMaximoMs) { consulta() }
    } catch (cancelamento: CancellationException) {
        throw cancelamento
    } catch (_: Exception) {
        null
    }
    return withContext(Dispatchers.IO) {
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
