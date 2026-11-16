package br.com.frila.app

import java.net.URI
import java.util.Base64
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * URL e chave publicável do Supabase que o app usa. Só se obtém por [validar], de modo que um
 * placeholder (`TODO...`), um valor vazio ou uma chave secreta nunca chegam ao cliente de rede.
 *
 * As regras de chave (TODO, `sb_secret_` e JWT com `role` `service_role`) também existem em
 * `app/build.gradle.kts`, que as aplica no build de release. As duas cópias são conferidas contra
 * os mesmos casos, em `src/test/resources/supabase-chaves-casos.tsv`: o teste desta classe e a
 * tarefa `verificarRegrasDeChaveSupabase` (que roda antes de `testDebugUnitTest`) leem esse arquivo.
 * Mudou uma regra: mude as duas e acrescente o caso.
 */
class ConfiguracaoDoBackend private constructor(
    val url: String,
    val chavePublicavel: String,
) {
    // Nunca expõe a chave em log nem em mensagem de erro.
    override fun toString(): String = "ConfiguracaoDoBackend(url=$url, chavePublicavel=***)"

    companion object {
        private const val PREFIXO_PLACEHOLDER = "TODO"
        private const val PREFIXO_CHAVE_SECRETA = "sb_secret_"
        private const val ROLE_SECRETO = "service_role"

        /** Lança [IllegalArgumentException] nomeando o campo, sem repetir o valor recebido. */
        fun validar(url: String, chavePublicavel: String): ConfiguracaoDoBackend {
            val urlLimpa = url.trim()
            val chaveLimpa = chavePublicavel.trim()
            require(urlLimpa.isNotEmpty()) { "BuildConfig.SUPABASE_URL está vazia." }
            require(!urlLimpa.startsWith(PREFIXO_PLACEHOLDER, ignoreCase = true) && temEsquemaEHost(urlLimpa)) {
                "BuildConfig.SUPABASE_URL não é uma URL http(s) com host."
            }
            require(chaveLimpa.isNotEmpty()) { "BuildConfig.SUPABASE_PUBLISHABLE_KEY está vazia." }
            require(!chaveLimpa.startsWith(PREFIXO_PLACEHOLDER, ignoreCase = true)) {
                "BuildConfig.SUPABASE_PUBLISHABLE_KEY é um placeholder (TODO)."
            }
            require(!chaveLimpa.startsWith(PREFIXO_CHAVE_SECRETA)) {
                "BuildConfig.SUPABASE_PUBLISHABLE_KEY é uma chave secreta; o app só aceita a chave publicável."
            }
            require(!ehJwtDeServiceRole(chaveLimpa)) {
                "BuildConfig.SUPABASE_PUBLISHABLE_KEY é um JWT com role $ROLE_SECRETO; o app só aceita a chave publicável."
            }
            return ConfiguracaoDoBackend(urlLimpa, chaveLimpa)
        }

        /**
         * JWT legado do Supabase: três partes separadas por ponto, payload em base64url. Um valor que
         * não decodifica como JWT com `role` não tem o que recusar aqui (as chaves `sb_publishable_`
         * não são JWT).
         */
        private fun ehJwtDeServiceRole(chave: String): Boolean {
            val partes = chave.split('.')
            if (partes.size != 3) return false
            return runCatching {
                val payload = String(Base64.getUrlDecoder().decode(partes[1].trimEnd('=').replace('+', '-').replace('/', '_')))
                Json.parseToJsonElement(payload).jsonObject["role"]?.jsonPrimitive?.content
                    ?.equals(ROLE_SECRETO, ignoreCase = true) == true
            }.getOrDefault(false)
        }

        private fun temEsquemaEHost(url: String): Boolean {
            val uri = runCatching { URI(url) }.getOrNull() ?: return false
            return uri.scheme?.lowercase() in setOf("http", "https") && !uri.host.isNullOrEmpty()
        }
    }
}
