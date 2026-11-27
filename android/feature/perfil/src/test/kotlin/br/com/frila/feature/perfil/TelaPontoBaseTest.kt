package br.com.frila.feature.perfil

import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.rede.FuncaoDto
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Ponto base: uma lista de regiões com busca e, só para quem não tem perfil, as funções. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h2400dp")
class TelaPontoBaseTest {

    @get:Rule
    val rule = createComposeRule()

    private val planoPiloto = OpcaoDePontoBase("Plano Piloto", Coordenada(-15.793889, -47.882778))
    private val taguatinga = OpcaoDePontoBase("Taguatinga", Coordenada(-15.833333, -48.056944))
    private val estadoBase = EstadoPontoBase(opcoes = listOf(planoPiloto, taguatinga))

    private class Toques {
        val escolhidas = mutableListOf<OpcaoDePontoBase>()
        val funcoes = mutableListOf<String>()
        var salvou = 0
        var voltou = 0
    }

    private fun montar(estado: EstadoPontoBase = estadoBase, toques: Toques = Toques()): Toques {
        rule.setContent {
            FrilaTheme {
                ConteudoPontoBase(
                    estado = estado,
                    aoEscolher = { toques.escolhidas += it },
                    aoAlternarFuncao = { toques.funcoes += it },
                    aoSalvar = { toques.salvou++ },
                    aoVoltar = { toques.voltou++ },
                )
            }
        }
        return toques
    }

    private fun contar(texto: String) = rule.onAllNodesWithText(texto).fetchSemanticsNodes().size

    @Test
    fun `mostra o titulo, a dica e as regioes, sem pedir funcao a quem ja tem perfil`() {
        montar()

        rule.onNodeWithText(TextosPontoBase.TITULO).assertIsDisplayed()
        rule.onNodeWithText(TextosPontoBase.DICA).assertIsDisplayed()
        rule.onNodeWithText("Plano Piloto").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("Taguatinga").performScrollTo().assertIsDisplayed()
        assertEquals(0, contar(TextosPontoBase.FUNCOES))
        assertEquals(0, contar(TextosPontoBase.PONTO_BASE_SALVO))
    }

    @Test
    fun `ponto salvo fora do DF mostra o aviso do iOS e o salvar segue habilitado`() {
        val toques = montar(estadoBase.copy(temPontoBaseSalvo = true, pontoSalvoForaDoDF = true))

        rule.onNodeWithText(TextosPontoBase.AVISO_FORA_DO_DF).assertIsDisplayed()
        rule.onNodeWithText(TextosPontoBase.SALVAR).performClick()

        assertEquals(1, toques.salvou)
    }

    @Test
    fun `dentro do DF nao mostra o aviso`() {
        montar(estadoBase.copy(temPontoBaseSalvo = true, escolhida = taguatinga))

        assertEquals(0, contar(TextosPontoBase.AVISO_FORA_DO_DF))
    }

    @Test
    fun `tocar numa regiao avisa a escolha, e a linha tem o alvo minimo de toque`() {
        val toques = montar()

        rule.onNodeWithText("Taguatinga").performScrollTo().assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()

        assertEquals(listOf(taguatinga), toques.escolhidas)
    }

    @Test
    fun `a regiao escolhida aparece selecionada e o aviso de ponto salvo aparece`() {
        montar(estadoBase.copy(escolhida = planoPiloto, temPontoBaseSalvo = true))

        rule.onNodeWithText("Plano Piloto").performScrollTo().assertIsSelected()
        rule.onNodeWithText(TextosPontoBase.PONTO_BASE_SALVO).assertIsDisplayed()
    }

    @Test
    fun `sem perfil mostra as funcoes e tocar numa avisa o id`() {
        val toques = montar(
            estadoBase.copy(semPerfil = true, funcoes = listOf(FuncaoDto("f-garcom", "garçom", "Salão"), FuncaoDto("f-bar", "barman", "Bar"))),
        )

        rule.onNodeWithText(TextosPontoBase.FUNCOES).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("barman").performScrollTo().assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()

        assertEquals(listOf("f-bar"), toques.funcoes)
    }

    @Test
    fun `salvar e voltar avisam quem abriu a tela, e o erro aparece`() {
        val toques = montar(estadoBase.copy(erro = TextosPontoBase.ERRO_SEM_PONTO_BASE))

        // O erro e o Salvar ficam no rodapé ancorado, fora da rolagem: não há o que rolar até eles.
        rule.onNodeWithText(TextosPontoBase.ERRO_SEM_PONTO_BASE).assertIsDisplayed()
        rule.onNodeWithText(TextosPontoBase.SALVAR).performClick()
        rule.onNodeWithContentDescription(TextosPontoBase.VOLTAR).performClick()

        assertEquals(1, toques.salvou)
        assertEquals(1, toques.voltou)
    }

    @Test
    fun `enquanto salva o botao fica desligado e diz que esta salvando`() {
        val toques = montar(estadoBase.copy(salvando = true))

        rule.onNodeWithText(TextosPontoBase.SALVANDO).assertIsNotEnabled().performClick()

        assertEquals(0, toques.salvou)
    }
}
