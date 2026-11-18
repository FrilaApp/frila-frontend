package br.com.frila.feature.suporte

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.hasAnyAncestor
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.isDialog
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ItemBloqueioDto
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaBloqueiosTest {

    @get:Rule
    val rule = createComposeRule()

    private val ana = ItemBloqueioDto("profissional", "a1", "Ana Souza", "2026-11-10T12:00:00Z")
    private val bar = ItemBloqueioDto("estabelecimento", "b1", "Bar do Zé", "2026-11-09T12:00:00Z")

    private class Chamadas {
        var novamente = 0
        val desbloqueados = mutableListOf<String>()
        var voltou = 0
    }

    private fun montar(tela: EstadoTelaBloqueios, chamadas: Chamadas = Chamadas()): Chamadas {
        rule.setContent {
            FrilaTheme {
                ConteudoBloqueios(
                    tela = tela,
                    aoTentarNovamente = { chamadas.novamente++ },
                    aoDesbloquear = { chamadas.desbloqueados += it.nome },
                    aoVoltar = { chamadas.voltou++ },
                )
            }
        }
        return chamadas
    }

    private fun comItens(vararg itens: ItemBloqueioDto, ajuste: EstadoTelaBloqueios.() -> EstadoTelaBloqueios = { this }) =
        EstadoTelaBloqueios(estado = EstadoBloqueios.Conteudo(itens.toList())).ajuste()

    @Test
    fun `cabecalho tem titulo como heading, explicacao e voltar com alvo minimo`() {
        val c = montar(comItens(ana))

        rule.onNodeWithText(TextosBloqueios.TITULO).assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        rule.onNodeWithText(TextosBloqueios.EXPLICACAO).assertIsDisplayed()
        rule.onNodeWithContentDescription(TextosBloqueios.ROTULO_VOLTAR)
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()

        assertEquals(1, c.voltou)
    }

    @Test
    fun `lista mostra o nome e o tipo de cada bloqueio`() {
        montar(comItens(ana, bar))

        rule.onNodeWithText("Ana Souza").assertIsDisplayed()
        rule.onNodeWithText(TextosBloqueios.TIPO_PROFISSIONAL).assertIsDisplayed()
        rule.onNodeWithText("Bar do Zé").assertIsDisplayed()
        rule.onNodeWithText(TextosBloqueios.TIPO_ESTABELECIMENTO).assertIsDisplayed()
    }

    @Test
    fun `desbloquear abre a confirmacao e so depois de confirmar chama o desbloqueio`() {
        val c = montar(comItens(ana, bar))

        rule.onNodeWithContentDescription("Desbloquear Ana Souza")
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()
        rule.onNodeWithText(TextosBloqueios.CONFIRMAR_DESBLOQUEIO).assertIsDisplayed()
        rule.onNodeWithText(TextosBloqueios.efeitoDesbloqueio("Ana Souza")).assertIsDisplayed()
        assertEquals(emptyList<String>(), c.desbloqueados)

        rule.onNode(hasText(TextosBloqueios.DESBLOQUEAR) and hasAnyAncestor(isDialog())).performClick()

        assertEquals(listOf("Ana Souza"), c.desbloqueados)
    }

    @Test
    fun `cancelar a confirmacao nao desbloqueia`() {
        val c = montar(comItens(ana))

        rule.onNodeWithContentDescription("Desbloquear Ana Souza").performClick()
        rule.onNodeWithText(TextosBloqueios.CANCELAR).performClick()

        assertEquals(emptyList<String>(), c.desbloqueados)
        rule.onAllNodesWithText(TextosBloqueios.CONFIRMAR_DESBLOQUEIO).assertCountEquals(0)
    }

    @Test
    fun `com um desbloqueio em voo os botoes ficam desligados`() {
        montar(comItens(ana, bar) { copy(desbloqueando = "profissional:a1") })

        rule.onNodeWithContentDescription("Desbloquear Ana Souza").assertIsNotEnabled()
        rule.onNodeWithContentDescription("Desbloquear Bar do Zé").assertIsNotEnabled()
        rule.onNodeWithText(TextosBloqueios.DESBLOQUEANDO).assertIsDisplayed()
    }

    @Test
    fun `vazio mostra o titulo e a mensagem`() {
        montar(EstadoTelaBloqueios(estado = EstadoBloqueios.Vazio))

        rule.onNodeWithText(TextosBloqueios.VAZIO_TITULO).assertIsDisplayed()
        rule.onNodeWithText(TextosBloqueios.VAZIO_MENSAGEM).assertIsDisplayed()
    }

    @Test
    fun `erro e sem rede mostram a mensagem com tentar novamente`() {
        val c = montar(EstadoTelaBloqueios(estado = EstadoBloqueios.Erro(TextosBloqueios.ERRO_CARREGAR)))

        rule.onNodeWithText(TextosBloqueios.ERRO_CARREGAR).assertIsDisplayed()
        rule.onNodeWithText(TextosBloqueios.TENTAR_NOVAMENTE).assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()

        assertEquals(1, c.novamente)
    }

    @Test
    fun `a mensagem de erro de uma acao aparece sem tirar a lista`() {
        montar(comItens(ana) { copy(mensagemErro = TextosBloqueios.ERRO_DESBLOQUEAR) })

        rule.onNodeWithText(TextosBloqueios.ERRO_DESBLOQUEAR).assertIsDisplayed()
        rule.onNodeWithText("Ana Souza").assertIsDisplayed()
    }
}
