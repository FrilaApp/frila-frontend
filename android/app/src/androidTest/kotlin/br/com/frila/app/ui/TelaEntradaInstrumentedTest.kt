package br.com.frila.app.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.TelaEntrada
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Teste de UI instrumentado Compose para a Tela de Entrada (Cartão 60).
 * Executa em dispositivo Android ou emulador através do AndroidJUnitRunner.
 */
@RunWith(AndroidJUnit4::class)
class TelaEntradaInstrumentedTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private fun criarViewModel(): EntradaViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste-instrumentado",
            engine = MockEngine {
                respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )
        return EntradaViewModel(
            servicoAutenticacao = ServicoAutenticacao(cliente),
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    @Test
    fun renderizaElementosEssenciaisDeEntrada() {
        val viewModel = criarViewModel()

        composeTestRule.setContent {
            FrilaTheme {
                TelaEntrada(
                    viewModel = viewModel,
                    aoReceberCodigo = {},
                )
            }
        }

        composeTestRule.onNodeWithText("Bem-vindo ao Frila")
            .assertIsDisplayed()

        composeTestRule.onNodeWithText("Entre com seu e-mail para receber o código de acesso.")
            .assertIsDisplayed()

        composeTestRule.onNodeWithText("E-mail")
            .assertIsDisplayed()

        composeTestRule.onNodeWithText("Receber código")
            .assertIsDisplayed()

        composeTestRule.onNodeWithText("Entrar em modo demonstração")
            .assertIsDisplayed()
    }

    @Test
    fun aoClicarModoDemonstracaoPreencheEmailEIniciaFluxo() {
        val viewModel = criarViewModel()
        var codigoRecebido = false

        composeTestRule.setContent {
            FrilaTheme {
                TelaEntrada(
                    viewModel = viewModel,
                    aoReceberCodigo = { codigoRecebido = true },
                )
            }
        }

        composeTestRule.onNodeWithText("Entrar em modo demonstração")
            .performClick()

        composeTestRule.waitForIdle()

        assertEquals("demo@frila.com.br", viewModel.estado.value.email)
        assertTrue(codigoRecebido)
    }

    @Test
    fun aoDigitarEmailValidoHabilitaSolicitacao() {
        val viewModel = criarViewModel()

        composeTestRule.setContent {
            FrilaTheme {
                TelaEntrada(
                    viewModel = viewModel,
                    aoReceberCodigo = {},
                )
            }
        }

        composeTestRule.onNodeWithText("E-mail")
            .performTextInput("profissional@teste.com")

        composeTestRule.waitForIdle()

        assertEquals("profissional@teste.com", viewModel.estado.value.email)
    }

    @Test
    fun aoDigitarEmailValidoEClicarReceberCodigoInvocaCallback() {
        val viewModel = criarViewModel()
        var codigoRecebido = false

        composeTestRule.setContent {
            FrilaTheme {
                TelaEntrada(
                    viewModel = viewModel,
                    aoReceberCodigo = { codigoRecebido = true },
                )
            }
        }

        composeTestRule.onNodeWithText("E-mail")
            .performTextInput("profissional@teste.com")

        composeTestRule.onNodeWithText("Receber código")
            .performClick()

        composeTestRule.waitUntil(timeoutMillis = 5_000) { codigoRecebido }
        composeTestRule.waitForIdle()

        assertTrue(codigoRecebido)
    }
}
