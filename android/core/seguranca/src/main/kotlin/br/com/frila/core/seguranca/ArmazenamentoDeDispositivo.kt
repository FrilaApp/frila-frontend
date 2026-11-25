package br.com.frila.core.seguranca

/**
 * Porta de domínio para persistência segura do token opaco de confiança de dispositivo (30 dias).
 *
 * Contrato 0.2.112 §4: deve permanecer em armazenamento separado da sessão ([ArmazenamentoDeSessao])
 * para que o logout normal preserve a confiança de dispositivo e só a apague em troca/reset de senha,
 * "Sair de todos os dispositivos" ou resposta `descartar_device_token: true`.
 */
interface ArmazenamentoDeDispositivo {
    fun salvarToken(email: String, token: String)
    fun obterToken(email: String): String?
    fun removerToken(email: String)
    fun removerTodos()
}

/** Implementação em memória para testes unitários em JVM pura, sem Keystore Android. */
class ArmazenamentoDeDispositivoEmMemoria : ArmazenamentoDeDispositivo {
    private val bloqueio = Any()
    private val tokens = mutableMapOf<String, String>()

    override fun salvarToken(email: String, token: String) {
        val chave = normalizarEmail(email)
        synchronized(bloqueio) {
            if (token.isBlank()) tokens.remove(chave) else tokens[chave] = token
        }
    }

    override fun obterToken(email: String): String? = synchronized(bloqueio) {
        tokens[normalizarEmail(email)]
    }

    override fun removerToken(email: String) {
        synchronized(bloqueio) {
            tokens.remove(normalizarEmail(email))
        }
    }

    override fun removerTodos() {
        synchronized(bloqueio) {
            tokens.clear()
        }
    }

    private fun normalizarEmail(email: String): String = email.trim().lowercase()
}
