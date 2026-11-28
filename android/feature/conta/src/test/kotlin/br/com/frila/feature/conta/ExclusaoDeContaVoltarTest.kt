package br.com.frila.feature.conta

import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.performClick
import br.com.frila.core.rede.ExclusaoDeContaDto
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão rKCpWPez (item 200): o voltar do sistema fica preso enquanto a exclusão roda, como o da barra.
 *
 * Um callback de fundo, registrado antes da tela, faz o papel de quem tiraria a tela da pilha (o `NavHost`, na app):
 * ele só conta quando a tela deixa o voltar passar. Sem ele, "não chamou `aoVoltar`" passaria com e sem o
 * `BackHandler`, porque o voltar do sistema nunca chega ao `aoVoltar` da barra.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h914dp")
class ExclusaoDeContaVoltarTest {

    @get:Rule
    val rule = createAndroidComposeRule<ComponentActivity>()

    private var saiu = 0
    private var voltou = 0

    private fun montar(estado: EstadoExclusaoDeConta, excluindoAoVivo: (() -> Boolean)? = null) {
        rule.runOnUiThread {
            rule.activity.onBackPressedDispatcher.addCallback(
                object : OnBackPressedCallback(true) {
                    override fun handleOnBackPressed() { saiu++ }
                },
            )
        }
        rule.setContent {
            FrilaTheme {
                if (excluindoAoVivo != null) {
                    ConteudoExclusaoDeConta(
                        estado = estado, aoAlterarConfirmacao = {}, aoExcluir = {}, aoVoltar = { voltou++ }, excluindoAoVivo = excluindoAoVivo,
                    )
                } else {
                    ConteudoExclusaoDeConta(estado = estado, aoAlterarConfirmacao = {}, aoExcluir = {}, aoVoltar = { voltou++ })
                }
            }
        }
        rule.waitForIdle()
    }

    private fun voltarDoSistema() {
        rule.runOnUiThread { rule.activity.onBackPressedDispatcher.onBackPressed() }
        rule.waitForIdle()
    }

    @Test
    fun `durante o Excluindo o voltar do sistema nao tira a tela`() {
        montar(EstadoExclusaoDeConta(confirmouConsequencias = true, excluindo = true))

        voltarDoSistema()

        assertEquals("a tela não pode sair da pilha com o pedido no meio", 0, saiu)
        assertEquals(0, voltou)
    }

    // Antes do item 213 o handler ficava desligado com a tela parada e o voltar chegava ao callback de fundo (o `NavHost`). Agora o
    // handler é sempre ativo e confere o pedido ao vivo; parada, entrega ao `aoVoltar`, que na rota é o mesmo `popBackStack`.
    @Test
    fun `parada, a tela deixa o voltar do sistema passar, entregando ao aoVoltar`() {
        montar(EstadoExclusaoDeConta(confirmouConsequencias = true))

        voltarDoSistema()

        assertEquals(1, voltou)
        assertEquals(0, saiu)
    }

    @Test
    fun `depois de um erro o voltar do sistema volta a passar, entregando ao aoVoltar`() {
        montar(EstadoExclusaoDeConta(confirmouConsequencias = true, mensagemErro = "Sem conexão. Tente de novo."))

        voltarDoSistema()

        assertEquals(1, voltou)
        assertEquals(0, saiu)
    }

    // F4owLsLH (item 213, B): o toque que dispara o pedido muda o estado do ViewModel na hora, e a tela só o enxerga no quadro seguinte.
    // Neste quadro o `estado` recomposto ainda diz "parado"; quem decide o voltar é a leitura ao vivo.
    @Test
    fun `no quadro em que o pedido ja saiu mas a tela ainda nao recompos, o voltar do sistema nao tira a tela`() {
        montar(EstadoExclusaoDeConta(confirmouConsequencias = true, excluindo = false), excluindoAoVivo = { true })

        voltarDoSistema()

        assertEquals("o voltar não pode passar com o pedido no ar", 0, saiu)
        assertEquals(0, voltou)
    }

    @Test
    fun `no mesmo quadro o botao de voltar da barra tambem nao tira a tela`() {
        montar(EstadoExclusaoDeConta(confirmouConsequencias = true, excluindo = false), excluindoAoVivo = { true })

        rule.onNodeWithContentDescription(TextosExclusaoDeConta.ROTULO_VOLTAR).performClick()
        rule.waitForIdle()

        assertEquals(0, voltou)
    }

    // A ligação real: a tela conectada lê o pedido do ViewModel ao vivo. O relógio do Compose para, o toque no Excluir muda o estado do
    // ViewModel e o voltar chega antes de qualquer recomposição: é o quadro da janela.
    @Test
    fun `na tela ligada ao ViewModel, o voltar logo depois do pedido sair nao tira a tela`() {
        val liberar = kotlinx.coroutines.CompletableDeferred<Unit>()
        val vm = ExclusaoDeContaViewModel(
            excluir = { liberar.await(); ExclusaoDeContaDto("2026-11-10T12:00:00Z", "2026-11-25", 0) },
            escopo = kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.Unconfined),
        )
        vm.alterarConfirmacao(true)
        rule.runOnUiThread {
            rule.activity.onBackPressedDispatcher.addCallback(
                object : OnBackPressedCallback(true) {
                    override fun handleOnBackPressed() { saiu++ }
                },
            )
        }
        rule.setContent { FrilaTheme { TelaExclusaoDeConta(viewModel = vm, aoVoltar = { voltou++ }) } }
        rule.waitForIdle()

        rule.mainClock.autoAdvance = false
        try {
            rule.runOnUiThread { vm.confirmarExclusao() }
            rule.runOnUiThread { rule.activity.onBackPressedDispatcher.onBackPressed() }

            assertEquals("o ViewModel já está excluindo", true, vm.estado.value.excluindo)
            assertEquals(0, saiu)
            assertEquals(0, voltou)
        } finally {
            rule.mainClock.autoAdvance = true
            liberar.complete(Unit)
        }
    }
}
