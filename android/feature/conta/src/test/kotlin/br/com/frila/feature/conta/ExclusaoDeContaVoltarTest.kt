package br.com.frila.feature.conta

import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.compose.ui.test.junit4.createAndroidComposeRule
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

    private fun montar(estado: EstadoExclusaoDeConta) {
        rule.runOnUiThread {
            rule.activity.onBackPressedDispatcher.addCallback(
                object : OnBackPressedCallback(true) {
                    override fun handleOnBackPressed() { saiu++ }
                },
            )
        }
        rule.setContent {
            FrilaTheme {
                ConteudoExclusaoDeConta(estado = estado, aoAlterarConfirmacao = {}, aoExcluir = {}, aoVoltar = { voltou++ })
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

    @Test
    fun `parada, a tela deixa o voltar do sistema passar`() {
        montar(EstadoExclusaoDeConta(confirmouConsequencias = true))

        voltarDoSistema()

        assertEquals(1, saiu)
    }

    @Test
    fun `depois de um erro o voltar do sistema volta a passar`() {
        montar(EstadoExclusaoDeConta(confirmouConsequencias = true, mensagemErro = "Sem conexão. Tente de novo."))

        voltarDoSistema()

        assertEquals(1, saiu)
    }
}
