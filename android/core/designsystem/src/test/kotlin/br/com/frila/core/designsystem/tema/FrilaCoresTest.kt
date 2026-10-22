package br.com.frila.core.designsystem.tema

import androidx.compose.ui.graphics.Color
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import kotlin.math.pow

/**
 * Confere os valores de cor contra o catálogo de cores medido do iOS
 * (cada `Contents.json` de cor em `iOS/Resources/DesignSystem.xcassets`) e o contraste WCAG mínimo
 * de texto sobre fundo (AA, 4.5:1 para texto normal).
 *
 * Contraste é calculado aqui pela fórmula WCAG (luminância relativa sRGB→linear), sem depender
 * de `android.graphics.Color` nem de nenhuma chamada de framework Android — roda em JVM pura.
 */
class FrilaCoresTest {

    private fun paraLinear(componenteSrgb: Float): Double {
        val c = componenteSrgb.toDouble()
        return if (c <= 0.04045) c / 12.92 else ((c + 0.055) / 1.055).pow(2.4)
    }

    private fun luminanciaRelativa(cor: Color): Double {
        val r = paraLinear(cor.red)
        val g = paraLinear(cor.green)
        val b = paraLinear(cor.blue)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    private fun contraste(a: Color, b: Color): Double {
        val la = luminanciaRelativa(a)
        val lb = luminanciaRelativa(b)
        val maior = maxOf(la, lb)
        val menor = minOf(la, lb)
        return (maior + 0.05) / (menor + 0.05)
    }

    @Test
    fun `BrandAccent claro e exatamente EA5A36 (terracota da marca)`() {
        assertEquals(Color(0xFFEA5A36), FrilaCores.brandAccentLight)
    }

    @Test
    fun `BrandPrimary claro e BrandOnPrimary escuro sao exatamente a mesma cor`() {
        // Medido: ambos vêm do mesmo componente sRGB (0.067, 0.067, 0.063) no catálogo do iOS.
        assertEquals(FrilaCores.brandPrimaryLight, FrilaCores.brandOnPrimaryDark)
    }

    @Test
    fun `BrandOnPrimary claro e branco puro, BrandPrimary escuro e quase branco (nao identicos)`() {
        // Medido: BrandOnPrimary claro é branco puro (1,1,1); BrandPrimary escuro é um branco
        // levemente quente (0.961, 0.957, 0.941) — por design, não são a mesma cor.
        assertEquals(Color(0xFFFFFFFF), FrilaCores.brandOnPrimaryLight)
        assertTrue(luminanciaRelativa(FrilaCores.brandPrimaryDark) > 0.85)
        assertTrue(FrilaCores.brandPrimaryDark != FrilaCores.brandOnPrimaryLight)
    }

    @Test
    fun `TextSecondary sobre Surface atinge contraste AA (4_5 a 1) no claro`() {
        val razao = contraste(FrilaCores.textSecondaryLight, FrilaCores.surfaceLight)

        assertTrue(razao >= 4.5, "contraste medido foi $razao, abaixo do mínimo AA de 4.5:1")
    }

    @Test
    fun `TextSecondary sobre Surface atinge contraste AA (4_5 a 1) no escuro`() {
        val razao = contraste(FrilaCores.textSecondaryDark, FrilaCores.surfaceDark)

        assertTrue(razao >= 4.5, "contraste medido foi $razao, abaixo do mínimo AA de 4.5:1")
    }

    @Test
    fun `TextPrimary sobre Surface atinge contraste AAA (7 a 1) no claro`() {
        val razao = contraste(FrilaCores.textPrimaryLight, FrilaCores.surfaceLight)

        assertTrue(razao >= 7.0, "contraste medido foi $razao, abaixo do mínimo AAA de 7:1")
    }

    @Test
    fun `BrandOnPrimario sobre BrandPrimario atinge contraste AAA em ambos os temas`() {
        assertTrue(contraste(FrilaCores.brandOnPrimaryLight, FrilaCores.brandPrimaryLight) >= 7.0)
        assertTrue(contraste(FrilaCores.brandOnPrimaryDark, FrilaCores.brandPrimaryDark) >= 7.0)
    }

    @Test
    fun `Hairline e ControlBorder sao translucidos, nunca opacos`() {
        assertTrue(FrilaCores.hairlineLight.alpha < 1f)
        assertTrue(FrilaCores.hairlineDark.alpha < 1f)
        assertTrue(FrilaCores.controlBorderLight.alpha < 1f)
        assertTrue(FrilaCores.controlBorderDark.alpha < 1f)
    }

    @Test
    fun `Danger nao e igual a Success nem a Warning em nenhum tema`() {
        assertTrue(FrilaCores.dangerLight != FrilaCores.successLight)
        assertTrue(FrilaCores.dangerLight != FrilaCores.warningLight)
        assertTrue(FrilaCores.dangerDark != FrilaCores.successDark)
        assertTrue(FrilaCores.dangerDark != FrilaCores.warningDark)
    }
}
