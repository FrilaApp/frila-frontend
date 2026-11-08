package br.com.frila.core.dominio.regra

import br.com.frila.core.dominio.modelo.DataCivil
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ValidadorMaioridadeTest {

    private val hoje = DataCivil.de(2026, 10, 22)

    @Test
    fun `aceita exatamente 18 anos completos hoje`() {
        val nascimento = DataCivil.de(2008, 10, 22)

        assertTrue(ValidadorMaioridade.ehMaiorDeIdade(nascimento, hoje))
    }

    @Test
    fun `recusa um dia antes de completar 18 anos`() {
        val nascimento = DataCivil.de(2008, 10, 23)

        assertFalse(ValidadorMaioridade.ehMaiorDeIdade(nascimento, hoje))
    }

    @Test
    fun `aceita maior de idade com folga`() {
        val nascimento = DataCivil.de(1990, 1, 1)

        assertTrue(ValidadorMaioridade.ehMaiorDeIdade(nascimento, hoje))
    }

    @Test
    fun `recusa crianca`() {
        val nascimento = DataCivil.de(2020, 1, 1)

        assertFalse(ValidadorMaioridade.ehMaiorDeIdade(nascimento, hoje))
    }

    @Test
    fun `usa fuso de Brasilia como referencia padrao quando hoje nao e informado`() {
        assertTrue(DataCivil.FUSO_BRASILIA.id == "America/Sao_Paulo")
    }
}
