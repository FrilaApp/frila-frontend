package br.com.frila.app

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.rede.StatusConectividade
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.perfil.EstadoPontoBase
import br.com.frila.feature.perfil.PontoBaseViewModel
import br.com.frila.feature.perfil.TextosPontoBase
import br.com.frila.feature.vagas.feed.EstadoFeed
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.vagas.feed.StatusFeed
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Ponto base (tela provisória): a lista de vagas que o servidor recusou por falta dele leva à tela, e salvar devolve à lista, que recarrega. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = android.app.Application::class, qualifiers = "w411dp-h891dp")
class AppNavegacaoPontoBaseTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste()

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private val feed = mockk<FeedVagasViewModel>(relaxed = true) {
        every { estado } returns MutableStateFlow(EstadoFeed(status = StatusFeed.ERRO, semPontoBase = true))
    }
    private val estadoDoPontoBase = MutableStateFlow(EstadoPontoBase())
    private val pontoBase = mockk<PontoBaseViewModel>(relaxed = true) {
        every { estado } returns estadoDoPontoBase
    }
    private lateinit var navController: NavHostController

    private fun abrirOApp() {
        val armazenamento = mockk<ArmazenamentoDeSessao>(relaxed = true)
        every { armazenamento.estaAutenticado() } returns true
        every { armazenamento.isBiometriaAtivada() } returns false
        rule.setContent {
            navController = rememberNavController()
            KoinApplication(application = {
                modules(
                    module {
                        single { mockk<ServicoAutenticacao>(relaxed = true) }
                        single { armazenamento }
                        viewModel { EntradaViewModel(get()) }
                        viewModel { feed }
                        viewModel { pontoBase }
                    },
                )
            }) {
                AppNavegacao(
                    armazenamentoDeSessao = armazenamento,
                    monitorDeConectividade = MonitorDeConectividadeFalso(StatusConectividade.CONECTADO),
                    navController = navController,
                    servicoMembros = null,
                )
            }
        }
        rule.waitForIdle()
    }

    private fun rotaAtual(): String? = rule.runOnUiThread<String?> { navController.currentDestination?.route }

    @Test
    fun `a lista sem ponto base leva a tela do ponto base`() {
        abrirOApp()

        rule.onNodeWithText("Falta o seu ponto base").assertExists()
        rule.onNodeWithText("Definir ponto base").performScrollTo().performClick()
        rule.waitForIdle()

        assertEquals(Rotas.PONTO_BASE, rotaAtual())
        rule.onNodeWithText(TextosPontoBase.DICA).assertExists()
        verify { pontoBase.carregar() }
    }

    @Test
    fun `salvar o ponto base devolve a lista de vagas, que carrega de novo`() {
        abrirOApp()
        rule.onNodeWithText("Definir ponto base").performScrollTo().performClick()
        rule.waitForIdle()

        estadoDoPontoBase.value = EstadoPontoBase(salvo = true)
        rule.waitForIdle()

        assertEquals(Rotas.FEED, rotaAtual())
        verify(exactly = 2) { feed.carregar() }
    }
}
