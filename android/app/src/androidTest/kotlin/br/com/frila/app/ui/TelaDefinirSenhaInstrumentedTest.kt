package br.com.frila.app.ui

import android.graphics.Bitmap
import androidx.compose.ui.focus.FocusManager
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.captureToImage
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
        lateinit var focusManager: FocusManager
        composeTestRule.setContent {
            focusManager = LocalFocusManager.current
            FrilaTheme {
                TelaDefinirSenha(viewModel = viewModel, aoConcluir = {})
            }
        }

        val capturarSemCaret: (String) -> Bitmap = { rotulo ->
            composeTestRule.runOnIdle { focusManager.clearFocus(force = true) }
            composeTestRule.waitForIdle()
            composeTestRule.onNodeWithText(rotulo).captureToImage().asAndroidBitmap()
        }

        composeTestRule.onNodeWithText("Nova senha").assertIsDisplayed()
        composeTestRule.onNodeWithText("Confirmar senha").assertIsDisplayed()

        // 1) Nova senha: antes (<1s) != referência mascarada; depois (>1s) == referência mascarada; controle negativo ==
        composeTestRule.onNodeWithText("Nova senha").performTextInput("a")
        composeTestRule.onNodeWithText("Nova senha").performTextInput("b")
        composeTestRule.onNodeWithText("Nova senha").performTextInput("W")
        val antesCampo1 = capturarSemCaret("Nova senha")
        Thread.sleep(1_150)
        composeTestRule.mainClock.advanceTimeBy(1_200)
        val depoisCampo1 = capturarSemCaret("Nova senha")

        // Referência totalmente mascarada via exclusão (abW1 -> abW) sem caret
        composeTestRule.onNodeWithText("Nova senha").performTextInput("1")
        composeTestRule.onNodeWithText("Nova senha").performTextReplacement("abW")
        val mascaradoCampo1 = capturarSemCaret("Nova senha")
        Thread.sleep(1_150)
        composeTestRule.mainClock.advanceTimeBy(1_200)
        val controleNegativoCampo1 = capturarSemCaret("Nova senha")

        org.junit.Assert.assertFalse(
            "Antes de 1 s, Nova senha deve diferir da referência totalmente mascarada",
            antesCampo1.sameAs(mascaradoCampo1),
        )
        org.junit.Assert.assertTrue(
            "Após >1 s, Nova senha deve coincidir pixel a pixel com a referência totalmente mascarada",
            depoisCampo1.sameAs(mascaradoCampo1),
        )
        org.junit.Assert.assertTrue(
            "Controle negativo: referência mascarada não pode mudar com o tempo (zero falso positivo de cursor)",
            mascaradoCampo1.sameAs(controleNegativoCampo1),
        )
        assertEquals("abW", viewModel.estado.value.senha)

        // Edição no meio / exclusão / colagem simulada (>=2 chars)
        composeTestRule.onNodeWithText("Nova senha").performTextReplacement("abXW")
        composeTestRule.waitForIdle()
        composeTestRule.onNodeWithText("Nova senha").performTextReplacement("abX")
        composeTestRule.waitForIdle()
        composeTestRule.onNodeWithText("Nova senha").performTextReplacement("abXcolado12")
        composeTestRule.waitForIdle()
        assertEquals("abXcolado12", viewModel.estado.value.senha)

        // 2) Confirmar senha: antes (<1s) != referência mascarada; depois (>1s) == referência mascarada
        composeTestRule.onNodeWithText("Confirmar senha").performTextInput("x")
        composeTestRule.onNodeWithText("Confirmar senha").performTextInput("K")
        val antesCampo2 = capturarSemCaret("Confirmar senha")
        Thread.sleep(1_150)
        composeTestRule.mainClock.advanceTimeBy(1_200)
        val depoisCampo2 = capturarSemCaret("Confirmar senha")

        composeTestRule.onNodeWithText("Confirmar senha").performTextInput("1")
        composeTestRule.onNodeWithText("Confirmar senha").performTextReplacement("xK")
        val mascaradoCampo2 = capturarSemCaret("Confirmar senha")

        org.junit.Assert.assertFalse(
            "Antes de 1 s, Confirmar senha deve diferir da referência totalmente mascarada",
            antesCampo2.sameAs(mascaradoCampo2),
        )
        org.junit.Assert.assertTrue(
            "Após >1 s, Confirmar senha deve coincidir pixel a pixel com a referência totalmente mascarada",
            depoisCampo2.sameAs(mascaradoCampo2),
        )
        assertEquals("xK", viewModel.estado.value.confirmacao)
    }
}
