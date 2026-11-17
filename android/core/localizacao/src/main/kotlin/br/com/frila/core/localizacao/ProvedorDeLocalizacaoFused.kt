package br.com.frila.core.localizacao

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import br.com.frila.core.dominio.modelo.Coordenada
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Implementação real de [ProvedorDeLocalizacao] sobre o Fused Location Provider do Google
 * Play Services. `clienteFused` é injetável para teste; em produção vem de
 * [LocationServices.getFusedLocationProviderClient].
 */
class ProvedorDeLocalizacaoFused(
    private val contexto: Context,
    private val clienteFused: FusedLocationProviderClient = LocationServices.getFusedLocationProviderClient(contexto),
) : ProvedorDeLocalizacao {

    override fun temPermissaoDeLocalizacao(): Boolean {
        val fina = contexto.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
        val aproximada = contexto.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
        return fina == PackageManager.PERMISSION_GRANTED || aproximada == PackageManager.PERMISSION_GRANTED
    }

    /**
     * Tratamento defensivo: `getSystemService` pode devolver nulo ou lançar em aparelhos
     * customizados, e `isProviderEnabled` pode lançar `IllegalArgumentException` para um nome de
     * provedor inesperado. Qualquer falha aqui é "GPS desligado", nunca um crash.
     */
    override fun isGpsAtivado(): Boolean = try {
        val gerenciador = contexto.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        gerenciador?.let {
            it.isProviderEnabled(LocationManager.GPS_PROVIDER) || it.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        } ?: false
    } catch (_: Exception) {
        false
    }

    /**
     * Sem permissão, nem chega a tocar no [clienteFused] — retorna `null` direto. Com
     * permissão, pede a posição atual (não o último fix em cache) e devolve `null` em caso de
     * falha ou ausência de fix, nunca lançando exceção para o chamador.
     */
    override suspend fun obterCoordenadaAtual(): Coordenada? =
        lerPosicaoAtual()?.let { Coordenada(it.latitude, it.longitude) }

    /**
     * Leitura do check-in: a espera é limitada a [TEMPO_LIMITE_DA_LEITURA_MS] (em lugar fechado o
     * Play Services pode levar dezenas de segundos) e a leitura leva junto a precisão e se veio
     * de app de localização falsa.
     */
    override suspend fun lerParaCheckin(): LeituraDeLocalizacao? {
        val localizacao = withTimeoutOrNull(TEMPO_LIMITE_DA_LEITURA_MS) { lerPosicaoAtual() } ?: return null
        return LeituraDeLocalizacao(
            coordenada = Coordenada(localizacao.latitude, localizacao.longitude),
            precisaoMetros = if (localizacao.hasAccuracy()) localizacao.accuracy else Float.POSITIVE_INFINITY,
            simulada = localizacao.veioDeFonteSimulada(),
        )
    }

    private suspend fun lerPosicaoAtual(): Location? {
        if (!temPermissaoDeLocalizacao()) return null

        return try {
            suspendCancellableCoroutine { continuacao ->
                // Se a espera desiste (prazo de 10 s), o pedido ao GPS também para; senão seguiria ligado e um
                // 2º toque abriria outro (revisão do #812).
                val fonte = CancellationTokenSource()
                continuacao.invokeOnCancellation { fonte.cancel() }
                val tarefa = clienteFused.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, fonte.token)
                tarefa.addOnSuccessListener { localizacao: Location? ->
                    if (continuacao.isActive) continuacao.resumeWith(Result.success(localizacao))
                }
                tarefa.addOnFailureListener {
                    if (continuacao.isActive) continuacao.resumeWith(Result.success(null))
                }
            }
        } catch (_: SecurityException) {
            null
        }
    }
}

@Suppress("DEPRECATION") // `isFromMockProvider` é o único jeito antes do Android 12 (API 31).
private fun Location.veioDeFonteSimulada(): Boolean =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) isMock else isFromMockProvider
