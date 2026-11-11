package br.com.frila.feature.vagas.painel

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.PainelDto
import br.com.frila.core.rede.PosicaoNoPainelDto
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
}
