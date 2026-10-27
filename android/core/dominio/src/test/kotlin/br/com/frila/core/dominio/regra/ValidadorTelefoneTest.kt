package br.com.frila.core.dominio.regra

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ValidadorTelefoneTest {

    @Test
    fun `celular valido com ddd e nono digito deve ser aceito`() {
        assertTrue(ValidadorTelefone.ehValido("11987654321"))
        assertTrue(ValidadorTelefone.ehValido("(11) 98765-4321"))
        assertTrue(ValidadorTelefone.ehValido("+5511987654321"))
        assertTrue(ValidadorTelefone.ehValido("+55 (21) 99876-5432"))
        assertTrue(ValidadorTelefone.ehValido("61991234567"))
    }

    @Test
    fun `telefone fixo valido com ddd deve ser aceito`() {
        assertTrue(ValidadorTelefone.ehValido("1134567890"))
        assertTrue(ValidadorTelefone.ehValido("(11) 3456-7890"))
        assertTrue(ValidadorTelefone.ehValido("+551134567890"))
        assertTrue(ValidadorTelefone.ehValido("2123456789"))
    }

    @Test
    fun `telefone com ddd invalido deve ser rejeitado`() {
        assertFalse(ValidadorTelefone.ehValido("00987654321"))
        assertFalse(ValidadorTelefone.ehValido("01987654321"))
        assertFalse(ValidadorTelefone.ehValido("05987654321"))
        assertFalse(ValidadorTelefone.ehValido("20987654321"))
    }

    @Test
    fun `celular de 11 digitos sem nono digito 9 deve ser rejeitado`() {
        // 11 dígitos começando com 8 após DDD (não é celular válido no padrão atual)
        assertFalse(ValidadorTelefone.ehValido("11887654321"))
        assertFalse(ValidadorTelefone.ehValido("11787654321"))
    }

    @Test
    fun `telefone com tamanho incorreto deve ser rejeitado`() {
        assertFalse(ValidadorTelefone.ehValido(""))
        assertFalse(ValidadorTelefone.ehValido("1198765"))
        assertFalse(ValidadorTelefone.ehValido("1198765432100"))
    }

    @Test
    fun `conversao para formato e164 deve incluir prefixo mais 55`() {
        assertEquals("+5511987654321", ValidadorTelefone.paraE164("(11) 98765-4321"))
        assertEquals("+551134567890", ValidadorTelefone.paraE164("1134567890"))
        assertEquals("+5521998765432", ValidadorTelefone.paraE164("+55 21 99876-5432"))
        assertNull(ValidadorTelefone.paraE164("invalido"))
    }

    @Test
    fun `formatar deve aplicar mascara nacional corretamente`() {
        assertEquals("(11) 98765-4321", ValidadorTelefone.formatar("11987654321"))
        assertEquals("(11) 3456-7890", ValidadorTelefone.formatar("1134567890"))
    }
}
