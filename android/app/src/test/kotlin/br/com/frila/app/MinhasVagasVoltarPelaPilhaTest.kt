package br.com.frila.app

import android.app.Application
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.PainelDto
import br.com.frila.core.rede.PosicaoNoPainelDto
import br.com.frila.core.rede.VagaNoPainelDto
import br.com.frila.core.rede.VagaResumoDto
import br.com.frila.feature.vagas.painel.MinhasVagasViewModel
import br.com.frila.feature.vagas.painel.TelaMinhasVagas
import java.time.Instant
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cancelar, republicar e escolher candidato fecham com `popBackStack()` e não mandam sinal nenhum para Minhas vagas
 * (`AppNavegacao`). Isto só funciona porque a tela, ao voltar à composição, reinicia o `LaunchedEffect(viewModel)` e relê
 * com `atualizar()`, mantendo a lista na tela. O cartão mcUadnA2 supunha o contrário; foi medido com uma pilha de verdade
 * (1 pedido ao abrir, 2 ao voltar) e este teste impede que isso regrida em silêncio.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class MinhasVagasVoltarPelaPilhaTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste()

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private fun painel(titulo: String) = PainelDto(
        estabelecimentoId = "est-1",
        checkinsPendentes = emptyList(),
        vagas = listOf(
            VagaNoPainelDto(
                vaga = VagaResumoDto("v1", titulo, "SQN 108", "Asa Norte", "2026-11-12T21:00:00Z", "2026-11-13T03:00:00Z", 16_000),
                modo = "selecao", estado = "publicada", oculta = false, alertaVagaVazia = false, candidatosPendentes = 0,
                posicoes = listOf(PosicaoNoPainelDto(id = "p1", estado = "aberta", emAtraso = false)),
            ),
        ),
    )

    private fun montar(vm: MinhasVagasViewModel) {
        rule.setContent {
            FrilaTheme {
                val nav = rememberNavController()
                NavHost(nav, startDestination = "lista") {
                    composable("lista") {
                        TelaMinhasVagas(
                            viewModel = vm,
                            aoVoltar = null,
                            aoVerCandidatos = { _, _, _ -> },
                            aoPublicarVaga = { nav.navigate("acao") },
                        )
                    }
                    composable("acao") {
                        Button(onClick = { nav.popBackStack() }) { Text("Fechar a ação") }
                    }
                }
            }
        }
    }

    @Test
    fun `voltar pela pilha rele o painel, com a lista antiga na tela ate a nova chegar`() {
        val segunda = CompletableDeferred<Result<PainelDto>>()
        var pedidos = 0
        val vm = MinhasVagasViewModel(
            estabelecimentoId = "est-1",
            buscarPainel = { _, _, _ -> if (++pedidos == 1) Result.success(painel("Garçom")) else segunda.await() },
            relogio = { Instant.parse("2026-11-10T15:00:00Z") },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        montar(vm)
        rule.waitForIdle()
        rule.onNodeWithText("Garçom").assertExists()
        assertEquals("a primeira leitura", 1, pedidos)

        rule.onNodeWithText("Publicar vaga").performClick()
        rule.waitForIdle()
        rule.onNodeWithText("Fechar a ação").performClick()
        rule.waitForIdle()

        assertEquals("voltar pela pilha relê o painel", 2, pedidos)
        // A segunda leitura ainda não chegou: a lista de antes fica na tela, sem voltar a "Carregando".
        rule.onNodeWithText("Garçom").assertExists()
        assertTrue("a releitura está em curso sobre a lista", vm.estado.value.atualizando)

        rule.runOnIdle { segunda.complete(Result.success(painel("Cozinheiro"))) }
        rule.waitForIdle()
        rule.onNodeWithText("Cozinheiro").assertExists()
        assertTrue("a lista nova substituiu a velha", vm.estado.value.atualizando.not())
    }
}
