package br.com.frila.feature.vagas.painel

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasAnyDescendant
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.PainelDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.PosicaoNoPainelDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.VagaNoPainelDto
import br.com.frila.core.rede.VagaResumoDto
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** A tela ligada ao ViewModel: carrega sozinha e entrega a quem a abriu o que ele precisa da vaga. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h1600dp")
class TelaMinhasVagasLigadaTest {

    @get:Rule
    val rule = createComposeRule()

    private val agora = Instant.parse("2026-11-10T15:00:00Z")

    private fun posicao(id: String, estado: String) =
        PosicaoNoPainelDto(id = id, estado = estado, emAtraso = false)

    private fun painel() = PainelDto(
        estabelecimentoId = "est-1",
        checkinsPendentes = emptyList(),
        vagas = listOf(
            VagaNoPainelDto(
                vaga = VagaResumoDto("v1", "Garçom", "SQN 108", "Asa Norte", "2026-11-12T21:00:00Z", "2026-11-13T03:00:00Z", 16_000),
                modo = "selecao", estado = "publicada", oculta = false, alertaVagaVazia = false, candidatosPendentes = 2,
                posicoes = listOf(posicao("p1", "aberta"), posicao("p2", "aberta"), posicao("p3", "confirmada")),
            ),
        ),
    )

    @Test
    fun `carrega ao abrir e entrega id, posicoes abertas e inicio ao ver candidatos`() {
        var pedidos = 0
        var recebido: Triple<String, Int, Instant?>? = null
        val vm = MinhasVagasViewModel(
            estabelecimentoId = "est-1",
            nomeEstabelecimento = "Bar da Lia",
            buscarPainel = { _, _, _ -> pedidos++; Result.success(painel()) },
            relogio = { agora },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )

        rule.setContent {
            FrilaTheme {
                TelaMinhasVagas(
                    viewModel = vm,
                    aoVoltar = {},
                    aoVerCandidatos = { id, abertas, inicio -> recebido = Triple(id, abertas, inicio) },
                    aoPublicarVaga = {},
                )
            }
        }
        rule.waitUntil(5_000) { rule.onAllNodesWithText("Garçom").fetchSemanticsNodes().isNotEmpty() }
        rule.onNodeWithContentDescription("Ver candidatos da vaga de Garçom").performClick()

        assertEquals(1, pedidos)
        assertEquals(Triple("v1", 2, Instant.parse("2026-11-12T21:00:00Z")), recebido)
    }

    @Test
    fun `publicar vaga entrega o id do estabelecimento e voltar chama o callback`() {
        var estabelecimento: String? = null
        var voltou = 0
        val vm = MinhasVagasViewModel(
            estabelecimentoId = "est-1",
            buscarPainel = { _, _, _ -> Result.success(painel()) },
            relogio = { agora },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )

        rule.setContent {
            FrilaTheme {
                TelaMinhasVagas(viewModel = vm, aoVoltar = { voltou++ }, aoVerCandidatos = { _, _, _ -> }, aoPublicarVaga = { estabelecimento = it })
            }
        }
        rule.waitUntil(5_000) { rule.onAllNodesWithText("Garçom").fetchSemanticsNodes().isNotEmpty() }
        assertNull(estabelecimento)
        rule.onNodeWithText(TextosMinhasVagas.PUBLICAR_VAGA).performClick()
        rule.onNodeWithContentDescription(TextosMinhasVagas.ROTULO_VOLTAR).performClick()

        assertEquals("est-1", estabelecimento)
        assertEquals(1, voltou)
    }

    @Test
    fun `puxar para atualizar chama o painel de novo`() {
        var pedidos = 0
        val vm = MinhasVagasViewModel(
            estabelecimentoId = "est-1",
            buscarPainel = { _, _, _ -> pedidos++; Result.success(painel()) },
            relogio = { agora },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )

        rule.setContent {
            FrilaTheme { TelaMinhasVagas(viewModel = vm, aoVoltar = {}, aoVerCandidatos = { _, _, _ -> }, aoPublicarVaga = {}) }
        }
        rule.waitUntil(5_000) { pedidos == 1 }
        vm.atualizar()
        rule.waitForIdle()

        assertEquals(2, pedidos)
    }

    @Test
    fun `acompanhar turno entrega a vaga e a posicao a quem abriu a tela`() {
        var recebido: Pair<String, String>? = null
        val vm = MinhasVagasViewModel(
            estabelecimentoId = "est-1",
            buscarPainel = { _, _, _ ->
                val confirmada = PosicaoNoPainelDto(id = "p3", estado = "confirmada", turnoId = "t3", emAtraso = false)
                Result.success(painel().let { p -> p.copy(vagas = p.vagas.map { it.copy(posicoes = it.posicoes + confirmada) }) })
            },
            relogio = { agora },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )

        rule.setContent {
            FrilaTheme {
                TelaMinhasVagas(
                    viewModel = vm,
                    aoVoltar = {},
                    aoVerCandidatos = { _, _, _ -> },
                    aoPublicarVaga = {},
                    aoAcompanharTurno = { vagaId, posicaoId -> recebido = vagaId to posicaoId },
                )
            }
        }
        rule.waitUntil(5_000) { rule.onAllNodesWithText("Acompanhar turno de profissional").fetchSemanticsNodes().isNotEmpty() }
        rule.onNodeWithText("Acompanhar turno de profissional").performClick()

        assertEquals("v1" to "p3", recebido)
    }

    // ---- Uk5UJWjQ, fatia 1: "Presenças a confirmar" no topo (Painel.checkins_pendentes), como o iOS ----

    private val ana = PerfilPublicoDto("pro-1", "profissional", "Ana Souza", null, ReputacaoDto(1, 1, null, 1, 1))

    /** O painel com a posição p4 confirmada da Ana (turno t1) e os pendentes pedidos. */
    private fun painelComPendentes(pendentes: List<String>) = painel().let { p ->
        val daAna = PosicaoNoPainelDto(id = "p4", estado = "confirmada", turnoId = "t1", profissional = ana, emAtraso = false)
        p.copy(checkinsPendentes = pendentes, vagas = p.vagas.map { it.copy(posicoes = it.posicoes + daAna) })
    }

    private fun montarComPainel(painel: PainelDto, aoAcompanharTurno: (String, String) -> Unit = { _, _ -> }) {
        val vm = MinhasVagasViewModel(
            estabelecimentoId = "est-1",
            buscarPainel = { _, _, _ -> Result.success(painel) },
            relogio = { agora },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        rule.setContent {
            FrilaTheme {
                TelaMinhasVagas(
                    viewModel = vm,
                    aoVoltar = {},
                    aoVerCandidatos = { _, _, _ -> },
                    aoPublicarVaga = {},
                    aoAcompanharTurno = aoAcompanharTurno,
                )
            }
        }
        rule.waitUntil(5_000) { rule.onAllNodesWithText("Garçom").fetchSemanticsNodes().isNotEmpty() }
    }

    @Test
    fun `painel com checkin pendente mostra Presencas a confirmar com o nome, e o toque abre o turno`() {
        var recebido: Pair<String, String>? = null
        montarComPainel(painelComPendentes(listOf("t1"))) { vagaId, posicaoId -> recebido = vagaId to posicaoId }

        rule.onNodeWithText(TextosMinhasVagas.PRESENCAS_A_CONFIRMAR).assertIsDisplayed()
        rule.onNode(hasTestTag("presenca-a-confirmar-t1") and hasAnyDescendant(hasText("Ana Souza"))).assertIsDisplayed()
        rule.onNodeWithText(TextosMinhasVagas.EXPLICACAO_DA_CONFIRMACAO).assertIsDisplayed()

        rule.onNodeWithTag("acompanhar-turno-t1").performClick()
        assertEquals("v1" to "p4", recebido)
    }

    @Test
    fun `sem checkin pendente a secao nao aparece`() {
        montarComPainel(painelComPendentes(emptyList()))

        assertEquals(0, rule.onAllNodesWithText(TextosMinhasVagas.PRESENCAS_A_CONFIRMAR).fetchSemanticsNodes().size)
        assertEquals(0, rule.onAllNodesWithTag("presenca-a-confirmar-t1").fetchSemanticsNodes().size)
    }

    @Test
    fun `pendente que o painel nao traz fica de fora, sem secao vazia`() {
        montarComPainel(painelComPendentes(listOf("t-de-outra-janela")))

        assertEquals(0, rule.onAllNodesWithText(TextosMinhasVagas.PRESENCAS_A_CONFIRMAR).fetchSemanticsNodes().size)
    }

    // ---- Uk5UJWjQ, fatia 2: "Confirmar presença" no próprio cartão ----

    @Test
    fun `Confirmar presenca no cartao envia, tira o cartao e mostra Presenca confirmada`() {
        val confirmados = mutableListOf<String>()
        var leituras = 0
        val vm = MinhasVagasViewModel(
            estabelecimentoId = "est-1",
            buscarPainel = { _, _, _ -> leituras++; Result.success(painelComPendentes(if (leituras == 1) listOf("t1") else emptyList())) },
            confirmarCheckin = { turnoId ->
                confirmados += turnoId
                Result.success(br.com.frila.core.rede.ResultadoRegistroDto(turnoId, "manual", "verificado", "2026-11-12T21:05:00Z"))
            },
            relogio = { agora },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        rule.setContent {
            FrilaTheme { TelaMinhasVagas(viewModel = vm, aoVoltar = {}, aoVerCandidatos = { _, _, _ -> }, aoPublicarVaga = {}) }
        }
        rule.waitUntil(5_000) { rule.onAllNodesWithTag("confirmar-presenca-t1").fetchSemanticsNodes().isNotEmpty() }

        rule.onNodeWithTag("confirmar-presenca-t1").assertIsDisplayed().performClick()
        rule.waitForIdle()

        assertEquals(listOf("t1"), confirmados)
        rule.onNodeWithText(TextosMinhasVagas.PRESENCA_CONFIRMADA).assertIsDisplayed()
        assertEquals(0, rule.onAllNodesWithTag("presenca-a-confirmar-t1").fetchSemanticsNodes().size)
    }

    @Test
    fun `sem o caminho de confirmar o cartao so oferece Acompanhar turno`() {
        montarComPainel(painelComPendentes(listOf("t1")))

        rule.onNodeWithTag("acompanhar-turno-t1").assertIsDisplayed()
        assertEquals(0, rule.onAllNodesWithTag("confirmar-presenca-t1").fetchSemanticsNodes().size)
    }
}
