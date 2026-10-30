package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * RNF10 (MEDIDO, Byakugan): cada osso do skeleton anunciava "Carregando conteúdo" via
 * `semantics { contentDescription = ... }` — numa lista de 4 cartões com 4 ossos cada, o
 * TalkBack anunciava o carregamento 16 vezes. `clearAndSetSemantics {}` torna o osso puramente
 * decorativo; quem anuncia uma vez é o container pai da lista (`SkeletonFeedVagas`/
 * `SkeletonMeusTurnos`, testados em `:feature:vagas`/`:feature:turnos`).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class FrilaSkeletonTest {

    @get:Rule
    val rule = createComposeRule()

    @Test
    fun `osso individual nao tem contentDescription redundante`() {
        rule.setContent {
            FrilaTheme {
                FrilaSkeleton(modifier = Modifier.testTag("osso-de-teste").width(100.dp).height(20.dp))
            }
        }
        rule.waitForIdle()

        assertEquals(0, rule.onAllNodesWithContentDescription("Carregando conteúdo").fetchSemanticsNodes().size)
        rule.onNodeWithTag("osso-de-teste").assertIsDisplayed()
    }

    @Test
    fun `renderiza sem quebrar no tema claro`() {
        rule.setContent {
            FrilaTheme(temaEscuro = false) {
                FrilaSkeleton(modifier = Modifier.testTag("osso-de-teste").width(100.dp).height(20.dp))
            }
        }
        rule.waitForIdle()

        rule.onNodeWithTag("osso-de-teste").assertIsDisplayed()
    }

    @Test
    fun `renderiza sem quebrar no tema escuro`() {
        rule.setContent {
            FrilaTheme(temaEscuro = true) {
                FrilaSkeleton(modifier = Modifier.testTag("osso-de-teste").width(100.dp).height(20.dp))
            }
        }
        rule.waitForIdle()

        rule.onNodeWithTag("osso-de-teste").assertIsDisplayed()
    }

    @Test
    fun `cartao skeleton nao expoe contentDescription redundante em nenhum dos tres ossos internos`() {
        rule.setContent {
            FrilaTheme {
                FrilaCartaoSkeleton()
            }
        }
        rule.waitForIdle()

        assertTrue(rule.onAllNodesWithContentDescription("Carregando conteúdo").fetchSemanticsNodes().isEmpty())
    }
}
