package br.com.frila.app.seguranca

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.Sessao
import java.security.KeyStore

/**
 * Adaptador Android para a porta de sessão de `:core:seguranca`.
 *
 * Os nomes persistidos seguem o contrato 0.2.30. Qualquer falha ao abrir ou decifrar o arquivo
 * invalida os dados locais: uma sessão inacessível nunca deve impedir a inicialização do app.
 */
class ArmazenamentoDeSessaoKeystore internal constructor(
    context: Context,
    private val fabricaDePreferencias: (Context) -> SharedPreferences,
) : ArmazenamentoDeSessao {

    constructor(context: Context) : this(context, ::criarPreferenciasCriptografadas)

    private val contexto = context.applicationContext
    private val bloqueio = Any()
    private var preferencias: SharedPreferences? = null

    override fun salvarSessao(sessao: Sessao) {
        synchronized(bloqueio) {
            val prefs = obterPreferenciasOuNull() ?: return@synchronized

            executarComRecuperacao {
                val persistiu = prefs.edit()
                    .putString(CHAVE_ACCESS_TOKEN, sessao.accessToken)
                    .putString(CHAVE_REFRESH_TOKEN, sessao.refreshToken)
                    .putString(CHAVE_TOKEN_TYPE, sessao.tokenType)
                    .putLong(CHAVE_EXPIRES_IN, sessao.expiresIn)
                    .apply {
                        if (sessao.vinculoId == null) remove(CHAVE_VINCULO_ID)
                        else putString(CHAVE_VINCULO_ID, sessao.vinculoId)
                    }
                    .commit()
                check(persistiu) { "Não foi possível persistir a sessão criptografada" }
            }
        }
    }

    override fun obterSessao(): Sessao? = synchronized(bloqueio) {
        val prefs = obterPreferenciasOuNull() ?: return@synchronized null

        executarComRecuperacao {
            val accessToken = prefs.getString(CHAVE_ACCESS_TOKEN, null) ?: return@executarComRecuperacao null
            val refreshToken = prefs.getString(CHAVE_REFRESH_TOKEN, null) ?: return@executarComRecuperacao null
            val tokenType = prefs.getString(CHAVE_TOKEN_TYPE, null) ?: return@executarComRecuperacao null
            if (!prefs.contains(CHAVE_EXPIRES_IN)) return@executarComRecuperacao null

            Sessao(
                accessToken = accessToken,
                refreshToken = refreshToken,
                tokenType = tokenType,
                expiresIn = prefs.getLong(CHAVE_EXPIRES_IN, 0L),
                vinculoId = prefs.getString(CHAVE_VINCULO_ID, null),
            )
        }
    }

    override fun limparSessao() {
        synchronized(bloqueio) {
            val prefs = obterPreferenciasOuNull() ?: return@synchronized
            executarComRecuperacao { prefs.edit().clear().commit() }
        }
    }

    override fun estaAutenticado(): Boolean = obterSessao() != null

    /**
     * RN15: a flag vive na mesma `EncryptedSharedPreferences` da sessão (`sessao_segura`) —
     * protegida pelo mesmo AES-256-GCM via Keystore, isenta de backup/extração (ver
     * `data_extraction_rules.xml`/`backup_rules.xml`), e zerada por tabela por `limparSessao()`
     * (`prefs.edit().clear()`), sem precisar de lógica extra aqui.
     */
    override fun isBiometriaAtivada(): Boolean = synchronized(bloqueio) {
        val prefs = obterPreferenciasOuNull() ?: return@synchronized false
        executarComRecuperacao { prefs.getBoolean(CHAVE_BIOMETRIA_ATIVADA, false) } ?: false
    }

    override fun definirBiometriaAtivada(ativada: Boolean) {
        synchronized(bloqueio) {
            val prefs = obterPreferenciasOuNull() ?: return@synchronized
            executarComRecuperacao { prefs.edit().putBoolean(CHAVE_BIOMETRIA_ATIVADA, ativada).commit() }
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
        Log.e(TAG, "Sessão criptografada inválida; armazenamento local será descartado", erro)
        preferencias = null
        runCatching { contexto.deleteSharedPreferences(NOME_PREFERENCIAS) }
        runCatching {
            KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
                .deleteEntry(MasterKey.DEFAULT_MASTER_KEY_ALIAS)
        }
    }

    private companion object {
        const val TAG = "SessaoKeystore"
        const val ANDROID_KEYSTORE = "AndroidKeyStore"
        const val NOME_PREFERENCIAS = "sessao_segura"
        const val CHAVE_ACCESS_TOKEN = "access_token"
        const val CHAVE_REFRESH_TOKEN = "refresh_token"
        const val CHAVE_TOKEN_TYPE = "token_type"
        const val CHAVE_EXPIRES_IN = "expires_in"
        const val CHAVE_VINCULO_ID = "vinculo_id"
        const val CHAVE_BIOMETRIA_ATIVADA = "biometria_ativada"

        fun criarPreferenciasCriptografadas(contexto: Context): SharedPreferences {
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
