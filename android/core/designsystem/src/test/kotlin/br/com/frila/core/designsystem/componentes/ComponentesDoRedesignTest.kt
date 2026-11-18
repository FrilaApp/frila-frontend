package br.com.frila.core.designsystem.componentes

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.state.ToggleableState
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertHasNoClickAction
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.assertWidthIsAtLeast
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** O que os componentes novos do redesign prometem a quem usa a tela: toque, estado e leitor de tela. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ComponentesDoRedesignTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `CampoDeTexto e achado pelo rotulo, recebe o texto e expoe o erro escrito`() {
        var valor by mutableStateOf("")
        compose.setContent {
            FrilaTheme {
                CampoDeTexto(valor = valor, aoMudar = { valor = it }, rotulo = "E-mail", erro = "Confira o e-mail.")
            }
        }

        compose.onNodeWithText("E-mail").performTextInput("ju@exemplo.com")

        assertEquals("ju@exemplo.com", valor)
        compose.onNodeWithText("E-mail")
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Error, "Confira o e-mail."))
            .assertHeightIsAtLeast(FrilaMetricas.alturaCampo)
        compose.onNodeWithText("Confira o e-mail.", useUnmergedTree = true).assertExists()
    }

    @Test
    fun `CaixasDeCodigo so aceita digitos e para na quantidade`() {
        var codigo by mutableStateOf("")
        compose.setContent {
            FrilaTheme { CaixasDeCodigo(codigo = codigo, aoMudar = { codigo = it }) }
        }

        compose.onNodeWithContentDescription("Código de acesso").performTextInput("12a3-45678")

        assertEquals("123456", codigo)
    }

    @Test
    fun `CampoDeBusca mostra o limpar so com texto e ele esvazia o campo`() {
        compose.setContent {
            FrilaTheme {
                var texto by remember { mutableStateOf("") }
                CampoDeBusca(texto = texto, aoMudar = { texto = it }, dica = "Buscar por função")
            }
        }

        compose.onNodeWithContentDescription("Limpar busca").assertDoesNotExist()
        compose.onNodeWithContentDescription("Buscar por função").performTextInput("bar")
        compose.onNodeWithContentDescription("Limpar busca")
            .assertHasClickAction()
            .assertWidthIsAtLeast(FrilaMetricas.alvoMinimo)
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()
        compose.onNodeWithContentDescription("Limpar busca").assertDoesNotExist()
    }

    @Test
    fun `ChipFrila tem alvo de 48, diz se esta marcado e alterna no toque`() {
        compose.setContent {
            FrilaTheme {
                var marcado by remember { mutableStateOf(false) }
                ChipFrila(texto = "Bartender", selecionado = marcado, aoClicar = { marcado = !marcado })
            }
        }

        val chip = compose.onNodeWithText("Bartender")
        chip.assertWidthIsAtLeast(FrilaMetricas.alvoMinimo)
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.ToggleableState, ToggleableState.Off))
            .performClick()
        chip.assert(SemanticsMatcher.expectValue(SemanticsProperties.ToggleableState, ToggleableState.On))
    }

    @Test
    fun `ChipFrila de escolha unica e uma opcao de grupo`() {
        compose.setContent {
            FrilaTheme { ChipFrila(texto = "Imprevisto", selecionado = true, aoClicar = {}, escolhaUnica = true) }
        }

        compose.onNodeWithText("Imprevisto")
            .assertIsSelected()
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.RadioButton))
    }

    @Test
    fun `linhas do grupo - a opcao marca no toque e a de navegacao e botao`() {
        var escolhida by mutableStateOf("Casa")
        var abriu = false
        compose.setContent {
            FrilaTheme {
                FrilaGrupoDeLinhas(titulo = "Salvar como") {
                    linha { FrilaLinhaDeOpcao("Casa", marcada = escolhida == "Casa", aoClicar = { escolhida = "Casa" }) }
                    linha { FrilaLinhaDeOpcao("Trabalho", marcada = escolhida == "Trabalho", aoClicar = { escolhida = "Trabalho" }) }
                    linha { FrilaLinhaDeNavegacao("Serviços", aoClicar = { abriu = true }) }
                }
            }
        }

        compose.onNodeWithText("Casa").assertIsSelected()
        compose.onNodeWithText("Trabalho")
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()
        compose.onNodeWithText("Trabalho").assertIsSelected()
        assertEquals("Trabalho", escolhida)

        compose.onNodeWithText("Serviços")
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Button))
            .performClick()
        assertTrue(abriu)
    }

    @Test
    fun `link e acao discreta sao botoes com alvo de 48`() {
        var toques = 0
        compose.setContent {
            FrilaTheme {
                androidx.compose.foundation.layout.Column {
                    LinkFrila("Reenviar código", aoClicar = { toques++ })
                    AcaoDiscreta("Cancelar turno", aoClicar = { toques++ })
                }
            }
        }

        listOf("Reenviar código", "Cancelar turno").forEach { texto ->
            compose.onNodeWithText(texto)
                .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
                .assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Button))
                .performClick()
        }
        assertEquals(2, toques)
    }

    @Test
    fun `selo de status informa e nao se toca`() {
        compose.setContent {
            FrilaTheme { SeloDeStatus("Confirmado", EstiloDoSelo.CONFIRMADO) }
        }

        compose.onNodeWithText("Confirmado")
            .assertHasNoClickAction()
            .assertHeightIsAtLeast(FrilaMetricas.alturaSelo)
    }

    @Test
    fun `linha de etapas diz ao leitor de tela qual e a etapa atual`() {
        compose.setContent {
            FrilaTheme {
                LinhaDeEtapas(etapas = listOf("Confirmado", "A caminho", "Presença", "Concluído"), atual = 1)
            }
        }

        compose.onNodeWithContentDescription("Etapa 2 de 4: A caminho").assertExists()
    }

    @Test
    fun `barra de topo tem o voltar com alvo de 48`() {
        var voltou = false
        compose.setContent {
            FrilaTheme { FrilaBarraDeTopo(aoVoltar = { voltou = true }) }
        }

        compose.onNodeWithContentDescription("Voltar")
            .assertWidthIsAtLeast(FrilaMetricas.alvoMinimo)
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()
        assertTrue(voltou)
    }

    @Test
    fun `mensagem junto ao botao e anunciada e o primario desligado nao recebe toque`() {
        compose.setContent {
            FrilaTheme {
                RodapeAncorado {
                    MensagemJuntoAoBotao("Esse código não confere.")
                    BotaoPrimario(texto = "Entrar", aoClicar = {}, habilitado = false)
                }
            }
        }

        val regiao = compose.onNodeWithText("Esse código não confere.").fetchSemanticsNode()
            .config.getOrNull(SemanticsProperties.LiveRegion)
        assertTrue(regiao != null)
        compose.onNodeWithText("Entrar").assertIsNotEnabled()
    }
}
