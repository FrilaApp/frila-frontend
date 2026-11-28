package br.com.frila.core.designsystem.componentes

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.state.ToggleableState
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão m3W8Ahuj (item 263): a `LinhaDeInterruptor` compartilhada. Anuncia-se como interruptor (`Role.Switch`) com o estado ligado ou
 * desligado, a linha inteira é o alvo (48 dp), e desabilitada não responde ao toque. Escolha única continua sendo a `FrilaLinhaDeOpcao`.
 *
 * JUnit: nenhum método devolve valor (um `@Test` que devolve valor é ignorado).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class LinhaDeInterruptorTest {

    @get:Rule
    val rule = createComposeRule()

    private var ligado by mutableStateOf(false)
    private val mudancas = mutableListOf<Boolean>()

    private fun montar(editavel: Boolean = true) {
        rule.setContent {
            FrilaTheme {
                LinhaDeInterruptor(
                    rotulo = "Confirmo",
                    ligado = ligado,
                    editavel = editavel,
                    aoMudar = { mudancas += it; ligado = it },
                    modifier = Modifier.testTag("linha"),
                )
            }
        }
    }

    private fun estado(): ToggleableState? = rule.onNodeWithTag("linha").fetchSemanticsNode().config.getOrNull(SemanticsProperties.ToggleableState)

    @Test
    fun `anuncia-se como interruptor e nao como botao de opcao`() {
        montar()

        rule.onNodeWithTag("linha").assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Switch))
        rule.onNodeWithTag("linha").assert(SemanticsMatcher.keyNotDefined(SemanticsProperties.Selected))
        rule.onNodeWithText("Confirmo").assertExists()
    }

    @Test
    fun `desligado, liga ao tocar, e ligado, desliga ao tocar, e o estado acompanha`() {
        montar()
        assertEquals(ToggleableState.Off, estado())

        rule.onNodeWithTag("linha").performClick()
        assertEquals(ToggleableState.On, estado())

        rule.onNodeWithTag("linha").performClick()
        assertEquals(ToggleableState.Off, estado())
        assertEquals(listOf(true, false), mudancas)
    }

    @Test
    fun `comeca ligado quando o estado de fora e ligado`() {
        ligado = true
        montar()

        assertEquals(ToggleableState.On, estado())
    }

    @Test
    fun `a linha inteira e o alvo, com 48 dp no minimo`() {
        montar()

        rule.onNodeWithTag("linha").assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
    }

    @Test
    fun `nao editavel, fica desabilitada e o toque nao muda nada`() {
        montar(editavel = false)

        rule.onNodeWithTag("linha").assertIsNotEnabled()
        rule.onNodeWithTag("linha").performClick()

        assertEquals(ToggleableState.Off, estado())
        assertEquals(emptyList<Boolean>(), mudancas)
    }

    @Test
    fun `editavel, fica habilitada`() {
        montar(editavel = true)

        rule.onNodeWithTag("linha").assertIsEnabled()
    }
}
