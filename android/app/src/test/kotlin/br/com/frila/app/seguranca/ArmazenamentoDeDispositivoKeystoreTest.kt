package br.com.frila.app.seguranca

import android.content.SharedPreferences
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ArmazenamentoDeDispositivoKeystoreTest {

    @Test
    fun `armazenamento de dispositivo isola por conta e nao interfere na sessao`() {
        val contexto = RuntimeEnvironment.getApplication()
        val prefsDispositivo = contexto.getSharedPreferences("test_dispositivo_seguro", 0).also { it.edit().clear().commit() }
        val prefsSessao = contexto.getSharedPreferences("test_sessao_segura", 0).also { it.edit().clear().commit() }

        val armazenamentoDispositivo = ArmazenamentoDeDispositivoKeystore(contexto) { prefsDispositivo }
        val armazenamentoSessao = ArmazenamentoDeSessaoKeystore(contexto) { prefsSessao }

        armazenamentoDispositivo.salvarToken("  Alice@Exemplo.Test ", "tok-alice")
        armazenamentoDispositivo.salvarToken("bob@exemplo.test", "tok-bob")

        assertNotEquals(
            ArmazenamentoDeDispositivoKeystore.chaveDaConta("alice@exemplo.test"),
            ArmazenamentoDeDispositivoKeystore.chaveDaConta("bob@exemplo.test"),
        )
        assertEquals("tok-alice", armazenamentoDispositivo.obterToken("alice@exemplo.test"))
        assertEquals("tok-bob", armazenamentoDispositivo.obterToken("bob@exemplo.test"))

        // Logout normal limpa apenas a sessão e preserva a confiança do dispositivo.
        armazenamentoSessao.limparSessao()
        assertEquals("tok-alice", armazenamentoDispositivo.obterToken("alice@exemplo.test"))

        armazenamentoDispositivo.removerToken("alice@exemplo.test")
        assertNull(armazenamentoDispositivo.obterToken("alice@exemplo.test"))
        assertEquals("tok-bob", armazenamentoDispositivo.obterToken("bob@exemplo.test"))

        armazenamentoDispositivo.removerTodos()
        assertNull(armazenamentoDispositivo.obterToken("bob@exemplo.test"))
    }
}
