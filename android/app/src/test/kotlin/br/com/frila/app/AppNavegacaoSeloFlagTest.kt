package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.assertCountEquals
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.dominio.modelo.StatusVerificacaoIdentidade
import br.com.frila.core.dominio.modelo.VerificacaoIdentidade
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.rede.StatusConectividade
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.perfil.EstadoPerfil
import br.com.frila.feature.perfil.EstadoVerificacaoIdentidade
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.StatusCargaVerificacao
import br.com.frila.feature.perfil.StatusPerfil
import br.com.frila.feature.perfil.VerificacaoIdentidadeViewModel
import br.com.frila.feature.vagas.feed.EstadoFeed
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.vagas.feed.StatusFeed
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Trava do selo de confiança (RN14): desligada por padrão, a rota `selo_confianca` não existe e o
 * perfil não pede o ViewModel do selo. O módulo Koin de teste só registra o ViewModel do selo
 * quando a trava está ligada; se o app o pedisse com a trava desligada, o Koin lançaria
 * `NoBeanDefFoundException`.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AppNavegacaoSeloFlagTest {

    @get:Rule
    val rule = createComposeRule()

    private val selo = mockk<VerificacaoIdentidadeViewModel>(relaxed = true).also {
        every { it.estado } returns MutableStateFlow(
            EstadoVerificacaoIdentidade(
                carga = StatusCargaVerificacao.PRONTO,
                verificacao = VerificacaoIdentidade(StatusVerificacaoIdentidade.NAO_EXIGIDA),
            ),
        )
    }

    /** `recursoSeloHabilitado = null` não passa o argumento: exercita o valor padrão de produção. */
    private fun montar(recursoSeloHabilitado: Boolean?, registrarSelo: Boolean): NavHostController {
        val armazenamento = mockk<ArmazenamentoDeSessao>(relaxed = true)
        every { armazenamento.estaAutenticado() } returns true
        every { armazenamento.isBiometriaAtivada() } returns false
        val feed = mockk<FeedVagasViewModel>(relaxed = true)
        every { feed.estado } returns MutableStateFlow(EstadoFeed(status = StatusFeed.SUCESSO))
        val perfil = mockk<PerfilViewModel>(relaxed = true)
        every { perfil.estado } returns MutableStateFlow(EstadoPerfil(status = StatusPerfil.SUCESSO))

        lateinit var navController: NavHostController
        rule.setContent {
            navController = rememberNavController()
            KoinApplication(application = {
                modules(
                    module {
                        single { mockk<ServicoAutenticacao>(relaxed = true) }
                        single { armazenamento }
                        viewModel { EntradaViewModel(get()) }
                        viewModel { feed }
                        viewModel { perfil }
                        if (registrarSelo) viewModel { selo }
                    },
                )
            }) {
                if (recursoSeloHabilitado == null) {
                    AppNavegacao(
                        armazenamentoDeSessao = armazenamento,
                        monitorDeConectividade = MonitorDeConectividadeFalso(StatusConectividade.CONECTADO),
                        navController = navController,
                    )
                } else {
                    AppNavegacao(
                        armazenamentoDeSessao = armazenamento,
                        monitorDeConectividade = MonitorDeConectividadeFalso(StatusConectividade.CONECTADO),
                        navController = navController,
                        recursoSeloHabilitado = recursoSeloHabilitado,
                    )
                }
            }
        }
        rule.waitForIdle()
        return navController
    }

    @Test
    fun `sem passar o argumento a trava do selo fica desligada`() {
        // Elegível no estado e VM registrado: só a trava padrão pode esconder o convite e a rota.
        val navController = montar(recursoSeloHabilitado = null, registrarSelo = true)

        rule.runOnUiThread { navController.navigate(Rotas.PERFIL) }
        rule.waitForIdle()

        rule.onAllNodesWithTag("selo-obter").assertCountEquals(0)
        verify(exactly = 0) { selo.carregar() }
        assertThrows(IllegalArgumentException::class.java) {
            rule.runOnUiThread { navController.navigate(Rotas.SELO_CONFIANCA) }
        }
    }

    @Test
    fun `trava desligada nao registra a rota do selo e o perfil nao pede o viewmodel`() {
        val navController = montar(recursoSeloHabilitado = false, registrarSelo = false)

        rule.runOnUiThread { navController.navigate(Rotas.PERFIL) }
        rule.waitForIdle()

        assertEquals(Rotas.PERFIL, navController.currentDestination?.route)
        rule.onAllNodesWithTag("selo-obter").assertCountEquals(0)
        assertThrows(IllegalArgumentException::class.java) {
            rule.runOnUiThread { navController.navigate(Rotas.SELO_CONFIANCA) }
        }
    }

    @Test
    fun `trava ligada mostra o convite no perfil e abre a rota do selo`() {
        val navController = montar(recursoSeloHabilitado = true, registrarSelo = true)

        rule.runOnUiThread { navController.navigate(Rotas.PERFIL) }
        rule.waitForIdle()
        verify(atLeast = 1) { selo.carregar() }

        rule.onNodeWithTag("selo-obter").performScrollTo().assertIsDisplayed().performClick()
        rule.waitForIdle()

        assertEquals(Rotas.SELO_CONFIANCA, navController.currentDestination?.route)
        rule.onNodeWithText("Consentimento para o selo").assertIsDisplayed()
    }
}
