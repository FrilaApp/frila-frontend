package br.com.frila.feature.vagas.painel

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertIsSelected
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

/** A tela provisória de cancelar a vaga e a entrada dela em Minhas vagas: o que aparece, o que toca e o alvo de 48 dp. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h1600dp")
class TelaCancelarVagaTest {

    @get:Rule
    val rule = createComposeRule()

    private fun contar(texto: String) = rule.onAllNodesWithText(texto).fetchSemanticsNodes().size

    private fun item(podeCancelar: Boolean) = ItemMinhaVaga(
        id = "v1", funcao = "Garçom", local = "SQN 108", inicio = Instant.parse("2026-11-12T21:00:00Z"),
        fim = Instant.parse("2026-11-13T03:00:00Z"), valorCentavos = 16_000, selecao = false, oculta = false, alertaVagaVazia = false,
        candidatosPendentes = 0, totalPosicoes = 3, confirmadas = 1, posicoesAbertas = 2, emAtraso = 0, secao = SecaoMinhasVagas.PROXIMAS,
        recemPublicada = false, podeVerCandidatos = false, comecaEm = null, podeCancelar = podeCancelar,
    )

    private fun minhasVagas(item: ItemMinhaVaga, acoes: AcoesMinhasVagas) = rule.setContent {
        FrilaTheme {
            ConteudoMinhasVagas(EstadoMinhasVagas(ListaMinhasVagas.Sucesso(listOf(item))), nomeEstabelecimento = null, acoes = acoes)
        }
    }

    @Test
    fun `Minhas vagas oferece Cancelar vaga na vaga que permite e entrega a vaga tocada`() {
        val tocadas = mutableListOf<String>()
        minhasVagas(item(podeCancelar = true), AcoesMinhasVagas(aoCancelarVaga = { tocadas += it.id }))

        rule.onNodeWithContentDescription("Cancelar a vaga de Garçom").assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()

        assertEquals(listOf("v1"), tocadas)
    }

    @Test
    fun `Minhas vagas nao mostra Cancelar vaga sem quem atenda`() {
        minhasVagas(item(podeCancelar = true), AcoesMinhasVagas())

        assertEquals(0, contar(TextosCancelarVaga.TITULO))
    }

    @Test
    fun `Minhas vagas nao mostra Cancelar vaga na vaga que nao pode ser cancelada`() {
        minhasVagas(item(podeCancelar = false), AcoesMinhasVagas(aoCancelarVaga = {}))

        assertEquals(0, contar(TextosCancelarVaga.TITULO))
    }

    private fun cancelar(
        estado: EstadoCancelarVaga,
        aoEscolher: (MotivoDeCancelamentoDaVaga) -> Unit = {},
        aoConfirmar: () -> Unit = {},
        aoFechar: () -> Unit = {},
    ) = rule.setContent {
        FrilaTheme { ConteudoCancelarVaga(estado, MotivoDeCancelamentoDaVaga.entries, aoEscolher, {}, aoConfirmar, aoFechar) }
    }

    @Test
    fun `sem motivo o Confirmar fica desligado, o aviso vem antes dos motivos e cada motivo tem alvo de 48 dp`() {
        var escolhido: MotivoDeCancelamentoDaVaga? = null
        cancelar(EstadoCancelarVaga(aviso = "Faltam 5 h para o início."), aoEscolher = { escolhido = it })

        rule.onNodeWithText(TextosCancelarVaga.TITULO).assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        rule.onNodeWithText(TextosCancelarVaga.CONFIRMAR).assertIsNotEnabled()
        val aviso = rule.onNodeWithText("Faltam 5 h para o início.").assertIsDisplayed()
        val motivo = rule.onNodeWithText(TextosCancelarVaga.MOTIVO_MOVIMENTO_MENOR)
        assertTrue(aviso.getUnclippedBoundsInRoot().top < motivo.getUnclippedBoundsInRoot().top)
        motivo.assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()

        assertEquals(MotivoDeCancelamentoDaVaga.MOVIMENTO_MENOR, escolhido)
        AuditoriaSemanticaAcessibilidade.assertSemanticaValida(rule.onRoot().fetchSemanticsNode())
    }

    @Test
    fun `com motivo o Confirmar liga, o motivo fica marcado e a recusa aparece em texto`() {
        var confirmou = 0
        cancelar(
            EstadoCancelarVaga(aviso = "x", motivo = MotivoDeCancelamentoDaVaga.OUTRO, detalhes = "Obra", erro = TextosCancelarVaga.VAGA_JA_FECHADA),
            aoConfirmar = { confirmou++ },
        )

        rule.onNodeWithText(TextosCancelarVaga.MOTIVO_OUTRO).assertIsSelected()
        rule.onNodeWithText(TextosCancelarVaga.DETALHES_OBRIGATORIOS).assertIsDisplayed()
        rule.onNodeWithText(TextosCancelarVaga.VAGA_JA_FECHADA).assertIsDisplayed()
        rule.onNodeWithText(TextosCancelarVaga.CONFIRMAR).assertIsEnabled().assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()

        assertEquals(1, confirmou)
    }

    @Test
    fun `enquanto envia, o Confirmar e o Voltar ficam desligados e a tela diz que esta enviando`() {
        cancelar(EstadoCancelarVaga(aviso = "x", motivo = MotivoDeCancelamentoDaVaga.PROBLEMA_NO_LOCAL, enviando = true))

        rule.onNodeWithText(TextosCancelarVaga.ENVIANDO).assertIsDisplayed()
        rule.onNodeWithText(TextosCancelarVaga.CONFIRMAR).assertIsNotEnabled()
        rule.onNodeWithText(TextosCancelarVaga.VOLTAR).assertIsNotEnabled()
    }

    @Test
    fun `cancelada mostra o desfecho e so o Fechar`() {
        var fechou = 0
        cancelar(EstadoCancelarVaga(aviso = "x", concluida = true), aoFechar = { fechou++ })

        rule.onNodeWithText(TextosCancelarVaga.CANCELADA).assertIsDisplayed()
        assertEquals(0, contar(TextosCancelarVaga.CONFIRMAR))
        rule.onNodeWithText(TextosCancelarVaga.FECHAR).performClick()

        assertEquals(1, fechou)
    }
}
