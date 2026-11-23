package br.com.frila.app

import android.app.Application
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import br.com.frila.app.seguranca.CoordenadorDeLogout
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import io.mockk.mockk
import io.mockk.verify
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class PreferenciasAparenciaTest {
    @get:Rule val pasta = TemporaryFolder()
    private val contexto get() = ApplicationProvider.getApplicationContext<Context>()
    private val arquivo get() = File(pasta.root, "datastore/filtros.preferences_pb")

    private suspend fun usar(bloco: suspend (PreferenciasAparencia) -> Unit) {
        val trabalho = SupervisorJob()
        val local = PreferenciasAndroid(contexto, arquivo, CoroutineScope(trabalho + Dispatchers.IO))
        try { bloco(PreferenciasAparencia(local.dados)) }
        finally { local.close(); trabalho.cancelAndJoin() }
    }

    @Test fun `padrao claro e escolhas persistem entre instancias`() = runBlocking {
        usar {
            assertFalse(it.temaEscuro.first())
            it.escolher(true)
            assertTrue(it.temaEscuro.first())
        }
        usar {
            assertTrue(it.temaEscuro.first())
            it.escolher(false)
        }
        usar { assertFalse(it.temaEscuro.first()) }
    }

    @Test fun `logout real limpa a sessao e preserva a escolha do aparelho`() = runBlocking {
        val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true)
        usar {
            it.escolher(true)
            CoordenadorDeLogout(sessao, diretorioArquivos = pasta.root).deslogar()
            verify(exactly = 1) { sessao.limparSessao() }
            assertTrue(arquivo.exists())
            assertTrue(it.temaEscuro.first())
        }
        usar { assertTrue(it.temaEscuro.first()) }
    }
}
