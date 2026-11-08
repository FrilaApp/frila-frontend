package br.com.frila.core.localizacao

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import br.com.frila.core.notificacoes.GerenciadorPreferenciasNotificacao
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import com.google.android.gms.location.LocationServices
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

/**
 * Recebe a transição `ENTER` de um geofence registrado por [GerenciadorGeofencingTurnosReal] e
 * mostra o alerta local de aproximação (RN06). Canal, título e corpo vêm como extras — este
 * receiver é agnóstico de turno/vaga de propósito.
 *
 * RF06 (bloqueante do Shisui, PR #598): [MonitorizadorDeTurnosProximos] já evita registrar a
 * geofence quando o canal está desativado, mas uma geofence registrada ANTES do usuário desligar
 * a preferência continua ativa no sistema até expirar — por isso esta checagem é repetida aqui,
 * no momento exato do disparo, não só no registro.
 *
 * RNF04: o alerta é único por turno — a própria geofence é removida depois de disparar, para
 * não notificar de novo e não continuar monitorando sem necessidade.
 */
class GeofenceAlertaReceiver : BroadcastReceiver(), KoinComponent {

    private val preferenciasNotificacao: GerenciadorPreferenciasNotificacao by inject()

    override fun onReceive(context: Context, intent: Intent) {
        val evento = GeofencingEvent.fromIntent(intent) ?: return
        if (evento.hasError()) return
        if (evento.geofenceTransition != Geofence.GEOFENCE_TRANSITION_ENTER) return

        val canal = intent.getStringExtra(EXTRA_CANAL) ?: return
        val titulo = intent.getStringExtra(EXTRA_TITULO).orEmpty()
        val corpo = intent.getStringExtra(EXTRA_CORPO).orEmpty()
        val idsDisparados = evento.triggeringGeofences.orEmpty().map { it.requestId }

        if (preferenciasNotificacao.estaAtivado(canal)) {
            mostrarNotificacao(context, canal, titulo, corpo, idsDisparados.firstOrNull())
        }

        if (idsDisparados.isNotEmpty()) {
            try {
                LocationServices.getGeofencingClient(context).removeGeofences(idsDisparados)
            } catch (_: SecurityException) {
                // Defensivo: a remoção é só uma otimização de bateria, não é crítica.
            }
        }
    }

    private fun mostrarNotificacao(context: Context, canal: String, titulo: String, corpo: String, idDoAlerta: String?) {
        try {
            val notificacao = NotificationCompat.Builder(context, canal)
                .setContentTitle(titulo)
                .setContentText(corpo)
                .setSmallIcon(android.R.drawable.stat_notify_chat)
                .setAutoCancel(true)
                .build()
            NotificationManagerCompat.from(context).notify(idDoAlerta?.hashCode() ?: titulo.hashCode(), notificacao)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS negada — degrada graciosamente, sem crash (mesma convenção de FrilaFirebaseMessagingService).
        }
    }

    companion object {
        const val EXTRA_CANAL = "br.com.frila.core.localizacao.EXTRA_CANAL"
        const val EXTRA_TITULO = "br.com.frila.core.localizacao.EXTRA_TITULO"
        const val EXTRA_CORPO = "br.com.frila.core.localizacao.EXTRA_CORPO"
    }
}
