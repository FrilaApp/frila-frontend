package br.com.frila.app.conectividade

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import br.com.frila.core.rede.MonitorDeConectividade
import br.com.frila.core.rede.StatusConectividade
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.stateIn

/**
 * Implementação real de [MonitorDeConectividade] sobre `ConnectivityManager` (RNF01, cartão
 * 9Q0sJIzW). Filtro rigoroso: `NET_CAPABILITY_INTERNET` **e** `NET_CAPABILITY_VALIDATED` — uma
 * rede Wi-Fi atrás de captive portal (portal de login do hotel/aeroporto) tem a primeira
 * capacidade mas nunca a segunda, então nunca é tratada como "conectado" (evita falso positivo).
 *
 * `.stateIn(..., SharingStarted.WhileSubscribed(5_000L), ...)`: o callback do
 * `ConnectivityManager` só fica registrado enquanto alguém observa o `StateFlow`, com um atraso
 * de 5s antes de desregistrar — evita cancelar/registrar de novo a cada troca rápida de tela
 * (RNF04, bateria).
 */
class MonitorDeConectividadeAndroid(
    contexto: Context,
    escopo: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Default),
) : MonitorDeConectividade {

    private val gerenciador = contexto.getSystemService(ConnectivityManager::class.java)

    override val status: StateFlow<StatusConectividade> = callbackFlow {
        trySend(statusAtual())

        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
                trySend(statusDeCapacidades(capabilities))
            }

            override fun onLost(network: Network) {
                trySend(StatusConectividade.SEM_CONEXAO)
            }

            override fun onUnavailable() {
                trySend(StatusConectividade.SEM_CONEXAO)
            }
        }

        runCatching { gerenciador?.registerDefaultNetworkCallback(callback) }

        awaitClose { runCatching { gerenciador?.unregisterNetworkCallback(callback) } }
    }.stateIn(escopo, SharingStarted.WhileSubscribed(5_000L), statusAtual())

    /** Leitura síncrona no boot, via `activeNetwork`/`getNetworkCapabilities` — zero delay/flicker. */
    private fun statusAtual(): StatusConectividade {
        val gerenciadorAtual = gerenciador ?: return StatusConectividade.SEM_CONEXAO
        val redeAtiva = gerenciadorAtual.activeNetwork ?: return StatusConectividade.SEM_CONEXAO
        val capacidades = gerenciadorAtual.getNetworkCapabilities(redeAtiva) ?: return StatusConectividade.SEM_CONEXAO
        return statusDeCapacidades(capacidades)
    }

    private fun statusDeCapacidades(capacidades: NetworkCapabilities): StatusConectividade {
        val valida = capacidades.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            capacidades.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        return if (valida) StatusConectividade.CONECTADO else StatusConectividade.SEM_CONEXAO
    }
}
