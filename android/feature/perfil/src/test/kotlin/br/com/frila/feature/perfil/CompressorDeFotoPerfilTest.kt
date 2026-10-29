package br.com.frila.feature.perfil

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

/**
 * `calcularInSampleSize` espelha o algoritmo já medido em
 * `br.com.frila.feature.turnos.CompressorDeFoto` (sem dependência cruzada de módulo), com o teto
 * reduzido para 512px (RNF04: avatar não precisa do mesmo tamanho de um anexo de ocorrência).
 * `calcularRecorteQuadrado` é novo: centraliza o corte 1:1 que o avatar exige.
 */
class CompressorDeFotoPerfilTest {

    @Test
    fun `imagem ja menor que o limite nao e subamostrada`() {
        val fator = CompressorDeFotoPerfil.calcularInSampleSize(largura = 400, altura = 300)
        assertEquals(1, fator)
    }

    @Test
    fun `imagem grande e subamostrada por potencia de 2 - sozinho nao garante o teto de 512px`() {
        // 8000x6000: 8000/2=4000>=512 -> fator 2, lado 4000
        // 4000/2=2000>=512 -> fator 4, lado 2000
        // 2000/2=1000>=512 -> fator 8, lado 1000
        // 1000/2=500<512 -> para. fator final 8, lado final 1000 (> 512!).
        // MEDIDO (Shisui, PR #590): sem um passo final de escala exata, o resultado real fica
        // entre 512 e 1023px. calcularInSampleSize só reduz por potência de 2; quem garante o
        // teto de 512px é CompressorDeFotoPerfil.comprimir() aplicando createScaledBitmap depois.
        val fator = CompressorDeFotoPerfil.calcularInSampleSize(largura = 8000, altura = 6000)
        assertEquals(8, fator)
    }

    @Test
    fun `dimensoes invalidas nao sobem erro, fator fica 1`() {
        assertEquals(1, CompressorDeFotoPerfil.calcularInSampleSize(largura = 0, altura = 0))
        assertEquals(1, CompressorDeFotoPerfil.calcularInSampleSize(largura = -100, altura = 600))
    }

    @Test
    fun `imagem quadrada nao tem recorte - origem na borda e lado igual a dimensao`() {
        val recorte = CompressorDeFotoPerfil.calcularRecorteQuadrado(largura = 500, altura = 500)
        assertEquals(0, recorte.origemX)
        assertEquals(0, recorte.origemY)
        assertEquals(500, recorte.lado)
    }

    @Test
    fun `imagem paisagem recorta as laterais centralizando no eixo X`() {
        val recorte = CompressorDeFotoPerfil.calcularRecorteQuadrado(largura = 800, altura = 600)
        assertEquals(600, recorte.lado)
        assertEquals(100, recorte.origemX)
        assertEquals(0, recorte.origemY)
    }

    @Test
    fun `imagem retrato recorta topo e base centralizando no eixo Y`() {
        val recorte = CompressorDeFotoPerfil.calcularRecorteQuadrado(largura = 600, altura = 800)
        assertEquals(600, recorte.lado)
        assertEquals(0, recorte.origemX)
        assertEquals(100, recorte.origemY)
    }

    @Test
    fun `dimensoes invalidas no recorte nao sobem erro, lado fica zero`() {
        val recorte = CompressorDeFotoPerfil.calcularRecorteQuadrado(largura = 0, altura = 0)
        assertEquals(0, recorte.lado)
        assertEquals(0, recorte.origemX)
        assertEquals(0, recorte.origemY)
    }
}
