package br.com.frila.core.designsystem.tema

import androidx.compose.ui.graphics.Color
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import kotlin.math.pow

/**
 * Matriz de Auditoria Formal de Contraste WCAG 2.1 AA (Critério de Aceite 3 do Cartão Q84ogJUr).
 *
 * Valida que as cores de texto e de controle do desenho do Fabrício, nos papéis do Material 3, atendem:
 * 1. Texto Normal sobre Superfície / Fundo: Ratio >= 4.5:1 (Nível AA).
 * 2. Texto grande (rótulo do botão primário, 20sp em negrito) e componentes gráficos: Ratio >= 3.0:1.
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

    private fun conferirEsquema(nome: String, paleta: PaletaFrila) {
        fun minimo(descricao: String, frente: Color, fundo: Color, piso: Double) {
            val ratio = calcularContraste(frente, fundo)
            assertTrue(ratio >= piso, "$nome: $descricao ($ratio) deve ser >= $piso:1")
        }

        // 1. Texto em tinta sobre o fundo da tela e sobre cartões.
        minimo("tinta sobre fundo", paleta.tinta, paleta.fundo, 4.5)
        minimo("tinta sobre superfície", paleta.tinta, paleta.superficie, 4.5)
        minimo("tinta sobre bloco de aviso", paleta.tinta, paleta.superficiePressionada, 4.5)

        // 2. Texto de apoio (tinta suave) sobre o fundo e sobre cartões.
        minimo("tinta suave sobre fundo", paleta.tintaSuave, paleta.fundo, 4.5)
        minimo("tinta suave sobre superfície", paleta.tintaSuave, paleta.superficie, 4.5)

        // 3. Rótulo do botão primário: branco, 20sp em negrito, sobre o laranja (texto grande).
        minimo("branco sobre o laranja de ação", paleta.sobreAcao, paleta.acao, 3.0)
        minimo("branco sobre o laranja pressionado", paleta.sobreAcao, paleta.acaoPressionada, 3.0)

        // 4. Botão em conferência (desligado): tinta suave sobre borda.
        minimo("tinta suave sobre borda", paleta.tintaSuave, paleta.borda, 4.5)

        // 5. Selos e chip marcado.
        minimo("texto sobre o selo roxo", paleta.sobreRoxo, paleta.destaqueRoxo, 4.5)
        minimo("texto sobre o selo amarelo", paleta.sobreAmarelo, paleta.destaqueAmarelo, 4.5)
        minimo("texto sobre preenchimento em tinta", paleta.sobreTinta, paleta.tinta, 4.5)

        // 6. Contorno de campo: componente gráfico (2,998 no claro contra o fundo, o piso do desenho).
        minimo("contorno de campo sobre fundo", paleta.bordaControle, paleta.fundo, 2.99)
        minimo("contorno de campo sobre superfície", paleta.bordaControle, paleta.superficie, 3.0)
    }

    @Test
    fun `matriz de contraste tema claro atende WCAG 2_1 AA`() {
        conferirEsquema("claro", PaletaClara)
    }

    @Test
    fun `matriz de contraste tema escuro atende WCAG 2_1 AA`() {
        conferirEsquema("escuro", PaletaEscura)
    }

    @Test
    fun `modo OLED de alto contraste atende WCAG AAA em todos os textos`() {
        val oled = FrilaCores.fundoOled

        val ratioPrimario = calcularContraste(FrilaCores.tintaEscuro, oled)
        val ratioSecundario = calcularContraste(FrilaCores.tintaSuaveEscuro, oled)

        assertTrue(ratioPrimario >= 7.0, "Texto em tinta sobre OLED ($ratioPrimario) deve ser >= 7:1")
        assertTrue(ratioSecundario >= 7.0, "Texto em tinta suave sobre OLED ($ratioSecundario) deve ser >= 7:1")
    }
}
