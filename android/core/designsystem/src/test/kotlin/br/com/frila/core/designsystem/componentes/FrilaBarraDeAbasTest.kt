package br.com.frila.core.designsystem.componentes

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsNotSelected
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.text.TextLayoutResult
import br.com.frila.core.designsystem.capturas.capturar
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
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

    @Test
    @Config(sdk = [34], qualifiers = "w360dp-h800dp-xxhdpi", fontScale = 2f)
    fun `num celular estreito com a fonte do sistema em 200 por cento nenhum rotulo da aba e cortado`() {
        val rotulos = listOf("Vagas", "Meus turnos", "Candidaturas", "Conta")
        rotulos.indices.forEach { ativa -> rotulosCabem(rotulos, ativa) }
    }

    private fun rotulosCabem(rotulos: List<String>, ativa: Int) {
        var selecionada by mutableIntStateOf(ativa)
        if (ativa == 0) {
            compose.setContent {
                FrilaTheme {
                    FrilaBarraDeAbas(abas = rotulos.map { AbaFrila(it, Icons.Default.DateRange) }, selecionada = selecionada, aoSelecionar = { selecionada = it })
                }
            }
        } else {
            compose.onNodeWithText(rotulos[ativa]).performClick()
        }
        rotulos.forEach { rotulo ->
            val resultados = mutableListOf<TextLayoutResult>()
            compose.onNodeWithText(rotulo, useUnmergedTree = true).performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(resultados) }
            val desenho = resultados.single()
            // Cortado = precisou de mais de uma linha (a barra só dá uma) ou a linha passa da caixa do rótulo.
            val larguraDaLinha = desenho.getLineRight(0) - desenho.getLineLeft(0)
            assertFalse(
                "\"$rotulo\" não coube numa linha com a aba ${rotulos[ativa]} ativa",
                desenho.multiParagraph.didExceedMaxLines || desenho.didOverflowHeight,
            )
            assertTrue(
                "\"$rotulo\" passa da caixa com a aba ${rotulos[ativa]} ativa (linha $larguraDaLinha, caixa ${desenho.size.width})",
                larguraDaLinha <= desenho.size.width + 0.5f,
            )
        }
    }
}
