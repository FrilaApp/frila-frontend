package br.com.frila.core.designsystem.abertura

import android.provider.Settings
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * Pedido 18-01: a abertura animada cobre o app sem segurá-lo, um toque pula, "reduzir movimento" troca o roteiro pelo de
 * 0,9 s e a chave de teste ([AberturaAnimada.ligada]) a desliga. O relógio dos testes é o do Compose (virtual): avançar
 * `mainClock` avança a abertura.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class AberturaAnimadaTest {

    @get:Rule
    val rule = createComposeRule()

    @After
    fun restaurarEscalaDeAnimacao() {
        val resolver = RuntimeEnvironment.getApplication().contentResolver
        Settings.Global.putFloat(resolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f)
    }

    private fun nomeDaMarca() = rule.onNodeWithContentDescription("Frila")

    private fun conteudoSimples(): @androidx.compose.runtime.Composable () -> Unit = {
        Box(Modifier.fillMaxSize()) { Text("conteudo do app") }
    }

    @Test
    fun `com a chave de teste a abertura nao aparece e o app esta na tela`() {
        rule.setContent {
            FrilaTheme { AberturaAnimada(ligada = false, conteudo = conteudoSimples()) }
        }
        rule.onNodeWithText("conteudo do app").assertIsDisplayed()
        nomeDaMarca().assertDoesNotExist()
    }

    @Test
    fun `ligada, cobre o app - rotulo falado Frila e o app some do leitor de tela`() {
        rule.mainClock.autoAdvance = false
        rule.setContent {
            FrilaTheme { AberturaAnimada(ligada = true, reduzirMovimento = false, conteudo = conteudoSimples()) }
        }
        rule.mainClock.advanceTimeBy(300)
        nomeDaMarca().assertExists()
        // O app por baixo fica oculto à acessibilidade só enquanto a abertura cobre.
        rule.onNodeWithText("conteudo do app").assertDoesNotExist()
    }

    @Test
    fun `a abertura oferece a acao Pular abertura`() {
        rule.mainClock.autoAdvance = false
        rule.setContent {
            FrilaTheme { AberturaAnimada(ligada = true, reduzirMovimento = false, conteudo = conteudoSimples()) }
        }
        rule.mainClock.advanceTimeBy(300)
        val config = nomeDaMarca().fetchSemanticsNode().config
        val acao = config[SemanticsActions.OnClick]
        assertEquals("Pular abertura", acao.label)
    }

    @Test
    fun `um toque pula e o app aparece, de novo visivel ao leitor de tela`() {
        var terminou = 0
        rule.mainClock.autoAdvance = false
        rule.setContent {
            FrilaTheme {
                AberturaAnimada(ligada = true, reduzirMovimento = false, aoTerminar = { terminou++ }, conteudo = conteudoSimples())
            }
        }
        rule.mainClock.advanceTimeBy(500)
        nomeDaMarca().assertExists()

        nomeDaMarca().performClick()
        // O esmaecimento do pulo dura 0,25 s: bem antes dos 2,8 s do roteiro.
        rule.mainClock.advanceTimeBy(600)
        rule.waitForIdle()

        nomeDaMarca().assertDoesNotExist()
        rule.onNodeWithText("conteudo do app").assertIsDisplayed()
        assertEquals("aoTerminar toca uma vez", 1, terminou)
    }

    @Test
    fun `sem toque, a abertura cheia dura 2,8 s e sai sozinha`() {
        rule.mainClock.autoAdvance = false
        rule.setContent {
            FrilaTheme { AberturaAnimada(ligada = true, reduzirMovimento = false, conteudo = conteudoSimples()) }
        }
        rule.mainClock.advanceTimeBy(2_000)
        nomeDaMarca().assertExists()
        rule.mainClock.advanceTimeBy(1_000)
        rule.waitForIdle()
        nomeDaMarca().assertDoesNotExist()
        rule.onNodeWithText("conteudo do app").assertIsDisplayed()
    }

    @Test
    fun `com reduzir movimento o roteiro e o reduzido de 0,9 s`() {
        rule.mainClock.autoAdvance = false
        rule.setContent {
            FrilaTheme { AberturaAnimada(ligada = true, reduzirMovimento = true, conteudo = conteudoSimples()) }
        }
        rule.mainClock.advanceTimeBy(500)
        nomeDaMarca().assertExists()
        // Com 1,2 s a reduzida já saiu; a cheia (2,8 s) ainda estaria na tela.
        rule.mainClock.advanceTimeBy(700)
        rule.waitForIdle()
        nomeDaMarca().assertDoesNotExist()
        rule.onNodeWithText("conteudo do app").assertIsDisplayed()
    }

    @Test
    fun `com as animacoes do sistema desligadas o padrao e o roteiro reduzido`() {
        val resolver = RuntimeEnvironment.getApplication().contentResolver
        Settings.Global.putFloat(resolver, Settings.Global.ANIMATOR_DURATION_SCALE, 0f)
        rule.mainClock.autoAdvance = false
        rule.setContent {
            // Sem passar `reduzirMovimento`: o padrão lê Settings.Global.ANIMATOR_DURATION_SCALE.
            FrilaTheme { AberturaAnimada(ligada = true, conteudo = conteudoSimples()) }
        }
        rule.mainClock.advanceTimeBy(500)
        nomeDaMarca().assertExists()
        rule.mainClock.advanceTimeBy(700)
        rule.waitForIdle()
        nomeDaMarca().assertDoesNotExist()
    }

    @Test
    fun `o app carrega por baixo - a primeira composicao e o primeiro efeito rodam com a abertura ainda na tela`() {
        var composicoes = 0
        var efeitos = 0
        rule.mainClock.autoAdvance = false
        rule.setContent {
            FrilaTheme {
                AberturaAnimada(ligada = true, reduzirMovimento = false) {
                    composicoes++
                    // O equivalente da primeira chamada de rede do app: um efeito que dispara na primeira composição.
                    LaunchedEffect(Unit) { efeitos++ }
                    Text("conteudo do app")
                }
            }
        }
        // 16 ms: o primeiro quadro, muito antes de a abertura (2,8 s) sair.
        rule.mainClock.advanceTimeBy(16)
        assertTrue("o conteúdo já compôs", composicoes >= 1)
        assertEquals("o efeito de carga já rodou", 1, efeitos)
        nomeDaMarca().assertExists()
    }

    @Test
    fun `o app tem a mesma identidade antes e depois da abertura - nao recarrega ao terminar`() {
        var efeitos = 0
        var chaveDoEstado = 0
        rule.mainClock.autoAdvance = false
        rule.setContent {
            FrilaTheme {
                AberturaAnimada(ligada = true, reduzirMovimento = false) {
                    val id = remember { ++chaveDoEstado }
                    LaunchedEffect(Unit) { efeitos++ }
                    Text("conteudo $id")
                }
            }
        }
        rule.mainClock.advanceTimeBy(3_500)
        rule.waitForIdle()
        nomeDaMarca().assertDoesNotExist()
        rule.onNodeWithText("conteudo 1").assertIsDisplayed()
        assertEquals("o conteúdo nasceu uma vez", 1, chaveDoEstado)
        assertEquals("o efeito de carga rodou uma vez", 1, efeitos)
    }

    @Test
    fun `o conteudo ve que a abertura cobre enquanto ela esta na tela`() {
        val cobrindo = mutableIntStateOf(-1)
        rule.mainClock.autoAdvance = false
        rule.setContent {
            FrilaTheme {
                AberturaAnimada(ligada = true, reduzirMovimento = false) {
                    cobrindo.intValue = if (LocalAberturaCobrindo.current) 1 else 0
                    Text("conteudo do app")
                }
            }
        }
        rule.mainClock.advanceTimeBy(300)
        assertEquals(1, cobrindo.intValue)
        rule.mainClock.advanceTimeBy(3_000)
        rule.waitForIdle()
        assertEquals(0, cobrindo.intValue)
    }

    @Test
    fun `um toque depois da saida nao pula mais`() {
        var terminou = 0
        rule.mainClock.autoAdvance = false
        rule.setContent {
            FrilaTheme {
                AberturaAnimada(ligada = true, reduzirMovimento = false, aoTerminar = { terminou++ }, conteudo = conteudoSimples())
            }
        }
        // A saída do roteiro cheio é em 2,38 s; aos 2,6 s a janela já abriu.
        rule.mainClock.advanceTimeBy(2_600)
        nomeDaMarca().assertExists()
        nomeDaMarca().performClick()
        rule.mainClock.advanceTimeBy(100)
        // Continua a abertura normal até os 2,8 s, sem o esmaecimento do pulo.
        assertEquals(0, terminou)
        rule.mainClock.advanceTimeBy(400)
        rule.waitForIdle()
        assertEquals(1, terminou)
    }
}
