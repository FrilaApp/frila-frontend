package br.com.frila.core.designsystem.componentes

import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Cartão v1cia6Y9 (item 256): `FrilaLinhaDeNavegacao` aceita o rótulo da ação (`onClickLabel`) e, sem ele, segue como estava. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class FrilaLinhaDeNavegacaoRotuloTest {

    @get:Rule
    val rule = createComposeRule()

    private fun rotulo(titulo: String) = rule.onNodeWithText(titulo).fetchSemanticsNode().config.getOrNull(SemanticsActions.OnClick)?.label

    @Test
    fun `com o rotulo da acao, o clique o anuncia`() {
        rule.setContent { FrilaTheme { FrilaLinhaDeNavegacao(titulo = "Linha", aoClicar = {}, rotuloDaAcao = "Abre a coisa") } }

        assertEquals("Abre a coisa", rotulo("Linha"))
    }

    @Test
    fun `sem o rotulo da acao, o clique segue sem rotulo`() {
        rule.setContent { FrilaTheme { FrilaLinhaDeNavegacao(titulo = "Linha", aoClicar = {}) } }

        assertNull(rotulo("Linha"))
    }

    @Test
    fun `o rotulo da acao nao tira o clique`() {
        var cliques = 0
        rule.setContent { FrilaTheme { FrilaLinhaDeNavegacao(titulo = "Linha", aoClicar = { cliques++ }, rotuloDaAcao = "Abre a coisa") } }

        rule.onNodeWithText("Linha").performClick()

        assertEquals(1, cliques)
    }
}
