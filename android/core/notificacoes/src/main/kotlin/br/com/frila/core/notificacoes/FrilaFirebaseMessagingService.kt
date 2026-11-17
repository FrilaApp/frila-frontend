package br.com.frila.core.notificacoes

import android.Manifest
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import br.com.frila.core.rede.ErroDaApi
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

/**
 * Serviço nativo de push FCM. Registra o token em [onNewToken] (RF06) e processa o push
 * recebido em [onMessageReceived] via [ProcessadorDePush], que aplica o isolamento de conta
 * por `vinculo_id` (RN15) antes de qualquer exibição.
 *
 * As dependências vêm do Koin montado pelo `:app` (ver `docs/android/01-arquitetura-e-modulos.md`
 * §5) — este serviço não constrói nada sozinho, só injeta.
 */
class FrilaFirebaseMessagingService : FirebaseMessagingService(), KoinComponent {

    private val registradorDeDispositivo: RegistradorDeDispositivo by inject()
    private val processadorDePush: ProcessadorDePush by inject()

    private val escopo = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        escopo.launch {
            try {
                registradorDeDispositivo.registrarComToken(token)
            } catch (_: ErroDaApi) {
                // Registro de dispositivo não pode travar o app nem a entrega de outros pushes;
                // falha aqui só significa tentar de novo na próxima abertura do app.
            }
        }
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        val notificacao = processadorDePush.processar(remoteMessage.data)
        exibir(notificacao)
    }

    private fun exibir(notificacao: NotificacaoParaExibir) {
        // RF06: canal desativado pelo usuário nas preferências locais — não notifica.
        if (notificacao.silenciada) return
        // Android 13 ou mais: sem a permissão de aviso, nada a mostrar.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val builder = NotificationCompat.Builder(this, notificacao.canal)
            .setContentTitle(notificacao.titulo)
            .setContentText(notificacao.corpo)
            // Ícone provisório do framework — o :app substitui por um recurso de marca próprio
            // antes do release (ver docs/android/README.md, Épico E5).
            .setSmallIcon(android.R.drawable.stat_notify_chat)
            .setPriority(prioridadeParaCanal(notificacao.canal))
            .setAutoCancel(true)

        ResolvedorDeDeepLinkPush.resolver(notificacao)?.let { deepLink ->
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(deepLink)).setPackage(packageName)
            val pendingIntent = PendingIntent.getActivity(
                this,
                deepLink.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            builder.setContentIntent(pendingIntent)
        }

        NotificationManagerCompat.from(this).notify(notificacao.hashCode(), builder.build())
    }

    private fun prioridadeParaCanal(canal: String): Int = when (canal) {
        GerenciadorDeCanais.CANAL_URGENCIA -> NotificationCompat.PRIORITY_HIGH
        else -> NotificationCompat.PRIORITY_DEFAULT
    }
}
