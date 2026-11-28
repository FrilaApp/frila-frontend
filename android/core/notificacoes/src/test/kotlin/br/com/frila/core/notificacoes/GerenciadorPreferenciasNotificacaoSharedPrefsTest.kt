package br.com.frila.core.notificacoes

import android.content.Context
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * Cartão bcelEBBA (item 252): a implementação de produção, gravada em `SharedPreferences`. Até aqui só a versão em memória tinha
 * teste. O arquivo é lido pelo nome literal, e não pela constante: trocar o nome perderia o que cada instalação já gravou.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class GerenciadorPreferenciasNotificacaoSharedPrefsTest {

    private val contexto: Context = RuntimeEnvironment.getApplication()

    private fun arquivoGravado() = contexto.getSharedPreferences("preferencias_notificacoes", Context.MODE_PRIVATE)

    @Test
    fun `numa instalacao nova todo canal comeca ligado`() {
        val gerenciador = GerenciadorPreferenciasNotificacaoSharedPrefs(contexto)

        for (canal in listOf(GerenciadorDeCanais.CANAL_URGENCIA, GerenciadorDeCanais.CANAL_TURNOS, GerenciadorDeCanais.CANAL_SISTEMA)) {
            assertTrue("$canal desligado sem o usuário pedir silenciaria os avisos", gerenciador.estaAtivado(canal))
        }
    }

    @Test
    fun `desligar e religar um canal persiste entre instancias, no arquivo de sempre`() {
        GerenciadorPreferenciasNotificacaoSharedPrefs(contexto).definirAtivado(GerenciadorDeCanais.CANAL_TURNOS, false)

        assertFalse(GerenciadorPreferenciasNotificacaoSharedPrefs(contexto).estaAtivado(GerenciadorDeCanais.CANAL_TURNOS))
        assertEquals(false, arquivoGravado().all[GerenciadorDeCanais.CANAL_TURNOS])

        GerenciadorPreferenciasNotificacaoSharedPrefs(contexto).definirAtivado(GerenciadorDeCanais.CANAL_TURNOS, true)

        assertTrue(GerenciadorPreferenciasNotificacaoSharedPrefs(contexto).estaAtivado(GerenciadorDeCanais.CANAL_TURNOS))
        assertEquals(true, arquivoGravado().all[GerenciadorDeCanais.CANAL_TURNOS])
    }

    @Test
    fun `o que ja estava gravado no arquivo e lido`() {
        // Uma instalação antiga, com o canal desligado antes desta versão do app.
        arquivoGravado().edit().putBoolean(GerenciadorDeCanais.CANAL_URGENCIA, false).commit()

        assertFalse(GerenciadorPreferenciasNotificacaoSharedPrefs(contexto).estaAtivado(GerenciadorDeCanais.CANAL_URGENCIA))
    }

    @Test
    fun `desligar um canal nao desliga os outros`() {
        GerenciadorPreferenciasNotificacaoSharedPrefs(contexto).definirAtivado(GerenciadorDeCanais.CANAL_TURNOS, false)

        val outra = GerenciadorPreferenciasNotificacaoSharedPrefs(contexto)
        assertFalse(outra.estaAtivado(GerenciadorDeCanais.CANAL_TURNOS))
        assertTrue(outra.estaAtivado(GerenciadorDeCanais.CANAL_URGENCIA))
        assertTrue(outra.estaAtivado(GerenciadorDeCanais.CANAL_SISTEMA))
    }
}
