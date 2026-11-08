package br.com.frila.feature.entrada.cadastro

import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertWidthIsAtLeast
import androidx.compose.ui.test.hasClickAction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class TelaCadastroTest {

    @get:Rule
    val rule = createComposeRule()

    @Test
    fun tituloPossuiSemanticaDeCabecalho() {
        val viewModel = CadastroViewModel()
        rule.setContent {
            FrilaTheme {
                TelaCadastro(
                    viewModel = viewModel,
                    aoConcluir = {},
                )
            }
        }

        rule.onNodeWithText("Complete seu cadastro")
            .assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
    }

    @Test
    fun checkboxTermosPossuiAlvoMinimoEStateDescription() {
        val viewModel = CadastroViewModel()
        rule.setContent {
            FrilaTheme {
                TelaCadastro(
                    viewModel = viewModel,
                    aoConcluir = {},
                )
            }
        }

        val checkboxNode = rule.onNodeWithText("Li e aceito os termos de uso e a política de privacidade.")
        checkboxNode.performScrollTo().assertIsDisplayed()

        // WCAG / Android touch target >= 48dp
        checkboxNode.assertWidthIsAtLeast(48.dp)
        checkboxNode.assertHeightIsAtLeast(48.dp)

        // Estado inicial não selecionado
        checkboxNode.assert(
            SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "não selecionado")
        )

        // Ao clicar, transiciona para selecionado
        checkboxNode.performClick()
        checkboxNode.assert(
            SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "selecionado")
        )
    }

    @Test
    fun erroNomeExibeTextoDedicadoComLiveRegionAssertive() {
        val viewModel = CadastroViewModel()
        rule.setContent {
            FrilaTheme {
                TelaCadastro(
                    viewModel = viewModel,
                    aoConcluir = {},
                )
            }
        }

        // Preenche nascimento para avançar até validação de nome ao submeter
        rule.onNodeWithText("Data de nascimento (dd/mm/aaaa)")
            .performScrollTo()
            .performTextInput("10/05/1990")

        // Submete sem preencher o nome
        viewModel.concluirCadastro()

        // Mensagem de erro dedicada do nome é exibida com LiveRegionMode.Assertive
        rule.onNodeWithText("Informe seu nome.")
            .performScrollTo()
            .assertIsDisplayed()
            .assert(
                SemanticsMatcher.expectValue(
                    SemanticsProperties.LiveRegion,
                    LiveRegionMode.Assertive,
                )
            )
    }

    @Test
    fun erroCpfExibeTextoDedicadoComLiveRegionAssertive() {
        val viewModel = CadastroViewModel()
        rule.setContent {
            FrilaTheme {
                TelaCadastro(
                    viewModel = viewModel,
                    aoConcluir = {},
                )
            }
        }

        // Digita CPF inválido com 11 dígitos repetidos
        rule.onNodeWithText("CPF")
            .performScrollTo()
            .performTextInput("11111111111")

        rule.onNodeWithText(MENSAGEM_CPF_INVALIDO)
            .performScrollTo()
            .assertIsDisplayed()
            .assert(
                SemanticsMatcher.expectValue(
                    SemanticsProperties.LiveRegion,
                    LiveRegionMode.Assertive,
                )
            )
    }

    @Test
    fun erroNascimentoExibeTextoDedicadoComLiveRegionAssertive() {
        val viewModel = CadastroViewModel()
        rule.setContent {
            FrilaTheme {
                TelaCadastro(
                    viewModel = viewModel,
                    aoConcluir = {},
                )
            }
        }

        // Digita nascimento de menor de idade
        rule.onNodeWithText("Data de nascimento (dd/mm/aaaa)")
            .performScrollTo()
            .performTextInput("01/01/2015")

        rule.onNodeWithText(MENSAGEM_MENOR_DE_IDADE)
            .performScrollTo()
            .assertIsDisplayed()
            .assert(
                SemanticsMatcher.expectValue(
                    SemanticsProperties.LiveRegion,
                    LiveRegionMode.Assertive,
                )
            )
    }
}
