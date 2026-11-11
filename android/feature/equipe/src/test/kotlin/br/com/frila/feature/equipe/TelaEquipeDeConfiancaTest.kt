package br.com.frila.feature.equipe

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaEquipeDeConfiancaTest {

    @get:Rule
    val rule = createComposeRule()

    private val ana = PerfilPublicoDto(
        id = "a1",
        tipo = "profissional",
        nome = "Ana Souza",
        funcoes = listOf("garçom", "barman"),
        reputacao = ReputacaoDto(positivas = 7, total = 8, turnosConsiderados = 8, turnosRealizados = 8),
    )
    private val beto = PerfilPublicoDto(
        id = "b1",
        tipo = "profissional",
        nome = "Beto Lima",
        funcoes = null,
        reputacao = ReputacaoDto(positivas = 0, total = 0, turnosConsiderados = 0, turnosRealizados = 0),
    )

    private class Chamadas {
        var novamente = 0
        val removidos = mutableListOf<String>()
        var voltou = 0
    }

    private fun montar(tela: EstadoTelaEquipe, chamadas: Chamadas = Chamadas()): Chamadas {
        rule.setContent {
            FrilaTheme {
                ConteudoEquipeDeConfianca(
                    tela = tela,
                    aoTentarNovamente = { chamadas.novamente++ },
                    aoRemover = { chamadas.removidos += it.id },
                    aoVoltar = { chamadas.voltou++ },
                )
            }
        }
        return chamadas
    }

    private fun comMembros(vararg membros: PerfilPublicoDto, ajuste: EstadoTelaEquipe.() -> EstadoTelaEquipe = { this }) =
        EstadoTelaEquipe(estado = EstadoEquipe.Conteudo(membros.toList())).ajuste()

    @Test
    fun cabecalhoTemTituloComoHeadingExplicacaoEVoltarComAlvoMinimo() {
        val c = montar(comMembros(ana))

        rule.onNodeWithText(TextosEquipe.TITULO).assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        rule.onNodeWithText(TextosEquipe.EXPLICACAO).assertIsDisplayed()
        rule.onNodeWithContentDescription(TextosEquipe.ROTULO_VOLTAR)
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()

        assertEquals(1, c.voltou)
    }

    @Test
    fun listaMostraNomeFuncoesEReputacaoDeCadaProfissional() {
        montar(comMembros(ana, beto))

        rule.onNodeWithText("Ana Souza").assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        rule.onNodeWithText("garçom, barman").assertIsDisplayed()
        rule.onNodeWithText("7 de 8 avaliações positivas").assertIsDisplayed()
        rule.onNodeWithText("Beto Lima").assertIsDisplayed()
        rule.onNodeWithText(TextosEquipe.SEM_AVALIACOES).assertIsDisplayed()
    }

    @Test
    fun cadaLinhaTemSeuBotaoRemoverComRotuloDoNomeEAlvoMinimo() {
        montar(comMembros(ana, beto))

        rule.onNodeWithContentDescription(TextosEquipe.rotuloRemover("Ana Souza"))
            .assertIsEnabled().assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
        rule.onNodeWithContentDescription(TextosEquipe.rotuloRemover("Beto Lima")).assertIsEnabled()
    }

    @Test
    fun removerPedeConfirmacaoComOEfeitoEscritoENaoRemoveAntes() {
        val c = montar(comMembros(ana))

        rule.onNodeWithContentDescription(TextosEquipe.rotuloRemover("Ana Souza")).performClick()

        rule.onNodeWithText(TextosEquipe.CONFIRMAR_REMOCAO).assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        rule.onNodeWithText(TextosEquipe.efeitoRemocao("Ana Souza")).assertIsDisplayed()
        assertEquals("abrir o diálogo não remove", emptyList<String>(), c.removidos)
    }

    @Test
    fun cancelarNoDialogoNaoRemoveEFechaODialogo() {
        val c = montar(comMembros(ana))

        rule.onNodeWithContentDescription(TextosEquipe.rotuloRemover("Ana Souza")).performClick()
        rule.onNodeWithText(TextosEquipe.CANCELAR).performClick()

        rule.onNodeWithText(TextosEquipe.CONFIRMAR_REMOCAO).assertDoesNotExist()
        assertEquals(emptyList<String>(), c.removidos)
    }

    @Test
    fun confirmarRemoveSoOProfissionalEscolhido() {
        val c = montar(comMembros(ana, beto))

        rule.onNodeWithContentDescription(TextosEquipe.rotuloRemover("Beto Lima")).performClick()
        rule.onNodeWithText(TextosEquipe.CONFIRMAR_REMOVER).performClick()

        assertEquals(listOf("b1"), c.removidos)
        rule.onNodeWithText(TextosEquipe.CONFIRMAR_REMOCAO).assertDoesNotExist()
    }

    @Test
    fun removendoDesabilitaTodosOsBotoesEMostraProgressoNaLinha() {
        montar(comMembros(ana, beto) { copy(removendo = "a1") })

        rule.onNodeWithContentDescription(TextosEquipe.rotuloRemover("Ana Souza")).assertIsNotEnabled()
        rule.onNodeWithContentDescription(TextosEquipe.rotuloRemover("Beto Lima")).assertIsNotEnabled()
        rule.onNodeWithText(TextosEquipe.REMOVENDO).assertIsDisplayed()
    }

    @Test
    fun avisoDeRemocaoEErroDeAcaoAparecemComAListaIntacta() {
        montar(comMembros(ana) { copy(aviso = TextosEquipe.REMOVIDO, mensagemErro = TextosEquipe.SO_ADMINISTRADOR) })

        rule.onNodeWithText(TextosEquipe.REMOVIDO).assertIsDisplayed()
        rule.onNodeWithText(TextosEquipe.SO_ADMINISTRADOR).assertIsDisplayed()
        rule.onNodeWithText("Ana Souza").assertIsDisplayed()
    }

    @Test
    fun carregandoMostraProgressoEMantemAExplicacao() {
        montar(EstadoTelaEquipe(estado = EstadoEquipe.Carregando))

        rule.onNodeWithText(TextosEquipe.CARREGANDO).assertIsDisplayed()
        rule.onNodeWithText(TextosEquipe.EXPLICACAO).assertIsDisplayed()
    }

    @Test
    fun vazioExplicaComoIncluirEOfereceNenhumaRemocao() {
        montar(EstadoTelaEquipe(estado = EstadoEquipe.Vazio))

        rule.onNodeWithText(TextosEquipe.VAZIO_TITULO).assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        rule.onNodeWithText(TextosEquipe.VAZIO_MENSAGEM).assertIsDisplayed()
        rule.onNodeWithText(TextosEquipe.REMOVER).assertDoesNotExist()
    }

    @Test
    fun semRedeMostraMensagemETentarNovamenteChamaORetry() {
        val c = montar(EstadoTelaEquipe(estado = EstadoEquipe.SemRede))

        rule.onNodeWithText(TextosEquipe.SEM_REDE).assertIsDisplayed()
        rule.onNodeWithText(TextosEquipe.TENTAR_NOVAMENTE)
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()

        assertEquals(1, c.novamente)
    }

    @Test
    fun erroMostraAMensagemMapeadaETentarNovamenteChamaORetry() {
        val c = montar(EstadoTelaEquipe(estado = EstadoEquipe.Erro(TextosEquipe.CONTA_SUSPENSA)))

        rule.onNodeWithText(TextosEquipe.CONTA_SUSPENSA).assertIsDisplayed()
        rule.onNodeWithText(TextosEquipe.TENTAR_NOVAMENTE).performClick()

        assertEquals(1, c.novamente)
    }
}
