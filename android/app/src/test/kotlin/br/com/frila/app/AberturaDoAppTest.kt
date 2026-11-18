package br.com.frila.app

import android.app.Application
import android.content.Intent
import androidx.compose.material3.Text
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.abertura.AberturaAnimada
import br.com.frila.core.designsystem.abertura.LocalAberturaCobrindo
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Pedido 18-01, lado do app: QUANDO a abertura toca ([PoliticaDaAbertura]) e a prova de que o app carrega por baixo
 * dela, com o mesmo padrão da `MainActivity` (a abertura envolvendo o portão de versão; a configuração do app consultada
 * por um efeito do conteúdo).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AberturaDoAppTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // C0-6b: testReleaseUnitTest

    @get:Rule(order = 1)
    val rule = createComposeRule()

    // --- quando toca

    @Test
    fun `toca na abertura a frio - primeira criacao do processo`() {
        val politica = PoliticaDaAbertura(AtomicBoolean(false))
        assertTrue(politica.deveTocar(Intent(), primeiraCriacao = true))
    }

    @Test
    fun `nao toca ao voltar com o processo vivo - so uma criacao por processo recebe a abertura`() {
        val politica = PoliticaDaAbertura(AtomicBoolean(false))
        assertTrue(politica.deveTocar(Intent(), primeiraCriacao = true))
        // Abrir o app de novo sem o processo ter morrido (saiu pelo voltar, voltou pelo ícone).
        assertFalse(politica.deveTocar(Intent(), primeiraCriacao = true))
        assertFalse(politica.deveTocar(Intent(), primeiraCriacao = true))
    }

    @Test
    fun `nao toca ao recriar a Activity (rotacao, tema) - chega com estado salvo`() {
        val jaTocou = AtomicBoolean(false)
        val politica = PoliticaDaAbertura(jaTocou)
        assertTrue(politica.deveTocar(Intent(), primeiraCriacao = true))
        assertFalse(politica.deveTocar(Intent(), primeiraCriacao = false))
    }

    @Test
    fun `recriacao com estado salvo nao gasta a vez do processo`() {
        val jaTocou = AtomicBoolean(false)
        val politica = PoliticaDaAbertura(jaTocou)
        // O sistema reconstrói a Activity antes de qualquer abertura a frio: não toca e não reserva.
        assertFalse(politica.deveTocar(Intent(), primeiraCriacao = false))
        assertFalse(jaTocou.get())
        assertTrue(politica.deveTocar(Intent(), primeiraCriacao = true))
    }

    @Test
    fun `a chave de teste desliga a abertura e nao gasta a vez do processo`() {
        val jaTocou = AtomicBoolean(false)
        val politica = PoliticaDaAbertura(jaTocou)
        val intent = Intent().putExtra(PoliticaDaAbertura.EXTRA_PULAR_ABERTURA, true)
        assertFalse(politica.deveTocar(intent, primeiraCriacao = true))
        assertFalse(jaTocou.get())
    }

    @Test
    fun `sem Intent a abertura toca normalmente`() {
        assertTrue(PoliticaDaAbertura(AtomicBoolean(false)).deveTocar(null, primeiraCriacao = true))
    }

    @Test
    fun `o tempo congelado so vale no debug`() {
        val intent = Intent().putExtra(PoliticaDaAbertura.EXTRA_ABERTURA_NO_TEMPO, 1.3f)
        assertEquals(1.3, PoliticaDaAbertura.tempoCongelado(intent, debug = true)!!, 1e-6)
        assertNull(PoliticaDaAbertura.tempoCongelado(intent, debug = false))
        assertNull(PoliticaDaAbertura.tempoCongelado(Intent(), debug = true))
        assertNull(PoliticaDaAbertura.tempoCongelado(null, debug = true))
    }

    // --- o app carrega por baixo

    @Test
    fun `a primeira chamada de rede do app sai e termina durante a abertura`() {
        val chamadas = AtomicInteger(0)
        val cobrindoNaChamada = AtomicBoolean(false)
        val resolvida = AtomicBoolean(false)
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                chamadas.incrementAndGet()
                respond(
                    content = """{"plataforma":"android","versao_minima":"1.0.0","recursos":{}}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        rule.mainClock.autoAdvance = false
        rule.setContent {
            FrilaTheme {
                AberturaAnimada(ligada = true, reduzirMovimento = false) {
                    val cobrindo = LocalAberturaCobrindo.current
                    LaunchedEffect(Unit) {
                        cobrindoNaChamada.set(cobrindo)
                        consultarConfiguracaoDoApp(cliente, versaoApp = "1.2.0")
                        resolvida.set(true)
                    }
                    Text("conteudo do app")
                }
            }
        }
        // O relógio da abertura fica parado em 16 ms (de 2.800): só o tempo real passa até a resposta chegar.
        rule.mainClock.advanceTimeBy(16)
        rule.waitUntil(timeoutMillis = 10_000) { resolvida.get() }

        assertEquals("a chamada saiu uma vez", 1, chamadas.get())
        assertTrue("a chamada saiu com a abertura cobrindo o app", cobrindoNaChamada.get())
        // A resposta já voltou e a abertura ainda está na tela: ela não segurou nada.
        rule.onNodeWithContentDescription("Frila").assertExists()
        cliente.http.close()
    }

    @Test
    fun `um toque leva direto ao app, ja carregado`() {
        val carregou = AtomicBoolean(false)
        rule.mainClock.autoAdvance = false
        rule.setContent {
            FrilaTheme {
                AberturaAnimada(ligada = true, reduzirMovimento = false) {
                    LaunchedEffect(Unit) { carregou.set(true) }
                    Text("conteudo do app")
                }
            }
        }
        rule.mainClock.advanceTimeBy(400)
        assertTrue(carregou.get())
        rule.onNodeWithContentDescription("Frila").performClick()
        rule.mainClock.advanceTimeBy(600)
        rule.waitForIdle()
        rule.onNodeWithContentDescription("Frila").assertDoesNotExist()
        rule.onNodeWithText("conteudo do app").assertIsDisplayed()
    }
}
