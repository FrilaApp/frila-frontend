package br.com.frila.feature.perfil

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class TelaLicencasTest {

    @get:Rule
    val rule = createComposeRule()

    @Test
    fun tituloPossuiSemanticaDeCabecalhoEAlvoMinimoNoBotaoVoltar() {
        var voltou = false

        rule.setContent {
            FrilaTheme {
                TelaLicencas(aoVoltar = { voltou = true })
            }
        }

        rule.onNodeWithText("Licenças de código aberto")
            .assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))

        val botaoVoltar = rule.onNodeWithContentDescription("Voltar")
        botaoVoltar.assertIsDisplayed()
        botaoVoltar.assertHeightIsAtLeast(48.dp)

        botaoVoltar.performClick()
        assertTrue(voltou)
    }

    @Test
    fun exibeItensDoCatalogoComAlvoMinimo() {
        rule.setContent {
            FrilaTheme {
                TelaLicencas(aoVoltar = {})
            }
        }

        rule.onNodeWithText("Kotlin Standard Library")
            .assertIsDisplayed()

        rule.onNodeWithText("Kotlinx Coroutines")
            .assertIsDisplayed()

        rule.onNodeWithText("AndroidX Jetpack Compose")
            .assertIsDisplayed()

        rule.onNodeWithText("Ktor Client")
            .assertIsDisplayed()
    }

    @Test
    fun aoClicarEmItemAbreDetalheDaLicencaERetorna() {
        rule.setContent {
            FrilaTheme {
                TelaLicencas(aoVoltar = {})
            }
        }

        // Clica no item de Kotlin Standard Library
        rule.onNodeWithText("Kotlin Standard Library")
            .performClick()

        // Detalhe exibido com metadados
        rule.onNodeWithText("Versão: 2.0.20")
            .assertIsDisplayed()

        rule.onNodeWithText("Licença: Apache-2.0")
            .assertIsDisplayed()

        rule.onNodeWithText("Avisos do pacote")
            .assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))

        rule.onNodeWithText("Texto da licença")
            .assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))

        // Clica em voltar no detalhe e retorna para a lista
        rule.onNodeWithContentDescription("Voltar")
            .performClick()

        // Volta para a lista principal
        rule.onNodeWithText("Licenças de código aberto")
            .assertIsDisplayed()
    }

    @Test
    fun aoClicarEmCoroutinesExibeVersaoEspecifica181() {
        rule.setContent {
            FrilaTheme {
                TelaLicencas(aoVoltar = {})
            }
        }

        rule.onNodeWithText("Kotlinx Coroutines")
            .performClick()

        rule.onNodeWithText("Versão: 1.8.1")
            .assertIsDisplayed()

        rule.onNodeWithText("Licença: Apache-2.0")
            .assertIsDisplayed()
    }
}
