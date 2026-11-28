package br.com.frila.app

import android.app.Application
import androidx.activity.ComponentActivity
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.rede.ExclusaoDeContaDto
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.conta.ExclusaoDeContaViewModel
import br.com.frila.feature.conta.TextosExclusaoDeConta
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão rKCpWPez (item 200), na navegação real: o ViewModel roda no `viewModelScope` (sem escopo de teste), e o pedido
 * fica suspenso até o teste o soltar. Um voltar do sistema no meio não tira a tela da pilha, o pedido não é cancelado,
 * e quando o servidor responde a sessão é limpa e a app vai para a Entrada.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AppNavegacaoExclusaoDeContaVoltarTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // C0-6b: testReleaseUnitTest

    @get:Rule(order = 1)
    val rule = createAndroidComposeRule<ComponentActivity>()

    private lateinit var nav: NavHostController
    private val pedidoIniciou = CompletableDeferred<Unit>()
    private val respostaDoServidor = CompletableDeferred<ExclusaoDeContaDto>()
    private var pedidoCancelado = false
    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } returns false
    }

    private fun montar() {
        val entrada = mockk<EntradaViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoEntrada()) }
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        single<ArmazenamentoDeSessao> { sessao }
                        viewModel { entrada }
                        viewModel {
                            ExclusaoDeContaViewModel(
                                excluir = {
                                    pedidoIniciou.complete(Unit)
                                    try {
                                        respostaDoServidor.await()
                                    } catch (cancelado: CancellationException) {
                                        pedidoCancelado = true
                                        throw cancelado
                                    }
                                },
                                aoConcluir = { sessao.limparSessao() },
                                // Sem `escopo`: o viewModelScope de verdade, que morre quando a tela sai da pilha.
                            )
                        }
                    },
                )
            }) {
                nav = rememberNavController()
                AppNavegacao(
                    armazenamentoDeSessao = sessao,
                    monitorDeConectividade = MonitorDeConectividadeFalso(),
                    navController = nav,
                )
            }
        }
        rule.runOnIdle { nav.navigate(Rotas.EXCLUSAO_DE_CONTA) }
        rule.onNodeWithText(TextosExclusaoDeConta.CONFIRMACAO_CHECK).performScrollTo().performClick()
        rule.onNodeWithText(TextosExclusaoDeConta.BOTAO_EXCLUIR).performScrollTo().performClick()
        rule.onNodeWithText(TextosExclusaoDeConta.DIALOGO_CONFIRMAR).performClick()
        rule.waitUntil(5_000) { pedidoIniciou.isCompleted }
        // A tela recompõe com "Excluindo…" e o BackHandler liga. Sem esperar, o voltar cai no quadro entre o toque em
        // "Confirmar" e a recomposição, ainda com o voltar livre (medido: sem esta espera, a rota vira a Entrada).
        rule.waitForIdle()
    }

    private fun rotaAtual(): String? {
        var rota: String? = null
        rule.runOnIdle { rota = nav.currentDestination?.route }
        return rota
    }

    @Test
    fun `voltar do sistema durante o Excluindo nao cancela o pedido e a sessao e limpa ao fim`() {
        montar()

        rule.runOnUiThread { rule.activity.onBackPressedDispatcher.onBackPressed() }
        rule.waitForIdle()

        assertEquals("a tela fica na pilha enquanto o pedido roda", Rotas.EXCLUSAO_DE_CONTA, rotaAtual())
        assertFalse("o pedido não pode ser cancelado no meio", pedidoCancelado)

        respostaDoServidor.complete(ExclusaoDeContaDto("2026-11-10T12:00:00Z", "2026-11-25", 0))
        rule.waitUntil(5_000) { rotaAtual() == Rotas.ENTRADA }

        assertFalse(pedidoCancelado)
        verify(exactly = 1) { sessao.limparSessao() }
    }
}
