package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import java.net.URI
import java.net.URLDecoder
import java.net.URLEncoder
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Base64

enum class ProvedorSocial(val valor: String) {
    GOOGLE("google"),
    APPLE("apple"),
}

sealed interface ResultadoCallbackOAuth {
    data class Codigo(val valor: String) : ResultadoCallbackOAuth
    data object Cancelado : ResultadoCallbackOAuth
    data object ConflitoDeIdentidade : ResultadoCallbackOAuth
    data object CallbackInvalido : ResultadoCallbackOAuth
    /** Callback com erro/sem código sem correlação `tx` (ex.: deep link forjado): NÃO apaga transação ativa (P2). */
    data object Ignorado : ResultadoCallbackOAuth
}

/**
 * Utilitários puros de OAuth PKCE S256 + correlação `tx` para login social (Google e Apple) no Android.
 * Nunca registra tokens, códigos OAuth ou verifiers em log.
 *
 * Nota de segurança pré-Prod (P2): custom scheme `frila-auth://auth/callback` é usado apenas em DEV/modo sombra
 * e NÃO oferece exclusividade contra outro app instalado que registre o mesmo scheme. Antes de habilitar em Prod,
 * migrar o callback para Android App Links verificados (`https://...` com `android:autoVerify="true"` e `assetlinks.json`).
 */
object SegurancaOAuthSocial {
    const val ESQUEMA_CALLBACK = "frila-auth"
    const val HOST_CALLBACK = "auth"
    const val PATH_CALLBACK = "/callback"
    const val URL_CALLBACK = "frila-auth://auth/callback"

    private val random = SecureRandom()
    private val padraoVerifier = Regex("^[A-Za-z0-9_-]{43,128}$")
    private val padraoCodigo = Regex("^[\\x21-\\x7E]{4,512}$")

    fun gerarVerifierPkce(): String {
        val bytes = ByteArray(32)
        random.nextBytes(bytes)
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)
    }

    fun desafioPkceS256(verifier: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray(Charsets.UTF_8))
        return Base64.getUrlEncoder().withoutPadding().encodeToString(digest)
    }

    fun gerarState(): String {
        val bytes = ByteArray(16)
        random.nextBytes(bytes)
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)
    }

    fun ehVerifierValido(verifier: String?): Boolean =
        verifier != null && padraoVerifier.matches(verifier)

    fun ehCodigoValido(codigo: String?): Boolean =
        codigo != null && padraoCodigo.matches(codigo)

    fun ehCallbackOAuthSocial(url: String?): Boolean {
        if (url.isNullOrBlank()) return false
        val uri = runCatching { URI(url) }.getOrNull() ?: return false
        return uri.scheme.equals(ESQUEMA_CALLBACK, ignoreCase = true) &&
            uri.host.equals(HOST_CALLBACK, ignoreCase = true) &&
            uri.path == PATH_CALLBACK
    }

    fun analisarCallback(
        url: String,
        esquemaEsperado: String = ESQUEMA_CALLBACK,
        hostEsperado: String = HOST_CALLBACK,
        pathEsperado: String = PATH_CALLBACK,
        stateEsperado: String? = null,
    ): ResultadoCallbackOAuth {
        val uri = runCatching { URI(url) }.getOrNull()
            ?: return if (stateEsperado != null) ResultadoCallbackOAuth.Ignorado else ResultadoCallbackOAuth.CallbackInvalido
        // P2: exige scheme + host + path exatos (não apenas scheme).
        val destinoValido = uri.scheme.equals(esquemaEsperado, ignoreCase = true) &&
            uri.host.equals(hostEsperado, ignoreCase = true) &&
            uri.path == pathEsperado
        if (!destinoValido) {
            return if (stateEsperado != null) ResultadoCallbackOAuth.Ignorado else ResultadoCallbackOAuth.CallbackInvalido
        }
        val params = parseQuery(uri.rawQuery)
        val correlacaoRecebida = params["tx"] ?: params["state"]

        // P1: quando há transação pendente (`stateEsperado != null`), exige correlação presente e igual
        // tanto para callbacks de erro quanto para callbacks com `code`. Ausente ou divergente -> Ignorado
        // (NÃO consome nem limpa `oauthPendente`).
        if (stateEsperado != null && (correlacaoRecebida.isNullOrBlank() || correlacaoRecebida != stateEsperado)) {
            return ResultadoCallbackOAuth.Ignorado
        }

        val erro = params["error"] ?: params["error_code"]
        if (erro != null) {
            val combinado = "$erro ${params["error_description"].orEmpty()}".lowercase()
            return when {
                combinado.contains("access_denied") || combinado.contains("cancel") ->
                    ResultadoCallbackOAuth.Cancelado
                combinado.contains("identity_already_exists") ||
                    combinado.contains("manual_linking") ||
                    combinado.contains("email_conflict") ||
                    combinado.contains("already_registered") ->
                    ResultadoCallbackOAuth.ConflitoDeIdentidade
                else -> ResultadoCallbackOAuth.CallbackInvalido
            }
        }

        val codigo = params["code"]
        if (!ehCodigoValido(codigo)) {
            return ResultadoCallbackOAuth.CallbackInvalido
        }
        return ResultadoCallbackOAuth.Codigo(codigo!!)
    }

    fun ehErroConflitoIdentidade(erro: ErroDaApi): Boolean {
        val combinado = "${erro.codigoOriginal} ${erro.detalhes.orEmpty()} ${erro.message.orEmpty()}".lowercase()
        return erro.codigo == CodigoErroAPI.CONTA_EXISTENTE ||
            combinado.contains("conflito_identidade") ||
            combinado.contains("identity_already_exists") ||
            combinado.contains("manual_linking") ||
            combinado.contains("email_conflict") ||
            combinado.contains("already registered")
    }

    private fun decodificarPercent(s: String): String {
        val bytes = java.io.ByteArrayOutputStream()
        var i = 0
        while (i < s.length) {
            val c = s[i]
            if (c == '%' && i + 2 < s.length) {
                val hex = s.substring(i + 1, i + 3)
                val byteVal = hex.toIntOrNull(16)
                if (byteVal != null) {
                    bytes.write(byteVal)
                    i += 3
                    continue
                }
            }
            bytes.write(c.code)
            i++
        }
        return bytes.toByteArray().toString(Charsets.UTF_8)
    }

    private fun parseQuery(rawQuery: String?): Map<String, String> {
        if (rawQuery.isNullOrBlank()) return emptyMap()
        val mapa = linkedMapOf<String, String>()
        for (par in rawQuery.split('&')) {
            if (par.isBlank()) continue
            val idx = par.indexOf('=')
            val chaveRaw = if (idx >= 0) par.substring(0, idx) else par
            val valorRaw = if (idx >= 0) par.substring(idx + 1) else ""
            mapa[decodificarPercent(chaveRaw)] = decodificarPercent(valorRaw)
        }
        return mapa
    }
}
