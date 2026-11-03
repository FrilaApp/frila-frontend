package br.com.frila.app.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.feature.entrada.cadastro.CadastroViewModel
import br.com.frila.feature.entrada.cadastro.MENSAGEM_MENOR_DE_IDADE
import br.com.frila.feature.entrada.cadastro.TelaCadastro
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Teste de UI instrumentado Compose para validação do bloqueio de menor de 18 anos (Cartão 60).
 * Executa em dispositivo Android ou emulador através do AndroidJUnitRunner.
 */
@RunWith(AndroidJUnit4::class)
class BloqueioMenorDeIdadeInstrumentedTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun aoDigitarNascimentoMenorDe18ExibeMensagemDeBloqueio() {
        val viewModel = CadastroViewModel()

        composeTestRule.setContent {
            FrilaTheme {
                TelaCadastro(
                    viewModel = viewModel,
                    aoConcluir = {},
                )
            }
        }

        composeTestRule.onNodeWithText("Complete seu cadastro")
            .assertIsDisplayed()

        // Digita data de nascimento de pessoa menor de 18 anos
        composeTestRule.onNodeWithText("Data de nascimento (dd/mm/aaaa)")
            .performScrollTo()
            .performTextInput("01/01/2015")

        composeTestRule.waitForIdle()

        // A mensagem de bloqueio legal/RN20 deve ser exibida imediatamente
        composeTestRule.onNodeWithText(MENSAGEM_MENOR_DE_IDADE)
            .performScrollTo()
            .assertIsDisplayed()

        assertFalse(viewModel.estado.value.nascimentoValido)
    }

    @Test
    fun aoDigitarNascimentoMaiorDe18PermiteAvancoSemBloqueio() {
        val viewModel = CadastroViewModel()

        composeTestRule.setContent {
            FrilaTheme {
                TelaCadastro(
                    viewModel = viewModel,
                    aoConcluir = {},
                )
            }
        }

        // Digita data de nascimento de pessoa maior de idade (ex.: 10/05/1990)
        composeTestRule.onNodeWithText("Data de nascimento (dd/mm/aaaa)")
            .performScrollTo()
            .performTextInput("10/05/1990")

        composeTestRule.waitForIdle()

        assertTrue(viewModel.estado.value.nascimentoValido)
    }
}
