package br.com.frila.app

import android.app.Application
import android.content.ActivityNotFoundException
import android.content.ContextWrapper
import android.content.Intent
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.perfil.EstadoPerfil
import br.com.frila.feature.perfil.PerfilViewModel
import io.mockk.every
import io.mockk.mockk
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

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AppNavegacaoAjudaIntegracaoTest {

    @get:Rule
    val rule = createComposeRule()

    private lateinit var nav: NavHostController

    private fun montar(semEmail: Boolean = false) {
        val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
            every { estaAutenticado() } returns false
            every { isBiometriaAtivada() } returns false
        }
        val entrada = mockk<EntradaViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoEntrada())
        }
        val perfil = mockk<PerfilViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoPerfil())
        }

        rule.setContent {
            val origem = LocalContext.current
            val contexto = object : ContextWrapper(origem) {
                override fun startActivity(intent: Intent) {
                    if (semEmail && intent.action == Intent.ACTION_SENDTO) {
                        throw ActivityNotFoundException("Sonda: aparelho sem cliente de e-mail")
                    }
                    super.startActivity(intent)
                }
            }
            KoinApplication(application = {
                modules(
                    module {
                        viewModel { entrada }
                        viewModel { perfil }
                    },
                )
            }) {
                CompositionLocalProvider(LocalContext provides contexto) {
                    nav = rememberNavController()
                    AppNavegacao(
                        armazenamentoDeSessao = sessao,
                        monitorDeConectividade = MonitorDeConectividadeFalso(),
                        navController = nav,
                    )
                }
            }
        }
        rule.runOnIdle { nav.navigate(Rotas.PERFIL) }
        rule.onNodeWithTag("botao-ajuda-barra").performClick()
    }

    @Test
    fun perfilAbreAjudaLicencasEVolta() {
        montar()
        rule.onNodeWithText("Licenças de código aberto").performScrollTo().performClick()
        rule.runOnIdle { assertEquals(Rotas.LICENCAS, nav.currentDestination?.route) }
        rule.onNodeWithContentDescription("Voltar").performClick()
        rule.runOnIdle { assertEquals(Rotas.AJUDA, nav.currentDestination?.route) }
        rule.onNodeWithContentDescription("Voltar").performClick()
        rule.runOnIdle { assertEquals(Rotas.PERFIL, nav.currentDestination?.route) }
    }

    @Test
    fun suporteSemAplicativoDeEmailNaoDeveDerrubarAjuda() {
        montar(semEmail = true)
        rule.onNodeWithText("Fale com o suporte").performClick()
        rule.runOnIdle { assertEquals(Rotas.AJUDA, nav.currentDestination?.route) }
    }
}
