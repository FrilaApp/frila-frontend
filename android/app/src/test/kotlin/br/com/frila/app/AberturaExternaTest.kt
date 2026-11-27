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
}
