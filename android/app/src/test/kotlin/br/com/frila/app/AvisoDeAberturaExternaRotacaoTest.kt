package br.com.frila.app

import android.app.Application
import androidx.compose.foundation.clickable
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.SaverScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.StateRestorationTester
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão HvHXbsEm (item 278): o `AvisoDeAberturaExterna.Salvador` guarda o aviso na rotação e na morte do processo com o diálogo
 * aberto. Sem teste, o `save` guardar só a mensagem (o `restore` estoura) e o `restore` usar `null` no lugar do endereço (o endereço para
 * copiar some) passavam. Aqui o `Saver` direto, e o diálogo de verdade atravessando `StateRestorationTester`. Fora: a Ajuda e a fiação
 * na `AppNavegacao`.
 *
 * JUnit: nenhum método devolve valor (um `@Test` que devolve valor é ignorado).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AvisoDeAberturaExternaRotacaoTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // C0-6b: testReleaseUnitTest

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private val escopo = SaverScope { true }

    private fun salvar(aviso: AvisoDeAberturaExterna?): Any? = with(AvisoDeAberturaExterna.Salvador) { escopo.save(aviso) }

    private fun restaurar(salvo: Any): AvisoDeAberturaExterna? = AvisoDeAberturaExterna.Salvador.restore(salvo)

    // ---- o Saver direto ----

    @Test
    fun `aviso com endereco volta igual, mensagem e endereco`() {
        val aviso = AvisoDeAberturaExterna.semEmail("suporte@frilabr.com")

        val volta = restaurar(salvar(aviso)!!)

        assertEquals(aviso, volta)
        assertEquals("suporte@frilabr.com", volta?.paraCopiar)
        assertEquals(aviso.mensagem, volta?.mensagem)
    }

    @Test
    fun `aviso sem endereco volta sem endereco, e nao com o texto vazio`() {
        val aviso = AvisoDeAberturaExterna.semNavegadorParaEntrar

        val volta = restaurar(salvar(aviso)!!)

        assertEquals(aviso, volta)
        assertNull(volta?.paraCopiar)
    }

    @Test
    fun `todos os avisos prontos atravessam o saver sem perder nada`() {
        val avisos = listOf(
            AvisoDeAberturaExterna.semEmail("suporte@frilabr.com"),
            AvisoDeAberturaExterna.semTelefone("190"),
            AvisoDeAberturaExterna.semNavegador("https://frilabr.com"),
            AvisoDeAberturaExterna.semLojaNemNavegador("https://play.google.com/store/apps/details?id=br.com.frila"),
            AvisoDeAberturaExterna.semNavegadorParaEntrar,
        )
        for (aviso in avisos) {
            assertEquals(aviso.mensagem, aviso, restaurar(salvar(aviso)!!))
        }
    }

    @Test
    fun `sem aviso nao guarda nada`() {
        assertNull(salvar(null))
    }

    @Test
    fun `o que e guardado cabe no estado salvo do sistema, so texto e na ordem mensagem e endereco`() {
        val guardado = salvar(AvisoDeAberturaExterna("m", "e"))

        assertTrue(guardado is ArrayList<*>)
        assertEquals(listOf("m", "e"), (guardado as ArrayList<*>).toList())
        assertEquals(listOf("m", null), (salvar(AvisoDeAberturaExterna("m")) as ArrayList<*>).toList())
    }

    @Test
    fun `texto com acento, quebra de linha e caracteres especiais atravessa igual`() {
        val aviso = AvisoDeAberturaExterna("Não deu:\nabra “este” endereço — ok", "https://frilabr.com/a?b=c&d=ç#x")

        assertEquals(aviso, restaurar(salvar(aviso)!!))
    }

    // ---- o diálogo de verdade, atravessando a restauração de estado ----

    /**
     * Como a `AppNavegacao`: o estado nasce vazio e um toque abre o aviso (`abrirForaDoApp`). Nascer já com o aviso faria o `init` do
     * `rememberSaveable` trazê-lo de volta depois de fechado, o que não acontece no app.
     */
    private fun montarComRestauracao(inicial: AvisoDeAberturaExterna): StateRestorationTester {
        val restaurador = StateRestorationTester(rule)
        restaurador.setContent {
            var aviso by rememberSaveable(stateSaver = AvisoDeAberturaExterna.Salvador) { mutableStateOf<AvisoDeAberturaExterna?>(null) }
            Text("abrir", modifier = Modifier.testTag("abrir").clickable { aviso = inicial })
            aviso?.let { DialogoDeAberturaExterna(aviso = it, aoFechar = { aviso = null }) }
        }
        rule.onNodeWithTag("abrir").performClick()
        rule.waitForIdle()
        return restaurador
    }

    @Test
    fun `a rotacao com o dialogo aberto mantem a mensagem e o endereco para copiar, com o botao Copiar`() {
        val aviso = AvisoDeAberturaExterna.semTelefone("190")
        val restaurador = montarComRestauracao(aviso)
        rule.onNodeWithTag("aviso-abertura-externa-endereco").assertExists()

        restaurador.emulateSavedInstanceStateRestore()
        rule.waitForIdle()

        rule.onNodeWithTag("aviso-abertura-externa").assertExists()
        rule.onNodeWithText(aviso.mensagem).assertExists()
        rule.onNodeWithTag("aviso-abertura-externa-endereco").assertExists()
        rule.onNodeWithText("190").assertExists()
        rule.onNodeWithText(TextosAberturaExterna.COPIAR).assertExists()
        rule.onNodeWithText(TextosAberturaExterna.FECHAR).assertExists()
    }

    @Test
    fun `a rotacao com o aviso so de explicar mantem o Entendi e continua sem endereco`() {
        val aviso = AvisoDeAberturaExterna.semNavegadorParaEntrar
        val restaurador = montarComRestauracao(aviso)

        restaurador.emulateSavedInstanceStateRestore()
        rule.waitForIdle()

        rule.onNodeWithText(aviso.mensagem).assertExists()
        rule.onAllNodesWithTag("aviso-abertura-externa-endereco").assertCountEquals(0)
        rule.onNodeWithText(TextosAberturaExterna.ENTENDI).assertExists()
    }

    @Test
    fun `depois de fechar o dialogo, a rotacao nao o traz de volta`() {
        val restaurador = montarComRestauracao(AvisoDeAberturaExterna.semEmail("suporte@frilabr.com"))
        rule.onNodeWithText(TextosAberturaExterna.FECHAR).performClick()
        rule.waitForIdle()
        rule.onAllNodesWithTag("aviso-abertura-externa").assertCountEquals(0)

        restaurador.emulateSavedInstanceStateRestore()
        rule.waitForIdle()

        rule.onAllNodesWithTag("aviso-abertura-externa").assertCountEquals(0)
    }

    @Test
    fun `duas rotacoes seguidas mantem o aviso`() {
        val aviso = AvisoDeAberturaExterna.semNavegador("https://frilabr.com")
        val restaurador = montarComRestauracao(aviso)

        restaurador.emulateSavedInstanceStateRestore()
        rule.waitForIdle()
        restaurador.emulateSavedInstanceStateRestore()
        rule.waitForIdle()

        rule.onNodeWithText(aviso.mensagem).assertExists()
        rule.onNodeWithText("https://frilabr.com").assertExists()
        assertNotNull(rule.onNodeWithTag("aviso-abertura-externa").fetchSemanticsNode())
    }
}
