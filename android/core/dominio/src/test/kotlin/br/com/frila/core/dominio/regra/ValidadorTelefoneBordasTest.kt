package br.com.frila.core.dominio.regra

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Cartão tgWVmR8Y (item 241): as bordas do `ValidadorTelefone`. Os testes antigos não tinham fixo começando em 6 a 9, número do DDD 55
 * (o do Rio Grande do Sul, que confunde com o código do país) nem entrada parcial. Sem eles, `'2'..'5'` virar `'2'..'9'` e tirar
 * `digitos.length in 12..13 &&` passavam, e o celular `55987654321` seria recusado.
 *
 * Cuidado do JUnit 5: um `@Test` que devolve valor é ignorado em silêncio; todos os métodos aqui têm corpo em bloco e devolvem `Unit`.
 */
class ValidadorTelefoneBordasTest {

    // ---- fixo: o primeiro dígito do número vai de 2 a 5 ----

    @Test
    fun `fixo com primeiro digito de 2 a 5 vale`() {
        for (digito in '2'..'5') {
            assertTrue(ValidadorTelefone.ehValido("11${digito}4567890"), "fixo 11 $digito...")
        }
    }

    @Test
    fun `fixo com primeiro digito 0, 1 ou de 6 a 9 e recusado`() {
        for (digito in listOf('0', '1', '6', '7', '8', '9')) {
            assertFalse(ValidadorTelefone.ehValido("11${digito}4567890"), "fixo 11 $digito...")
            assertFalse(ValidadorTelefone.ehValido("(11) ${digito}456-7890"), "fixo com máscara 11 $digito...")
            assertFalse(ValidadorTelefone.ehValido("+5511${digito}4567890"), "fixo com +55, 11 $digito...")
        }
    }

    // ---- celular: 11 dígitos e o primeiro do número é 9 ----

    @Test
    fun `celular com primeiro digito diferente de 9 e recusado, qualquer que seja`() {
        for (digito in '0'..'8') {
            assertFalse(ValidadorTelefone.ehValido("11${digito}87654321"), "celular 11 $digito...")
        }
        assertTrue(ValidadorTelefone.ehValido("11987654321"))
    }

    // ---- o DDD 55 (RS) não é o código do país ----

    @Test
    fun `celular do DDD 55 com 11 digitos vale, sem ser tomado como codigo do pais`() {
        assertTrue(ValidadorTelefone.ehValido("55987654321"))
        assertTrue(ValidadorTelefone.ehValido("(55) 98765-4321"))
        assertEquals("55987654321", ValidadorTelefone.extrairDigitosNacionais("55987654321"))
        assertEquals("+5555987654321", ValidadorTelefone.paraE164("(55) 98765-4321"))
        assertEquals("(55) 98765-4321", ValidadorTelefone.formatar("55987654321"))
    }

    @Test
    fun `fixo do DDD 55 com 10 digitos vale, sem ser tomado como codigo do pais`() {
        assertTrue(ValidadorTelefone.ehValido("5534567890"))
        assertTrue(ValidadorTelefone.ehValido("(55) 3456-7890"))
        assertEquals("5534567890", ValidadorTelefone.extrairDigitosNacionais("5534567890"))
        assertEquals("+555534567890", ValidadorTelefone.paraE164("5534567890"))
        assertEquals("(55) 3456-7890", ValidadorTelefone.formatar("5534567890"))
    }

    @Test
    fun `DDD 55 com o codigo do pais na frente tira so o primeiro 55`() {
        assertTrue(ValidadorTelefone.ehValido("+5555987654321"))
        assertTrue(ValidadorTelefone.ehValido("5555987654321"))
        assertEquals("55987654321", ValidadorTelefone.extrairDigitosNacionais("+55 55 98765-4321"))
        assertTrue(ValidadorTelefone.ehValido("555534567890"))
        assertEquals("5534567890", ValidadorTelefone.extrairDigitosNacionais("555534567890"))
        // E.164 de volta dá o mesmo número.
        assertEquals("+5555987654321", ValidadorTelefone.paraE164("+5555987654321"))
    }

    // ---- o prefixo +55 só vale com 12 ou 13 dígitos e começando em 55 ----

    @Test
    fun `o codigo do pais so e tirado com 12 ou 13 digitos que comecam em 55`() {
        assertEquals("1134567890", ValidadorTelefone.extrairDigitosNacionais("551134567890")) // 12
        assertEquals("11987654321", ValidadorTelefone.extrairDigitosNacionais("5511987654321")) // 13
        assertEquals("11987654321", ValidadorTelefone.extrairDigitosNacionais("11987654321")) // 11: nada a tirar
        assertEquals("1134567890", ValidadorTelefone.extrairDigitosNacionais("1134567890")) // 10: nada a tirar
        assertEquals("55119876543210", ValidadorTelefone.extrairDigitosNacionais("55119876543210")) // 14: não tira
        assertEquals("4411987654321", ValidadorTelefone.extrairDigitosNacionais("4411987654321")) // 13 sem 55: não tira
        assertEquals("441134567890", ValidadorTelefone.extrairDigitosNacionais("441134567890")) // 12 sem 55: não tira
    }

    @Test
    fun `numero com codigo de outro pais ou longo demais e recusado`() {
        assertFalse(ValidadorTelefone.ehValido("+4411987654321"))
        assertFalse(ValidadorTelefone.ehValido("+441134567890"))
        assertFalse(ValidadorTelefone.ehValido("55119876543210"))
        assertFalse(ValidadorTelefone.ehValido("+55 11 98765-43210"))
    }

    @Test
    fun `o tamanho nacional vai de 10 a 11 digitos, 9 e 12 nao valem mesmo com cara de fixo`() {
        assertFalse(ValidadorTelefone.ehValido("113456789"), "9 dígitos")
        assertFalse(ValidadorTelefone.ehValido("1134567890123"), "13 dígitos sem 55")
        assertFalse(ValidadorTelefone.ehValido("113456789012"), "12 dígitos sem 55")
        assertTrue(ValidadorTelefone.ehValido("1134567890"), "10 dígitos")
        assertTrue(ValidadorTelefone.ehValido("11987654321"), "11 dígitos")
    }

    // ---- entrada parcial ----

    @Test
    fun `entrada parcial nunca vale e nunca vira E164`() {
        for (parcial in listOf("", "1", "11", "119", "1198", "11987", "119876", "1198765", "11987654", "119876543", "+55", "+5511", "55", "(11) 9")) {
            assertFalse(ValidadorTelefone.ehValido(parcial), "'$parcial'")
            assertNull(ValidadorTelefone.paraE164(parcial), "'$parcial'")
        }
    }

    @Test
    fun `formatar devolve a entrada como veio quando nao tem 10 nem 11 digitos`() {
        for (parcial in listOf("", "11", "119876", "+55", "(11) 9876")) {
            assertEquals(parcial, ValidadorTelefone.formatar(parcial), "'$parcial'")
        }
        assertEquals("(11) 3456-7890", ValidadorTelefone.formatar("1134567890"))
        assertEquals("(11) 98765-4321", ValidadorTelefone.formatar("11987654321"))
    }

    // ---- DDDs ----

    @Test
    fun `so os DDDs do plano de numeracao valem, todos os de 10 a 99`() {
        val validos = setOf(
            11, 12, 13, 14, 15, 16, 17, 18, 19, 21, 22, 24, 27, 28, 31, 32, 33, 34, 35, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49,
            51, 53, 54, 55, 61, 62, 63, 64, 65, 66, 67, 68, 69, 71, 73, 74, 75, 77, 79, 81, 82, 83, 84, 85, 86, 87, 88, 89,
            91, 92, 93, 94, 95, 96, 97, 98, 99,
        )
        for (ddd in 10..99) {
            assertEquals(ddd in validos, ValidadorTelefone.ehValido("${ddd}987654321"), "celular DDD $ddd")
            assertEquals(ddd in validos, ValidadorTelefone.ehValido("${ddd}34567890"), "fixo DDD $ddd")
        }
        assertFalse(ValidadorTelefone.ehValido("00987654321"))
        assertFalse(ValidadorTelefone.ehValido("09987654321"))
    }
}
