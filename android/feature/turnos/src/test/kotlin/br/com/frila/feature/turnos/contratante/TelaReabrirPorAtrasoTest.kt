package br.com.frila.feature.turnos.contratante

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.hasAnyAncestor
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.isDialog
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaReabrirPorAtrasoTest {

    @get:Rule
    val rule = createComposeRule()

    private val ana = PerfilPublicoDto("p1", "profissional", "Ana", listOf("garçom"), ReputacaoDto(1, 1, null, 1, 1))

    private fun estado(
        disponivel: Boolean = true,
        emAtraso: Boolean = true,
        pedindo: Boolean = false,
        reabrindo: Boolean = false,
        aviso: AvisoDaReabertura? = null,
    ) = EstadoTurnoDoContratante(
        contexto = ContextoDoTurnoContratante(
            turnoId = "t1", funcao = "Garçom", local = "SQN 108", inicio = Instant.parse("2026-11-12T21:00:00Z"),
            fim = Instant.parse("2026-11-13T03:00:00Z"), profissional = ana, aCaminhoEm = null, checkinEm = null,
            checkinTipo = null, verificacao = null, emAtraso = emAtraso, posicaoId = "pos1", estadoDaPosicao = "confirmada",
        ),
        reaberturaDisponivel = disponivel,
        pedindoReabertura = pedindo,
        reabrindo = reabrindo,
        avisoDaReabertura = aviso,
    )

    private class Chamadas {
        var pediu = 0
        var confirmou = 0
        var desistiu = 0
    }

    private fun montar(estado: EstadoTurnoDoContratante, chamadas: Chamadas = Chamadas()): Chamadas {
        rule.setContent {
            FrilaTheme {
                ConteudoTurnoDoContratante(
                    estado = estado,
                    acoes = AcoesTurnoDoContratante(
                        aoPedirReabertura = { chamadas.pediu++ },
                        aoConfirmarReabertura = { chamadas.confirmou++ },
                        aoDesistirDaReabertura = { chamadas.desistiu++ },
                    ),
                )
            }
        }
        return chamadas
    }

    @Test
    fun `em atraso com a reabertura ligada mostra Reabrir vaga, com alvo minimo, e o toque pede a confirmacao`() {
        val c = montar(estado())

        rule.onNodeWithText(TextosTurnoDoContratante.REABRIR_VAGA).performScrollTo().assertIsDisplayed()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()

        assertEquals(1, c.pediu)
        assertEquals(0, c.confirmou)
    }

    @Test
    fun `sem a reabertura ligada, ou antes do atraso, o botao nao aparece`() {
        montar(estado(disponivel = false))
        rule.onAllNodesWithText(TextosTurnoDoContratante.REABRIR_VAGA).assertCountEquals(0)
    }

    @Test
    fun `antes dos 15 minutos o botao nao aparece`() {
        montar(estado(emAtraso = false))
        rule.onAllNodesWithText(TextosTurnoDoContratante.REABRIR_VAGA).assertCountEquals(0)
    }

    @Test
    fun `a pergunta avisa da falta e so reabre ao confirmar`() {
        val c = montar(estado(pedindo = true))

        rule.onNodeWithText(TextosTurnoDoContratante.REABRIR_PERGUNTA).assertIsDisplayed()
        rule.onNodeWithText(TextosTurnoDoContratante.REABRIR_AVISO.format("Ana")).assertIsDisplayed()
        assertEquals(0, c.confirmou)

        rule.onNode(hasText(TextosTurnoDoContratante.REABRIR_CONFIRMAR) and hasAnyAncestor(isDialog())).performClick()

        assertEquals(1, c.confirmou)
    }

    @Test
    fun `esperar fecha a pergunta sem reabrir`() {
        val c = montar(estado(pedindo = true))

        rule.onNodeWithText(TextosTurnoDoContratante.ESPERAR).performClick()

        assertEquals(1, c.desistiu)
        assertEquals(0, c.confirmou)
    }

    @Test
    fun `reabrindo desliga o botao e mostra o andamento`() {
        montar(estado(reabrindo = true))

        rule.onNodeWithText(TextosTurnoDoContratante.REABRINDO).performScrollTo().assertIsDisplayed().assertIsNotEnabled()
    }

    @Test
    fun `o desfecho aparece em texto do Frila`() {
        montar(estado(emAtraso = false, aviso = AvisoDaReabertura.ANTES_DA_TOLERANCIA))

        rule.onNodeWithText(TextosTurnoDoContratante.ERRO_ANTES_DA_TOLERANCIA).performScrollTo().assertIsDisplayed()
    }
}
