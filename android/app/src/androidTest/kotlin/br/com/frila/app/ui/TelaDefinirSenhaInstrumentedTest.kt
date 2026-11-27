package br.com.frila.app.ui

import android.graphics.Bitmap
import androidx.compose.ui.graphics.asAndroidBitmap
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
        composeTestRule.setContent {
            FrilaTheme {
                TelaDefinirSenha(viewModel = viewModel, aoConcluir = {})
            }
        }

        composeTestRule.onNodeWithText("Nova senha").assertIsDisplayed()
        composeTestRule.onNodeWithText("Confirmar senha").assertIsDisplayed()
        val vazioCampo1 = composeTestRule.onNodeWithText("Nova senha").captureToImage().asAndroidBitmap()

        // Digitação rápida no primeiro campo: captura pixels antes (<1s) e depois (>1s) do mascaramento
        val t0 = System.currentTimeMillis()
        composeTestRule.onNodeWithText("Nova senha").performTextInput("a")
        composeTestRule.onNodeWithText("Nova senha").performTextInput("b")
        composeTestRule.onNodeWithText("Nova senha").performTextInput("W")
        val tAposInput = System.currentTimeMillis() - t0
        Thread.sleep(150)
        val antesCampo1 = composeTestRule.onNodeWithText("Nova senha").captureToImage().asAndroidBitmap()
        Thread.sleep(1_150)
        composeTestRule.mainClock.advanceTimeBy(1_200)
        composeTestRule.waitForIdle()
        val depoisCampo1 = composeTestRule.onNodeWithText("Nova senha").captureToImage().asAndroidBitmap()

        // Compara também com exclusão (abW1 -> abW) que garante mascaramento total imediato
        composeTestRule.onNodeWithText("Nova senha").performTextInput("1")
        composeTestRule.onNodeWithText("Nova senha").performTextReplacement("abW")
        composeTestRule.waitForIdle()
        val mascaradoCampo1 = composeTestRule.onNodeWithText("Nova senha").captureToImage().asAndroidBitmap()

        org.junit.Assert.assertFalse(
            "Os pixels renderizados em Nova senha devem mudar entre <1s (t=${tAposInput}ms, igualVazio=${antesCampo1.sameAs(vazioCampo1)}, igualMascarado=${antesCampo1.sameAs(mascaradoCampo1)}) e >1s (depoisIgualMascarado=${depoisCampo1.sameAs(mascaradoCampo1)})",
            antesCampo1.sameAs(depoisCampo1),
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

        // Segundo campo (Confirmar senha): captura pixels antes (<1s) e depois (>1s) do mascaramento
        composeTestRule.onNodeWithText("Confirmar senha").performTextInput("x")
        composeTestRule.onNodeWithText("Confirmar senha").performTextInput("K")
        Thread.sleep(150)
        val antesCampo2 = composeTestRule.onNodeWithText("Confirmar senha").captureToImage().asAndroidBitmap()
        Thread.sleep(1_150)
        composeTestRule.mainClock.advanceTimeBy(1_200)
        composeTestRule.waitForIdle()
        val depoisCampo2 = composeTestRule.onNodeWithText("Confirmar senha").captureToImage().asAndroidBitmap()
        org.junit.Assert.assertFalse(
            "Os pixels renderizados em Confirmar senha devem mudar entre <1s (caractere K visível) e >1s (bolinha)",
            antesCampo2.sameAs(depoisCampo2),
        )
        assertEquals("xK", viewModel.estado.value.confirmacao)
    }
}
