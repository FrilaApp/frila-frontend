package br.com.frila.feature.turnos.contratante

import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
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

/**
 * 0P4RwnNi: com as ações de segurança que o app traz (Denunciar e Bloquear, `AcoesDeSeguranca`), a tela as põe no fim, no lugar do
 * "Denunciar" avulso, e não repete o "Você bloqueou este profissional": quem desenha o rótulo é a ação de segurança.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h1600dp")
class TurnoDoContratanteAcoesDeSegurancaTest {

    @get:Rule
    val rule = createComposeRule()

    private val ana = PerfilPublicoDto(
        id = "pr1", tipo = "profissional", nome = "Ana",
        reputacao = ReputacaoDto(positivas = 1, total = 1, turnosConsiderados = 1, turnosRealizados = 1),
    )

    private val recebidos = mutableListOf<String>()

    private fun montar(profissional: PerfilPublicoDto?, bloqueado: Boolean = false) {
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
                    acoes = AcoesTurnoDoContratante(aoDenunciarProfissional = { _, _ -> }, aoPedirSuporte = {}),
                    profissionalBloqueado = bloqueado,
                    acoesDeSeguranca = { perfil ->
                        recebidos += perfil.id
                        Text("seguranca de ${perfil.nome}", modifier = Modifier.testTag("slot-seguranca"))
                    },
                )
            }
        }
    }

    private fun contar(texto: String) = rule.onAllNodesWithText(texto).fetchSemanticsNodes().size

    @Test
    fun `com as acoes de seguranca, a tela as desenha com o profissional do turno no lugar do Denunciar avulso`() {
        montar(ana)

        rule.onNodeWithTag("slot-seguranca").performScrollTo().assertIsDisplayed()
        assertEquals(listOf("pr1"), recebidos.distinct())
        assertEquals(0, contar(TextosTurnoDoContratante.DENUNCIAR))
    }

    @Test
    fun `bloqueado, a tela nao repete o rotulo que a acao de seguranca ja desenha`() {
        montar(ana, bloqueado = true)

        rule.onNodeWithTag("slot-seguranca").performScrollTo().assertIsDisplayed()
        assertEquals(0, contar(TextosTurnoDoContratante.VOCE_BLOQUEOU_PROFISSIONAL))
    }

    @Test
    fun `sem profissional no turno, nao ha acao de seguranca`() {
        montar(null)

        assertEquals(0, rule.onAllNodesWithTag("slot-seguranca").fetchSemanticsNodes().size)
        assertEquals(emptyList<String>(), recebidos)
    }
}
