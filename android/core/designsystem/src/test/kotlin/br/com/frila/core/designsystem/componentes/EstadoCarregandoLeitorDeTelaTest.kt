package br.com.frila.core.designsystem.componentes

import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onAllNodesWithText
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão PXpS5TKV (item 283): o "Carregando" de tela inteira avisa o leitor de tela, como o iOS (`EstadosDeTela.swift:59-60`:
 * `.accessibilityElement(children: .ignore)` com `.accessibilityLabel("Carregando…")`). Antes, o indicador não tinha rótulo, e as telas que chamam sem mensagem
 * (acompanhar chamadas, chamada direta, perfil público, candidatos, abertura da vaga) ficavam mudas. Sem mensagem, o leitor lê "Carregando…"; com mensagem, lê
 * a mensagem, uma vez só.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class EstadoCarregandoLeitorDeTelaTest {

    @get:Rule
    val compose = createComposeRule()

    private val carregando = "Carregando…"

    private fun progressos() = compose.onAllNodes(SemanticsMatcher.keyIsDefined(SemanticsProperties.ProgressBarRangeInfo))

    @Test
    fun `sem mensagem, o leitor de tela le Carregando`() {
        compose.setContent { FrilaTheme { EstadoCarregando() } }

        compose.onAllNodesWithContentDescription(carregando).assertCountEquals(1)
    }

    @Test
    fun `mensagem em branco conta como sem mensagem`() {
        compose.setContent { FrilaTheme { EstadoCarregando(mensagem = "   ") } }

        compose.onAllNodesWithContentDescription(carregando).assertCountEquals(1)
    }

    @Test
    fun `sem mensagem, o indicador nao e uma segunda parada do leitor`() {
        compose.setContent { FrilaTheme { EstadoCarregando() } }

        progressos().assertCountEquals(0)
    }

    @Test
    fun `com mensagem, o leitor le a mensagem`() {
        compose.setContent { FrilaTheme { EstadoCarregando(mensagem = "Carregando as vagas…") } }

        compose.onAllNodesWithText("Carregando as vagas…").assertCountEquals(1)
    }

    @Test
    fun `com mensagem, ela e lida uma vez so, sem o rotulo generico e sem o indicador`() {
        compose.setContent { FrilaTheme { EstadoCarregando(mensagem = "Carregando as vagas…") } }

        compose.onAllNodesWithContentDescription(carregando).assertCountEquals(0)
        progressos().assertCountEquals(0)
    }

    // O leitor de tela fala o `Text` E o `contentDescription` de cada nó da árvore mesclada. Contar só os nós com o texto da mensagem não pega um contêiner que
    // ponha a mensagem no próprio `contentDescription` sem limpar os filhos: a mensagem seria falada duas vezes (por isso se somam as duas fontes, em todos os nós).
    private fun quantasVezesALeitorFala(mensagem: String): Int =
        compose.onAllNodes(SemanticsMatcher("qualquer nó") { true }).fetchSemanticsNodes().sumOf { no ->
            val texto = no.config.getOrNull(SemanticsProperties.Text).orEmpty().count { it.text == mensagem }
            val descricao = no.config.getOrNull(SemanticsProperties.ContentDescription).orEmpty().count { it == mensagem }
            texto + descricao
        }

    @Test
    fun `com mensagem, a leitora fala a mensagem exatamente uma vez, somando texto e descricao de todos os nos`() {
        compose.setContent { FrilaTheme { EstadoCarregando(mensagem = "Carregando as vagas\u2026") } }

        assertEquals(1, quantasVezesALeitorFala("Carregando as vagas\u2026"))
    }

    @Test
    fun `sem mensagem, o rotulo e falado exatamente uma vez`() {
        compose.setContent { FrilaTheme { EstadoCarregando() } }

        assertEquals(1, quantasVezesALeitorFala(carregando))
    }

    @Test
    fun `o rotulo do chamador vence o generico`() {
        compose.setContent {
            FrilaTheme { EstadoCarregando(modifier = Modifier.semantics { contentDescription = "Carregando suas vagas…" }) }
        }

        compose.onAllNodesWithContentDescription("Carregando suas vagas…").assertCountEquals(1)
        compose.onAllNodesWithContentDescription(carregando).assertCountEquals(0)
    }
}
