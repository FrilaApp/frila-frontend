package br.com.frila.app.desempenho

import android.app.Activity
import android.os.SystemClock
import androidx.compose.ui.test.junit4.createComposeRule
import br.com.frila.app.FrilaApplication
import br.com.frila.app.MainActivity
import br.com.frila.core.rede.MonitorDeConectividade
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.StatusConectividade
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.dsl.module
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Testes unitários e de integração do medidor de inicialização a frio (cold start) (Cartão 53, RNF04).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class MedidorDeColdStartTest {

    @get:Rule
    val compose = createComposeRule()

    @Before
    @After
    fun limparEstado() {
        try {
            stopKoin()
        } catch (_: Exception) {}
        MedidorDeColdStart.resetarParaTestes()
    }

    @Test
    fun `obterInicioDoProcesso retorna timestamp positivo valido`() {
        val inicioProcesso = MedidorDeColdStart.obterInicioDoProcesso()
        assertTrue("Timestamp de início do processo deve ser positivo", inicioProcesso > 0L)
    }

    @Test
    fun `marcarPrimeiroQuadro calcula TTID exato entre inicio do processo e primeiro quadro`() {
        val inicio = 1000L
        val fim = 1380L

        MedidorDeColdStart.iniciar(inicioMillis = inicio)
        val duracao = MedidorDeColdStart.marcarPrimeiroQuadro(fimMillis = fim)

        assertNotNull("Duração de TTID não deve ser nula após início", duracao)
        assertEquals(380L, duracao)
        assertTrue(MedidorDeColdStart.primeiroQuadroConcluido)
    }

    @Test
    fun `marcarInterfacePronta calcula TTFD exato e invoca reportFullyDrawn`() {
        val activity = mockk<Activity>(relaxed = true)
        val inicio = 1000L
        val fimPronto = 1650L

        MedidorDeColdStart.iniciar(inicioMillis = inicio)
        val duracaoPronto = MedidorDeColdStart.marcarInterfacePronta(activity = activity, fimMillis = fimPronto)

        assertNotNull("Duração de TTFD não deve ser nula após início", duracaoPronto)
        assertEquals(650L, duracaoPronto)
        assertTrue(MedidorDeColdStart.interfaceProntaConcluida)
        verify(exactly = 1) { activity.reportFullyDrawn() }
    }

    @Test
    fun `marcarPrimeiroQuadro e marcarInterfacePronta nao duplicam medicoes subsequentes`() {
        val inicio = 1000L
        MedidorDeColdStart.iniciar(inicioMillis = inicio)

        val primeiraMedicao = MedidorDeColdStart.marcarPrimeiroQuadro(fimMillis = 1400L)
        val segundaMedicao = MedidorDeColdStart.marcarPrimeiroQuadro(fimMillis = 1500L)

        assertEquals(400L, primeiraMedicao)
        assertNull("Segunda chamada de TTID deve retornar null para evitar duplicação", segundaMedicao)

        val primeiraProntidao = MedidorDeColdStart.marcarInterfacePronta(fimMillis = 1600L)
        val segundaProntidao = MedidorDeColdStart.marcarInterfacePronta(fimMillis = 1700L)

        assertEquals(600L, primeiraProntidao)
        assertNull("Segunda chamada de TTFD deve retornar null para evitar duplicação", segundaProntidao)
    }

    @Test
    fun `medicoes sem iniciar retornam null defensivamente`() {
        assertNull("marcarPrimeiroQuadro sem iniciar deve retornar null", MedidorDeColdStart.marcarPrimeiroQuadro(fimMillis = 2000L))
        assertNull("marcarInterfacePronta sem iniciar deve retornar null", MedidorDeColdStart.marcarInterfacePronta(fimMillis = 2000L))
        assertFalse(MedidorDeColdStart.estaIniciado)
    }

    @Test
    fun `formatarMensagens produzem textos padronizados para logcat com TTID e TTFD`() {
        val msgTTID = MedidorDeColdStart.formatarMensagemPrimeiroQuadro(250L)
        assertEquals("Cold start concluído até o primeiro quadro (TTID): 250ms", msgTTID)

        val msgTTFD = MedidorDeColdStart.formatarMensagemProntidao(480L)
        assertEquals("Cold start concluído com interface totalmente pronta (TTFD): 480ms", msgTTFD)
    }

    @Test
    fun `duracao negativa por inconsistencia de clock e truncada para zero`() {
        MedidorDeColdStart.iniciar(inicioMillis = 5000L)
        val duracao = MedidorDeColdStart.marcarPrimeiroQuadro(fimMillis = 4000L)
        assertEquals(0L, duracao)
    }

    @Test
    fun `MainActivity integra doOnPreDraw para primeiro quadro e notifica prontidao real da interface`() {
        // Configura Koin isolado para alimentar AppNavegacao em MainActivity
        startKoin {
            modules(
                module {
                    single<ArmazenamentoDeSessao> {
                        mockk(relaxed = true) {
                            every { estaAutenticado() } returns false
                            every { isBiometriaAtivada() } returns false
                        }
                    }
                    single<MonitorDeConectividade> {
                        MonitorDeConectividadeFalso(StatusConectividade.CONECTADO)
                    }
                    viewModel {
                        mockk<EntradaViewModel>(relaxed = true) {
                            every { estado } returns MutableStateFlow(EstadoEntrada())
                        }
                    }
                },
            )
        }

        MedidorDeColdStart.iniciar(inicioMillis = SystemClock.elapsedRealtime() - 100L)

        val controller = Robolectric.buildActivity(MainActivity::class.java)
        val activity = controller.create().get()

        assertFalse(
            "Antes do pre-draw, o primeiro quadro não deve estar registrado",
            MedidorDeColdStart.primeiroQuadroConcluido,
        )

        // Simula o ciclo de pré-desenho da view root (primeiro quadro real antes do desenho)
        activity.window.decorView.viewTreeObserver.dispatchOnPreDraw()
        assertTrue(
            "window.decorView.doOnPreDraw deve disparar e registrar o primeiro quadro (TTID)",
            MedidorDeColdStart.primeiroQuadroConcluido,
        )

        // Ao tornar a Activity visível e deixar o Compose estabilizar
        controller.start().postCreate(null).resume().visible()
        compose.waitForIdle()

        assertTrue(
            "aoPronto em AppNavegacao deve disparar marcarInterfacePronta (TTFD)",
            MedidorDeColdStart.interfaceProntaConcluida,
        )
    }

    @Test
    fun `inicializacao a frio registra inicio do processo e permite consulta de estado`() {
        assertFalse(MedidorDeColdStart.estaIniciado)
        MedidorDeColdStart.iniciar()
        assertTrue(MedidorDeColdStart.estaIniciado)
        assertTrue(MedidorDeColdStart.instanteInicioMillis > 0L)
    }
}
