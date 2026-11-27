package br.com.frila.core.designsystem.componentes

import android.content.Intent
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowToast

/** Cartão zjiTWbAP: o link `geo:` do "Ver no mapa" e o botão que o abre. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class VerNoMapaTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `endereco com virgula e acento vai codificado, sem coordenadas procura so o texto`() {
        assertEquals(
            "geo:0,0?q=Bar%20do%20Z%C3%A9%2C%20CLN%20201%20Bloco%20B%2C%20Asa%20Norte",
            linkDoMapa("Bar do Zé, CLN 201 Bloco B, Asa Norte"),
        )
    }

    @Test
    fun `com coordenadas o mapa centra no ponto e procura o texto ali, com ponto decimal`() {
        assertEquals(
            "geo:-15.794200,-47.882200?q=Quadra%205%20%26%206%2C%20Bras%C3%ADlia",
            linkDoMapa("  Quadra 5 & 6, Brasília ", latitude = -15.7942, longitude = -47.8822),
        )
    }

    @Test
    fun `so uma das coordenadas nao basta para centrar`() {
        assertEquals("geo:0,0?q=SQN%20108", linkDoMapa("SQN 108", latitude = -15.7942, longitude = null))
    }

    @Test
    fun `tocar em Ver no mapa abre o link geo no app de mapas`() {
        val link = linkDoMapa("Bar do Zé, SQN 108")
        compose.setContent { FrilaTheme { BotaoVerNoMapa(link = link) } }

        compose.onNodeWithTag(TextosVerNoMapa.TAG).performClick()
        compose.waitForIdle()

        val aberto = shadowOf(RuntimeEnvironment.getApplication()).nextStartedActivity
        assertEquals(Intent.ACTION_VIEW, aberto.action)
        assertEquals(link, aberto.dataString)
    }

    @Test
    fun `sem app que abra o mapa avisa, em vez de nao fazer nada`() {
        val abertos = mutableListOf<String>()
        compose.setContent {
            FrilaTheme { BotaoVerNoMapa(link = "geo:0,0?q=x", abrir = { _, link -> abertos += link; false }) }
        }

        compose.onNodeWithTag(TextosVerNoMapa.TAG).performClick()
        compose.waitForIdle()

        assertEquals(listOf("geo:0,0?q=x"), abertos)
        assertEquals(TextosVerNoMapa.SEM_APP, ShadowToast.getTextOfLatestToast())
        assertNull(shadowOf(RuntimeEnvironment.getApplication()).nextStartedActivity)
    }
}
