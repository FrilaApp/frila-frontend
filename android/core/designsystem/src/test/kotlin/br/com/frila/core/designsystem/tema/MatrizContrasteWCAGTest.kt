package br.com.frila.core.designsystem.tema

import androidx.compose.ui.graphics.Color
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import kotlin.math.pow

/**
 * Matriz de Auditoria Formal de Contraste WCAG 2.1 AA (Critério de Aceite 3 do Cartão Q84ogJUr).
 *
 * Valida que todas as cores de texto e controles mapeados do iOS para Material 3 atendem:
 * 1. Texto Normal sobre Superfície / Fundo: Ratio >= 4.5:1 (Nível AA).
 * 2. Texto em Destaque / Ícones Essenciais: Ratio >= 3.0:1 (Nível AA para componentes gráficos).
 * 3. Ambos os temas validados: Claro (Light) e Escuro (Dark).
 *
 * Cálculo realizado por luminância relativa sRGB -> Linear segundo especificação W3C WCAG 2.1.
 */
class MatrizContrasteWCAGTest {

    private fun srgbParaLinear(c: Float): Double {
        val cd = c.toDouble()
        return if (cd <= 0.04045) cd / 12.92 else ((cd + 0.055) / 1.055).pow(2.4)
    }

    private fun luminanciaRelativa(cor: Color): Double {
        val r = srgbParaLinear(cor.red)
        val g = srgbParaLinear(cor.green)
        val b = srgbParaLinear(cor.blue)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    private fun calcularContraste(frente: Color, fundo: Color): Double {
        val l1 = luminanciaRelativa(frente)
        val l2 = luminanciaRelativa(fundo)
        val maisClaro = maxOf(l1, l2)
        val maisEscuro = minOf(l1, l2)
        return (maisClaro + 0.05) / (maisEscuro + 0.05)
    }

    @Test
    fun `matriz de contraste tema claro atende WCAG 2_1 AA`() {
        val fundo = FrilaCores.surfaceLight
        val superficie = FrilaCores.surfaceElevatedLight

        // 1. Texto primário sobre fundo agrupado
        val ratioTextoPrimarioFundo = calcularContraste(FrilaCores.textPrimaryLight, fundo)
        assertTrue(ratioTextoPrimarioFundo >= 4.5, "Texto primário sobre fundo claro ($ratioTextoPrimarioFundo) deve ser >= 4.5:1")

        // 2. Texto primário sobre superfície de cartões
        val ratioTextoPrimarioCard = calcularContraste(FrilaCores.textPrimaryLight, superficie)
        assertTrue(ratioTextoPrimarioCard >= 4.5, "Texto primário sobre cartão claro ($ratioTextoPrimarioCard) deve ser >= 4.5:1")

        // 3. Texto secundário sobre superfície
        val ratioTextoSecundarioCard = calcularContraste(FrilaCores.textSecondaryLight, superficie)
        assertTrue(ratioTextoSecundarioCard >= 4.5, "Texto secundário sobre cartão claro ($ratioTextoSecundarioCard) deve ser >= 4.5:1")

        // 4. Texto OnPrimary sobre botão principal BrandPrimary
        val ratioBotaoPrimario = calcularContraste(FrilaCores.brandOnPrimaryLight, FrilaCores.brandPrimaryLight)
        assertTrue(ratioBotaoPrimario >= 4.5, "Texto de botão primário claro ($ratioBotaoPrimario) deve ser >= 4.5:1")

        // 5. Cor semântica de Sucesso sobre superfície
        val ratioSucesso = calcularContraste(FrilaCores.successLight, superficie)
        assertTrue(ratioSucesso >= 4.5, "Sucesso sobre cartão claro ($ratioSucesso) deve ser >= 4.5:1")

        // 6. Cor semântica de Perigo sobre superfície
        val ratioPerigo = calcularContraste(FrilaCores.dangerLight, superficie)
        assertTrue(ratioPerigo >= 4.5, "Perigo sobre cartão claro ($ratioPerigo) deve ser >= 4.5:1")

        // 7. Cor semântica de Atenção / Aviso sobre superfície
        val ratioAviso = calcularContraste(FrilaCores.warningLight, superficie)
        assertTrue(ratioAviso >= 4.5, "Aviso sobre cartão claro ($ratioAviso) deve ser >= 4.5:1")
    }

    @Test
    fun `matriz de contraste tema escuro atende WCAG 2_1 AA`() {
        val fundo = FrilaCores.surfaceDark
        val superficie = FrilaCores.surfaceElevatedDark

        // 1. Texto primário sobre fundo escuro
        val ratioTextoPrimarioFundo = calcularContraste(FrilaCores.textPrimaryDark, fundo)
        assertTrue(ratioTextoPrimarioFundo >= 4.5, "Texto primário sobre fundo escuro ($ratioTextoPrimarioFundo) deve ser >= 4.5:1")

        // 2. Texto primário sobre superfície de cartões escuros
        val ratioTextoPrimarioCard = calcularContraste(FrilaCores.textPrimaryDark, superficie)
        assertTrue(ratioTextoPrimarioCard >= 4.5, "Texto primário sobre cartão escuro ($ratioTextoPrimarioCard) deve ser >= 4.5:1")

        // 3. Texto secundário sobre superfície escura
        val ratioTextoSecundarioCard = calcularContraste(FrilaCores.textSecondaryDark, superficie)
        assertTrue(ratioTextoSecundarioCard >= 4.5, "Texto secundário sobre cartão escuro ($ratioTextoSecundarioCard) deve ser >= 4.5:1")

        // 4. Texto OnPrimary sobre botão principal BrandPrimary
        val ratioBotaoPrimario = calcularContraste(FrilaCores.brandOnPrimaryDark, FrilaCores.brandPrimaryDark)
        assertTrue(ratioBotaoPrimario >= 4.5, "Texto de botão primário escuro ($ratioBotaoPrimario) deve ser >= 4.5:1")

        // 5. Cor semântica de Sucesso sobre superfície escura
        val ratioSucesso = calcularContraste(FrilaCores.successDark, superficie)
        assertTrue(ratioSucesso >= 4.5, "Sucesso sobre cartão escuro ($ratioSucesso) deve ser >= 4.5:1")

        // 6. Cor semântica de Perigo sobre superfície escura
        val ratioPerigo = calcularContraste(FrilaCores.dangerDark, superficie)
        assertTrue(ratioPerigo >= 4.5, "Perigo sobre cartão escuro ($ratioPerigo) deve ser >= 4.5:1")

        // 7. Cor semântica de Atenção / Aviso sobre superfície escura
        val ratioAviso = calcularContraste(FrilaCores.warningDark, superficie)
        assertTrue(ratioAviso >= 4.5, "Aviso sobre cartão escuro ($ratioAviso) deve ser >= 4.5:1")
    }

    @Test
    fun `modo OLED de alto contraste atende WCAG AAA em todos os textos`() {
        val oled = FrilaCores.surfaceOled

        val ratioPrimario = calcularContraste(FrilaCores.textPrimaryDark, oled)
        val ratioSecundario = calcularContraste(FrilaCores.textSecondaryDark, oled)

        assertTrue(ratioPrimario >= 7.0, "Texto primário sobre preto OLED ($ratioPrimario) deve atender AAA (>= 7.0)")
        assertTrue(ratioSecundario >= 7.0, "Texto secundário sobre preto OLED ($ratioSecundario) deve atender AAA (>= 7.0)")
    }
}
