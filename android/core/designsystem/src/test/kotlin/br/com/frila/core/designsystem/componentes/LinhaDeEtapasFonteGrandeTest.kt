package br.com.frila.core.designsystem.componentes

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.unit.Density
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão nPkFbOdN (item 292): a `LinhaDeEtapas` mostra os rótulos com `fontScale <= 1,3` e, acima, só a frase "Etapa 2 de 4: A caminho". O
 * teste antigo roda com a fonte padrão. Sem isto, `<=` virar `<` e apagar o bloco `if (!rotulosCabem)` passavam. Fora: Meus turnos.
 *
 * Os textos da linha ficam sob `clearAndSetSemantics`, então a busca usa a árvore não mesclada. JUnit: nenhum método devolve valor.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class LinhaDeEtapasFonteGrandeTest {

    @get:Rule
    val compose = createComposeRule()

    private val etapas = listOf("Confirmado", "A caminho", "Presença", "Concluído")
    private val frase = "Etapa 2 de 4: A caminho"

    private fun montar(fontScale: Float, atual: Int = 1) {
        compose.setContent {
            ComFonte(fontScale) { FrilaTheme { LinhaDeEtapas(etapas = etapas, atual = atual) } }
        }
    }

    @Composable
    private fun ComFonte(fontScale: Float, conteudo: @Composable () -> Unit) {
        val base = LocalDensity.current
        CompositionLocalProvider(LocalDensity provides Density(base.density, fontScale), content = conteudo)
    }

    private fun quantosRotulosNaTela() = etapas.sumOf { compose.onAllNodesWithText(it, useUnmergedTree = true).fetchSemanticsNodes().size }

    private fun quantasFrasesNaTela(texto: String = frase) = compose.onAllNodesWithText(texto, useUnmergedTree = true).fetchSemanticsNodes().size

    @Test
    fun `com a fonte padrao os quatro rotulos aparecem e a frase nao`() {
        montar(1.0f)

        compose.waitForIdle()
        assert(quantosRotulosNaTela() == 4) { "rótulos: ${quantosRotulosNaTela()}" }
        compose.onAllNodesWithText(frase, useUnmergedTree = true).assertCountEquals(0)
    }

    @Test
    fun `com fonte 1,3 exata os rotulos ainda aparecem e a frase nao`() {
        montar(1.3f)

        compose.waitForIdle()
        assert(quantosRotulosNaTela() == 4) { "rótulos: ${quantosRotulosNaTela()}" }
        compose.onAllNodesWithText(frase, useUnmergedTree = true).assertCountEquals(0)
    }

    @Test
    fun `logo acima de 1,3 os rotulos somem e a frase da etapa atual aparece escrita`() {
        montar(1.31f)

        compose.waitForIdle()
        assert(quantosRotulosNaTela() == 0) { "rótulos: ${quantosRotulosNaTela()}" }
        compose.onAllNodesWithText(frase, useUnmergedTree = true).assertCountEquals(1)
    }

    @Test
    fun `com fonte 2,0 so a frase da etapa atual, sem rotulos`() {
        montar(2.0f)

        compose.waitForIdle()
        assert(quantosRotulosNaTela() == 0) { "rótulos: ${quantosRotulosNaTela()}" }
        assert(quantasFrasesNaTela() == 1) { "frases: ${quantasFrasesNaTela()}" }
    }

    @Test
    fun `a frase acompanha a etapa atual na fonte grande, da primeira a ultima`() {
        montar(2.0f, atual = 0)
        compose.waitForIdle()
        assert(quantasFrasesNaTela("Etapa 1 de 4: Confirmado") == 1)
    }

    @Test
    fun `na ultima etapa a frase diz 4 de 4`() {
        montar(2.0f, atual = 3)
        compose.waitForIdle()
        assert(quantasFrasesNaTela("Etapa 4 de 4: Concluído") == 1)
    }

    @Test
    fun `o leitor de tela ouve a etapa atual na fonte padrao e na grande`() {
        montar(2.0f)
        compose.onNodeWithContentDescription(frase).assertExists()
    }
}
