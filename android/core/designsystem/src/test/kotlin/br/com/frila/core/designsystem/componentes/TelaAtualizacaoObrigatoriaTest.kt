package br.com.frila.core.designsystem.componentes

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaAtualizacaoObrigatoriaTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `ComparadorDeVersao detecta quando atualizacao eh obrigatoria`() {
        assertTrue(ComparadorDeVersao.precisaAtualizar(versaoAtual = "1.0.0", versaoMinima = "1.0.1"))
        assertTrue(ComparadorDeVersao.precisaAtualizar(versaoAtual = "1.0", versaoMinima = "1.1.0"))
        assertTrue(ComparadorDeVersao.precisaAtualizar(versaoAtual = "1.9.9", versaoMinima = "2.0.0"))
        assertTrue(ComparadorDeVersao.precisaAtualizar(versaoAtual = "0.9.0-alpha", versaoMinima = "1.0.0"))

        assertFalse(ComparadorDeVersao.precisaAtualizar(versaoAtual = "1.0.0", versaoMinima = "1.0.0"))
        assertFalse(ComparadorDeVersao.precisaAtualizar(versaoAtual = "1.1", versaoMinima = "1.1.0"))
        assertFalse(ComparadorDeVersao.precisaAtualizar(versaoAtual = "1.2.0", versaoMinima = "1.1.0"))
        assertFalse(ComparadorDeVersao.precisaAtualizar(versaoAtual = "2.0.0", versaoMinima = "1.9.9"))
    }

    // i3NSbCXD: o que separa o trim e o takeWhile, que os casos acima não distinguem.

    @Test
    fun `sufixo depois dos numeros nao conta, e 1_0_1-beta nao bloqueia contra a minima 1_0_1`() {
        assertFalse(ComparadorDeVersao.precisaAtualizar(versaoAtual = "1.0.1-beta", versaoMinima = "1.0.1"))
        assertTrue(ComparadorDeVersao.precisaAtualizar(versaoAtual = "1.0.0-rc1", versaoMinima = "1.0.1"))
    }

    @Test
    fun `espacos em volta da versao nao contam, na atual e na minima`() {
        assertFalse(ComparadorDeVersao.precisaAtualizar(versaoAtual = " 1.2.0", versaoMinima = "1.1.0"))
        assertTrue(ComparadorDeVersao.precisaAtualizar(versaoAtual = "1.0.0", versaoMinima = " 1.1.0 "))
    }

    @Test
    fun `TelaAtualizacaoObrigatoria exibe titulo com semantica heading e botao acessivel`() {
        var atualizou = false

        compose.setContent {
            FrilaTheme {
                TelaAtualizacaoObrigatoria(
                    aoAtualizar = { atualizou = true },
                    mensagem = "Versão mínima 1.2.0 exigida pelo servidor.",
                )
            }
        }

        // Título normativo com marcação de heading para leitores de tela
        val noTitulo = compose.onNodeWithText(TextosAtualizacaoObrigatoria.TITULO)
        noTitulo.assertExists()
        noTitulo.assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))

        // Mensagem explicativa
        compose.onNodeWithText("Versão mínima 1.2.0 exigida pelo servidor.").assertExists()

        // Botão de atualização com ação de clique e alvo mínimo de 48dp
        val noBotao = compose.onNodeWithText(TextosAtualizacaoObrigatoria.BOTAO_ATUALIZAR)
        noBotao.assertExists()
        noBotao.assertHasClickAction()
        noBotao.assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)

        // Clique dispara callback
        noBotao.performClick()
        assertTrue("Callback aoAtualizar deve ter sido disparado", atualizou)
    }
}
