package br.com.frila.core.notificacoes

import android.Manifest
import android.app.Application
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Bundle
import br.com.frila.core.dominio.regra.AtualizacaoAutomatica
import com.google.firebase.messaging.RemoteMessage
import io.mockk.every
import io.mockk.mockk
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.dsl.module
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * CJrHct3L (item 251): o toque no aviso sempre abre o app. Antes, o aviso só ganhava ação de toque quando havia link; o neutralizado (RN15) e o sem tipo
 * não tinham `contentIntent`, e tocar neles não fazia nada. Agora a ação existe nos dois casos, e sem link ela não leva dado nenhum: a
 * `EntradaDoAvisoActivity` abre o app como o ícone abre. O aviso neutralizado não expõe nada do original.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class AvisoSempreAbreOAppTest {

    private val processador = mockk<ProcessadorDePush>()
    private val app: Application get() = RuntimeEnvironment.getApplication()
    private val gerente get() = app.getSystemService(NotificationManager::class.java)

    @Before
    fun antes() {
        startKoin {
            modules(
                module {
                    single { mockk<RegistradorDeDispositivo>(relaxed = true) }
                    single { processador }
                    single { mockk<AtualizacaoAutomatica>(relaxed = true) }
                },
            )
        }
        shadowOf(app).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        gerente.createNotificationChannel(NotificationChannel(CANAL, "Canal de teste", NotificationManager.IMPORTANCE_DEFAULT))
    }

    @After
    fun depois() {
        stopKoin()
    }

    private fun aviso(
        neutralizada: Boolean = false,
        tipo: String? = "vaga_aberta",
        silenciada: Boolean = false,
    ) = NotificacaoParaExibir(
        canal = CANAL,
        titulo = if (neutralizada) "Você tem uma novidade no Frila" else "Vaga nova perto de você",
        corpo = if (neutralizada) "Abra o app para ver." else "Garçom, hoje à noite",
        vagaId = "vaga-secreta-123",
        neutralizada = neutralizada,
        silenciada = silenciada,
        chamadaId = "chamada-secreta-456",
        turnoId = "turno-secreto-789",
        tipo = tipo,
        posicaoId = "posicao-secreta-000",
    )

    private fun receber(notificacao: NotificacaoParaExibir): List<Notification> {
        every { processador.processar(any()) } returns notificacao
        val servico = Robolectric.buildService(FrilaFirebaseMessagingService::class.java).create().get()
        servico.onMessageReceived(RemoteMessage(Bundle()))
        return shadowOf(gerente).allNotifications
    }

    private fun toque(notificacao: Notification): Intent {
        val pendente: PendingIntent = assertNotNull("o aviso tem de ter ação de toque", notificacao.contentIntent).let { notificacao.contentIntent }
        return shadowOf(pendente).savedIntent
    }

    @Test
    fun `aviso com link abre a entrada do aviso com o link`() {
        val intent = toque(receber(aviso()).single())

        assertEquals(EntradaDoAvisoActivity::class.java.name, intent.component?.className)
        assertTrue(intent.dataString.orEmpty().startsWith("frila://aviso?tipo=vaga_aberta"))
    }

    @Test
    fun `aviso neutralizado tambem tem acao de toque, e ela nao leva dado nenhum`() {
        val intent = toque(receber(aviso(neutralizada = true)).single())

        assertEquals(EntradaDoAvisoActivity::class.java.name, intent.component?.className)
        assertNull("o link do aviso neutralizado não pode vazar", intent.data)
        assertNull(intent.extras)
        assertNull(intent.action)
        assertTrue("nada do original (ids do aviso) na ação de toque", !intent.toUri(0).contains("secret"))
    }

    @Test
    fun `aviso sem tipo tambem tem acao de toque, sem dado`() {
        val intent = toque(receber(aviso(tipo = null)).single())

        assertEquals(EntradaDoAvisoActivity::class.java.name, intent.component?.className)
        assertNull(intent.data)
        assertNull(intent.extras)
    }

    @Test
    fun `aviso com tipo em branco tambem tem acao de toque, sem dado`() {
        val intent = toque(receber(aviso(tipo = "   ")).single())

        assertEquals(EntradaDoAvisoActivity::class.java.name, intent.component?.className)
        assertNull(intent.data)
        assertNull(intent.extras)
    }

    @Test
    fun `a acao de toque e imutavel nos dois casos`() {
        val comLink = receber(aviso()).single().contentIntent
        val semLink = receber(aviso(neutralizada = true)).last().contentIntent

        assertTrue(shadowOf(comLink).flags and PendingIntent.FLAG_IMMUTABLE != 0)
        assertTrue(shadowOf(semLink).flags and PendingIntent.FLAG_IMMUTABLE != 0)
    }

    @Test
    fun `aviso silenciado continua sem notificar`() {
        assertTrue(receber(aviso(silenciada = true)).isEmpty())
    }

    private companion object {
        const val CANAL = "canal_teste"
    }
}
