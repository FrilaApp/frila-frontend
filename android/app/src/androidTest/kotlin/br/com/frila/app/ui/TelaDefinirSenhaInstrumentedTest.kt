package br.com.frila.app.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTextReplacement
import androidx.test.ext.junit.runners.AndroidJUnit4
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import br.com.frila.feature.entrada.senha.DefinirSenhaViewModel
import br.com.frila.feature.entrada.senha.TelaDefinirSenha
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Prova instrumentada em AVD Android real para [TelaDefinirSenha]:
 * digitação rápida, edição no meio, exclusão, colagem e temporizador de 1 s nos dois campos.
 */
@RunWith(AndroidJUnit4::class)
class TelaDefinirSenhaInstrumentedTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private fun criarViewModel(): DefinirSenhaViewModel {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply {
            salvarSessao(Sessao("tok-avd", "ref-avd", "bearer", 3600))
        }
        val servico = ServicoAutenticacao(
            ClienteSupabase(
                baseUrl = "https://frila.supabase.co",
                apiKey = "chave-teste-avd",
                armazenamentoDeSessao = armazenamento,
                engine = MockEngine {
                    respond("""{"id":"uid-avd"}""", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
                },
            ),
        )
        return DefinirSenhaViewModel(
            servicoAutenticacao = servico,
            armazenamentoDeSessao = armazenamento,
            escopo = CoroutineScope(SupervisorJob() + Dispatchers.Default),
        )
    }

    @Test
    fun provaInterativaNosDoisCamposEmEmuladorReal() {
        val viewModel = criarViewModel()
        composeTestRule.setContent {
            FrilaTheme {
                TelaDefinirSenha(viewModel = viewModel, aoConcluir = {})
            }
        }

        composeTestRule.onNodeWithText("Nova senha").assertIsDisplayed()
        composeTestRule.onNodeWithText("Confirmar senha").assertIsDisplayed()

        // Digitação rápida no primeiro campo + espera real de 1,15 s para mascaramento
        composeTestRule.onNodeWithText("Nova senha").performTextInput("a")
        composeTestRule.onNodeWithText("Nova senha").performTextInput("b")
        composeTestRule.onNodeWithText("Nova senha").performTextInput("c")
        composeTestRule.waitForIdle()
        Thread.sleep(1_150)
        composeTestRule.waitForIdle()
        assertEquals("abc", viewModel.estado.value.senha)

        // Edição no meio / exclusão / colagem simulada (>=2 chars)
        composeTestRule.onNodeWithText("Nova senha").performTextReplacement("abXc")
        composeTestRule.waitForIdle()
        composeTestRule.onNodeWithText("Nova senha").performTextReplacement("abX")
        composeTestRule.waitForIdle()
        composeTestRule.onNodeWithText("Nova senha").performTextReplacement("abXcolado12")
        composeTestRule.waitForIdle()
        assertEquals("abXcolado12", viewModel.estado.value.senha)

        // Segundo campo (Confirmar senha): digitação + espera real de 1,15 s
        composeTestRule.onNodeWithText("Confirmar senha").performTextInput("x")
        composeTestRule.onNodeWithText("Confirmar senha").performTextInput("y")
        composeTestRule.waitForIdle()
        Thread.sleep(1_150)
        composeTestRule.waitForIdle()
        assertEquals("xy", viewModel.estado.value.confirmacao)
    }
}
