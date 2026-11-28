package br.com.frila.app

import android.app.Application
import android.content.ActivityNotFoundException
import android.content.ClipboardManager
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Cartão B7bqwHxg: abrir e-mail, discador ou navegador sem app no aparelho devolve `false` e o aviso mostra o endereço. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AberturaExternaTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // C0-6b: testReleaseUnitTest

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private val aplicacao: Context = ApplicationProvider.getApplicationContext()
    private val email = Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:suporte@frilabr.com"))

    private fun contexto(falha: Exception?, disparados: MutableList<Intent> = mutableListOf()) = object : ContextWrapper(aplicacao) {
        override fun startActivity(intent: Intent) {
            falha?.let { throw it }
            disparados += intent
        }
    }

    @Test
    fun `sem app que trate o intent devolve false sem lancar`() {
        assertFalse(abrirExterno(contexto(ActivityNotFoundException("sem app de e-mail")), email))
    }

    @Test
    fun `recusa do sistema tambem devolve false`() {
        assertFalse(abrirExterno(contexto(SecurityException("recusado")), email))
    }

    @Test
    fun `com app disponivel dispara o intent e devolve true`() {
        val disparados = mutableListOf<Intent>()
        assertTrue(abrirExterno(contexto(falha = null, disparados), email))
        assertEquals(listOf(email), disparados)
    }

    @Test
    fun `o navegador do login social devolve false sem navegador e abre a url com navegador`() {
        val url = "https://frila.supabase.co/auth/v1/authorize?provider=google"
        assertFalse(abrirNavegadorLoginSocial(contexto(ActivityNotFoundException("sem navegador")), url))

        val disparados = mutableListOf<Intent>()
        assertTrue(abrirNavegadorLoginSocial(contexto(falha = null, disparados), url))
        val aberto = disparados.single()
        assertEquals(Intent.ACTION_VIEW, aberto.action)
        assertEquals(url, aberto.dataString)
        assertTrue(aberto.hasCategory(Intent.CATEGORY_BROWSABLE))
    }

    @Test
    fun `o aviso mostra o endereco, copia para a area de transferencia e fecha`() {
        val aviso = AvisoDeAberturaExterna.semEmail("suporte@frilabr.com")
        rule.setContent {
            var aberto by remember { mutableStateOf(true) }
            if (aberto) DialogoDeAberturaExterna(aviso = aviso, aoFechar = { aberto = false })
        }

        rule.onNodeWithText(TextosAberturaExterna.TITULO).assertExists()
        rule.onNodeWithText(aviso.mensagem).assertExists()
        rule.onNodeWithTag("aviso-abertura-externa-endereco").assertExists()
        rule.onNodeWithText("suporte@frilabr.com").assertExists()

        rule.onNodeWithText(TextosAberturaExterna.COPIAR).performClick()

        rule.onAllNodesWithTag("aviso-abertura-externa").assertCountEquals(0)
        val area = aplicacao.getSystemService(ClipboardManager::class.java)
        assertEquals("suporte@frilabr.com", area.primaryClip?.getItemAt(0)?.text?.toString())
    }

    @Test
    fun `o aviso do login social so explica, sem endereco para copiar`() {
        rule.setContent {
            DialogoDeAberturaExterna(aviso = AvisoDeAberturaExterna.semNavegadorParaEntrar, aoFechar = {})
        }

        rule.onNodeWithText(AvisoDeAberturaExterna.semNavegadorParaEntrar.mensagem).assertExists()
        rule.onAllNodesWithTag("aviso-abertura-externa-endereco").assertCountEquals(0)
        rule.onNodeWithText(TextosAberturaExterna.ENTENDI).assertExists()
    }

    // ── Cartão bepD1DEV: a loja do app, com o navegador de reserva e o endereço para copiar ─────────────────────────────────

    /** Um contexto que recusa os intents cujo esquema está em [recusados] e guarda os que passaram. */
    private fun contextoQueRecusa(vararg recusados: String, abertos: MutableList<Intent> = mutableListOf()) =
        object : ContextWrapper(aplicacao) {
            override fun startActivity(intent: Intent) {
                if (intent.data?.scheme in recusados) throw ActivityNotFoundException(intent.data.toString())
                abertos += intent
            }
        }

    @Test
    fun `a loja abre pelo market e nao aciona o navegador`() {
        val abertos = mutableListOf<Intent>()

        val aviso = abrirLojaDoApp(contextoQueRecusa(abertos = abertos), "br.com.frila")

        assertEquals(null, aviso)
        assertEquals(listOf("market://details?id=br.com.frila"), abertos.map { it.data.toString() })
    }

    @Test
    fun `sem loja abre a pagina da loja no navegador`() {
        val abertos = mutableListOf<Intent>()

        val aviso = abrirLojaDoApp(contextoQueRecusa("market", abertos = abertos), "br.com.frila")

        assertEquals(null, aviso)
        assertEquals(listOf("https://play.google.com/store/apps/details?id=br.com.frila"), abertos.map { it.data.toString() })
    }

    @Test
    fun `sem loja e sem navegador devolve o aviso com o endereco da loja, sem lancar`() {
        val aviso = abrirLojaDoApp(contextoQueRecusa("market", "https"), "br.com.frila")

        assertEquals("https://play.google.com/store/apps/details?id=br.com.frila", aviso?.paraCopiar)
        assertTrue(aviso!!.mensagem.contains("loja"))
    }

    @Test
    fun `recusa do sistema tambem vira aviso, nao excecao`() {
        val recusa = object : ContextWrapper(aplicacao) {
            override fun startActivity(intent: Intent) { throw SecurityException("recusado") }
        }

        assertEquals("https://play.google.com/store/apps/details?id=x", abrirLojaDoApp(recusa, "x")?.paraCopiar)
    }

    @Test
    fun `ligar abre o discador com o numero, sem exigir a permissao de chamada`() {
        val intent = intentParaLigar("190")

        assertEquals(Intent.ACTION_DIAL, intent.action)
        assertEquals(Uri.parse("tel:190"), intent.data)
        assertTrue(intent.flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0)
    }
}
