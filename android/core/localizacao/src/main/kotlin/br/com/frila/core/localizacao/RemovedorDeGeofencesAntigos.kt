package br.com.frila.core.localizacao

import android.content.Context
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.LocationServices

/**
 * Versões anteriores do app registravam no Play Services um geofence de aproximação por turno (o id do registro era o id do
 * turno), que valia até o fim do turno. Esta versão não registra geofence nenhum: isto só desfaz o que uma instalação antiga
 * tenha deixado. O Play Services só remove por id, então quem chama informa os ids dos turnos.
 */
fun interface RemovedorDeGeofencesAntigos {
    fun remover(idsDosTurnos: List<String>)
}

class RemovedorDeGeofencesAntigosDoPlayServices(
    contexto: Context,
    private val cliente: GeofencingClient = LocationServices.getGeofencingClient(contexto),
) : RemovedorDeGeofencesAntigos {

    /** Nunca lança: sem permissão ou sem Play Services não há registro antigo para desfazer. */
    override fun remover(idsDosTurnos: List<String>) {
        if (idsDosTurnos.isEmpty()) return
        try {
            cliente.removeGeofences(idsDosTurnos)
        } catch (_: RuntimeException) {
        }
    }
}
