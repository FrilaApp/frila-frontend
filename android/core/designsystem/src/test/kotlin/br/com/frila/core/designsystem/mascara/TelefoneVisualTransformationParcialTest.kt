package br.com.frila.core.designsystem.mascara

import androidx.compose.ui.text.AnnotatedString
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

/**
 * Cartão tgWVmR8Y (item 241): a máscara do telefone enquanto a pessoa digita (entrada parcial). Os testes antigos só tinham o número
 * completo; `> 2` virar `>= 2` faria `11` virar `(11) ` (com o parêntese e o espaço antes do terceiro dígito), e nada pegava.
 *
 * Cuidado do JUnit 5: um `@Test` que devolve valor é ignorado em silêncio; todos os métodos aqui têm corpo em bloco e devolvem `Unit`.
 */
class TelefoneVisualTransformationParcialTest {

    private val mascara = TelefoneVisualTransformation()

    private fun formatar(digitado: String): String = mascara.filter(AnnotatedString(digitado)).text.text

    @Test
    fun `cada passo da digitacao de um celular tem a mascara certa, sem parenteses ou hifen sobrando`() {
        val passos = listOf(
            "" to "",
            "1" to "(1",
            "11" to "(11",
            "119" to "(11) 9",
            "1198" to "(11) 98",
            "11987" to "(11) 987",
            "119876" to "(11) 9876",
            "1198765" to "(11) 9876-5",
            "11987654" to "(11) 9876-54",
            "119876543" to "(11) 9876-543",
            "1198765432" to "(11) 9876-5432",
            "11987654321" to "(11) 98765-4321",
        )
        for ((digitado, esperado) in passos) {
            assertEquals(esperado, formatar(digitado), "'$digitado'")
        }
    }

    @Test
    fun `dois digitos viram so abre parenteses e os dois digitos, o fecha e o espaco vem com o terceiro`() {
        assertEquals("(11", formatar("11"))
        assertEquals("(11) 9", formatar("119"))
    }

    @Test
    fun `fixo de 10 digitos e celular de 11 mudam o hifen de lugar`() {
        assertEquals("(11) 3456-7890", formatar("1134567890"))
        assertEquals("(11) 98765-4321", formatar("11987654321"))
    }

    @Test
    fun `o que nao e digito some e mais de 11 digitos sao cortados`() {
        assertEquals("(11) 98765-4321", formatar("(11) 98765-4321"))
        assertEquals("(11) 98765-4321", formatar("+11 9 8765 4321"))
        assertEquals("(11) 98765-4321", formatar("119876543219999"))
        assertEquals("", formatar("abc"))
        assertEquals("(1", formatar("a1b"))
    }

    @Test
    fun `o DDD 55 e formatado como qualquer outro, sem ser tomado como codigo do pais`() {
        assertEquals("(55) 98765-4321", formatar("55987654321"))
        assertEquals("(55) 3456-7890", formatar("5534567890"))
        assertEquals("(55) 9", formatar("559"))
    }

    @Test
    fun `o cursor acompanha a digitacao em cada passo, sem sair do texto formatado`() {
        for (digitos in listOf("1", "11", "119", "119876", "1198765", "1134567890", "11987654321")) {
            val transformado = mascara.filter(AnnotatedString(digitos))
            val mapa = transformado.offsetMapping
            val tamanho = transformado.text.length
            for (posicao in 0..digitos.length) {
                val naTela = mapa.originalToTransformed(posicao)
                assertEquals(true, naTela in 0..tamanho, "$digitos original $posicao -> $naTela fora de 0..$tamanho")
                assertEquals(posicao, mapa.transformedToOriginal(naTela), "$digitos: ida e volta da posição $posicao")
            }
            // O fim do texto digitado é o fim do texto formatado.
            assertEquals(tamanho, mapa.originalToTransformed(digitos.length), "$digitos: cursor no fim")
            assertEquals(digitos.length, mapa.transformedToOriginal(tamanho), "$digitos: fim da tela é o fim do texto")
        }
    }
}
