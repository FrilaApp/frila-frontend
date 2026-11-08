package br.com.frila.feature.turnos

import org.junit.Assert.assertEquals
import org.junit.Test

class CompressorDeFotoTest {

    @Test
    fun `imagem ja menor que o limite nao e subamostrada`() {
        val fator = CompressorDeFoto.calcularInSampleSize(largura = 800, altura = 600)
        assertEquals(1, fator)
    }

    @Test
    fun `imagem com maior lado pouco acima do limite nao exige subamostragem de 2x`() {
        // 1280 * 2 = 2560; 1281 / 2 = 640 (< 1280), entao nao atinge o limiar de dobrar.
        val fator = CompressorDeFoto.calcularInSampleSize(largura = 1281, altura = 900)
        assertEquals(1, fator)
    }

    @Test
    fun `imagem grande e subamostrada para o maior lado nao passar de 1280px`() {
        // 4000x3000: maior lado 4000. 4000/2=2000>=1280 -> fator 2, maiorLado 2000.
        // 2000/2=1000<1280 -> para. fator final 2.
        val fator = CompressorDeFoto.calcularInSampleSize(largura = 4000, altura = 3000)
        assertEquals(2, fator)
    }

    @Test
    fun `dimensoes invalidas (zero ou negativas) nao sobem erro, fator fica 1`() {
        assertEquals(1, CompressorDeFoto.calcularInSampleSize(largura = 0, altura = 0))
        assertEquals(1, CompressorDeFoto.calcularInSampleSize(largura = -100, altura = 600))
    }

    @Test
    fun `limite maximo customizado e respeitado`() {
        val fator = CompressorDeFoto.calcularInSampleSize(largura = 2000, altura = 2000, ladoMaximo = 500)
        // 2000/2=1000>=500; 1000/2=500, 500/2=250<500(500/2=250>=500? nao) -> loop: maiorLado=2000
        // iter1: 2000/2=1000>=500 -> fator=2, maiorLado=1000
        // iter2: 1000/2=500>=500 -> fator=4, maiorLado=500
        // iter3: 500/2=250>=500? nao -> para. fator=4
        assertEquals(4, fator)
    }
}
