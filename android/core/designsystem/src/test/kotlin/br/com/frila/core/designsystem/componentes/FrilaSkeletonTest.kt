package br.com.frila.core.designsystem.componentes

import android.provider.Settings
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertHeightIsEqualTo
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertWidthIsEqualTo
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
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

    @After
    fun restaurarEscalaDeAnimacao() {
        // Restaura a escala de animação padrão do sistema após cada teste
        val resolver = RuntimeEnvironment.getApplication().contentResolver
        Settings.Global.putFloat(resolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f)
    }

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

    @Test
    fun `reduzir movimento ativado renderiza esqueleto estatico sem quebrar`() {
        val resolver = RuntimeEnvironment.getApplication().contentResolver
        Settings.Global.putFloat(resolver, Settings.Global.ANIMATOR_DURATION_SCALE, 0f)

        assertFalse(animacoesAtivadasNoSistema(resolver))

        rule.setContent {
            FrilaTheme {
                FrilaSkeleton(modifier = Modifier.testTag("osso-estatico").width(120.dp).height(24.dp))
            }
        }
        rule.waitForIdle()

        rule.onNodeWithTag("osso-estatico")
            .assertIsDisplayed()
            .assertWidthIsEqualTo(120.dp)
            .assertHeightIsEqualTo(24.dp)
        assertEquals(0, rule.onAllNodesWithContentDescription("Carregando conteúdo").fetchSemanticsNodes().size)
    }

    @Test
    fun `reduzir movimento desativado renderiza esqueleto animado padrao`() {
        val resolver = RuntimeEnvironment.getApplication().contentResolver
        Settings.Global.putFloat(resolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f)

        assertTrue(animacoesAtivadasNoSistema(resolver))

        rule.setContent {
            FrilaTheme {
                FrilaSkeleton(modifier = Modifier.testTag("osso-animado").width(80.dp).height(16.dp))
            }
        }
        rule.waitForIdle()

        rule.onNodeWithTag("osso-animado")
            .assertIsDisplayed()
            .assertWidthIsEqualTo(80.dp)
            .assertHeightIsEqualTo(16.dp)
    }

    @Test
    fun `customizacao de formato e dimensoes sao respeitadas no esqueleto`() {
        rule.setContent {
            FrilaTheme {
                FrilaSkeleton(
                    modifier = Modifier.testTag("osso-circular").width(48.dp).height(48.dp),
                    shape = CircleShape,
                )
            }
        }
        rule.waitForIdle()

        rule.onNodeWithTag("osso-circular")
            .assertIsDisplayed()
            .assertWidthIsEqualTo(48.dp)
            .assertHeightIsEqualTo(48.dp)
    }

    @Test
    fun `cartao skeleton renderiza com altura customizada`() {
        rule.setContent {
            FrilaTheme {
                FrilaCartaoSkeleton(
                    modifier = Modifier.testTag("cartao-customizado"),
                    altura = 160.dp,
                )
            }
        }
        rule.waitForIdle()

        rule.onNodeWithTag("cartao-customizado")
            .assertIsDisplayed()
            .assertHeightIsEqualTo(160.dp)
    }
}

