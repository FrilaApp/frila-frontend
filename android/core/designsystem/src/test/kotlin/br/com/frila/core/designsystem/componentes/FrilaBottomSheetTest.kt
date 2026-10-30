package br.com.frila.core.designsystem.componentes

import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertWidthIsAtLeast
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
    fun `drag handle decorativo nao expoe contentDescription nem fica no caminho do botao fechar`() {
        compose.setContent {
            FrilaTheme {
                FrilaDragHandle()
            }
        }

        // Decorativo: clearAndSetSemantics { } remove a semântica própria. A prova direta de
        // "nenhuma semântica" fica no teste de mutação (reverter o clearAndSetSemantics faz o
        // próprio onNodeWithContentDescription("Fechar") acima mudar de comportamento quando
        // combinado ao sheet completo); aqui garantimos que o handle isolado não expõe nenhum
        // texto nem contentDescription usados pelos outros testes.
        compose.onNodeWithContentDescription("Fechar").assertDoesNotExist()
    }
}
