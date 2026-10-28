package br.com.frila.feature.turnos

import android.app.Notification
import android.app.NotificationManager
import br.com.frila.core.notificacoes.GerenciadorDeCanais
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class NotificadorTurnoAndroidTest {

    private val contexto = RuntimeEnvironment.getApplication()
    private val notificador = NotificadorTurnoAndroid(contexto)

    private val turnoId = "t-1"
    private val fimTurno: Instant = Instant.parse("2026-11-02T02:00:00Z")

    private fun especificacao(): EspecificacaoNotificacaoTurno = EspecificacaoNotificacaoTurno.paraTurnoEmAndamento(
        turnoId = turnoId,
        funcaoNome = "garçom",
        estabelecimentoNome = "Bar do Lago",
        fimTurno = fimTurno,
        instanteAtual = fimTurno.minusSeconds(1800),
    )

    @Test
    fun `notificacao construida e ongoing (FLAG_ONGOING_EVENT) e usa o canal de turnos`() {
        val notificacao = notificador.construir(especificacao(), fimTurno)

        assertTrue((notificacao.flags and Notification.FLAG_ONGOING_EVENT) != 0)
        assertEquals(GerenciadorDeCanais.CANAL_TURNOS, notificacao.channelId)
    }

    @Test
    fun `notificacao usa cronometro nativo em contagem regressiva ate o fim do turno`() {
        val notificacao = notificador.construir(especificacao(), fimTurno)

        assertTrue(notificacao.extras.getBoolean(Notification.EXTRA_SHOW_CHRONOMETER))
        assertTrue(notificacao.extras.getBoolean(Notification.EXTRA_CHRONOMETER_COUNT_DOWN))
        assertEquals(fimTurno.toEpochMilli(), notificacao.`when`)
    }

    @Test
    fun `notificacao tem as duas acoes rapidas de detalhes do turno e suporte`() {
        val notificacao = notificador.construir(especificacao(), fimTurno)

        assertEquals(2, notificacao.actions.size)
        val titulos = notificacao.actions.map { it.title.toString() }
        assertTrue(titulos.contains(NotificadorTurnoAndroid.ROTULO_DETALHES))
        assertTrue(titulos.contains(NotificadorTurnoAndroid.ROTULO_SUPORTE))
        assertTrue(notificacao.actions.all { it.actionIntent != null })
    }

    @Test
    fun `postar registra a notificacao ativa no sistema com o id do turno`() {
        notificador.postar(especificacao(), fimTurno)

        val gerenciador = contexto.getSystemService(NotificationManager::class.java)
        val ativas = shadowOf(gerenciador).allNotifications

        assertEquals(1, ativas.size)
    }

    @Test
    fun `cancelar remove a notificacao ativa do turno`() {
        notificador.postar(especificacao(), fimTurno)
        notificador.cancelar(turnoId)

        val gerenciador = contexto.getSystemService(NotificationManager::class.java)
        val ativas = shadowOf(gerenciador).allNotifications

        assertTrue(ativas.isEmpty())
    }

    @Test
    fun `cancelar sem notificacao ativa nao lanca exececao`() {
        notificador.cancelar("turno-inexistente")

        val gerenciador = contexto.getSystemService(NotificationManager::class.java)
        assertNull(shadowOf(gerenciador).getNotification(NotificadorTurnoAndroid.idDaNotificacao("turno-inexistente")))
    }
}
