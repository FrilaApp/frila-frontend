package br.com.frila.feature.vagas.candidaturas

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import br.com.frila.core.designsystem.tema.FrilaTheme
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * ARHvBJEK: o texto que o profissional lê. O view model real recebe candidaturas e `meus_turnos` e a tela mostra o que ele
 * entrega: a aceita de turno cancelado diz "Turno cancelado", e a de turno de pé continua com a confirmação.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h1600dp")
class TelaCandidaturaTurnoCanceladoTest {

    @get:Rule
    val rule = createComposeRule()

    private fun contar(texto: String) = rule.onAllNodesWithText(texto).fetchSemanticsNodes().size

    private fun montar(estadosDosTurnos: Map<String, String?>) {
        val vm = MinhasCandidaturasViewModel(
            buscar = {
                listOf(
                    candidatura("c1", "aceita", turnoId = "t1").let { it.copy(vaga = it.vaga.copy(funcao = "Garçom")) },
                    candidatura("c2", "aceita", turnoId = "t2").let { it.copy(vaga = it.vaga.copy(funcao = "Barman")) },
                )
            },
            buscarEstadosDosTurnos = { estadosDosTurnos },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        vm.carregar()
        rule.setContent { FrilaTheme { ConteudoMinhasCandidaturas(vm.estado.value, AcoesMinhasCandidaturas()) } }
    }

    @Test
    fun `a aceita de turno cancelado mostra Turno cancelado e nao a confirmacao, e a de turno de pe mostra a confirmacao`() {
        montar(mapOf("t1" to "cancelada", "t2" to "confirmada"))

        rule.onNodeWithText("Garçom").assertIsDisplayed()
        rule.onNodeWithText("Barman").assertIsDisplayed()
        assertEquals(1, contar("Turno cancelado"))
        assertEquals(1, contar(TextosCandidaturas.ESTADO_ACEITA))
    }

    @Test
    fun `sem turno cancelado, nenhuma candidatura diz Turno cancelado`() {
        montar(mapOf("t1" to "confirmada", "t2" to null))

        assertEquals(0, contar("Turno cancelado"))
        assertEquals(2, contar(TextosCandidaturas.ESTADO_ACEITA))
    }
}
