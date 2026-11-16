package br.com.frila.feature.chamadas.casa

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

class ValorEmReaisTest {

    @Test
    fun `digitado deixa so algarismos e uma virgula, com ate 2 casas de centavos`() {
        assertEquals("180", ValorEmReais.digitado("180"))
        assertEquals("180,5", ValorEmReais.digitado("180,5"))
        assertEquals("180,50", ValorEmReais.digitado("R$ 180,509"))
        assertEquals("180,", ValorEmReais.digitado("180,"))
        assertEquals("0,5", ValorEmReais.digitado(",5"))
        assertEquals("", ValorEmReais.digitado("abc"))
    }

    @Test
    fun `digitado entende ponto de milhar e ponto decimal de outro teclado`() {
        assertEquals("1500,00", ValorEmReais.digitado("R$ 1.500,00"))
        assertEquals("1500", ValorEmReais.digitado("1.500"))
        assertEquals("1,50", ValorEmReais.digitado("1.50"))
    }

    @Test
    fun `digitado devolve o anterior quando passa de 5 algarismos em reais`() {
        assertEquals("15000", ValorEmReais.digitado("150000", anterior = "15000"))
        assertEquals("15000", ValorEmReais.digitado("1.500.000,00", anterior = "15000"))
    }

    @Test
    fun `centavos le reais, virgula solta e vazio`() {
        assertEquals(18000L, ValorEmReais.centavos("180"))
        assertEquals(18000L, ValorEmReais.centavos("180,"))
        assertEquals(18050L, ValorEmReais.centavos("180,5"))
        assertEquals(18005L, ValorEmReais.centavos("180,05"))
        assertEquals(150000L, ValorEmReais.centavos("1.500,00"))
        assertNull(ValorEmReais.centavos(""))
        assertNull(ValorEmReais.centavos("0"))
        assertNull(ValorEmReais.centavos("abc"))
    }

    @Test
    fun `texto devolve reais inteiros sem virgula e centavos com duas casas`() {
        assertEquals("180", ValorEmReais.texto(18000))
        assertEquals("180,50", ValorEmReais.texto(18050))
        assertEquals("1,05", ValorEmReais.texto(105))
    }
}
