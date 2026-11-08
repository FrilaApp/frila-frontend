package br.com.frila.core.dominio.modelo

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource

class DinheiroTest {

    @Test
    fun `deReais converte reais e centavos para centavos totais`() {
        assertEquals(16_050L, Dinheiro.deReais(160, 50).centavos)
        assertEquals(0L, Dinheiro.deReais(0).centavos)
    }

    @Test
    fun `formatado produz BRL com separador decimal de virgula`() {
        val valor = Dinheiro.deReais(160, 0)
        assertTrue(valor.formatado().contains("160,00"))
    }

    @ParameterizedTest
    @ValueSource(longs = [10_000, 50_000, 100_000])
    fun `ehValorHoraValido aceita a faixa RN02 de 100 a 1000 reais`(centavos: Long) {
        assertTrue(Dinheiro.ehValorHoraValido(Dinheiro(centavos)))
    }

    @ParameterizedTest
    @ValueSource(longs = [0, 9_999, 100_001, 500_000])
    fun `ehValorHoraValido recusa fora da faixa RN02`(centavos: Long) {
        assertFalse(Dinheiro.ehValorHoraValido(Dinheiro(centavos)))
    }

    @Test
    fun `paraValorHora falha abaixo do minimo de RN02`() {
        val resultado = Dinheiro.paraValorHora(9_999)
        assertTrue(resultado.isFailure)
    }

    @Test
    fun `paraValorHora falha acima do maximo de RN02`() {
        val resultado = Dinheiro.paraValorHora(100_001)
        assertTrue(resultado.isFailure)
    }

    @Test
    fun `paraValorHora aceita os limites inclusivos`() {
        assertTrue(Dinheiro.paraValorHora(10_000).isSuccess)
        assertTrue(Dinheiro.paraValorHora(100_000).isSuccess)
    }

    @Test
    fun `operador mais soma centavos`() {
        val total = Dinheiro(10_000) + Dinheiro(5_000)
        assertEquals(15_000L, total.centavos)
    }
}
