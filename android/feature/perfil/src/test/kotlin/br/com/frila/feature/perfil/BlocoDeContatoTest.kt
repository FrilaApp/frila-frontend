package br.com.frila.feature.perfil

import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** wdgLuHOV: telefone formatado e e-mail no perfil, cada um com copiar (`ContatoCopiavel` do iOS); editar o contato fica de fora. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h1200dp")
class BlocoDeContatoTest {

    @get:Rule
    val rule = createComposeRule()

    private val copiados = mutableListOf<String>()

    private fun montar(telefone: String? = "+5561988887777", email: String? = "ana@exemplo.com") {
        rule.setContent { FrilaTheme { BlocoDeContato(telefone = telefone, email = email, aoCopiar = { copiados += it }) } }
    }

    @Test
    fun `mostra o rotulo de cada contato e o telefone formatado`() {
        montar()

        rule.onNodeWithText(TextosContatoDoPerfil.TELEFONE).assertIsDisplayed()
        rule.onNodeWithText(TextosContatoDoPerfil.EMAIL).assertIsDisplayed()
        rule.onNodeWithText("(61) 98888-7777").assertIsDisplayed()
        rule.onNodeWithText("ana@exemplo.com").assertIsDisplayed()
        assertTrue(rule.onAllNodesWithText("+5561988887777").fetchSemanticsNodes().isEmpty())
    }

    @Test
    fun `tocar no telefone copia o valor como esta na tela, e tocar no e-mail copia o e-mail`() {
        montar()

        rule.onNodeWithTag("perfil-telefone").performClick()
        rule.onNodeWithTag("perfil-email").performClick()

        assertEquals(listOf("(61) 98888-7777", "ana@exemplo.com"), copiados)
    }

    @Test
    fun `depois de copiar mostra Copiado no lugar do valor e o valor volta sozinho`() {
        montar()

        rule.onNodeWithTag("perfil-telefone").performClick()
        rule.onNodeWithText(TextosContatoDoPerfil.COPIADO).assertIsDisplayed()
        assertTrue(rule.onAllNodesWithText("(61) 98888-7777").fetchSemanticsNodes().isEmpty())
        rule.mainClock.advanceTimeBy(500)
        rule.onNodeWithText(TextosContatoDoPerfil.COPIADO).assertIsDisplayed()

        rule.mainClock.advanceTimeBy(3_000)
        rule.onNodeWithText("(61) 98888-7777").assertIsDisplayed()
        assertTrue(rule.onAllNodesWithText(TextosContatoDoPerfil.COPIADO).fetchSemanticsNodes().isEmpty())
    }

    @Test
    fun `contato vazio mostra o travessao e nao copia nada`() {
        montar(telefone = "", email = null)

        rule.onAllNodesWithText(TextosContatoDoPerfil.NAO_INFORMADO).let { assertEquals(2, it.fetchSemanticsNodes().size) }
        rule.onNodeWithTag("perfil-telefone").performClick()
        rule.onNodeWithTag("perfil-email").performClick()

        assertTrue(copiados.isEmpty())
    }

    @Test
    fun `a acao de copiar tem o nome Copiar para o leitor de tela`() {
        montar()

        val acao = rule.onNodeWithTag("perfil-telefone").fetchSemanticsNode().config.getOrNull(SemanticsActions.OnClick)
        assertEquals(TextosContatoDoPerfil.COPIAR, acao?.label)
    }

    @Test
    fun `numero estrangeiro aparece como veio`() {
        montar(telefone = "+14155550123")

        rule.onNodeWithText("+14155550123").assertIsDisplayed()
    }
}
