package br.com.frila.core.designsystem.componentes

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsNotSelected
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.capturas.capturar
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class FrilaBarraDeAbasTest {

    @get:Rule
    val compose = createComposeRule()

    private val abas = listOf(
        AbaFrila("Vagas", IconeMaleta),
        AbaFrila("Meus turnos", Icons.Default.DateRange, pendencias = 2),
        AbaFrila("Conta", Icons.Default.AccountCircle),
    )

    @Test
    fun `a aba ativa e a selecionada, o toque troca de aba e o alvo tem 48`() {
        var selecionada by mutableIntStateOf(0)
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                FrilaBarraDeAbas(abas = abas, selecionada = selecionada, aoSelecionar = { selecionada = it })
            }
        }

        compose.onNodeWithText("Vagas").assertIsSelected()
        compose.onNodeWithText("Conta")
            .assertIsNotSelected()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()

        assertEquals(2, selecionada)
        compose.onNodeWithText("Conta").assertIsSelected()
        compose.capturar("rn-barra-de-abas-claro")
    }

    @Test
    fun `a pendencia da aba e falada no plural e no singular`() {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                FrilaBarraDeAbas(
                    abas = abas + AbaFrila("Candidaturas", Icons.Default.DateRange, pendencias = 1),
                    selecionada = 1,
                    aoSelecionar = {},
                )
            }
        }

        compose.onNodeWithContentDescription("2 itens precisam de você", useUnmergedTree = true).assertExists()
        compose.onNodeWithContentDescription("1 item precisa de você", useUnmergedTree = true).assertExists()
    }
}
