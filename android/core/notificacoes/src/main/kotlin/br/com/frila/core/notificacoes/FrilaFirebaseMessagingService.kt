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
import br.com.frila.core.dominio.regra.AtualizacaoAutomatica
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
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
    private val atualizacaoAutomatica: AtualizacaoAutomatica by inject()

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // Registro de dispositivo não pode travar nem derrubar o app (erro de rede incluso): o registrador pega tudo,
        // só registra o motivo, e a próxima abertura com sessão tenta de novo.
        registradorDeDispositivo.registrarTokenNovoEmSegundoPlano(token)
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        val notificacao = processadorDePush.processar(remoteMessage.data)
        // As listas abertas relêem (HaRJJ0L0), mesmo com o canal silenciado ou sem a permissão de aviso: o dado mudou.
        AvisoParaAtualizacao.sinalizar(notificacao, atualizacaoAutomatica)
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

        // O toque sempre abre o app (item 251). Com link (`frila://aviso?...`), a entrada do aviso o põe na fila; sem link (aviso neutralizado,
        // RN15, ou sem tipo), a intenção não leva dado nenhum: a `EntradaDoAvisoActivity` abre o app como o ícone abre, e nada do aviso original vaza.
        val deepLink = ResolvedorDeDeepLinkPush.resolver(notificacao)
        // Explícito e para a entrada não exportada: só este PendingIntent põe um aviso na fila.
        val intent = Intent(this, EntradaDoAvisoActivity::class.java)
        deepLink?.let { intent.data = Uri.parse(it) }
        builder.setContentIntent(
            PendingIntent.getActivity(
                this,
                deepLink.orEmpty().hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            ),
        )

        NotificationManagerCompat.from(this).notify(notificacao.hashCode(), builder.build())
    }

    private fun prioridadeParaCanal(canal: String): Int = when (canal) {
        GerenciadorDeCanais.CANAL_URGENCIA -> NotificationCompat.PRIORITY_HIGH
        else -> NotificationCompat.PRIORITY_DEFAULT
    }
}
