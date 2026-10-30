package br.com.frila.core.localizacao

import android.Manifest
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import br.com.frila.core.dominio.modelo.Coordenada
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import java.time.Duration
import java.time.Instant

/**
 * Geofencing passivo de aproximação de turno (RN06/RNF04, cartão Uu04zAt4). Registra um círculo
 * de monitoramento em segundo plano via Google Play Services, com baixo dreno de bateria — o
 * sistema decide quando reavaliar a posição, nunca o app (RNF04).
 */
interface GerenciadorGeofencingTurnos {

    /**
     * Registra (ou substitui, se [id] já existir) um alerta de aproximação. Degrada
     * graciosamente (nenhuma exceção) quando faltar permissão de localização — o app simplesmente
     * não terá o alerta prévio, mas o check-in manual continua funcionando (RN22).
     */
    fun registrarAlerta(
        id: String,
        centro: Coordenada,
        raioMetros: Float,
        expiraEm: Instant?,
        canalNotificacao: String,
        titulo: String,
        corpo: String,
    )

    /** Remove o alerta de [id], se existir. RNF04: chamado assim que o check-in é feito ou o turno é cancelado/encerrado. */
    fun removerAlerta(id: String)
}

/** Implementação sem efeito, usada como default fora de um `Context` Android real (grafo Koin em JVM puro). */
class GerenciadorGeofencingTurnosNulo : GerenciadorGeofencingTurnos {
    override fun registrarAlerta(
        id: String,
        centro: Coordenada,
        raioMetros: Float,
        expiraEm: Instant?,
        canalNotificacao: String,
        titulo: String,
        corpo: String,
    ) = Unit

    override fun removerAlerta(id: String) = Unit
}

/**
 * Implementação real sobre [GeofencingClient]. `clienteGeofencing` é injetável para teste; em
 * produção vem de [LocationServices.getGeofencingClient].
 */
class GerenciadorGeofencingTurnosReal(
    private val contexto: Context,
    private val clienteGeofencing: GeofencingClient = LocationServices.getGeofencingClient(contexto),
    /**
     * Fábrica do `PendingIntent` do alerta — injetável porque `PendingIntent.getBroadcast` é um
     * método estático do Android, não mockável em teste de unidade puro (sem instrumentação).
     */
    private val criarPendingIntent: (id: String, canal: String, titulo: String, corpo: String) -> PendingIntent =
        { id, canal, titulo, corpo -> pendingIntentReal(contexto, id, canal, titulo, corpo) },
) : GerenciadorGeofencingTurnos {

    override fun registrarAlerta(
        id: String,
        centro: Coordenada,
        raioMetros: Float,
        expiraEm: Instant?,
        canalNotificacao: String,
        titulo: String,
        corpo: String,
    ) {
        if (!temPermissaoDeLocalizacao()) return

        try {
            val duracaoAteExpirar = expiraEm
                ?.let { Duration.between(Instant.now(), it).toMillis().coerceAtLeast(0) }
                ?: Geofence.NEVER_EXPIRE.toLong()

            val geofence = Geofence.Builder()
                .setRequestId(id)
                .setCircularRegion(centro.latitude, centro.longitude, raioMetros)
                .setExpirationDuration(duracaoAteExpirar)
                .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER)
                .build()

            val requisicao = GeofencingRequest.Builder()
                .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
                .addGeofence(geofence)
                .build()

            clienteGeofencing.addGeofences(requisicao, criarPendingIntent(id, canalNotificacao, titulo, corpo))
        } catch (_: SecurityException) {
            // Permissão revogada entre a checagem e a chamada — degrada graciosamente.
        }
    }

    override fun removerAlerta(id: String) {
        try {
            clienteGeofencing.removeGeofences(listOf(id))
        } catch (_: SecurityException) {
            // Mesma degradação defensiva de registrarAlerta.
        }
    }

    private fun temPermissaoDeLocalizacao(): Boolean {
        val fina = contexto.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
        val aproximada = contexto.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
        return fina == PackageManager.PERMISSION_GRANTED || aproximada == PackageManager.PERMISSION_GRANTED
    }
}

private fun pendingIntentReal(contexto: Context, id: String, canal: String, titulo: String, corpo: String): PendingIntent {
    val intencao = Intent(contexto, GeofenceAlertaReceiver::class.java).apply {
        putExtra(GeofenceAlertaReceiver.EXTRA_CANAL, canal)
        putExtra(GeofenceAlertaReceiver.EXTRA_TITULO, titulo)
        putExtra(GeofenceAlertaReceiver.EXTRA_CORPO, corpo)
    }
    // FLAG_MUTABLE é exigido pela Geofencing API — o sistema preenche extras no Intent entregue
    // de volta (ver GeofencingEvent.fromIntent).
    return PendingIntent.getBroadcast(
        contexto,
        id.hashCode(),
        intencao,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
    )
}
