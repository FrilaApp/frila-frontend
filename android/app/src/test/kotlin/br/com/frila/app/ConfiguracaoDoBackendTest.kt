package br.com.frila.app

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource

class ConfiguracaoDoBackendTest {
    private val urlSintetica = "https://exemplo.invalid"
    private val chaveSintetica = "sb_publishable_sintetica"

    @Test
    fun `aceita URL https e chave publicavel sinteticas`() {
        val configuracao = ConfiguracaoDoBackend.validar(urlSintetica, chaveSintetica)

        assertEquals(urlSintetica, configuracao.url)
        assertEquals(chaveSintetica, configuracao.chavePublicavel)
    }

    @ParameterizedTest
    @ValueSource(strings = ["", " ", "   \t"])
    fun `reprova URL vazia ou em branco`(url: String) {
        assertThrows(IllegalArgumentException::class.java) {
            ConfiguracaoDoBackend.validar(url, chaveSintetica)
        }
    }

    @ParameterizedTest
    @ValueSource(strings = ["frila.supabase.co", "ftp://exemplo.invalid", "https://", "TODO_INJETAR_VIA_BUILDCONFIG"])
    fun `reprova URL sem esquema http ou https e sem host`(url: String) {
        assertThrows(IllegalArgumentException::class.java) {
            ConfiguracaoDoBackend.validar(url, chaveSintetica)
        }
    }

    @ParameterizedTest
    @ValueSource(strings = ["", " ", "TODO_INJETAR_VIA_BUILDCONFIG", "TODO", "todo_injetar", "  TODO_x"])
    fun `reprova chave vazia ou que comece com TODO`(chave: String) {
        assertThrows(IllegalArgumentException::class.java) {
            ConfiguracaoDoBackend.validar(urlSintetica, chave)
        }
    }

    @Test
    fun `reprova chave secreta do Supabase, que nunca pode ir para dentro do APK`() {
        assertThrows(IllegalArgumentException::class.java) {
            ConfiguracaoDoBackend.validar(urlSintetica, "sb_secret_sintetica")
        }
    }

    @Test
    fun `a mensagem de erro nomeia o campo e nao repete o valor da chave`() {
        val chaveRuim = "sb_secret_nao_pode_vazar"

        val erro = assertThrows(IllegalArgumentException::class.java) {
            ConfiguracaoDoBackend.validar(urlSintetica, chaveRuim)
        }

        assertTrue(erro.message.orEmpty().contains("SUPABASE_PUBLISHABLE_KEY"))
        assertFalse(erro.message.orEmpty().contains(chaveRuim))
    }

    @Test
    fun `toString nao expoe a chave`() {
        val texto = ConfiguracaoDoBackend.validar(urlSintetica, chaveSintetica).toString()

        assertFalse(texto.contains(chaveSintetica))
    }
}
