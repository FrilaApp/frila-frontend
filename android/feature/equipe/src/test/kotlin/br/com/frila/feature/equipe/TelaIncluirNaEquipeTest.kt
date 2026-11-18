package br.com.frila.feature.equipe

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaIncluirNaEquipeTest {

    @get:Rule
    val rule = createComposeRule()

    private fun montar(estado: EstadoIncluirNaEquipe, aoIncluir: () -> Unit = {}) {
        rule.setContent { FrilaTheme { ConteudoIncluirNaEquipe(estado = estado, nome = "Ana Souza", aoIncluir = aoIncluir) } }
    }

    @Test
    fun `fora da equipe mostra o botao com o nome no rotulo e um toque inclui`() {
        var toques = 0
        montar(EstadoIncluirNaEquipe(SituacaoNaEquipe.FORA_DA_EQUIPE)) { toques++ }

        rule.onNodeWithContentDescription("Incluir na equipe: Ana Souza")
            .assertIsDisplayed()
            .assertIsEnabled()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()

        assertEquals(1, toques)
    }

    @Test
    fun `na equipe mostra o texto e nao mostra o botao`() {
        montar(EstadoIncluirNaEquipe(SituacaoNaEquipe.NA_EQUIPE))

        rule.onNodeWithText(TextosEquipe.NA_EQUIPE).assertIsDisplayed()
        rule.onAllNodesWithContentDescriptionCount("Incluir na equipe: Ana Souza", 0)
    }

    @Test
    fun `incluindo desliga o botao`() {
        montar(EstadoIncluirNaEquipe(SituacaoNaEquipe.FORA_DA_EQUIPE, incluindo = true))

        rule.onNodeWithContentDescription("Incluir na equipe: Ana Souza").assertIsNotEnabled()
        rule.onNodeWithText(TextosEquipe.INCLUINDO).assertIsDisplayed()
    }

    @Test
    fun `a recusa do servidor aparece em texto do Frila e o botao continua`() {
        montar(EstadoIncluirNaEquipe(SituacaoNaEquipe.FORA_DA_EQUIPE, mensagemErro = TextosEquipe.SEM_TURNO_CUMPRIDO))

        rule.onNodeWithText(TextosEquipe.SEM_TURNO_CUMPRIDO).assertIsDisplayed()
        rule.onNodeWithContentDescription("Incluir na equipe: Ana Souza").assertIsEnabled()
    }

    private fun androidx.compose.ui.test.junit4.ComposeContentTestRule.onAllNodesWithContentDescriptionCount(descricao: String, esperado: Int) {
        assertEquals(esperado, onAllNodesWithContentDescription(descricao).fetchSemanticsNodes().size)
    }
}
