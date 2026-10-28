package br.com.frila.feature.turnos

import android.app.Notification
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.time.Instant

/**
 * Constrói e posta/cancela no sistema Android a notificação persistente de turno em
 * andamento (RF11/RN06), a partir de [EspecificacaoNotificacaoTurno]. Única classe deste
 * fluxo que toca `Context`/`NotificationManagerCompat` — o que mostrar e quando
 * montar/cancelar já foi decidido em [GerenciadorNotificacaoTurno]/[EspecificacaoNotificacaoTurno],
 * puros e testados em JVM; aqui só a tradução para a API real do Android (`NotificationCompat`),
 * testada com Robolectric.
 */
class NotificadorTurnoAndroid(private val contexto: Context) {

    /**
     * Monta a `Notification` nativa: `setOngoing(true)` (RF11, não descartável com swipe
     * enquanto persistente), cronômetro nativo do Android em contagem regressiva
     * (`setUsesChronometer` + `setChronometerCountDown` + `setWhen(fimTurno)` — é o relógio do
     * próprio `Notification`, não um texto estático recalculado pelo app), e as duas ações
     * rápidas (detalhes do turno, suporte) no canal `especificacao.canal`
     * (`GerenciadorDeCanais.CANAL_TURNOS`).
     */
    fun construir(especificacao: EspecificacaoNotificacaoTurno, fimTurno: Instant): Notification =
        NotificationCompat.Builder(contexto, especificacao.canal)
            .setContentTitle(especificacao.titulo)
            .setContentText(especificacao.corpo)
            .setSmallIcon(android.R.drawable.stat_notify_chat)
            .setOngoing(especificacao.persistente)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setWhen(fimTurno.toEpochMilli())
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .addAction(acaoDetalhesDoTurno(especificacao.turnoId))
            .addAction(acaoSuporte(especificacao.turnoId))
            .build()

    /** Monta e posta a notificação no sistema, identificada por [idDaNotificacao]. */
    fun postar(especificacao: EspecificacaoNotificacaoTurno, fimTurno: Instant) {
        val notificacao = construir(especificacao, fimTurno)
        NotificationManagerCompat.from(contexto).notify(idDaNotificacao(especificacao.turnoId), notificacao)
    }

    /** Cancela a notificação do turno — chamado quando [GerenciadorNotificacaoTurno.avaliar] decide `Cancelar`. */
    fun cancelar(turnoId: String) {
        NotificationManagerCompat.from(contexto).cancel(idDaNotificacao(turnoId))
    }

    private fun acaoDetalhesDoTurno(turnoId: String): NotificationCompat.Action {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("frila://meus_turnos/$turnoId"))
            .setPackage(contexto.packageName)
        val pendingIntent = PendingIntent.getActivity(
            contexto,
            idDaNotificacao(turnoId),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Action(0, ROTULO_DETALHES, pendingIntent)
    }

    private fun acaoSuporte(turnoId: String): NotificationCompat.Action {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("frila://suporte?turno_id=$turnoId"))
            .setPackage(contexto.packageName)
        val pendingIntent = PendingIntent.getActivity(
            contexto,
            idDaNotificacao(turnoId) + 1,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Action(0, ROTULO_SUPORTE, pendingIntent)
    }

    companion object {
        const val ROTULO_DETALHES = "Ver turno"
        const val ROTULO_SUPORTE = "Suporte"

        /** Id estável por turno — a mesma notificação é atualizada, nunca duplicada. */
        fun idDaNotificacao(turnoId: String): Int = turnoId.hashCode()
    }
}
