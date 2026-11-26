package br.com.frila.app.seguranca

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import br.com.frila.core.seguranca.ArmazenamentoOAuthPendente
import br.com.frila.core.seguranca.ProvedorOAuthSocial
import br.com.frila.core.seguranca.TransacaoOAuthPendente
import java.security.KeyStore

/**
 * Adaptador Android para [ArmazenamentoOAuthPendente] usando arquivo `EncryptedSharedPreferences`
 * dedicado (`oauth_pendente_seguro`), isolado de `sessao_segura` e `dispositivo_confiavel_seguro`.
 *
 * Garante sobrevivência a morte de processo e recriação da Activity enquanto o usuário
 * autentica no navegador, com expiração estrita (TTL <= 10 min) e descarte seguro.
 */
class ArmazenamentoOAuthPendenteKeystore internal constructor(
    context: Context,
    private val fabricaDePreferencias: (Context) -> SharedPreferences,
    private val relogio: () -> Long = { System.currentTimeMillis() },
) : ArmazenamentoOAuthPendente {

    constructor(context: Context) : this(context, ::criarPreferenciasCriptografadas)

    private val contexto = context.applicationContext
    private val bloqueio = Any()
    private var preferencias: SharedPreferences? = null

    override fun salvar(transacao: TransacaoOAuthPendente) {
        synchronized(bloqueio) {
            val prefs = obterPreferenciasOuNull() ?: return@synchronized
            executarComRecuperacao {
                prefs.edit()
                    .putString(CHAVE_PROVEDOR, transacao.provedor.valor)
                    .putString(CHAVE_TRANSACAO_ID, transacao.transacaoId)
                    .putString(CHAVE_VERIFIER, transacao.verifier)
                    .putString(CHAVE_TX_LOCAL, transacao.txLocal)
                    .putLong(CHAVE_EXPIRA_EM, transacao.expiraEmMillis)
                    .commit()
            }
        }
    }

    override fun obter(): TransacaoOAuthPendente? = synchronized(bloqueio) {
        val prefs = obterPreferenciasOuNull() ?: return@synchronized null
        executarComRecuperacao {
            val provedorStr = prefs.getString(CHAVE_PROVEDOR, null) ?: return@executarComRecuperacao null
            val transacaoId = prefs.getString(CHAVE_TRANSACAO_ID, null) ?: return@executarComRecuperacao null
            val verifier = prefs.getString(CHAVE_VERIFIER, null) ?: return@executarComRecuperacao null
            val txLocal = prefs.getString(CHAVE_TX_LOCAL, null) ?: return@executarComRecuperacao null
            val expiraEm = prefs.getLong(CHAVE_EXPIRA_EM, 0L)

            val provedor = ProvedorOAuthSocial.doValorOuNull(provedorStr)
            if (provedor == null) {
                limpar()
                return@executarComRecuperacao null
            }

            val transacao = TransacaoOAuthPendente(
                provedor = provedor,
                transacaoId = transacaoId,
                verifier = verifier,
                txLocal = txLocal,
                expiraEmMillis = expiraEm,
            )

            if (transacao.expirou(relogio())) {
                limpar()
                null
            } else {
                transacao
            }
        }
    }

    override fun limpar() {
        synchronized(bloqueio) {
            val prefs = obterPreferenciasOuNull() ?: return@synchronized
            executarComRecuperacao {
                prefs.edit().clear().commit()
            }
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
        Log.e(TAG, "Armazenamento de OAuth pendente inválido; descartando", erro)
        preferencias = null
        runCatching { contexto.deleteSharedPreferences(NOME_PREFERENCIAS) }
        runCatching {
            KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
                .deleteEntry(MasterKey.DEFAULT_MASTER_KEY_ALIAS)
        }
    }

    private companion object {
        const val TAG = "OAuthPendenteKeystore"
        const val ANDROID_KEYSTORE = "AndroidKeyStore"
        const val NOME_PREFERENCIAS = "oauth_pendente_seguro"
        const val CHAVE_PROVEDOR = "provedor"
        const val CHAVE_TRANSACAO_ID = "transacao_id"
        const val CHAVE_VERIFIER = "verifier"
        const val CHAVE_TX_LOCAL = "tx_local"
        const val CHAVE_EXPIRA_EM = "expira_em"

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
