package br.com.frila.feature.chamadas.casa

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

/**
 * Cartão jP0ERhaA (item 255): as bordas do `ValorEmReais`. O teste antigo não tinha 5 algarismos exatos, 3 casas de centavos, mais de 9
 * algarismos nem dois pontos sem vírgula. Sem eles, `>` virar `>=` (de R$ 10.000 em diante não se digitaria), tirar `fracao.length > 2`,
 * tirar `partes.size > 2` (`1.2.3` viraria 102 centavos) e tirar `inteiro.length > 9` passavam. Fora: a faixa de referência (`aviso`).
 *
 * JUnit: nenhum método devolve valor (um `@Test` que devolve valor é ignorado).
 */
class ValorEmReaisBordasTest {

    // ---- digitado: até 5 algarismos em reais ----

    @Test
    fun `cinco algarismos em reais exatos sao aceitos, com e sem centavos e com ponto de milhar`() {
        assertEquals("10000", ValorEmReais.digitado("10000"))
        assertEquals("99999", ValorEmReais.digitado("99999"))
        assertEquals("99999,99", ValorEmReais.digitado("99999,99"))
        assertEquals("10000", ValorEmReais.digitado("10.000"))
        assertEquals("99999,50", ValorEmReais.digitado("R$ 99.999,50"))
        // Cinco algarismos digitados um a um: o quinto entra, mesmo com um anterior de 4.
        assertEquals("10000", ValorEmReais.digitado("10000", anterior = "1000"))
    }

    @Test
    fun `seis algarismos em reais devolvem o anterior, com e sem virgula, e nada de anterior devolve vazio`() {
        assertEquals("99999", ValorEmReais.digitado("100000", anterior = "99999"))
        assertEquals("99999", ValorEmReais.digitado("999999", anterior = "99999"))
        assertEquals("99999", ValorEmReais.digitado("123456,78", anterior = "99999"))
        assertEquals("99999", ValorEmReais.digitado("100.000,00", anterior = "99999"))
        assertEquals("", ValorEmReais.digitado("100000"))
        assertEquals("", ValorEmReais.digitado("1.500.000"))
    }

    // ---- digitado: ponto de milhar só com grupo inicial de 1 a 3 algarismos e grupos de 3 ----

    @Test
    fun `ponto de milhar so vale com grupo inicial de 1 a 3 algarismos`() {
        // 3 no primeiro grupo é milhar: "123.456" tem 6 algarismos em reais e devolve o anterior.
        assertEquals("1", ValorEmReais.digitado("123.456", anterior = "1"))
        // 4 no primeiro grupo não é milhar: o ponto é a vírgula de outro teclado.
        assertEquals("1234,56", ValorEmReais.digitado("1234.567"))
        // Sem nada antes do ponto também não é milhar.
        assertEquals("0,50", ValorEmReais.digitado(".500"))
    }

    // ---- digitado: até 2 casas de centavos ----

    @Test
    fun `tres ou mais casas de centavos sao cortadas em duas, sem arredondar`() {
        assertEquals("180,50", ValorEmReais.digitado("180,509"))
        assertEquals("180,99", ValorEmReais.digitado("180,999"))
        assertEquals("0,12", ValorEmReais.digitado("0,125"))
        assertEquals("1,23", ValorEmReais.digitado("1,23456789"))
        assertEquals("180,5", ValorEmReais.digitado("180,5"))
        assertEquals("180,05", ValorEmReais.digitado("180,05"))
    }

    // ---- centavos: até 2 casas e 9 algarismos ----

    @Test
    fun `centavos recusa tres casas e aceita uma ou duas`() {
        assertNull(ValorEmReais.centavos("180,505"))
        assertNull(ValorEmReais.centavos("180,500"))
        assertNull(ValorEmReais.centavos("1,000"))
        assertEquals(18050L, ValorEmReais.centavos("180,50"))
        assertEquals(18050L, ValorEmReais.centavos("180,5"))
        assertEquals(1L, ValorEmReais.centavos("0,01"))
    }

    @Test
    fun `centavos aceita ate 9 algarismos em reais e recusa 10`() {
        assertEquals(99_999_999_900L, ValorEmReais.centavos("999999999"))
        assertEquals(12_345_678_900L, ValorEmReais.centavos("123.456.789,00"))
        assertNull(ValorEmReais.centavos("1000000000"))
        assertNull(ValorEmReais.centavos("9999999999"))
        assertNull(ValorEmReais.centavos("1.234.567.890,00"), "10 algarismos com milhar e vírgula")
    }

    // ---- centavos: dois pontos sem vírgula ----

    @Test
    fun `dois pontos sem virgula nao viram valor`() {
        assertNull(ValorEmReais.centavos("1.2.3"))
        assertNull(ValorEmReais.centavos("1.500.000"))
        assertNull(ValorEmReais.centavos("1..2"))
        assertNull(ValorEmReais.centavos("..."))
    }

    @Test
    fun `um ponto sem virgula e a casa decimal, e com virgula os pontos sao milhar`() {
        assertEquals(150L, ValorEmReais.centavos("1.5"))
        assertEquals(105L, ValorEmReais.centavos("1.05"))
        assertEquals(123456L, ValorEmReais.centavos("1.234,56"))
        assertEquals(150000000L, ValorEmReais.centavos("1.500.000,00"))
    }

    // ---- ida e volta: o que se digita chega aos centavos e volta ao texto ----

    @Test
    fun `de 5 algarismos em reais a ida e volta digitado, centavos e texto fecha`() {
        val digitado = ValorEmReais.digitado("R$ 99.999,99")
        assertEquals("99999,99", digitado)
        val centavos = ValorEmReais.centavos(digitado)
        assertEquals(9_999_999L, centavos)
        assertEquals("99999,99", ValorEmReais.texto(centavos!!))
        assertEquals("10000", ValorEmReais.texto(ValorEmReais.centavos(ValorEmReais.digitado("10.000"))!!))
    }
}
