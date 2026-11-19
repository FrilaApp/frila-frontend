package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.navigation.compose.rememberNavController
import br.com.frila.app.falhas.GerenciadorConsentimentoCrashlytics
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.cadastro.CadastroViewModel
import br.com.frila.feature.entrada.codigo.CodigoViewModel
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", application = Application::class)
class AppNavegacaoConsentimentoFalhasTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste()

    @get:Rule(order = 1)
    val compose = createComposeRule()

    private class ConsentimentoFalso(
        var precisa: Boolean = true,
        var ativa: Boolean = false,
    ) : GerenciadorConsentimentoCrashlytics {
        var ultimoValorGravado: Boolean? = null
        override fun coletaAtiva(): Boolean = ativa
        override fun precisaPerguntar(): Boolean = precisa
        override fun definirConsentimento(concedido: Boolean) {
            ultimoValorGravado = concedido
            ativa = concedido
            precisa = false
        }
    }

    private fun moduloDeTeste(armazenamento: ArmazenamentoDeSessao) = module {
        val auth = mockk<ServicoAutenticacao>(relaxed = true)
        single { auth }
        single { armazenamento }
        viewModel { EntradaViewModel(get()) }
        viewModel { (email: String) ->
            CodigoViewModel(
                email = email,
                servicoAutenticacao = get(),
                armazenamentoDeSessao = get(),
            )
        }
        viewModel { CadastroViewModel() }
    }

    @Test
    fun `rota de consentimento permite aceitar e registra consentimento`() {
        val consentimento = ConsentimentoFalso(precisa = true, ativa = false)
        val armazenamento = mockk<ArmazenamentoDeSessao>(relaxed = true)
        every { armazenamento.estaAutenticado() } returns false

        compose.setContent {
            val navController = rememberNavController()
            KoinApplication(application = { modules(moduloDeTeste(armazenamento)) }) {
                AppNavegacao(
                    armazenamentoDeSessao = armazenamento,
                    monitorDeConectividade = MonitorDeConectividadeFalso(),
                    navController = navController,
                    gerenciadorConsentimento = consentimento,
                )
                androidx.compose.runtime.LaunchedEffect(Unit) {
                    navController.navigate(Rotas.CONSENTIMENTO_FALHAS)
                }
            }
        }

        compose.waitForIdle()
        compose.onNodeWithTag("botao-permitir-envio").assertIsDisplayed().performClick()
        compose.waitForIdle()

        assertEquals(true, consentimento.ultimoValorGravado)
        assertTrue(consentimento.coletaAtiva())
        assertFalse(consentimento.precisaPerguntar())
    }

    @Test
    fun `rota de consentimento permite recusar com Agora nao e desliga coleta sem travar nada`() {
        val consentimento = ConsentimentoFalso(precisa = true, ativa = false)
        val armazenamento = mockk<ArmazenamentoDeSessao>(relaxed = true)
        every { armazenamento.estaAutenticado() } returns false

        compose.setContent {
            val navController = rememberNavController()
            KoinApplication(application = { modules(moduloDeTeste(armazenamento)) }) {
                AppNavegacao(
                    armazenamentoDeSessao = armazenamento,
                    monitorDeConectividade = MonitorDeConectividadeFalso(),
                    navController = navController,
                    gerenciadorConsentimento = consentimento,
                )
                androidx.compose.runtime.LaunchedEffect(Unit) {
                    navController.navigate(Rotas.CONSENTIMENTO_FALHAS)
                }
            }
        }

        compose.waitForIdle()
        compose.onNodeWithTag("botao-recusar-envio").assertIsDisplayed().performClick()
        compose.waitForIdle()

        assertEquals(false, consentimento.ultimoValorGravado)
        assertFalse(consentimento.coletaAtiva())
        assertFalse(consentimento.precisaPerguntar())
    }
}
