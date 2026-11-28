package br.com.frila.feature.chamadas.profissional

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import br.com.frila.core.designsystem.tema.FrilaTheme
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.Instant

/**
 * A fiação da [TelaDetalheChamadaRecebida] ao [ChamadaRecebidaViewModel]: o `TelasDoProfissionalTest` prova o
 * [ConteudoDaChamadaRecebida] com callbacks soltos; este prova que aceitar e recusar na tela montada chegam ao servidor.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaDetalheChamadaRecebidaTest {

    @get:Rule
    val rule = createComposeRule()

    private fun montar(rede: RedeDeTeste): ChamadaRecebidaViewModel {
        val viewModel = ChamadaRecebidaViewModel(
            chamadaId = Fixtures.CHAMADA,
            detalhar = rede.servico::detalheChamada,
            responder = rede.servico::responderChamada,
            agora = { Instant.parse("2026-11-17T00:00:00Z") },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        rule.setContent {
            FrilaTheme {
                TelaDetalheChamadaRecebida(viewModel = viewModel, aoVoltar = {})
            }
        }
        rule.waitUntil(TIMEOUT_MS) { viewModel.estado.value.podeResponder }
        // Espera o botão na TELA, não só o estado do ViewModel: o clique vem depois da recomposição.
        rule.waitUntil(TIMEOUT_MS) { rule.onAllNodesWithTag("aceitar-chamada").fetchSemanticsNodes().isNotEmpty() }
        return viewModel
    }

    @Test
    fun aceitarNaTelaMontadaEnviaAceiteAoServidor() {
        val rede = RedeDeTeste().apply {
            ok("/rpc/detalhe_chamada", Fixtures.detalheChamadaJson())
            ok("/rpc/responder_chamada", Fixtures.resultadoJson("aceita"))
        }
        val viewModel = montar(rede)

        rule.onNodeWithTag("aceitar-chamada").performClick()
        rule.waitUntil(TIMEOUT_MS) { viewModel.estado.value.resultado != null }

        val corpo = rede.doCaminho("/rpc/responder_chamada").single().corpo!!
        assertEquals(Fixtures.CHAMADA, corpo["chamada_id"]!!.jsonPrimitive.content)
        assertEquals("aceitar", corpo["resposta"]!!.jsonPrimitive.content)
    }

    @Test
    fun recusarNaTelaMontadaEnviaOMotivoEscolhidoAoServidor() {
        val rede = RedeDeTeste().apply {
            ok("/rpc/detalhe_chamada", Fixtures.detalheChamadaJson())
            ok("/rpc/responder_chamada", Fixtures.resultadoJson("recusada"))
        }
        val viewModel = montar(rede)

        rule.onNodeWithTag("recusar-chamada").performClick()
        rule.onNodeWithText(TextosChamadaProfissional.MOTIVO_AGENDA).performScrollTo().performClick()
        rule.onNodeWithTag("confirmar-recusa-chamada").performScrollTo().performClick()
        rule.waitUntil(TIMEOUT_MS) { viewModel.estado.value.resultado != null }

        val corpo = rede.doCaminho("/rpc/responder_chamada").single().corpo!!
        assertEquals("recusar", corpo["resposta"]!!.jsonPrimitive.content)
        assertEquals("agenda", corpo["motivo_recusa"]!!.jsonPrimitive.content)
    }

    private companion object {
        const val TIMEOUT_MS = 5_000L
    }

    private fun reabrirAceita(detalhe: String): Pair<ChamadaRecebidaViewModel, MutableList<String>> {
        val rede = RedeDeTeste().apply { ok("/rpc/detalhe_chamada", detalhe) }
        val abertos = mutableListOf<String>()
        val viewModel = ChamadaRecebidaViewModel(
            chamadaId = Fixtures.CHAMADA,
            detalhar = rede.servico::detalheChamada,
            responder = rede.servico::responderChamada,
            agora = { Instant.parse("2026-11-17T00:00:00Z") },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        rule.setContent {
            FrilaTheme { TelaDetalheChamadaRecebida(viewModel = viewModel, aoVoltar = {}, aoAbrirTurno = { abertos += it }) }
        }
        rule.waitUntil(TIMEOUT_MS) { !viewModel.estado.value.carregando }
        rule.waitForIdle()
        return viewModel to abertos
    }

    @Test
    fun chamadaAceitaReabertaMostraAceitaEVerTurnoPeloTurnoDoDetalhe() {
        val (_, abertos) = reabrirAceita(
            Fixtures.detalheChamadaJson(estado = "aceita", turnoId = Fixtures.TURNO, local = "SCS Quadra 2", responsavelLocal = "Ana"),
        )

        rule.onNodeWithTag("chamada-aceita").assertIsDisplayed()
        rule.onNodeWithText("SCS Quadra 2").assertIsDisplayed()
        assertEquals(0, rule.onAllNodesWithTag("aviso-concorrencia").fetchSemanticsNodes().size)
        rule.onNodeWithTag("ver-turno-aceito").assertIsDisplayed().performClick()
        assertEquals(listOf(Fixtures.TURNO), abertos)
    }

    @Test
    fun chamadaAceitaReabertaSemTurnoNoDetalheMostraAceitaSemVerTurno() {
        reabrirAceita(Fixtures.detalheChamadaJson(estado = "aceita"))

        rule.onNodeWithTag("chamada-aceita").assertIsDisplayed()
        assertEquals(0, rule.onAllNodesWithTag("aviso-concorrencia").fetchSemanticsNodes().size)
        assertEquals(0, rule.onAllNodesWithTag("ver-turno-aceito").fetchSemanticsNodes().size)
    }
}
