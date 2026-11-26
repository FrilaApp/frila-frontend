package br.com.frila.feature.vagas.escala

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.EscalaPublicadaDto
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.NovaEscalaDto
import br.com.frila.core.rede.VagaPublicadaDto
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.feature.vagas.publicacao.EstabelecimentoDaVaga
import br.com.frila.feature.vagas.publicacao.TextosPublicarVaga
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Caminho feliz da escala de evento com fakes no lugar da rede: o formulário de verdade, o [EscalaDeEventoViewModel] de
 * verdade e `enviarEscala` capturando o corpo. O que a tela faz com cada recusa está nos testes do ViewModel.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaEscalaDeEventoTest {

    @get:Rule
    val rule = createComposeRule()

    private val base: Instant = Instant.parse("2026-11-10T15:00:00Z")

    private val funcoes = listOf(FuncaoDto("f1", "Garçom", "Salão"), FuncaoDto("f2", "Cozinheiro", "Cozinha"))

    private val enviados = mutableListOf<NovaEscalaDto>()
    private var concluiu = 0
    private var voltou = 0

    private fun viewModel(falhar: Boolean = false) = EscalaDeEventoViewModel(
        estabelecimento = EstabelecimentoDaVaga("e1", "CLS 408, Bloco B, Loja 12", "Plano Piloto", CoordenadaDto(-15.7942, -47.8822)),
        buscarFuncoes = { funcoes },
        enviarEscala = { corpo ->
            enviados += corpo
            if (falhar) error("sem rede")
            EscalaPublicadaDto("ev1", corpo.vagas.map { VagaPublicadaDto("v", listOf("p")) })
        },
        relogio = { base },
        novaChave = { "chave-1" },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    private fun montar(vm: EscalaDeEventoViewModel = viewModel()): EscalaDeEventoViewModel {
        rule.setContent {
            FrilaTheme(temaEscuro = false) {
                TelaEscalaDeEvento(viewModel = vm, aoConcluir = { concluiu++ }, aoVoltar = { voltou++ })
            }
        }
        return vm
    }

    private fun preencherPrimeiraVaga(funcao: String = "Garçom") {
        rule.onNodeWithText(TextosEscala.NOME).performTextInput("Formatura de Direito")
        rule.onAllNodesWithText(TextosEscala.FUNCAO_SELECIONAR)[0].performScrollTo().performClick()
        rule.onNodeWithText(funcao).performClick()
        rule.onAllNodesWithText(TextosPublicarVaga.VALOR)[0].performScrollTo().performTextInput("180")
        rule.onAllNodesWithText(TextosPublicarVaga.RESPONSAVEL)[0].performScrollTo().performTextInput("Lia")
    }

    @Test
    fun `caminho feliz - nome, funcao, valor e responsavel publicam a escala e mostram a confirmacao`() {
        montar()

        rule.onNodeWithText(TextosEscala.TITULO)
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        rule.onNodeWithText(TextosEscala.ENDERECO.format("CLS 408, Bloco B, Loja 12")).performScrollTo().assertIsDisplayed()
        preencherPrimeiraVaga()
        rule.onNodeWithText(TextosEscala.PUBLICAR).assertIsEnabled().performClick()

        rule.onNodeWithText(TextosEscala.PUBLICADA_TITULO).assertIsDisplayed()
        rule.onNodeWithText(TextosEscala.PUBLICADA_UMA).assertIsDisplayed()
        val corpo = enviados.single()
        assertEquals("e1", corpo.estabelecimentoId)
        assertEquals("Formatura de Direito", corpo.evento.nome)
        assertEquals("2026-11-17", corpo.evento.data)
        assertEquals(1, corpo.vagas.size)
        assertEquals("f1", corpo.vagas.single().funcaoId)
        assertEquals(18000L, corpo.vagas.single().valorCentavos)
        assertEquals("Lia", corpo.vagas.single().responsavelLocal)
        assertEquals("chave-1", corpo.chave)

        rule.onNodeWithText(TextosEscala.VER_MINHAS_VAGAS).performClick()
        assertEquals(1, concluiu)
    }

    @Test
    fun `duas vagas viram uma escala so`() {
        montar()
        preencherPrimeiraVaga()
        rule.onNodeWithText(TextosEscala.ADICIONAR).performScrollTo().performClick()

        rule.onNodeWithText(TextosEscala.VAGA.format(2, 2)).performScrollTo().assertIsDisplayed()
        rule.onAllNodesWithText(TextosEscala.FUNCAO_SELECIONAR).assertCountEquals(1)
        rule.onAllNodesWithText(TextosEscala.FUNCAO_SELECIONAR)[0].performScrollTo().performClick()
        rule.onNodeWithText("Cozinheiro").performClick()
        rule.onAllNodesWithText(TextosPublicarVaga.VALOR)[1].performScrollTo().performTextInput("220")
        rule.onNodeWithText(TextosEscala.PUBLICAR).performClick()

        val corpo = enviados.single()
        assertEquals(listOf("f1", "f2"), corpo.vagas.map { it.funcaoId })
        rule.onNodeWithText(TextosEscala.PUBLICADA_VARIAS.format(2)).assertIsDisplayed()
    }

    @Test
    fun `tudo ou nada - formulario incompleto nao envia nada e avisa que nada foi publicado`() {
        montar()

        rule.onNodeWithText(TextosEscala.PUBLICAR).performClick()

        assertTrue(enviados.isEmpty())
        rule.onNodeWithText(TextosEscala.ERRO_CONFIRA_CAMPOS).assertIsDisplayed()
        rule.onNodeWithText(TextosEscala.NOME_CAMPO).assertIsDisplayed()
    }

    @Test
    fun `remover uma vaga so aparece com mais de uma e adicionar para no limite`() {
        montar()
        rule.onAllNodesWithText(TextosEscala.REMOVER.format(1)).assertCountEquals(0)

        repeat(9) { rule.onNodeWithText(TextosEscala.ADICIONAR).performScrollTo().performClick() }

        rule.onNodeWithText(TextosEscala.VAGA.format(10, 10)).performScrollTo().assertIsDisplayed()
        rule.onAllNodesWithText(TextosEscala.ADICIONAR).assertCountEquals(0)
        rule.onNodeWithText(TextosEscala.LIMITE.format(10)).performScrollTo().assertIsDisplayed()

        rule.onNodeWithText(TextosEscala.REMOVER.format(10)).performScrollTo().performClick()
        rule.onNodeWithText(TextosEscala.ADICIONAR).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun `sem rede a escala fica pendente e o botao vira tentar novamente`() {
        montar(viewModel(falhar = true))
        preencherPrimeiraVaga()

        rule.onNodeWithText(TextosEscala.PUBLICAR).performClick()

        rule.onNodeWithText(TextosEscala.TENTAR_NOVAMENTE).assertIsEnabled()
        rule.onNodeWithText(TextosEscala.PENDENTE).assertIsDisplayed()
        rule.onNodeWithText(TextosEscala.ERRO_GENERICO).assertIsDisplayed()
        // Pendente: o formulário trava, o reenvio é o mesmo corpo.
        rule.onAllNodesWithText(TextosEscala.ADICIONAR)[0].performScrollTo().assertIsNotEnabled()
    }

    @Test
    fun `os botoes principais tem alvo de pelo menos 48 dp`() {
        montar()

        rule.onNodeWithText(TextosEscala.PUBLICAR).assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
        rule.onNodeWithText(TextosEscala.ADICIONAR).performScrollTo().assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
    }

    @Test
    @Config(sdk = [35], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `com a fonte do sistema em 200 por cento o formulario e a confirmacao seguem acessiveis`() {
        montar()
        rule.onNodeWithText(TextosEscala.PUBLICAR).assertIsDisplayed()
        preencherPrimeiraVaga()
        rule.onNodeWithText(TextosEscala.ADICIONAR).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosEscala.PUBLICAR).performClick()

        rule.onNodeWithText(TextosEscala.VER_MINHAS_VAGAS).assertIsDisplayed()
    }

    @Test
    fun `voltar chama quem abriu a tela`() {
        montar()
        rule.onNodeWithContentDescription(TextosEscala.ROTULO_VOLTAR).performClick()
        assertEquals(1, voltou)
    }

    @Test
    fun `valor abaixo de 50 reais mostra aviso e permite publicar a escala`() {
        montar()
        rule.onNodeWithText(TextosEscala.NOME).performTextInput("Formatura")
        rule.onAllNodesWithText(TextosEscala.FUNCAO_SELECIONAR)[0].performScrollTo().performClick()
        rule.onNodeWithText("Garçom").performClick()
        rule.onAllNodesWithText(TextosPublicarVaga.VALOR)[0].performScrollTo().performTextInput("49,99")
        rule.onAllNodesWithText(TextosPublicarVaga.RESPONSAVEL)[0].performScrollTo().performTextInput("Lia")

        rule.onNodeWithText(TextosPublicarVaga.VALOR_MUITO_BAIXO).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosPublicarVaga.VALOR_MUITO_ALTO).assertDoesNotExist()
        rule.onNodeWithText(TextosEscala.PUBLICAR).assertIsEnabled().performClick()

        assertEquals(4999L, enviados.single().vagas.single().valorCentavos)
    }

    @Test
    fun `valor acima de 2000 reais mostra aviso e permite publicar a escala`() {
        montar()
        rule.onNodeWithText(TextosEscala.NOME).performTextInput("Formatura")
        rule.onAllNodesWithText(TextosEscala.FUNCAO_SELECIONAR)[0].performScrollTo().performClick()
        rule.onNodeWithText("Garçom").performClick()
        rule.onAllNodesWithText(TextosPublicarVaga.VALOR)[0].performScrollTo().performTextInput("2000,01")
        rule.onAllNodesWithText(TextosPublicarVaga.RESPONSAVEL)[0].performScrollTo().performTextInput("Lia")

        rule.onNodeWithText(TextosPublicarVaga.VALOR_MUITO_ALTO).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosPublicarVaga.VALOR_MUITO_BAIXO).assertDoesNotExist()
        rule.onNodeWithText(TextosEscala.PUBLICAR).assertIsEnabled().performClick()

        assertEquals(200001L, enviados.single().vagas.single().valorCentavos)
    }

    @Test
    fun `valor dentro da faixa ou zero nao mostra aviso na escala`() {
        val vm = montar()
        for (valor in listOf("", "0", "50", "2000")) {
            vm.editarValor(0, valor)
            rule.waitForIdle()
            rule.onNodeWithText(TextosPublicarVaga.VALOR_MUITO_BAIXO).assertDoesNotExist()
            rule.onNodeWithText(TextosPublicarVaga.VALOR_MUITO_ALTO).assertDoesNotExist()
        }
    }

    @Test
    fun `aviso de valor junto com erro de outro campo nao tem semantica de erro e mantem publicar habilitado`() {
        montar()
        rule.onAllNodesWithText(TextosPublicarVaga.VALOR)[0].performScrollTo().performTextInput("49,99")
        rule.onNodeWithText(TextosEscala.PUBLICAR).assertIsEnabled().performClick()

        rule.onNodeWithText(TextosPublicarVaga.VALOR_MUITO_BAIXO).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosEscala.NOME_CAMPO).performScrollTo().assertIsDisplayed()
        rule.onAllNodes(hasText(TextosPublicarVaga.VALOR) and hasSetTextAction())[0]
            .assert(SemanticsMatcher.keyNotDefined(SemanticsProperties.Error))
        rule.onNode(hasText(TextosEscala.NOME) and hasSetTextAction())
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Error))
        rule.onNodeWithText(TextosEscala.PUBLICAR).assertIsEnabled()
    }
}
