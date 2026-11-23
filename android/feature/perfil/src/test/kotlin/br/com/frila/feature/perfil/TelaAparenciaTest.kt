package br.com.frila.feature.perfil

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotSelected
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaAparenciaTest {
    @get:Rule val rule = createComposeRule()

    @Test fun `claro e escuro sao escolha unica com explicacao e retorno`() {
        var voltou = false
        rule.setContent {
            var escuro by remember { mutableStateOf(false) }
            FrilaTheme(temaEscuro = escuro) {
                TelaAparencia(escuro, aoEscolher = { escuro = it }, aoVoltar = { voltou = true })
            }
        }
        rule.onNodeWithText("Aparência").assertIsDisplayed()
        rule.onNodeWithText("Escolha como o Frila aparece. A escolha fica só neste aparelho e vale também depois de trocar de conta.").assertIsDisplayed()
        rule.onNodeWithText("Claro").assertIsSelected().assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
        rule.onNodeWithText("Escuro").assertIsNotSelected().performClick().assertIsSelected()
        rule.onNodeWithText("Claro").assertIsNotSelected().performClick().assertIsSelected()
        rule.onNodeWithText("Escuro").assertIsNotSelected()
        rule.onNodeWithContentDescription("Voltar").performClick()
        assertTrue(voltou)
    }
}
