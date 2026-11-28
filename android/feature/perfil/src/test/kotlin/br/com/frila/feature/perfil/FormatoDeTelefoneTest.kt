package br.com.frila.feature.perfil

import org.junit.Assert.assertEquals
import org.junit.Test

/** wdgLuHOV: só número brasileiro (+55 com DDD e 8 ou 9 dígitos) ganha máscara; outro formato aparece como veio. */
class FormatoDeTelefoneTest {

    @Test
    fun `celular brasileiro em E164 ganha a mascara com nove digitos`() {
        assertEquals("(61) 98888-7777", FormatoDeTelefone.paraExibir("+5561988887777"))
    }

    @Test
    fun `fixo brasileiro em E164 ganha a mascara com oito digitos`() {
        assertEquals("(61) 3333-4444", FormatoDeTelefone.paraExibir("+556133334444"))
    }

    @Test
    fun `com pontuacao no meio o numero brasileiro tambem ganha a mascara`() {
        assertEquals("(61) 98888-7777", FormatoDeTelefone.paraExibir("+55 (61) 98888-7777"))
    }

    @Test
    fun `numero estrangeiro aparece como veio, mesmo com onze digitos`() {
        assertEquals("+14155550123", FormatoDeTelefone.paraExibir("+14155550123"))
        assertEquals("+4915112345678", FormatoDeTelefone.paraExibir("+4915112345678"))
    }

    @Test
    fun `numero brasileiro curto ou longo demais aparece como veio`() {
        assertEquals("+55619888", FormatoDeTelefone.paraExibir("+55619888"))
        assertEquals("+55619888877771", FormatoDeTelefone.paraExibir("+55619888877771"))
    }

    @Test
    fun `sem o mais cinquenta e cinco aparece como veio, formatado ou nao`() {
        assertEquals("61988887777", FormatoDeTelefone.paraExibir("61988887777"))
        assertEquals("(61) 98888-7777", FormatoDeTelefone.paraExibir("(61) 98888-7777"))
    }

    @Test
    fun `vazio continua vazio`() {
        assertEquals("", FormatoDeTelefone.paraExibir(""))
    }
}
