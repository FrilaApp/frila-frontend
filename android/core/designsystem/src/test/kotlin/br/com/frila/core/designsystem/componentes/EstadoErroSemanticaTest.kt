package br.com.frila.core.designsystem.componentes

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão MEnxYaqu (item 239): a semântica do `EstadoErro`. O teste do `FeedbackEmptyStateTest` sempre passa a mensagem, mas as telas reais
 * (equipe de confiança, trocar de casa, bloqueados) passam `mensagem = null`, e é aí que a semântica de erro, o título como heading e a mensagem em
 * branco escondida valem.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class EstadoErroSemanticaTest {

    @get:Rule
    val compose = createComposeRule()

    private val titulo = "Não foi possível carregar a equipe"
    private val mensagem = "Verifique sua conexão e tente novamente."

    private fun montar(mensagem: String?, aoTentarNovamente: (() -> Unit)? = null) {
        compose.setContent { FrilaTheme { EstadoErro(titulo = titulo, mensagem = mensagem, aoTentarNovamente = aoTentarNovamente) } }
    }

    private fun erro(texto: String) = SemanticsMatcher.expectValue(SemanticsProperties.Error, texto)
    private val textos get() = compose.onAllNodes(SemanticsMatcher.keyIsDefined(SemanticsProperties.Text))

    @Test
    fun `sem mensagem, a semantica de erro anuncia o titulo`() {
        montar(mensagem = null)

        compose.onNode(erro(titulo)).assertExists()
    }

    @Test
    fun `com mensagem, a semantica de erro anuncia a mensagem e nao o titulo`() {
        montar(mensagem = mensagem)

        compose.onNode(erro(mensagem)).assertExists()
        compose.onAllNodes(erro(titulo)).assertCountEquals(0)
    }

    @Test
    fun `o titulo e um heading e a mensagem nao`() {
        montar(mensagem = mensagem)

        compose.onNodeWithText(titulo).assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        compose.onNodeWithText(mensagem).assert(SemanticsMatcher.keyNotDefined(SemanticsProperties.Heading))
    }

    @Test
    fun `sem mensagem, o titulo continua heading e e o unico texto da tela`() {
        montar(mensagem = null)

        compose.onNodeWithText(titulo).assertIsDisplayed().assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        textos.assertCountEquals(1)
    }

    @Test
    fun `mensagem vazia nao vira texto na tela`() {
        montar(mensagem = "")

        compose.onNodeWithText(titulo).assertIsDisplayed()
        textos.assertCountEquals(1)
    }

    @Test
    fun `mensagem so de espacos nao vira texto na tela`() {
        montar(mensagem = "   ")

        compose.onNodeWithText(titulo).assertIsDisplayed()
        textos.assertCountEquals(1)
    }

    @Test
    fun `com mensagem, titulo e mensagem aparecem`() {
        montar(mensagem = mensagem)

        compose.onNodeWithText(titulo).assertIsDisplayed()
        compose.onNodeWithText(mensagem).assertIsDisplayed()
        textos.assertCountEquals(2)
    }

    @Test
    fun `o botao so existe com a acao de tentar de novo`() {
        montar(mensagem = null)
        compose.onAllNodes(SemanticsMatcher.keyIsDefined(SemanticsProperties.Role)).assertCountEquals(0)
    }

    @Test
    fun `com a acao de tentar de novo, o botao aparece mesmo sem mensagem`() {
        montar(mensagem = null, aoTentarNovamente = {})

        compose.onNodeWithText("Tentar novamente").assertIsDisplayed()
    }
}
