package br.com.frila.core.designsystem.tema

import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performTextInput
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Testes de [FrilaTheme] que dependem de composição real (Robolectric) — seleção de esquema
 * (claro/escuro/OLED) lida de dentro de `MaterialTheme.colorScheme`, e preservação de estado de
 * UI ao trocar `temaEscuro`/`modoOled` em runtime (critério de aceite do cartão 912WNW1M).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class FrilaThemeComposeTest {

    @get:Rule
    val compose = createComposeRule()

    private fun backgroundDoTema(temaEscuro: Boolean, modoOled: Boolean = false): Color {
        var corCapturada: Color? = null
        compose.setContent {
            FrilaTheme(temaEscuro = temaEscuro, modoOled = modoOled) {
                corCapturada = MaterialTheme.colorScheme.background
            }
        }
        compose.waitForIdle()
        return corCapturada!!
    }

    @Test
    fun `tema claro usa EsquemaClaro`() {
        assertEquals(FrilaCores.surfaceLight, backgroundDoTema(temaEscuro = false))
    }

    @Test
    fun `tema escuro sem OLED usa EsquemaEscuro`() {
        assertEquals(FrilaCores.surfaceDark, backgroundDoTema(temaEscuro = true, modoOled = false))
    }

    @Test
    fun `tema escuro com OLED usa EsquemaEscuroOled (preto puro)`() {
        assertEquals(FrilaCores.surfaceOled, backgroundDoTema(temaEscuro = true, modoOled = true))
    }

    @Test
    fun `modoOled no tema claro nao tem efeito`() {
        // modoOled só se aplica no escuro — no claro, o fundo continua surfaceLight.
        assertEquals(FrilaCores.surfaceLight, backgroundDoTema(temaEscuro = false, modoOled = true))
    }

    @Test
    fun `alternar temaEscuro e modoOled preserva texto digitado em campo de texto`() {
        var temaEscuro by mutableStateOf(false)
        var modoOled by mutableStateOf(false)

        compose.setContent {
            FrilaTheme(temaEscuro = temaEscuro, modoOled = modoOled) {
                var texto by remember { mutableStateOf("") }
                BasicTextField(
                    value = texto,
                    onValueChange = { texto = it },
                    modifier = Modifier.testTag("campo-de-teste"),
                )
            }
        }

        compose.onNodeWithTag("campo-de-teste").performTextInput("ocorrência no turno")
        compose.onNodeWithTag("campo-de-teste").assertTextEquals("ocorrência no turno")

        temaEscuro = true
        compose.waitForIdle()
        compose.onNodeWithTag("campo-de-teste").assertTextEquals("ocorrência no turno")

        modoOled = true
        compose.waitForIdle()
        compose.onNodeWithTag("campo-de-teste").assertTextEquals("ocorrência no turno")

        temaEscuro = false
        modoOled = false
        compose.waitForIdle()
        compose.onNodeWithTag("campo-de-teste").assertTextEquals("ocorrência no turno")
    }
}
