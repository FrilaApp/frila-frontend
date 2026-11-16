package br.com.frila.app

import java.net.URI

/**
 * URL e chave publicável do Supabase que o app usa. Só se obtém por [validar], de modo que um
 * placeholder (`TODO...`), um valor vazio ou uma chave secreta nunca chegam ao cliente de rede.
 *
 * As regras de TODO e de `sb_secret_` também existem em `app/build.gradle.kts`, que as aplica
 * no build de release; mantenha as duas pontas iguais.
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
            return ConfiguracaoDoBackend(urlLimpa, chaveLimpa)
        }

        private fun temEsquemaEHost(url: String): Boolean {
            val uri = runCatching { URI(url) }.getOrNull() ?: return false
            return uri.scheme?.lowercase() in setOf("http", "https") && !uri.host.isNullOrEmpty()
        }
    }
}
