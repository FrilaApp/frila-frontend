package br.com.frila.core.localizacao

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import br.com.frila.core.dominio.modelo.Coordenada
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import kotlinx.coroutines.suspendCancellableCoroutine

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
    override suspend fun obterCoordenadaAtual(): Coordenada? {
        if (!temPermissaoDeLocalizacao()) return null

        return try {
            suspendCancellableCoroutine { continuacao ->
                val tarefa = clienteFused.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, null)
                tarefa.addOnSuccessListener { localizacao: Location? ->
                    val coordenada = localizacao?.let { Coordenada(it.latitude, it.longitude) }
                    if (continuacao.isActive) continuacao.resumeWith(Result.success(coordenada))
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
