package br.com.frila.core.designsystem.tema

import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performTextInput
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
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
    @Config(sdk = [34])
    fun `dynamicColor na API 31+ ativa esquema dinamico preservando cores criticas da marca`() {
        var scheme: ColorScheme? = null
        var dynamicEsperado: ColorScheme? = null
        compose.setContent {
            val ctx = LocalContext.current
            dynamicEsperado = dynamicLightColorScheme(ctx)
            FrilaTheme(temaEscuro = false, dynamicColor = true) {
                scheme = MaterialTheme.colorScheme
            }
        }
        compose.waitForIdle()
        // As cores críticas da marca devem sempre ser preservadas mesmo com dynamicColor ativo (RNF10)
        assertEquals(FrilaCores.brandPrimaryLight, scheme!!.primary)
        assertEquals(FrilaCores.brandOnPrimaryLight, scheme!!.onPrimary)
        assertEquals(FrilaCores.dangerLight, scheme!!.error)

        // Papéis dinâmicos vêm da paleta do sistema (Material You) e distinguem da estática
        assertEquals(dynamicEsperado!!.secondary, scheme!!.secondary)
        assertEquals(dynamicEsperado!!.onSecondary, scheme!!.onSecondary)
        assertNotEquals(EsquemaClaro.secondary, scheme!!.secondary)
    }

    @Test
    @Config(sdk = [34])
    fun `dynamicColor no tema escuro na API 31+ preserva cores criticas escuras`() {
        var scheme: ColorScheme? = null
        var dynamicEsperado: ColorScheme? = null
        compose.setContent {
            val ctx = LocalContext.current
            dynamicEsperado = dynamicDarkColorScheme(ctx)
            FrilaTheme(temaEscuro = true, dynamicColor = true) {
                scheme = MaterialTheme.colorScheme
            }
        }
        compose.waitForIdle()
        assertEquals(FrilaCores.brandPrimaryDark, scheme!!.primary)
        assertEquals(FrilaCores.brandOnPrimaryDark, scheme!!.onPrimary)
        assertEquals(FrilaCores.dangerDark, scheme!!.error)

        // Papéis dinâmicos vêm da paleta escura do sistema (Material You) e distinguem da estática
        assertEquals(dynamicEsperado!!.secondary, scheme!!.secondary)
        assertEquals(dynamicEsperado!!.onSecondary, scheme!!.onSecondary)
        assertNotEquals(EsquemaEscuro.secondary, scheme!!.secondary)
    }

    @Test
    @Config(sdk = [28])
    fun `dynamicColor na API 28 faz fallback seguro para EsquemaClaro estatico da Frila`() {
        var scheme: ColorScheme? = null
        compose.setContent {
            FrilaTheme(temaEscuro = false, dynamicColor = true) {
                scheme = MaterialTheme.colorScheme
            }
        }
        compose.waitForIdle()
        assertEquals(FrilaCores.surfaceLight, scheme!!.background)
        assertEquals(FrilaCores.brandPrimaryLight, scheme!!.primary)
        assertEquals(FrilaCores.surfaceElevatedLight, scheme!!.surface)
    }

    @Test
    @Config(sdk = [28])
    fun `dynamicColor no escuro na API 28 faz fallback seguro para EsquemaEscuro estatico da Frila`() {
        var scheme: ColorScheme? = null
        compose.setContent {
            FrilaTheme(temaEscuro = true, dynamicColor = true) {
                scheme = MaterialTheme.colorScheme
            }
        }
        compose.waitForIdle()
        assertEquals(FrilaCores.surfaceDark, scheme!!.background)
        assertEquals(FrilaCores.brandPrimaryDark, scheme!!.primary)
        assertEquals(FrilaCores.surfaceElevatedDark, scheme!!.surface)
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
