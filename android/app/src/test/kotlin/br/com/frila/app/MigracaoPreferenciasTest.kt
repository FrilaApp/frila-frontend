package br.com.frila.app

import android.app.Application
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import br.com.frila.feature.vagas.feed.ArmazenamentoPreferenciasFiltro
import br.com.frila.feature.vagas.feed.ArmazenamentoPreferenciasFiltroDataStore
import br.com.frila.feature.vagas.feed.PreferenciaFaixaRemuneracao
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.koin.dsl.koinApplication
import org.koin.dsl.module
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class MigracaoPreferenciasTest {
    @get:Rule val pasta = TemporaryFolder()
    private val contexto get() = ApplicationProvider.getApplicationContext<Context>()
    private val legado get() = contexto.getSharedPreferences("preferencias_filtros_vagas", Context.MODE_PRIVATE)
    private val minimo = "filtro_remuneracao_hora_minimo"
    private val maximo = "filtro_remuneracao_hora_maximo"
    private val ativa = "filtro_remuneracao_hora_ativa"
    private val arquivo get() = File(pasta.root, "filtros.preferences_pb")

    private fun gravarLegado() {
        assertTrue(legado.edit().clear().putFloat(minimo, 35f).putFloat(maximo, 95f)
            .putBoolean(ativa, true).commit())
    }
    private suspend fun usar(bloco: suspend (PreferenciasAndroid, ArmazenamentoPreferenciasFiltroDataStore) -> Unit) {
        val trabalho = SupervisorJob()
        val preferencias = PreferenciasAndroid(contexto, arquivo, CoroutineScope(trabalho + Dispatchers.IO))
        try { bloco(preferencias, ArmazenamentoPreferenciasFiltroDataStore(preferencias.dados)) }
        finally { preferencias.close(); trabalho.cancelAndJoin() }
    }

    @Test fun `migra valores exatos e remove duplicatas antigas sem tocar notificacoes`() = runBlocking {
        gravarLegado()
        val notificacoes = contexto.getSharedPreferences("preferencias_notificacoes", Context.MODE_PRIVATE)
        notificacoes.edit().putBoolean("turnos", false).commit()
        usar { preferencias, _ ->
            val grafo = koinApplication { modules(moduloFeatures, module {
                single<Context> { contexto }
                single { preferencias }
            }) }
            try {
                val filtros = grafo.koin.get<ArmazenamentoPreferenciasFiltro>()
                assertTrue(filtros is ArmazenamentoPreferenciasFiltroDataStore)
                assertEquals(PreferenciaFaixaRemuneracao(35f, 95f, true), filtros.obterFaixaRemuneracaoHora())
                assertEquals(3, preferencias.dados.data.first().asMap().size)
                assertTrue(legado.all.isEmpty())
                assertFalse(notificacoes.getBoolean("turnos", true))
            } finally { grafo.close() }
        }
        usar { _, filtros ->
            assertEquals(PreferenciaFaixaRemuneracao(35f, 95f, true), filtros.obterFaixaRemuneracaoHora())
            assertTrue(legado.all.isEmpty())
        }
    }

    @Test fun `migracao repetida preserva valor novo e limpa chave antiga sem duplicar`() = runBlocking {
        gravarLegado()
        usar { _, filtros -> filtros.salvarFaixaRemuneracaoHora(40f, 80f, false) }
        // Simula valores legados remanescentes: o DataStore já gravado deve prevalecer.
        gravarLegado()
        usar { preferencias, filtros ->
            assertEquals(PreferenciaFaixaRemuneracao(40f, 80f, false), filtros.obterFaixaRemuneracaoHora())
            assertEquals(3, preferencias.dados.data.first().asMap().size)
            assertTrue(legado.all.isEmpty())
        }
    }

    @Test fun `novas gravacoes e limpeza usam somente DataStore e sobrevivem a reabertura`() = runBlocking {
        gravarLegado()
        usar { _, filtros ->
            filtros.salvarFaixaRemuneracaoHora(30f, 70f, false)
            assertTrue(legado.all.isEmpty())
        }
        usar { _, filtros ->
            assertEquals(PreferenciaFaixaRemuneracao(30f, 70f, false), filtros.obterFaixaRemuneracaoHora())
            filtros.limparFaixaRemuneracaoHora()
        }
        usar { preferencias, filtros ->
            assertNull(filtros.obterFaixaRemuneracaoHora())
            assertTrue(preferencias.dados.data.first().asMap().isEmpty())
            assertTrue(legado.all.isEmpty())
        }
    }

    @Test fun `arquivo corrompido recupera padrao e permite nova persistencia`() = runBlocking {
        legado.edit().clear().commit()
        arquivo.writeBytes(byteArrayOf(0x0f, 0x7f, 0x12))
        usar { _, filtros ->
            assertNull(filtros.obterFaixaRemuneracaoHora())
            filtros.salvarFaixaRemuneracaoHora(20f, 60f, true)
        }
        usar { _, filtros ->
            assertEquals(PreferenciaFaixaRemuneracao(20f, 60f, true), filtros.obterFaixaRemuneracaoHora())
        }
    }
}
