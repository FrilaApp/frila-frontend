package br.com.frila.feature.vagas.candidaturas

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.componentes.AuditoriaSemanticaAcessibilidade
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** As telas provisórias das candidaturas: a lista em seções e a confirmação de retirar. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h1600dp")
class TelasCandidaturasTest {

    @get:Rule
    val rule = createComposeRule()

    private fun contar(texto: String) = rule.onAllNodesWithText(texto).fetchSemanticsNodes().size

    private fun item(id: String, funcao: String, pendente: Boolean, texto: String, destino: DestinoDaCandidatura) = ItemCandidatura(
        id = id, vagaId = "vaga-$id", funcao = funcao, local = "CLS 405 Bloco C", inicio = Instant.parse("2026-12-01T21:00:00Z"),
        fim = Instant.parse("2026-12-02T00:00:00Z"), valorCentavos = 16_000, pendente = pendente, textoDoEstado = texto, destino = destino,
    )

    private val pendente = item("c1", "Garçom", true, TextosCandidaturas.ESTADO_PENDENTE, DestinoDaCandidatura.Vaga("vaga-c1"))
    private val aceita = item("c2", "Barman", false, TextosCandidaturas.ESTADO_ACEITA, DestinoDaCandidatura.Turno("t2"))

    private fun lista(estado: EstadoMinhasCandidaturas, acoes: AcoesMinhasCandidaturas = AcoesMinhasCandidaturas()) = rule.setContent {
        FrilaTheme { ConteudoMinhasCandidaturas(estado, acoes) }
    }

    private fun carregadas(vararg itens: ItemCandidatura) =
        EstadoMinhasCandidaturas(ListaDeCandidaturas.Carregadas(itens.filter { it.pendente }, itens.filterNot { it.pendente }))

    @Test
    fun `a lista mostra as que aguardam resposta antes das anteriores, cada secao em cabecalho, e cada cartao com o essencial`() {
        lista(carregadas(pendente, aceita))

        rule.onNodeWithText(TextosCandidaturas.TITULO).assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        val aguardando = rule.onNodeWithText(TextosCandidaturas.AGUARDANDO).assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        val anteriores = rule.onNodeWithText(TextosCandidaturas.ANTERIORES).assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        assertTrue(aguardando.getUnclippedBoundsInRoot().top < anteriores.getUnclippedBoundsInRoot().top)
        rule.onNodeWithText("Garçom").assertIsDisplayed()
        rule.onNodeWithText(TextosCandidaturas.ESTADO_PENDENTE).assertIsDisplayed()
        rule.onNodeWithText(TextosCandidaturas.ESTADO_ACEITA).assertIsDisplayed()
        assertEquals(2, contar("01/12/2026, 18:00 – 21:00"))
        assertEquals(2, contar("R$\u00A0160,00 pelo turno"))
        AuditoriaSemanticaAcessibilidade.assertSemanticaValida(rule.onRoot().fetchSemanticsNode())
    }

    @Test
    fun `tocar na candidatura leva ao destino dela - a pendente a vaga, a aceita ao turno`() {
        val abertos = mutableListOf<DestinoDaCandidatura>()
        lista(carregadas(pendente, aceita), AcoesMinhasCandidaturas(aoAbrir = { abertos += it }))

        rule.onNodeWithText("Garçom").assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()
        rule.onNodeWithText("Barman").performClick()

        assertEquals(listOf(DestinoDaCandidatura.Vaga("vaga-c1"), DestinoDaCandidatura.Turno("t2")), abertos)
    }

    @Test
    fun `so a pendente oferece Retirar candidatura, com alvo de 48 dp, e so quando ha quem atenda`() {
        val retiradas = mutableListOf<String>()
        lista(carregadas(pendente, aceita), AcoesMinhasCandidaturas(aoRetirar = { retiradas += it.id }))

        assertEquals(1, contar(TextosCandidaturas.RETIRAR))
        rule.onNodeWithContentDescription("Retirar a candidatura à vaga de Garçom").assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()

        assertEquals(listOf("c1"), retiradas)
    }

    @Test
    fun `sem quem atenda a retirada, a lista nao mostra botao morto`() {
        lista(carregadas(pendente))

        assertEquals(0, contar(TextosCandidaturas.RETIRAR))
    }

    @Test
    fun `lista vazia, erro com tentar de novo e aviso de desatualizada`() {
        var tentou = 0
        lista(
            EstadoMinhasCandidaturas(ListaDeCandidaturas.Erro(TextosCandidaturas.ERRO_SEM_REDE, podeTentarDeNovo = true), desatualizada = true),
            AcoesMinhasCandidaturas(aoCarregar = { tentou++ }),
        )

        rule.onNodeWithText(TextosCandidaturas.ERRO_TITULO).assertIsDisplayed()
        rule.onNodeWithText(TextosCandidaturas.ERRO_SEM_REDE).assertIsDisplayed()
        rule.onNodeWithText(TextosCandidaturas.DESATUALIZADA).assertIsDisplayed()
        rule.onNodeWithText(TextosCandidaturas.TENTAR_DE_NOVO).assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()

        assertEquals(1, tentou)
    }

    @Test
    fun `sem candidaturas a tela explica onde elas aparecem`() {
        lista(EstadoMinhasCandidaturas(ListaDeCandidaturas.Vazia))

        rule.onNodeWithText(TextosCandidaturas.VAZIO_TITULO).assertIsDisplayed()
        rule.onNodeWithText(TextosCandidaturas.VAZIO_MENSAGEM).assertIsDisplayed()
    }

    private fun dialogo(estado: EstadoRetirarCandidatura, aoConfirmar: () -> Unit = {}, aoFechar: () -> Unit = {}) = rule.setContent {
        FrilaTheme { DialogoRetirarCandidatura(estado, aoConfirmar, aoFechar) }
    }

    @Test
    fun `retirar pergunta antes de enviar e explica o efeito`() {
        var confirmou = 0
        dialogo(EstadoRetirarCandidatura(), aoConfirmar = { confirmou++ })

        rule.onNodeWithText(TextosCandidaturas.PERGUNTA_DA_RETIRADA).assertIsDisplayed()
        rule.onNodeWithText(TextosCandidaturas.AVISO_DA_RETIRADA).assertIsDisplayed()
        rule.onNodeWithText(TextosCandidaturas.CANCELAR).assertIsDisplayed()
        rule.onNodeWithText(TextosCandidaturas.CONFIRMAR_RETIRADA).assertIsEnabled().performClick()

        assertEquals(1, confirmou)
    }

    @Test
    fun `enquanto retira a tela diz que esta retirando e o botao fica desligado`() {
        dialogo(EstadoRetirarCandidatura(SituacaoDaRetirada.RETIRANDO))

        rule.onNodeWithText(TextosCandidaturas.RETIRANDO).assertIsDisplayed()
        rule.onNodeWithText(TextosCandidaturas.CONFIRMAR_RETIRADA).assertIsNotEnabled()
    }

    @Test
    fun `falha passageira aparece em texto e deixa retirar de novo`() {
        dialogo(EstadoRetirarCandidatura(SituacaoDaRetirada.PENDENTE, TextosCandidaturas.RETIRADA_SEM_CONEXAO))

        rule.onNodeWithText(TextosCandidaturas.RETIRADA_SEM_CONEXAO).assertIsDisplayed()
        rule.onNodeWithText(TextosCandidaturas.CONFIRMAR_RETIRADA).assertIsEnabled()
    }

    @Test
    fun `retirada ou ja respondida - a tela diz o desfecho e so resta Fechar`() {
        var fechou = 0
        dialogo(EstadoRetirarCandidatura(SituacaoDaRetirada.INDISPONIVEL, TextosCandidaturas.JA_ESCOLHIDA), aoFechar = { fechou++ })

        rule.onNodeWithText(TextosCandidaturas.JA_ESCOLHIDA).assertIsDisplayed()
        assertEquals(0, contar(TextosCandidaturas.CONFIRMAR_RETIRADA))
        assertEquals(0, contar(TextosCandidaturas.AVISO_DA_RETIRADA))
        rule.onNodeWithText(TextosCandidaturas.FECHAR).performClick()

        assertEquals(1, fechou)
    }

    @Test
    fun `candidatura retirada mostra o desfecho em titulo e texto`() {
        dialogo(EstadoRetirarCandidatura(SituacaoDaRetirada.RETIRADA))

        rule.onNodeWithText(TextosCandidaturas.RETIRADA_TITULO).assertIsDisplayed()
        rule.onNodeWithText(TextosCandidaturas.RETIRADA_MENSAGEM).assertIsDisplayed()
        assertEquals(0, contar(TextosCandidaturas.CONFIRMAR_RETIRADA))
    }
}
