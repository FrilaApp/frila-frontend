package br.com.frila.core.rede

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class SegurancaOAuthSocialTest {

    @Test
    fun `parseQuery preserva caractere de mais literal e decodifica percent-encoding estrito`() {
        val url = "frila-auth://auth/callback?code=abc+123%2B456&tx=state+valor%20extra"
        val resultado = SegurancaOAuthSocial.analisarCallback(url, stateEsperado = "state+valor extra")

        assertTrue(resultado is ResultadoCallbackOAuth.Codigo)
        val codigo = (resultado as ResultadoCallbackOAuth.Codigo).valor
        assertEquals("abc+123+456", codigo)
    }

    @Test
    fun `analisarCallback recusa code com tamanho menor que 4 ou com espaco`() {
        val urlPequeno = "frila-auth://auth/callback?code=12&tx=teste"
        assertEquals(ResultadoCallbackOAuth.CallbackInvalido, SegurancaOAuthSocial.analisarCallback(urlPequeno, stateEsperado = "teste"))

        val urlEspaco = "frila-auth://auth/callback?code=123%20456&tx=teste"
        assertEquals(ResultadoCallbackOAuth.CallbackInvalido, SegurancaOAuthSocial.analisarCallback(urlEspaco, stateEsperado = "teste"))
    }

    @Test
    fun `ehCallbackOAuthSocial valida esquema host e path exatos`() {
        assertTrue(SegurancaOAuthSocial.ehCallbackOAuthSocial("frila-auth://auth/callback?tx=123"))
        assertFalse(SegurancaOAuthSocial.ehCallbackOAuthSocial("frila-auth://outro/callback?tx=123"))
        assertFalse(SegurancaOAuthSocial.ehCallbackOAuthSocial("frila-auth://auth/outro?tx=123"))
        assertFalse(SegurancaOAuthSocial.ehCallbackOAuthSocial("https://auth/callback?tx=123"))
    }
}
