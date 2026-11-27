package br.com.frila.app

import android.app.Application
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.ui.test.junit4.createEmptyComposeRule
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
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.After
import org.junit.AfterClass
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import br.com.frila.core.notificacoes.CaixaDoAvisoDoToque
import br.com.frila.core.notificacoes.EntradaDoAvisoActivity
import org.robolectric.Robolectric
import org.robolectric.Shadows.shadowOf
import org.junit.Before
import org.junit.BeforeClass
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * A `MainActivity` de verdade, aberta pelo Intent que outro app do aparelho consegue mandar (ela é exportada): um
 * `frila://aviso` com o tipo e o turno. A conta é de profissional, e a tela do turno do aviso é a única que pede
 * `MeusTurnosViewModel.carregar()`; o feed não pede.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AvisoDoPushNaMainActivityTest {

    @get:Rule
    val rule = createEmptyComposeRule()

    private var cena: ActivityScenario<MainActivity>? = null
    private val contexto: Context get() = ApplicationProvider.getApplicationContext()

    @Before
    fun antes() {
        cargasDoTurno.set(0)
        CaixaDoAvisoDoToque.consumir()
    }

    @After
    fun depois() {
        cena?.close()
        rule.waitForIdle()
    }

    private fun abrir(intent: Intent) {
        cena = ActivityScenario.launch(intent.putExtra(PoliticaDaAbertura.EXTRA_PULAR_ABERTURA, true))
    }

    /** Espera [prazoMs] e devolve se a tela do turno do aviso abriu nesse tempo. */
    private fun abriuOTurno(prazoMs: Long = 6_000): Boolean =
        try {
            rule.waitUntil(prazoMs) { cargasDoTurno.get() > 0 }
            true
        } catch (_: androidx.compose.ui.test.ComposeTimeoutException) {
            false
        }

    @Test
    fun `Intent de outro app com frila aviso nao abre tela nenhuma`() {
        val deFora = Intent(Intent.ACTION_VIEW, Uri.parse("frila://aviso?tipo=confirmacao&turno_id=$TURNO"))
            .setComponent(ComponentName(contexto, MainActivity::class.java))

        abrir(deFora)

        assertEquals("o Intent de fora abriu o turno do aviso", false, abriuOTurno())
    }

    /** O caminho do PendingIntent: a entrada não exportada guarda o aviso e abre o app como o ícone abre. */
    @Test
    fun `o toque pela entrada nao exportada abre o turno do aviso`() {
        val entrada = Robolectric.buildActivity(
            EntradaDoAvisoActivity::class.java,
            Intent(contexto, EntradaDoAvisoActivity::class.java).setData(Uri.parse("frila://aviso?tipo=confirmacao&turno_id=$TURNO")),
        ).create().get()
        val abertura = shadowOf(contexto as Application).nextStartedActivity

        assertTrue("a entrada não terminou", entrada.isFinishing)
        assertEquals(ComponentName(contexto, MainActivity::class.java), abertura.component)
        abrir(abertura)

        assertEquals("o toque pelo PendingIntent não abriu o turno", true, abriuOTurno())
    }

    @Test
    fun `a entrada so guarda link de aviso`() {
        Robolectric.buildActivity(
            EntradaDoAvisoActivity::class.java,
            Intent(contexto, EntradaDoAvisoActivity::class.java).setData(Uri.parse("frila://vagas/$TURNO")),
        ).create()

        assertEquals(null, CaixaDoAvisoDoToque.link.value)
    }

    @Test
    fun `controle - a abertura normal pelo lancador nao abre o turno`() {
        abrir(Intent(contexto, MainActivity::class.java))

        assertEquals(false, abriuOTurno(prazoMs = 3_000))
    }

    companion object {
        private const val TURNO = "60000000-0000-0000-0000-000000000001"
        private val cargasDoTurno = AtomicInteger(0)

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
                every { carregar() } answers { cargasDoTurno.incrementAndGet(); Job() }
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
