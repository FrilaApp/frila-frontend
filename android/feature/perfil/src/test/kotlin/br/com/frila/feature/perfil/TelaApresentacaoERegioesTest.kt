package br.com.frila.feature.perfil

import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.RegiaoAdministrativaDto
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** L1-2a: apresentação e regiões do profissional. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h2400dp")
class TelaApresentacaoERegioesTest {

    @get:Rule
    val rule = createComposeRule()

    private val regioes = listOf(
        RegiaoAdministrativaDto(1, "I", "Plano Piloto", true),
        RegiaoAdministrativaDto(3, "III", "Taguatinga", true),
    )

    private val estadoBase = EstadoApresentacaoERegioes(
        sobreMim = "Garçom há 8 anos",
        ondeTrabalhei = "Buffet de casamento",
        experienciaFaixa = "de_5_a_10_anos",
        cursos = listOf("Coquetelaria", "Barista"),
        idiomas = setOf("ingles"),
        regioesSelecionadas = setOf(3),
        regioesDisponiveis = regioes,
    )

    private class Toques {
        val sobreMim = mutableListOf<String>()
        val experiencia = mutableListOf<String?>()
        val cursosRemovidos = mutableListOf<Int>()
        val idiomas = mutableListOf<String>()
        val regioes = mutableListOf<Int>()
        val todoDf = mutableListOf<Boolean>()
        var adicionou = 0
        var salvou = 0
        var voltou = 0
    }

    private fun montar(estado: EstadoApresentacaoERegioes = estadoBase, toques: Toques = Toques()): Toques {
        rule.setContent {
            FrilaTheme {
                ConteudoApresentacaoERegioes(
                    estado = estado,
                    acoes = AcoesApresentacaoERegioes(
                        aoMudarSobreMim = { toques.sobreMim += it },
                        aoEscolherExperiencia = { toques.experiencia += it },
                        aoAdicionarCurso = { toques.adicionou++ },
                        aoRemoverCurso = { toques.cursosRemovidos += it },
                        aoAlternarIdioma = { toques.idiomas += it },
                        aoAlternarTodoDf = { toques.todoDf += it },
                        aoAlternarRegiao = { toques.regioes += it },
                        aoSalvar = { toques.salvou++ },
                        aoVoltar = { toques.voltou++ },
                    ),
                )
            }
        }
        return toques
    }

    private fun contar(texto: String) = rule.onAllNodesWithText(texto).fetchSemanticsNodes().size

    @Test
    fun `mostra o titulo e o rascunho nos campos`() {
        montar()

        rule.onNodeWithText(TextosApresentacaoERegioes.TITULO).assertIsDisplayed()
        rule.onNodeWithText("Garçom há 8 anos").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("Buffet de casamento").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("Coquetelaria").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("Barista").performScrollTo().assertIsDisplayed()
    }

    @Test
    fun `digitar em sobre mim avisa a mudanca`() {
        val toques = montar()

        rule.onNodeWithTag("campo-sobre-mim").performScrollTo().performTextInput("!")

        // O cursor de um campo com valor inicial começa no início: o que importa é que o texto antigo fica e o novo entra.
        assertEquals(1, toques.sobreMim.size)
        assertEquals("Garçom há 8 anos".length + 1, toques.sobreMim.single().length)
        assertTrue(toques.sobreMim.single().contains("!"))
    }

    @Test
    fun `escolher a experiencia e nao informado avisam a faixa`() {
        val toques = montar()

        rule.onNodeWithText("Mais de 10 anos").performScrollTo().performClick()
        rule.onNodeWithText(TextosApresentacaoERegioes.NAO_INFORMADO).performScrollTo().performClick()

        assertEquals(listOf("mais_de_10_anos", null), toques.experiencia)
    }

    @Test
    fun `idiomas e regioes sao marcaveis pelo nome`() {
        val toques = montar()

        rule.onNodeWithText("Libras").performScrollTo().performClick()
        rule.onNodeWithText("Plano Piloto", substring = true).performScrollTo().performClick()

        assertEquals(listOf("libras"), toques.idiomas)
        assertEquals(listOf(1), toques.regioes)
    }

    @Test
    fun `atender em todo o DF avisa o novo valor`() {
        val toques = montar()

        rule.onNodeWithText(TextosApresentacaoERegioes.TODO_O_DF).performScrollTo().performClick()

        assertEquals(listOf(true), toques.todoDf)
    }

    @Test
    fun `remover curso leva a posicao e tem alvo minimo`() {
        val toques = montar()

        rule.onNodeWithContentDescription("${TextosApresentacaoERegioes.REMOVER_CURSO}: Barista").performScrollTo()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()

        assertEquals(listOf(1), toques.cursosRemovidos)
    }

    @Test
    fun `adicionar curso e voltar chamam os callbacks`() {
        val toques = montar(estadoBase.copy(novoCurso = "Sommelier"))

        rule.onNodeWithText(TextosApresentacaoERegioes.ADICIONAR_CURSO).performScrollTo().performClick()
        rule.onNodeWithContentDescription(TextosApresentacaoERegioes.VOLTAR).performClick()

        assertEquals(1, toques.adicionou)
        assertEquals(1, toques.voltou)
    }

    @Test
    fun `salvar tem alvo minimo, chama o callback e desliga enquanto salva`() {
        val toques = montar()

        // O Salvar fica no rodapé ancorado, fora da rolagem.
        rule.onNodeWithText(TextosApresentacaoERegioes.SALVAR)
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).assertIsEnabled().performClick()

        assertEquals(1, toques.salvou)
    }

    @Test
    fun `salvando mostra o texto e o botao fica desligado`() {
        montar(estadoBase.copy(salvando = true))

        rule.onNodeWithText(TextosApresentacaoERegioes.SALVANDO).assertIsNotEnabled()
    }

    @Test
    fun `os erros e o sucesso aparecem em texto`() {
        montar(
            estadoBase.copy(
                erroSobreMim = TextosApresentacaoERegioes.ERRO_ANTI_CONTATO,
                erroOndeTrabalhei = TextosApresentacaoERegioes.LIMITE_ONDE_TRABALHEI,
                erroCursos = TextosApresentacaoERegioes.LIMITE_CURSOS,
                erroRegioes = TextosApresentacaoERegioes.ERRO_REGIOES,
                erroGeral = TextosApresentacaoERegioes.ERRO_SEM_REDE,
                sucesso = true,
            ),
        )

        for (texto in listOf(
            TextosApresentacaoERegioes.ERRO_ANTI_CONTATO, TextosApresentacaoERegioes.LIMITE_ONDE_TRABALHEI,
            TextosApresentacaoERegioes.LIMITE_CURSOS, TextosApresentacaoERegioes.ERRO_REGIOES,
        )) {
            rule.onNodeWithText(texto).performScrollTo().assertIsDisplayed()
        }
        // O resultado do salvar fica junto ao botão, no rodapé ancorado, fora da rolagem.
        rule.onNodeWithText(TextosApresentacaoERegioes.ERRO_SEM_REDE).assertIsDisplayed()
        rule.onNodeWithText(TextosApresentacaoERegioes.SUCESSO).assertIsDisplayed()
    }

    @Test
    fun `sem erro nem sucesso nao ha mensagem`() {
        montar()

        assertEquals(0, contar(TextosApresentacaoERegioes.SUCESSO))
        assertEquals(0, contar(TextosApresentacaoERegioes.ERRO_SEM_REDE))
    }

    @Test
    fun `carregando mostra o aviso`() {
        montar(EstadoApresentacaoERegioes(carregando = true))

        rule.onNodeWithText(TextosApresentacaoERegioes.CARREGANDO).assertIsDisplayed()
    }
}
