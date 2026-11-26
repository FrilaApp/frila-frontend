package br.com.frila.core.seguranca

/**
 * Provedores sociais aceitos pelo fluxo OAuth do Frila (contrato 0.2.117).
 */
enum class ProvedorOAuthSocial(val valor: String) {
    APPLE("apple"),
    GOOGLE("google");

    companion object {
        fun doValorOuNull(valor: String?): ProvedorOAuthSocial? = when (valor?.trim()?.lowercase()) {
            APPLE.valor -> APPLE
            GOOGLE.valor -> GOOGLE
            else -> null
        }
    }
}

/**
 * Dados de uma transação OAuth PKCE em andamento (Google ou Apple).
 *
 * Contrato 0.2.117: a transação tem TTL de até 10 minutos (600.000 ms).
 * Deve ser persistida em armazenamento privado cifrado isolado para sobreviver
 * a rotações de tela e morte do processo do Android (process death) enquanto o usuário
 * interage com o navegador externo / Custom Tabs.
 */
data class TransacaoOAuthPendente(
    val provedor: ProvedorOAuthSocial,
    val transacaoId: String,
    val verifier: String,
    val txLocal: String,
    val expiraEmMillis: Long,
) {
    fun expirou(agoraMillis: Long = System.currentTimeMillis()): Boolean = agoraMillis >= expiraEmMillis
}

/**
 * Porta de domínio para persistência segura e efêmera de transações OAuth pendentes.
 */
interface ArmazenamentoOAuthPendente {
    fun salvar(transacao: TransacaoOAuthPendente)
    fun obter(): TransacaoOAuthPendente?
    fun limpar()
}

/**
 * Implementação em memória para testes unitários em JVM pura sem Keystore.
 */
class ArmazenamentoOAuthPendenteEmMemoria(
    private val relogio: () -> Long = { System.currentTimeMillis() },
) : ArmazenamentoOAuthPendente {
    private val bloqueio = Any()
    private var transacaoAtual: TransacaoOAuthPendente? = null

    override fun salvar(transacao: TransacaoOAuthPendente) {
        synchronized(bloqueio) {
            transacaoAtual = transacao
        }
    }

    override fun obter(): TransacaoOAuthPendente? = synchronized(bloqueio) {
        val t = transacaoAtual ?: return@synchronized null
        if (t.expirou(relogio())) {
            transacaoAtual = null
            null
        } else {
            t
        }
    }

    override fun limpar() {
        synchronized(bloqueio) {
            transacaoAtual = null
        }
    }
}
