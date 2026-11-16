package br.com.frila.app

import java.util.Base64
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

    /** JWT sintético: cabeçalho, payload com o `role` dado e assinatura falsa. Nenhum valor real. */
    private fun jwtSintetico(payloadJson: String): String {
        val base64Url = Base64.getUrlEncoder().withoutPadding()
        fun parte(texto: String) = base64Url.encodeToString(texto.toByteArray())
        return "${parte("""{"alg":"HS256","typ":"JWT"}""")}.${parte(payloadJson)}.assinatura_sintetica"
    }

    @Test
    fun `aceita JWT legado com role anon`() {
        val chave = jwtSintetico("""{"role":"anon","iss":"sintetico"}""")

        assertEquals(chave, ConfiguracaoDoBackend.validar(urlSintetica, chave).chavePublicavel)
    }

    @ParameterizedTest
    @ValueSource(strings = ["""{"role":"service_role"}""", """{"iss":"x","role":"service_role","exp":1}""", """{"role":"SERVICE_ROLE"}"""])
    fun `reprova JWT legado com role service_role`(payload: String) {
        assertThrows(IllegalArgumentException::class.java) {
            ConfiguracaoDoBackend.validar(urlSintetica, jwtSintetico(payload))
        }
    }

    @Test
    fun `reprova JWT service_role tambem com payload em base64 padrao com preenchimento`() {
        val payload = Base64.getEncoder().encodeToString("""{"role":"service_role"}""".toByteArray())
        val chave = "eyJhbGciOiJIUzI1NiJ9.$payload.assinatura_sintetica"

        assertThrows(IllegalArgumentException::class.java) {
            ConfiguracaoDoBackend.validar(urlSintetica, chave)
        }
    }

    @Test
    fun `aceita valor com tres partes que nao decodifica como JWT, pois nao ha role a recusar`() {
        ConfiguracaoDoBackend.validar(urlSintetica, "parte1.parte2.parte3")
    }

    @Test
    fun `a mensagem do JWT service_role nomeia o campo e nao repete o valor`() {
        val chave = jwtSintetico("""{"role":"service_role"}""")

        val erro = assertThrows(IllegalArgumentException::class.java) {
            ConfiguracaoDoBackend.validar(urlSintetica, chave)
        }

        assertTrue(erro.message.orEmpty().contains("SUPABASE_PUBLISHABLE_KEY"))
        assertTrue(erro.message.orEmpty().contains("service_role"))
        assertFalse(erro.message.orEmpty().contains(chave))
        assertFalse(erro.message.orEmpty().contains(chave.substringAfter('.').substringBefore('.')))
    }

    @Test
    fun `os casos compartilhados com a regra do Gradle dao o mesmo veredito`() {
        val linhas = checkNotNull(javaClass.getResourceAsStream("/supabase-chaves-casos.tsv")) {
            "supabase-chaves-casos.tsv ausente dos recursos de teste"
        }.bufferedReader().readLines().filter { it.isNotBlank() && !it.startsWith("#") }
        assertTrue(linhas.size >= 9)

        for (linha in linhas) {
            val (veredito, chave) = linha.split('\t', limit = 2)
            val aceitou = runCatching { ConfiguracaoDoBackend.validar(urlSintetica, chave) }.isSuccess
            assertEquals(veredito == "aceita", aceitou, "veredito divergente para o caso '$veredito' (${chave.take(12)}...)")
        }
    }
}
