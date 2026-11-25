package br.com.frila.app.seguranca

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import br.com.frila.core.seguranca.ArmazenamentoDeDispositivo
import java.security.KeyStore
import java.security.MessageDigest

/**
 * Adaptador Android para [ArmazenamentoDeDispositivo] usando arquivo `EncryptedSharedPreferences`
 * dedicado (`dispositivo_confiavel_seguro`), isolado de `sessao_segura`.
 */
class ArmazenamentoDeDispositivoKeystore internal constructor(
    context: Context,
    private val fabricaDePreferencias: (Context) -> SharedPreferences,
) : ArmazenamentoDeDispositivo {

    constructor(context: Context) : this(context, ::criarPreferenciasCriptografadas)

    private val contexto = context.applicationContext
    private val bloqueio = Any()
    private var preferencias: SharedPreferences? = null

    override fun salvarToken(email: String, token: String) {
        if (token.isBlank()) {
            removerToken(email)
            return
        }
        val chave = chaveDaConta(email)
        synchronized(bloqueio) {
            val prefs = obterPreferenciasOuNull() ?: return@synchronized
            executarComRecuperacao {
                prefs.edit().putString(chave, token).commit()
            }
        }
    }

    override fun obterToken(email: String): String? {
        val chave = chaveDaConta(email)
        return synchronized(bloqueio) {
            val prefs = obterPreferenciasOuNull() ?: return@synchronized null
            executarComRecuperacao {
                prefs.getString(chave, null)?.takeIf { it.isNotBlank() }
            }
        }
    }

    override fun removerToken(email: String) {
        val chave = chaveDaConta(email)
        synchronized(bloqueio) {
            val prefs = obterPreferenciasOuNull() ?: return@synchronized
            executarComRecuperacao { prefs.edit().remove(chave).commit() }
        }
    }

    override fun removerTodos() {
        synchronized(bloqueio) {
            val prefs = obterPreferenciasOuNull() ?: return@synchronized
            executarComRecuperacao { prefs.edit().clear().commit() }
        }
    }

    private fun obterPreferenciasOuNull(): SharedPreferences? {
        preferencias?.let { return it }
        return try {
            fabricaDePreferencias(contexto).also { preferencias = it }
        } catch (erro: Exception) {
            invalidarArmazenamento(erro)
            null
        }
    }

    private inline fun <T> executarComRecuperacao(operacao: () -> T): T? = try {
        operacao()
    } catch (erro: Exception) {
        invalidarArmazenamento(erro)
        null
    }

    private fun invalidarArmazenamento(erro: Exception) {
        Log.e(TAG, "Armazenamento de dispositivo confiável inválido; será descartado", erro)
        preferencias = null
        runCatching { contexto.deleteSharedPreferences(NOME_PREFERENCIAS) }
        runCatching {
            KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
                .deleteEntry(MasterKey.DEFAULT_MASTER_KEY_ALIAS)
        }
    }

    companion object {
        private const val TAG = "DispositivoKeystore"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        internal const val NOME_PREFERENCIAS = "dispositivo_confiavel_seguro"

        fun chaveDaConta(email: String): String {
            val normalizado = email.trim().lowercase()
            val digest = MessageDigest.getInstance("SHA-256").digest(normalizado.toByteArray(Charsets.UTF_8))
            val hex = digest.joinToString("") { "%02x".format(it) }
            return "frila.dispositivo_token.$hex"
        }

        private fun criarPreferenciasCriptografadas(contexto: Context): SharedPreferences {
            val masterKey = MasterKey.Builder(contexto)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()

            return EncryptedSharedPreferences.create(
                contexto,
                NOME_PREFERENCIAS,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
        }
    }
}
