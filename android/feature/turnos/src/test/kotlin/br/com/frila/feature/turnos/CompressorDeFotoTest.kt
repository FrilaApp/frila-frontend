package br.com.frila.feature.turnos

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CompressorDeFotoTest {

    @Test
    fun `imagem ja menor que o limite nao e subamostrada`() {
        val fator = CompressorDeFoto.calcularInSampleSize(largura = 800, altura = 600)
        assertEquals(1, fator)
    }

    @Test
    fun `imagem com maior lado pouco acima do limite e subamostrada para nao ultrapassar o teto`() {
        // 1281/1=1281>1280 -> fator 2; 1281/2=640<=1280 -> para. Resultado final 640px, <= 1280.
        val fator = CompressorDeFoto.calcularInSampleSize(largura = 1281, altura = 900)
        assertEquals(2, fator)
    }

    @Test
    fun `imagem grande e subamostrada para o maior lado nao passar de 1280px`() {
        // 4000x3000: 4000/1=4000>1280 -> fator 2; 4000/2=2000>1280 -> fator 4; 4000/4=1000<=1280 -> para.
        val fator = CompressorDeFoto.calcularInSampleSize(largura = 4000, altura = 3000)
        assertEquals(4, fator)
        assertTrue(4000 / fator <= 1280)
    }

    @Test
    fun `resultado final nunca ultrapassa o ladoMaximo, para varias dimensoes de entrada`() {
        val ladoMaximo = 1280
        listOf(1281 to 900, 2000 to 2000, 2559 to 2000, 4000 to 3000, 8000 to 6000, 1_000_000 to 1).forEach { (largura, altura) ->
            val fator = CompressorDeFoto.calcularInSampleSize(largura, altura, ladoMaximo)
            val maiorLadoResultante = maxOf(largura, altura) / fator
            assertTrue(
                "largura=$largura altura=$altura fator=$fator maiorLadoResultante=$maiorLadoResultante",
                maiorLadoResultante <= ladoMaximo,
            )
        }
    }

    @Test
    fun `dimensoes invalidas (zero ou negativas) nao sobem erro, fator fica 1`() {
        assertEquals(1, CompressorDeFoto.calcularInSampleSize(largura = 0, altura = 0))
        assertEquals(1, CompressorDeFoto.calcularInSampleSize(largura = -100, altura = 600))
    }

    @Test
    fun `limite maximo customizado e respeitado`() {
        // 2000/1=2000>500 -> fator2; 2000/2=1000>500 -> fator4; 2000/4=500<=500 -> para.
        val fator = CompressorDeFoto.calcularInSampleSize(largura = 2000, altura = 2000, ladoMaximo = 500)
        assertEquals(4, fator)
    }
}
