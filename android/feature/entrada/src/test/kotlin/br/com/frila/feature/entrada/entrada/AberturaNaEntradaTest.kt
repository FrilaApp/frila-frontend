package br.com.frila.feature.entrada.entrada

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.abertura.AberturaAnimada
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoAutenticacao
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Pedido 18-01: a abertura sobre a tela de entrada (T6). O toque leva direto à entrada, a entrada carrega por baixo
 * e o rótulo "Frila" da tela é o mesmo em que a abertura pousa.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class AberturaNaEntradaTest {

    @get:Rule
    val rule = createComposeRule()

    private fun entrada() = EntradaViewModel(
        ServicoAutenticacao(
            ClienteSupabase(
                baseUrl = "https://frila.supabase.co",
                apiKey = "chave-teste",
                engine = MockEngine {
                    respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
                },
            ),
        ),
        escopo = CoroutineScope(Dispatchers.Default),
    )

    @Test
    fun `um toque na abertura leva direto a entrada`() {
        val vm = entrada()
        rule.mainClock.autoAdvance = false
        rule.setContent {
            FrilaTheme {
                AberturaAnimada(ligada = true, reduzirMovimento = false) {
                    TelaEntrada(vm, aoReceberCodigo = {})
                }
            }
        }
        rule.mainClock.advanceTimeBy(500)
        // Cobrindo: a entrada está por baixo, escondida do leitor de tela; só o rótulo falado da abertura existe.
        rule.onNodeWithText("Receber código").assertDoesNotExist()
        rule.onAllNodesWithContentDescription("Frila").assertCountEquals(1)

        rule.onNodeWithContentDescription("Frila").performClick()
        rule.mainClock.advanceTimeBy(700)
        rule.waitForIdle()

        // A entrada aparece, completa, e o rótulo "Frila" que sobra é o da tela.
        rule.onNodeWithText("Receber código").assertIsDisplayed()
        rule.onNodeWithText("Bem-vindo ao Frila").assertIsDisplayed()
        rule.onAllNodesWithContentDescription("Frila").assertCountEquals(1)
        rule.onNodeWithContentDescription("Frila").assertIsDisplayed()
    }

    @Test
    fun `com a chave de teste a entrada abre direto, sem abertura`() {
        val vm = entrada()
        rule.setContent {
            FrilaTheme {
                AberturaAnimada(ligada = false) { TelaEntrada(vm, aoReceberCodigo = {}) }
            }
        }
        rule.onNodeWithText("Receber código").assertIsDisplayed()
        // Só o rótulo da tela: nenhum rótulo falado extra de abertura.
        rule.onAllNodesWithContentDescription("Frila").assertCountEquals(1)
    }

    @Test
    fun `a entrada carrega por baixo e o rotulo da tela espera a abertura sair`() {
        val vm = entrada()
        rule.mainClock.autoAdvance = false
        rule.setContent {
            FrilaTheme {
                AberturaAnimada(ligada = true, reduzirMovimento = false) {
                    TelaEntrada(vm, aoReceberCodigo = {})
                }
            }
        }
        rule.mainClock.advanceTimeBy(16)
        // A tela de entrada já compôs (existe na árvore sem o filtro do leitor de tela).
        rule.onNodeWithText("Receber código", useUnmergedTree = true).assertExists()
        // Termina sozinha aos 2,8 s e a tela fica no lugar.
        rule.mainClock.advanceTimeBy(3_000)
        rule.waitForIdle()
        rule.onNodeWithText("Receber código").assertIsDisplayed()
    }
}
