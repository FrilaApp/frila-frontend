package br.com.frila.core.dominio.regra

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ValidadorCpfTest {

    @Test
    fun `cpf valido com digitos verificadores corretos deve ser aceito`() {
        // CPFs válidos conhecidos gerados pelo algoritmo da Receita Federal
        assertTrue(ValidadorCpf.ehValido("52998224725"))
        assertTrue(ValidadorCpf.ehValido("529.982.247-25"))
        assertTrue(ValidadorCpf.ehValido("11144477735"))
        assertTrue(ValidadorCpf.ehValido("111.444.777-35"))
        assertTrue(ValidadorCpf.ehValido("00000000191"))
    }

    @Test
    fun `cpf com digitos verificadores incorretos deve ser rejeitado`() {
        // Primeiro dígito verificador incorreto
        assertFalse(ValidadorCpf.ehValido("52998224715"))
        // Segundo dígito verificador incorreto
        assertFalse(ValidadorCpf.ehValido("52998224726"))
        assertFalse(ValidadorCpf.ehValido("12345678900"))
        assertFalse(ValidadorCpf.ehValido("123.456.789-00"))
    }

    @Test
    fun `cpf com todos os digitos repetidos deve ser rejeitado`() {
        assertFalse(ValidadorCpf.ehValido("00000000000"))
        assertFalse(ValidadorCpf.ehValido("11111111111"))
        assertFalse(ValidadorCpf.ehValido("22222222222"))
        assertFalse(ValidadorCpf.ehValido("33333333333"))
        assertFalse(ValidadorCpf.ehValido("44444444444"))
        assertFalse(ValidadorCpf.ehValido("55555555555"))
        assertFalse(ValidadorCpf.ehValido("66666666666"))
        assertFalse(ValidadorCpf.ehValido("77777777777"))
        assertFalse(ValidadorCpf.ehValido("88888888888"))
        assertFalse(ValidadorCpf.ehValido("99999999999"))
    }

    @Test
    fun `cpf com tamanho incorreto ou caracteres invalidos deve ser rejeitado`() {
        assertFalse(ValidadorCpf.ehValido(""))
        assertFalse(ValidadorCpf.ehValido("123"))
        assertFalse(ValidadorCpf.ehValido("1234567890"))
        assertFalse(ValidadorCpf.ehValido("123456789012"))
        assertFalse(ValidadorCpf.ehValido("abcdefghijk"))
    }

    @Test
    fun `formatar e desformatar devem operar corretamente sem corromper digitos`() {
        assertEquals("529.982.247-25", ValidadorCpf.formatar("52998224725"))
        assertEquals("52998224725", ValidadorCpf.desformatar("529.982.247-25"))
    }
}
