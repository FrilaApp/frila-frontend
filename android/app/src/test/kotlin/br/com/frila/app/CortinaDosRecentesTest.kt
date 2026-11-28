package br.com.frila.app

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.Intent
import android.view.WindowManager
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import br.com.frila.core.rede.MonitorDeConectividade
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.turnos.EstadoMeusTurnos
import br.com.frila.feature.turnos.MeusTurnosViewModel
import br.com.frila.feature.vagas.feed.EstadoFeed
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.vagas.feed.StatusFeed
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.AfterClass
import org.junit.BeforeClass
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.dsl.module
import io.mockk.verify
import java.util.concurrent.CopyOnWriteArrayList
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.shadows.ShadowActivity

/** Observa o que a MainActivity pede ao sistema: o Robolectric não guarda o estado da miniatura dos recentes. */
@Implements(Activity::class)
class ShadowActivityDosRecentes : ShadowActivity() {
    @Implementation
    fun setRecentsScreenshotEnabled(habilitada: Boolean) {
        PEDIDOS.add(habilitada)
    }

    companion object {
        val PEDIDOS = CopyOnWriteArrayList<Boolean>()
    }
}

@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, shadows = [ShadowActivityDosRecentes::class])
class CortinaDosRecentesTest {
    private var cena: ActivityScenario<MainActivity>? = null
    private val contexto: Context get() = ApplicationProvider.getApplicationContext()

    @Before
    fun antes() {
        ShadowActivityDosRecentes.PEDIDOS.clear()
    }

    @After
    fun depois() {
        cena?.close()
    }

    private fun abrirMainActivity(): MainActivity {
        var activity: MainActivity? = null
        cena = ActivityScenario.launch<MainActivity>(
            Intent(contexto, MainActivity::class.java).putExtra(PoliticaDaAbertura.EXTRA_PULAR_ABERTURA, true),
        ).also { it.onActivity { a -> activity = a } }
        return requireNotNull(activity)
    }

    @Test
    @Config(sdk = [33])
    fun `no Android 13 a MainActivity tira a miniatura dos recentes ao abrir`() {
        abrirMainActivity()
        assertEquals(listOf(false), ShadowActivityDosRecentes.PEDIDOS.toList())
    }

    @Test
    @Config(sdk = [32])
    fun `no Android 12L nao pede nada e nao usa FLAG_SECURE`() {
        val activity = abrirMainActivity()
        assertTrue(ShadowActivityDosRecentes.PEDIDOS.isEmpty())
        assertEquals(0, activity.window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE)
    }

    @Test
    @Config(sdk = [33])
    fun `no Android 13 tambem nao bloqueia a captura de tela`() {
        val activity = abrirMainActivity()
        assertEquals(0, activity.window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE)
    }

    @Test
    @Config(sdk = [35])
    fun `a funcao so chama a API a partir do 33`() {
        val activity = mockk<Activity>(relaxed = true)
        esconderMiniaturaNosRecentes(activity, sdk = 32)
        verify(exactly = 0) { activity.setRecentsScreenshotEnabled(any()) }
        esconderMiniaturaNosRecentes(activity, sdk = 33)
        verify(exactly = 1) { activity.setRecentsScreenshotEnabled(false) }
        esconderMiniaturaNosRecentes(activity, sdk = 28)
        verify(exactly = 1) { activity.setRecentsScreenshotEnabled(any()) }
    }

    companion object {
        @JvmStatic @BeforeClass fun iniciarKoin() {
            EscopoPadraoDoKoinCompose.reiniciar()
            val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
                every { estaAutenticado() } returns true
                every { isBiometriaAtivada() } returns false
            }
            val feed = mockk<FeedVagasViewModel>(relaxed = true) {
                every { estado } returns MutableStateFlow(EstadoFeed(status = StatusFeed.SUCESSO))
            }
            val turnos = mockk<MeusTurnosViewModel>(relaxed = true) {
                every { estado } returns MutableStateFlow(EstadoMeusTurnos())
            }
            startKoin {
                modules(
                    module {
                        single<ArmazenamentoDeSessao> { sessao }
                        single<MonitorDeConectividade> { MonitorDeConectividadeFalso() }
                        single {
                            AvaliadorDeDestino(
                                descobrir = { DestinoDaConta.Profissional },
                                guardado = DestinoGuardadoEmMemoria(),
                                sessaoGuardada = { true },
                            )
                        }
                        viewModel { feed }
                        viewModel { turnos }
                    },
                )
            }
        }

        @JvmStatic @AfterClass fun pararKoin() {
            stopKoin()
            EscopoPadraoDoKoinCompose.reiniciar()
        }
    }
}
