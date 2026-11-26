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
 * Utilitários puros de OAuth PKCE S256 + state para login social (Google e Apple) no Android.
 * Nunca registra tokens, códigos OAuth ou verifiers em log.
 */
object SegurancaOAuthSocial {
    const val ESQUEMA_CALLBACK = "frila-auth"
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

    fun montarUrlAutorizacao(
        baseSupabaseUrl: String,
        provedor: ProvedorSocial,
        redirectTo: String = URL_CALLBACK,
        codeChallenge: String,
        state: String,
    ): String {
        val base = baseSupabaseUrl.trimEnd('/')
        val enc = { v: String -> URLEncoder.encode(v, Charsets.UTF_8.name()) }
        return "$base/auth/v1/authorize" +
            "?provider=${enc(provedor.valor)}" +
            "&redirect_to=${enc(redirectTo)}" +
            "&code_challenge=${enc(codeChallenge)}" +
            "&code_challenge_method=s256" +
            "&state=${enc(state)}"
    }

    fun analisarCallback(
        url: String,
        esquemaEsperado: String = ESQUEMA_CALLBACK,
        stateEsperado: String? = null,
    ): ResultadoCallbackOAuth {
        val uri = runCatching { URI(url) }.getOrNull() ?: return ResultadoCallbackOAuth.CallbackInvalido
        if (!uri.scheme.equals(esquemaEsperado, ignoreCase = true)) {
            return ResultadoCallbackOAuth.CallbackInvalido
        }
        val params = parseQuery(uri.rawQuery)
        val correlacaoRecebida = params["tx"] ?: params["state"]

        val erro = params["error"] ?: params["error_code"]
        if (erro != null) {
            // P2: deep link forjado com ?error=... sem correspondência de `tx` NÃO limpa a transação ativa.
            if (stateEsperado != null && correlacaoRecebida != stateEsperado) {
                return ResultadoCallbackOAuth.Ignorado
            }
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

        if (stateEsperado != null && correlacaoRecebida != null && correlacaoRecebida != stateEsperado) {
            return ResultadoCallbackOAuth.CallbackInvalido
        }

        val codigo = params["code"]
        if (!ehCodigoValido(codigo)) {
            if (stateEsperado != null && correlacaoRecebida != stateEsperado) {
                return ResultadoCallbackOAuth.Ignorado
            }
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

    private fun parseQuery(rawQuery: String?): Map<String, String> {
        if (rawQuery.isNullOrBlank()) return emptyMap()
        val mapa = linkedMapOf<String, String>()
        for (par in rawQuery.split('&')) {
            if (par.isBlank()) continue
            val idx = par.indexOf('=')
            val chave = URLDecoder.decode(if (idx >= 0) par.substring(0, idx) else par, Charsets.UTF_8.name())
            val valor = if (idx >= 0) URLDecoder.decode(par.substring(idx + 1), Charsets.UTF_8.name()) else ""
            mapa[chave] = valor
        }
        return mapa
    }
}
