package br.com.frila.core.designsystem.componentes

import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertWidthIsAtLeast
import androidx.compose.ui.test.assertCountEquals
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

/**
 * RNF10 (cartão 9X49Nr0l): FrilaBottomSheet encapsula ModalBottomSheet cru com os tokens do
 * Design System e a semântica de acessibilidade que a implementação anterior em
 * TelaFeedVagas.kt não tinha.
 */
@OptIn(ExperimentalMaterial3Api::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class FrilaBottomSheetTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `renderiza titulo e conteudo`() {
        compose.setContent {
            FrilaTheme {
                FrilaBottomSheet(onDismissRequest = {}, titulo = "Filtros avançados") {
                    Text("Conteúdo do filtro")
                }
            }
        }

        compose.onNodeWithText("Filtros avançados").assertExists()
        compose.onNodeWithText("Conteúdo do filtro").assertExists()
    }

    @Test
    fun `titulo expoe trait de heading para o TalkBack`() {
        compose.setContent {
            FrilaTheme {
                FrilaBottomSheet(onDismissRequest = {}, titulo = "Filtros avançados") {
                    Text("Conteúdo")
                }
            }
        }

        compose.onNodeWithText("Filtros avançados")
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
    }

    @Test
    fun `botao fechar tem alvo minimo de 48dp, contentDescription Fechar, e dispara aoFechar`() {
        var fechou = false
        compose.setContent {
            FrilaTheme {
                FrilaBottomSheet(
                    onDismissRequest = {},
                    titulo = "Filtros avançados",
                    aoFechar = { fechou = true },
                ) {
                    Text("Conteúdo")
                }
            }
        }

        compose.onNodeWithContentDescription("Fechar")
            .assertHasClickAction()
            .assertWidthIsAtLeast(48.dp)
            .assertHeightIsAtLeast(48.dp)
            .performClick()

        assertTrue(fechou)
    }

    @Test
    fun `sem titulo e sem aoFechar nao mostra botao de fechar`() {
        compose.setContent {
            FrilaTheme {
                FrilaBottomSheet(onDismissRequest = {}, aoFechar = null) {
                    Text("Conteúdo sozinho")
                }
            }
        }

        compose.onNodeWithContentDescription("Fechar").assertDoesNotExist()
    }

    @Test
    fun `drag handle decorativo nao expoe nenhuma semantica propria ao TalkBack`() {
        // MEDIDO (Shisui, PR #605, bloqueante): a versão anterior deste teste só checava a
        // ausência do texto "Fechar" — verdadeiro mesmo SEM clearAndSetSemantics (mutantes S3:
        // clearAndSetSemantics removido, e S3b: contentDescription "Alça" no lugar sobreviviam,
        // porque nenhum dos dois produz um nó com contentDescription igual a "Fechar"). A árvore
        // de semântica inteira do handle (useUnmergedTree, para não herdar nada de fora) precisa
        // não ter ContentDescription nem Role nenhum — essa é a prova de "sem ruído no TalkBack".
        compose.setContent {
            FrilaTheme {
                FrilaDragHandle()
            }
        }

        compose.onAllNodes(SemanticsMatcher.keyIsDefined(SemanticsProperties.ContentDescription), useUnmergedTree = true)
            .assertCountEquals(0)
        compose.onAllNodes(SemanticsMatcher.keyIsDefined(SemanticsProperties.Role), useUnmergedTree = true)
            .assertCountEquals(0)
    }
}
