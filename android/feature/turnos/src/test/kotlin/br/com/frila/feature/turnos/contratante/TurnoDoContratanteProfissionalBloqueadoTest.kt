package br.com.frila.feature.turnos.contratante

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performScrollTo
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

/** I1PonzKJ, fatia 2: o turno do contratante diz que a casa bloqueou o profissional, como o iOS ("Você bloqueou este profissional"). */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h1600dp")
class TurnoDoContratanteProfissionalBloqueadoTest {

    @get:Rule
    val rule = createComposeRule()

    private val ana = PerfilPublicoDto(
        id = "pr1", tipo = "profissional", nome = "Ana",
        reputacao = ReputacaoDto(positivas = 1, total = 1, turnosConsiderados = 1, turnosRealizados = 1),
    )

    private fun montar(profissional: PerfilPublicoDto?, bloqueado: Boolean, comDenunciar: Boolean = true) {
        val estado = EstadoTurnoDoContratante(
            contexto = ContextoDoTurnoContratante(
                turnoId = "t1", funcao = "Garçom", local = "SQN 108", inicio = Instant.parse("2026-11-12T21:00:00Z"),
                fim = Instant.parse("2026-11-13T03:00:00Z"), profissional = profissional, aCaminhoEm = null, checkinEm = null,
                checkinTipo = null, verificacao = "verificado", emAtraso = false,
            ),
        )
        rule.setContent {
            FrilaTheme {
                ConteudoTurnoDoContratante(
                    estado = estado,
                    acoes = AcoesTurnoDoContratante(aoDenunciarProfissional = if (comDenunciar) ({ _, _ -> }) else null),
                    profissionalBloqueado = bloqueado,
                )
            }
        }
    }

    @Test
    fun `com o profissional bloqueado na sessao, a tela diz que a casa o bloqueou`() {
        montar(ana, bloqueado = true)

        rule.onNodeWithText(TextosTurnoDoContratante.VOCE_BLOQUEOU_PROFISSIONAL).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun `sem bloqueio, a tela nao diz isso`() {
        montar(ana, bloqueado = false)

        assertEquals(0, rule.onAllNodesWithText(TextosTurnoDoContratante.VOCE_BLOQUEOU_PROFISSIONAL).fetchSemanticsNodes().size)
    }

    @Test
    fun `o aviso aparece mesmo quando a tela nao oferece denunciar`() {
        montar(ana, bloqueado = true, comDenunciar = false)

        rule.onNodeWithText(TextosTurnoDoContratante.VOCE_BLOQUEOU_PROFISSIONAL).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun `sem profissional no turno nao ha o que dizer`() {
        montar(null, bloqueado = true)

        assertEquals(0, rule.onAllNodesWithText(TextosTurnoDoContratante.VOCE_BLOQUEOU_PROFISSIONAL).fetchSemanticsNodes().size)
    }
}
