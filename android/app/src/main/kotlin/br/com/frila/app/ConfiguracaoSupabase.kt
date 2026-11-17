package br.com.frila.app

import java.util.Base64

/**
 * URL e chave PUBLICÁVEL do Supabase que o app usa (pedido 16-26). O `app/build.gradle.kts` põe as
 * duas no `BuildConfig`: o par DEV no debug e o par PROD no release, lidos de variável de ambiente ou
 * de `android/local.properties` (fora do Git). O build recusa o release sem o par PROD, e qualquer par
 * com chave proibida; esta classe repete a regra (mude as duas juntas) para o debug compilado sem o
 * par DEV avisar por que não alcança o servidor. Os motivos nunca repetem o valor.
 */
data class ConfiguracaoSupabase(val url: String, val chavePublicavel: String) {

    /** Por que a configuração não serve para falar com o servidor, ou `null` se serve. */
    val problema: String?
        get() = motivoDeRecusaDaUrl(url) ?: motivoDeRecusaDaChave(chavePublicavel)

    /** Sem valores: a chave publicável não é segredo, mas não precisa ir para log nenhum. */
    override fun toString(): String = "ConfiguracaoSupabase(serve=${problema == null})"

    companion object {
        /** O que o build põe no debug sem o par DEV: domínio reservado (RFC 2606), que nunca resolve. */
        const val URL_SEM_CONFIGURACAO = "https://supabase-nao-configurado.invalid"

        private val ROLE_SERVICE_ROLE = Regex("\"role\"\\s*:\\s*\"service_role\"")

        fun doBuildConfig() = ConfiguracaoSupabase(BuildConfig.SUPABASE_URL, BuildConfig.SUPABASE_PUBLISHABLE_KEY)

        fun motivoDeRecusaDaUrl(url: String): String? = when {
            url.isBlank() || url == URL_SEM_CONFIGURACAO -> "URL não configurada"
            url.startsWith("TODO", ignoreCase = true) -> "URL é placeholder (TODO)"
            !url.startsWith("https://") -> "URL não usa https"
            else -> null
        }

        fun motivoDeRecusaDaChave(chave: String): String? = when {
            chave.isBlank() -> "chave não configurada"
            chave.startsWith("TODO", ignoreCase = true) -> "chave é placeholder (TODO)"
            chave.startsWith("sb_secret_") -> "chave secreta (sb_secret_); use a publicável"
            ehJwtDeServiceRole(chave) -> "JWT com role service_role; use a publicável"
            else -> null
        }

        /** Chave antiga em JWT: a `anon` é publicável; a `service_role` dá acesso total e nunca vai no app. */
        private fun ehJwtDeServiceRole(chave: String): Boolean {
            val partes = chave.split('.')
            if (partes.size != 3) return false
            val carga = runCatching { String(Base64.getUrlDecoder().decode(partes[1].trimEnd('='))) }.getOrNull()
            return carga != null && ROLE_SERVICE_ROLE.containsMatchIn(carga)
        }
    }
}
