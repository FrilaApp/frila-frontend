package br.com.frila.core.notificacoes

import android.app.NotificationManager
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * Matriz de compatibilidade (APIs 28 a 35) exigida pelo cartão 62.
 * Prova a criação dos canais, com som (IMPORTANCE_HIGH), vibração habilitada (shouldVibrate())
 * e o padrão de vibração em cada nível de API suportado (28 a 35).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 29, 30, 31, 32, 33, 34, 35])
class GerenciadorDeCanaisCompatibilidadeTest {

    @Test
    fun `criarCanais registra canais com som e vibracao em cada API suportada`() {
        val context = RuntimeEnvironment.getApplication()
        GerenciadorDeCanais.criarCanais(context)

        val manager = context.getSystemService(NotificationManager::class.java)
        assertNotNull("NotificationManager deve estar disponível", manager)

        val canalUrgencia = manager.getNotificationChannel(GerenciadorDeCanais.CANAL_URGENCIA)
        assertNotNull("Canal de urgência deve existir", canalUrgencia)
        assertEquals(NotificationManager.IMPORTANCE_HIGH, canalUrgencia.importance)
        assertTrue("Canal de urgência deve ter vibração ativa", canalUrgencia.shouldVibrate())
        assertArrayEquals(GerenciadorDeCanais.PADRAO_VIBRACAO_URGENCIA, canalUrgencia.vibrationPattern)

        val canalTurnos = manager.getNotificationChannel(GerenciadorDeCanais.CANAL_TURNOS)
        assertNotNull("Canal de turnos deve existir", canalTurnos)
        assertEquals(NotificationManager.IMPORTANCE_DEFAULT, canalTurnos.importance)

        val canalSistema = manager.getNotificationChannel(GerenciadorDeCanais.CANAL_SISTEMA)
        assertNotNull("Canal de sistema deve existir", canalSistema)
        assertEquals(NotificationManager.IMPORTANCE_DEFAULT, canalSistema.importance)
    }
}
