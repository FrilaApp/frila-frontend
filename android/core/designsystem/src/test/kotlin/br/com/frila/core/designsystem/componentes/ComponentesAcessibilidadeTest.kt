package br.com.frila.core.designsystem.componentes

import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertHasNoClickAction
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertWidthIsAtLeast
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ComponentesAcessibilidadeTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `BotaoPrimario expoe acao e alvo minimo de 48dp`() {
        compose.setContent {
            FrilaTheme {
                BotaoPrimario(texto = "Continuar", aoClicar = {})
            }
        }

        compose.onNodeWithText("Continuar")
            .assertHasClickAction()
            .assertWidthIsAtLeast(48.dp)
            .assertHeightIsAtLeast(48.dp)
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Button))
    }

    @Test
    fun `BotaoSecundario expoe acao e alvo minimo de 48dp`() {
        compose.setContent {
            FrilaTheme {
                BotaoSecundario(texto = "Tentar novamente", aoClicar = {})
            }
        }

        compose.onNodeWithText("Tentar novamente")
            .assertHasClickAction()
            .assertWidthIsAtLeast(48.dp)
            .assertHeightIsAtLeast(48.dp)
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Button))
    }

    @Test
    fun `CartaoVaga clicavel expoe papel de botao e alvo minimo de 48dp`() {
        compose.setContent {
            FrilaTheme {
                CartaoVaga(
                    aoClicar = {},
                    rotuloDaAcao = "Abrir detalhes da vaga",
                ) {
                    Text("Garçom")
                }
            }
        }

        compose.onNodeWithText("Garçom")
            .assertHasClickAction()
            .assertWidthIsAtLeast(48.dp)
            .assertHeightIsAtLeast(48.dp)
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Button))
    }

    @Test
    fun `CartaoVaga informativo nao anuncia acao inexistente`() {
        compose.setContent {
            FrilaTheme {
                CartaoVaga {
                    Text("Resumo da vaga")
                }
            }
        }

        compose.onNodeWithText("Resumo da vaga").assertHasNoClickAction()
    }

    @OptIn(ExperimentalMaterial3Api::class)
    @Test
    fun `chip de filtro expoe selecao unica estado e alvo minimo de 48dp`() {
        compose.setContent {
            FrilaTheme {
                FilterChip(
                    selected = true,
                    onClick = {},
                    label = { Text("Até 5 km") },
                    modifier = Modifier.semanticaDeFiltro(selecionado = true),
                )
            }
        }

        compose.onNodeWithText("Até 5 km")
            .assertHasClickAction()
            .assertWidthIsAtLeast(48.dp)
            .assertHeightIsAtLeast(48.dp)
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.RadioButton))
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "selecionado"))
    }

    @OptIn(ExperimentalMaterial3Api::class)
    @Test
    fun `chip de filtro nao selecionado anuncia estado correto`() {
        compose.setContent {
            FrilaTheme {
                FilterChip(
                    selected = false,
                    onClick = {},
                    label = { Text("Até 10 km") },
                    modifier = Modifier.semanticaDeFiltro(selecionado = false),
                )
            }
        }

        compose.onNodeWithText("Até 10 km")
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.RadioButton))
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "não selecionado"))
    }
}
