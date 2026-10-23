package br.com.frila.core.designsystem.tema

import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotEquals
import org.junit.jupiter.api.Test

class FrilaThemeTest {

    @Test
    fun `EsquemaClaro aplica exatamente os tokens claros`() {
        assertEquals(FrilaCores.brandPrimaryLight, EsquemaClaro.primary)
        assertEquals(FrilaCores.brandOnPrimaryLight, EsquemaClaro.onPrimary)
        assertEquals(FrilaCores.surfaceLight, EsquemaClaro.background)
        assertEquals(FrilaCores.textPrimaryLight, EsquemaClaro.onBackground)
        assertEquals(FrilaCores.surfaceElevatedLight, EsquemaClaro.surface)
        assertEquals(FrilaCores.textPrimaryLight, EsquemaClaro.onSurface)
        assertEquals(FrilaCores.surfaceElevatedLight, EsquemaClaro.surfaceVariant)
        assertEquals(FrilaCores.textSecondaryLight, EsquemaClaro.onSurfaceVariant)
        assertEquals(FrilaCores.dangerLight, EsquemaClaro.error)
        assertEquals(FrilaCores.controlBorderLight, EsquemaClaro.outline)
        assertEquals(FrilaCores.hairlineLight, EsquemaClaro.outlineVariant)
        assertEquals(FrilaCores.successLight, EsquemaClaro.tertiary)
    }

    @Test
    fun `EsquemaEscuro aplica exatamente os tokens escuros`() {
        assertEquals(FrilaCores.brandPrimaryDark, EsquemaEscuro.primary)
        assertEquals(FrilaCores.brandOnPrimaryDark, EsquemaEscuro.onPrimary)
        assertEquals(FrilaCores.surfaceDark, EsquemaEscuro.background)
        assertEquals(FrilaCores.textPrimaryDark, EsquemaEscuro.onBackground)
        assertEquals(FrilaCores.surfaceElevatedDark, EsquemaEscuro.surface)
        assertEquals(FrilaCores.textPrimaryDark, EsquemaEscuro.onSurface)
        assertEquals(FrilaCores.surfaceElevatedDark, EsquemaEscuro.surfaceVariant)
        assertEquals(FrilaCores.textSecondaryDark, EsquemaEscuro.onSurfaceVariant)
        assertEquals(FrilaCores.dangerDark, EsquemaEscuro.error)
        assertEquals(FrilaCores.controlBorderDark, EsquemaEscuro.outline)
        assertEquals(FrilaCores.hairlineDark, EsquemaEscuro.outlineVariant)
        assertEquals(FrilaCores.successDark, EsquemaEscuro.tertiary)
    }

    @Test
    fun `extensoes resolvem tokens claros`() {
        assertEquals(FrilaCores.brandAccentLight, EsquemaClaro.brandAccent)
        assertEquals(FrilaCores.warningLight, EsquemaClaro.warning)
        assertEquals(FrilaCores.hairlineLight, EsquemaClaro.hairline)
        assertEquals(FrilaCores.controlBorderLight, EsquemaClaro.controlBorder)
        assertEquals(FrilaCores.surfaceElevatedLight, EsquemaClaro.surfaceElevated)
    }

    @Test
    fun `extensoes resolvem tokens escuros`() {
        assertEquals(FrilaCores.brandAccentDark, EsquemaEscuro.brandAccent)
        assertEquals(FrilaCores.warningDark, EsquemaEscuro.warning)
        assertEquals(FrilaCores.hairlineDark, EsquemaEscuro.hairline)
        assertEquals(FrilaCores.controlBorderDark, EsquemaEscuro.controlBorder)
        assertEquals(FrilaCores.surfaceElevatedDark, EsquemaEscuro.surfaceElevated)
    }

    @Test
    fun `BrandAccent nunca e primary nem surface em nenhum tema`() {
        assertNotEquals(EsquemaClaro.primary, EsquemaClaro.brandAccent)
        assertNotEquals(EsquemaClaro.surface, EsquemaClaro.brandAccent)
        assertNotEquals(EsquemaEscuro.primary, EsquemaEscuro.brandAccent)
        assertNotEquals(EsquemaEscuro.surface, EsquemaEscuro.brandAccent)
    }

    @Test
    fun `cores dinamicas preservam CTA e erro da marca nos dois temas`() {
        val secondaryDinamico = Color(0xFF123456)
        val esquemaDinamico = lightColorScheme(
            primary = Color.Magenta,
            onPrimary = Color.Yellow,
            error = Color.Cyan,
            secondary = secondaryDinamico,
        )

        val claro = esquemaDinamico.comCoresCriticasFrila(temaEscuro = false)
        val escuro = esquemaDinamico.comCoresCriticasFrila(temaEscuro = true)

        assertEquals(FrilaCores.brandPrimaryLight, claro.primary)
        assertEquals(FrilaCores.brandOnPrimaryLight, claro.onPrimary)
        assertEquals(FrilaCores.dangerLight, claro.error)
        assertEquals(secondaryDinamico, claro.secondary)
        assertEquals(FrilaCores.brandPrimaryDark, escuro.primary)
        assertEquals(FrilaCores.brandOnPrimaryDark, escuro.onPrimary)
        assertEquals(FrilaCores.dangerDark, escuro.error)
        assertEquals(secondaryDinamico, escuro.secondary)
    }
}
