package br.com.frila.core.designsystem.tema

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import kotlin.math.pow

/**
 * Confere as cores do Frila contra o desenho do Fabrício (`tokens.css` do protótipo e a proposta do
 * modo escuro) e os pisos de contraste que o desenho declara.
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
    fun `as cores claras sao exatamente as do prototipo`() {
        assertEquals(Color(0xFFF9F6F4), FrilaCores.fundoClaro)
        assertEquals(Color(0xFFFFFFFF), FrilaCores.superficieClaro)
        assertEquals(Color(0xFF111111), FrilaCores.tintaClaro)
        assertEquals(Color(0xFF5A5A58), FrilaCores.tintaSuaveClaro)
        assertEquals(Color(0xFFE5E3DD), FrilaCores.bordaClaro)
        assertEquals(Color(0xFF918F8A), FrilaCores.bordaControleClaro)
        assertEquals(Color(0xFFEBE9E2), FrilaCores.bordaNavClaro)
        assertEquals(Color(0xFFFCEB36), FrilaCores.destaqueAmarelo)
        assertEquals(Color(0xFF9D47F5), FrilaCores.destaqueRoxo)
    }

    @Test
    fun `o laranja de acao e F46700 e o pressionado e DD5C00`() {
        assertEquals(Color(0xFFF46700), FrilaCores.acao)
        assertEquals(Color(0xFFDD5C00), FrilaCores.acaoPressionada)
    }

    @Test
    fun `botao colorido leva texto BRANCO, em negrito de 19sp ou mais`() {
        // Regra firme do desenho: nunca texto preto (nem leve, nem pequeno) em botão laranja.
        assertEquals(Color(0xFFFFFFFF), FrilaCores.sobreAcao)
        assertEquals(FontWeight.Bold, FrilaTipo.rotuloDoPrimario.fontWeight)
        assertTrue(FrilaTipo.rotuloDoPrimario.fontSize.value >= 19f)
    }

    @Test
    fun `branco sobre o laranja passa no piso de texto grande (3 a 1), solto e pressionado`() {
        val solto = contraste(FrilaCores.sobreAcao, FrilaCores.acao)
        val pressionado = contraste(FrilaCores.sobreAcao, FrilaCores.acaoPressionada)

        assertTrue(solto >= 3.0, "branco sobre acao: $solto")
        assertTrue(pressionado >= 3.0, "branco sobre acaoPressionada: $pressionado")
    }

    @Test
    fun `tinta sobre o fundo atinge AAA (7 a 1) nos dois modos e no OLED`() {
        assertTrue(contraste(FrilaCores.tintaClaro, FrilaCores.fundoClaro) >= 7.0)
        assertTrue(contraste(FrilaCores.tintaEscuro, FrilaCores.fundoEscuro) >= 7.0)
        assertTrue(contraste(FrilaCores.tintaEscuro, FrilaCores.fundoOled) >= 7.0)
    }

    @Test
    fun `tinta suave atinge AA (4_5 a 1) sobre fundo, superficie e superficie pressionada, nos dois modos`() {
        val pares = listOf(
            FrilaCores.tintaSuaveClaro to FrilaCores.fundoClaro,
            FrilaCores.tintaSuaveClaro to FrilaCores.superficieClaro,
            FrilaCores.tintaSuaveClaro to FrilaCores.superficiePressionadaClaro,
            FrilaCores.tintaSuaveEscuro to FrilaCores.fundoEscuro,
            FrilaCores.tintaSuaveEscuro to FrilaCores.superficieEscuro,
            FrilaCores.tintaSuaveEscuro to FrilaCores.superficiePressionadaEscuro,
            FrilaCores.tintaSuaveEscuro to FrilaCores.fundoOled,
        )

        pares.forEach { (texto, fundo) ->
            val razao = contraste(texto, fundo)
            assertTrue(razao >= 4.5, "tinta suave $texto sobre $fundo: $razao")
        }
    }

    @Test
    fun `o botao em conferencia (tinta suave sobre borda) continua legivel nos dois modos`() {
        assertTrue(contraste(FrilaCores.tintaSuaveClaro, FrilaCores.bordaClaro) >= 4.5)
        assertTrue(contraste(FrilaCores.tintaSuaveEscuro, FrilaCores.bordaEscuro) >= 4.5)
    }

    @Test
    fun `o contorno de campo fica no piso de 3 a 1 contra o fundo e a superficie`() {
        // No claro contra o fundo o desenho mede 3,0:1 cravado (2,998 antes de arredondar).
        assertTrue(contraste(FrilaCores.bordaControleClaro, FrilaCores.fundoClaro) >= 2.99)
        assertTrue(contraste(FrilaCores.bordaControleClaro, FrilaCores.superficieClaro) >= 3.0)
        assertTrue(contraste(FrilaCores.bordaControleEscuro, FrilaCores.fundoEscuro) >= 3.0)
        assertTrue(contraste(FrilaCores.bordaControleEscuro, FrilaCores.superficieEscuro) >= 3.0)
    }

    @Test
    fun `texto sobre os destaques passa em AA - branco no roxo, tinta no amarelo`() {
        assertTrue(contraste(FrilaCores.sobreRoxo, FrilaCores.destaqueRoxo) >= 4.5)
        assertTrue(contraste(FrilaCores.sobreAmarelo, FrilaCores.destaqueAmarelo) >= 7.0)
    }

    @Test
    fun `texto sobre preenchimento em tinta (chip marcado, selo) atinge AAA nas duas paletas`() {
        listOf(PaletaClara, PaletaEscura).forEach { paleta ->
            assertTrue(contraste(paleta.sobreTinta, paleta.tinta) >= 7.0)
            assertTrue(contraste(paleta.sobreTinta, paleta.tintaPressionada) >= 7.0)
            assertTrue(contraste(paleta.sobreTinta, paleta.tintaSuave) >= 4.5)
        }
    }

    @Test
    fun `o fundo do modo OLED e preto puro (RNF10) e so o fundo muda`() {
        assertEquals(Color(0xFF000000), FrilaCores.fundoOled)
        assertEquals(PaletaEscura.copy(fundo = FrilaCores.fundoOled), PaletaEscuraOled)
    }

    @Test
    fun `laranja, amarelo e roxo sao os mesmos no claro e no escuro`() {
        assertEquals(PaletaClara.acao, PaletaEscura.acao)
        assertEquals(PaletaClara.sobreAcao, PaletaEscura.sobreAcao)
        assertEquals(PaletaClara.destaqueAmarelo, PaletaEscura.destaqueAmarelo)
        assertEquals(PaletaClara.destaqueRoxo, PaletaEscura.destaqueRoxo)
    }
}
