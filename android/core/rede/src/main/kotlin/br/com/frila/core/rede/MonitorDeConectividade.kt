package br.com.frila.core.rede

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** Estado reativo de conectividade de rede (RNF01, cartão 9Q0sJIzW). */
enum class StatusConectividade {
    CONECTADO,
    SEM_CONEXAO,
}

/**
 * Porta de domínio para conectividade reativa — `:core:rede` é Kotlin/JVM puro, sem
 * `ConnectivityManager`; a implementação real (`MonitorDeConectividadeAndroid`) fica em `:app`,
 * mesmo padrão de [ArmazenamentoDeSessao]/`ArmazenamentoDeSessaoKeystore`.
 */
interface MonitorDeConectividade {
    val status: StateFlow<StatusConectividade>
    val estaConectado: Boolean get() = status.value == StatusConectividade.CONECTADO
}

/** Dublê controlável para teste — muda [status] diretamente, sem `ConnectivityManager`/`Context`. */
class MonitorDeConectividadeFalso(
    statusInicial: StatusConectividade = StatusConectividade.CONECTADO,
) : MonitorDeConectividade {
    private val _status = MutableStateFlow(statusInicial)
    override val status: StateFlow<StatusConectividade> = _status.asStateFlow()

    fun definirStatus(novoStatus: StatusConectividade) {
        _status.value = novoStatus
    }
}
