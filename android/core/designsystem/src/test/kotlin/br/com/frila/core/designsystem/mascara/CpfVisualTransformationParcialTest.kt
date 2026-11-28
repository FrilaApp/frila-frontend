package br.com.frila.core.designsystem.mascara

import androidx.compose.ui.text.AnnotatedString
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Cartão Y0k7MOPt (item 280): a máscara do CPF enquanto a pessoa digita (entrada parcial) e o mapeamento do cursor nas duas direções. O
 * teste antigo só conferia os deslocamentos 0, 3, 11 e 20 com os 11 dígitos. Sem isto, tirar `&& i != digitos.lastIndex` (e "123" viraria
 * "123.") e `clamped <= 6` virar `<= 7` (o cursor salta) passavam. Fora: a tela de cadastro.
 *
 * JUnit: nenhum método devolve valor (um `@Test` que devolve valor é ignorado).
 */
class CpfVisualTransformationParcialTest {

    private val mascara = CpfVisualTransformation()

    private fun filtrar(digitado: String) = mascara.filter(AnnotatedString(digitado))

    private fun formatar(digitado: String): String = filtrar(digitado).text.text

    private val passos = listOf(
        "" to "",
        "1" to "1",
        "12" to "12",
        "123" to "123",
        "1234" to "123.4",
        "12345" to "123.45",
        "123456" to "123.456",
        "1234567" to "123.456.7",
        "12345678" to "123.456.78",
        "123456789" to "123.456.789",
        "1234567890" to "123.456.789-0",
        "12345678901" to "123.456.789-01",
    )

    // ---- o texto, um dígito por vez ----

    @Test
    fun `cada passo da digitacao tem a mascara certa, sem ponto nem hifen sobrando no fim`() {
        for ((digitado, esperado) in passos) {
            assertEquals(esperado, formatar(digitado), "'$digitado'")
        }
    }

    @Test
    fun `os separadores so entram quando vem um digito depois deles`() {
        assertEquals("123", formatar("123"))
        assertEquals("123.456", formatar("123456"))
        assertEquals("123.456.789", formatar("123456789"))
        assertEquals(false, formatar("123").endsWith("."))
        assertEquals(false, formatar("123456").endsWith("."))
        assertEquals(false, formatar("123456789").endsWith("-"))
    }

    @Test
    fun `o que nao e digito some e mais de 11 digitos sao cortados`() {
        assertEquals("123.456.789-01", formatar("123.456.789-01"))
        assertEquals("123.456.789-01", formatar("12a3b4c5d6e7f8g9h0i1"))
        assertEquals("123.456.789-01", formatar("1234567890123456"))
        assertEquals("", formatar("abc.-"))
        assertEquals("1", formatar("a1-"))
    }

    // ---- o cursor, nas duas direções ----

    @Test
    fun `do texto digitado para a tela, cada posicao do cursor cai no lugar certo, com 11 digitos`() {
        val mapa = filtrar("12345678901").offsetMapping
        // 123.456.789-01 : posições 0..14
        val esperado = mapOf(0 to 0, 1 to 1, 2 to 2, 3 to 3, 4 to 5, 5 to 6, 6 to 7, 7 to 9, 8 to 10, 9 to 11, 10 to 13, 11 to 14)
        for ((original, naTela) in esperado) {
            assertEquals(naTela, mapa.originalToTransformed(original), "original $original")
        }
    }

    @Test
    fun `da tela para o texto digitado, cada posicao do cursor cai no lugar certo, com 11 digitos`() {
        val mapa = filtrar("12345678901").offsetMapping
        val esperado = mapOf(
            0 to 0, 1 to 1, 2 to 2, 3 to 3, 4 to 3, 5 to 4, 6 to 5, 7 to 6, 8 to 6, 9 to 7, 10 to 8, 11 to 9, 12 to 9, 13 to 10, 14 to 11,
        )
        for ((naTela, original) in esperado) {
            assertEquals(original, mapa.transformedToOriginal(naTela), "tela $naTela")
        }
    }

    @Test
    fun `ida e volta, de cada posicao do texto para a tela e de volta, fecha em todas as larguras de 1 a 11 digitos`() {
        for (largura in 1..11) {
            val digitos = "12345678901".take(largura)
            val transformado = filtrar(digitos)
            val mapa = transformado.offsetMapping
            val tamanho = transformado.text.length
            for (posicao in 0..largura) {
                val naTela = mapa.originalToTransformed(posicao)
                assertTrue(naTela in 0..tamanho, "$digitos original $posicao -> $naTela fora de 0..$tamanho")
                assertEquals(posicao, mapa.transformedToOriginal(naTela), "$digitos: ida e volta da posição $posicao")
            }
        }
    }

    @Test
    fun `o cursor no fim do texto digitado e o fim do texto formatado, e vice-versa, em cada largura`() {
        for ((digitado, esperado) in passos.filter { it.first.isNotEmpty() }) {
            val mapa = filtrar(digitado).offsetMapping

            assertEquals(esperado.length, mapa.originalToTransformed(digitado.length), "$digitado: fim")
            assertEquals(digitado.length, mapa.transformedToOriginal(esperado.length), "$digitado: fim da tela")
        }
    }

    @Test
    fun `o cursor nunca anda para tras quando a posicao cresce, e nunca pula mais de 2 casas`() {
        for (largura in 1..11) {
            val mapa = filtrar("12345678901".take(largura)).offsetMapping
            var anterior = mapa.originalToTransformed(0)
            for (posicao in 1..largura) {
                val atual = mapa.originalToTransformed(posicao)
                assertTrue(atual >= anterior, "$largura: $posicao ($atual) < ${posicao - 1} ($anterior)")
                assertTrue(atual - anterior in 1..2, "$largura: salto de ${atual - anterior} em $posicao")
                anterior = atual
            }
        }
    }

    @Test
    fun `posicao fora do texto e limitada, sem estourar, em qualquer largura`() {
        for (largura in 0..11) {
            val transformado = filtrar("12345678901".take(largura))
            val mapa = transformado.offsetMapping
            val tamanho = transformado.text.length
            assertEquals(0, mapa.originalToTransformed(-5), "$largura: negativa")
            assertEquals(tamanho, mapa.originalToTransformed(99), "$largura: acima")
            assertEquals(0, mapa.transformedToOriginal(-5), "$largura: negativa na tela")
            assertEquals(largura, mapa.transformedToOriginal(99), "$largura: acima na tela")
        }
    }
}
