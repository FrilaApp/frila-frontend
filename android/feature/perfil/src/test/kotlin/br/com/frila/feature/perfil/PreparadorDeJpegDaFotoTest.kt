package br.com.frila.feature.perfil

import org.junit.jupiter.api.Assertions.assertArrayEquals
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

/** L1-3b: o JPEG que sobe tem o lado maior até 1600 px e até 5 MB (contrato 0.2.54). A leitura e a orientação do Android são provadas no aparelho. */
class PreparadorDeJpegDaFotoTest {

    @Test
    fun `foto maior que 1600 px reduz mantendo a proporcao`() {
        assertEquals(PreparadorDeJpegDaFoto.Medidas(1600, 1067), PreparadorDeJpegDaFoto.medidasFinais(3000, 2000))
        assertEquals(PreparadorDeJpegDaFoto.Medidas(1067, 1600), PreparadorDeJpegDaFoto.medidasFinais(2000, 3000))
    }

    @Test
    fun `foto que ja cabe nao e ampliada nem alterada`() {
        assertEquals(PreparadorDeJpegDaFoto.Medidas(800, 600), PreparadorDeJpegDaFoto.medidasFinais(800, 600))
        assertEquals(PreparadorDeJpegDaFoto.Medidas(1600, 1200), PreparadorDeJpegDaFoto.medidasFinais(1600, 1200))
    }

    @Test
    fun `nunca devolve lado zero, nem em foto muito comprida`() {
        assertEquals(PreparadorDeJpegDaFoto.Medidas(1600, 1), PreparadorDeJpegDaFoto.medidasFinais(40_000, 10))
    }

    @Test
    fun `fica com a primeira qualidade que cabe nos 5 MB`() {
        val tentadas = mutableListOf<Int>()
        val resultado = PreparadorDeJpegDaFoto.comprimirAteCaber(limite = 1000) { qualidade ->
            tentadas += qualidade
            ByteArray(if (qualidade > 70) 5000 else 900)
        }
        assertEquals(listOf(90, 80, 70), tentadas)
        assertEquals(900, resultado!!.size)
    }

    @Test
    fun `se nenhuma qualidade couber, devolve nulo`() {
        assertNull(PreparadorDeJpegDaFoto.comprimirAteCaber(limite = 10) { ByteArray(100) })
    }

    @Test
    fun `o limite e o do contrato e a primeira tentativa ja serve quando cabe`() {
        assertEquals(5 * 1024 * 1024, PreparadorDeJpegDaFoto.TAMANHO_MAXIMO_BYTES)
        assertEquals(1600, PreparadorDeJpegDaFoto.LADO_MAXIMO_PX)
        val unico = byteArrayOf(1, 2, 3)
        assertArrayEquals(unico, PreparadorDeJpegDaFoto.comprimirAteCaber { unico })
    }
}
