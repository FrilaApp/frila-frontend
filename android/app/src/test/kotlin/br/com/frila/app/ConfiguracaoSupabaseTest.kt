package br.com.frila.app

import java.util.Base64
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

/**
 * Pedido 16-26: a config do Supabase vem do BuildConfig, e chave proibida não serve. Só dados SINTÉTICOS
 * (o JWT é montado aqui, com assinatura falsa, para a regra do `role`).
 */
class ConfiguracaoSupabaseTest {

    private val urlDeExemplo = "https://exemplo.supabase.co"
    private val chaveDeExemplo = "sb_publishable_exemplo"

    private fun jwtSintetico(role: String): String {
        val base64 = Base64.getUrlEncoder().withoutPadding()
        val cabecalho = base64.encodeToString("""{"alg":"HS256","typ":"JWT"}""".toByteArray())
        val carga = base64.encodeToString("""{"iss":"exemplo","role":"$role"}""".toByteArray())
        return "$cabecalho.$carga.assinatura-falsa"
    }

    @Test
    fun `le a URL e a chave do BuildConfig`() {
        val configuracao = ConfiguracaoSupabase.doBuildConfig()

        assertEquals(BuildConfig.SUPABASE_URL, configuracao.url)
        assertEquals(BuildConfig.SUPABASE_PUBLISHABLE_KEY, configuracao.chavePublicavel)
    }

    @Test
    fun `par com URL https e chave publicavel serve, inclusive a chave anon antiga em JWT`() {
        assertNull(ConfiguracaoSupabase(urlDeExemplo, chaveDeExemplo).problema)
        assertNull(ConfiguracaoSupabase(urlDeExemplo, jwtSintetico("anon")).problema)
    }

    @Test
    fun `debug sem o par DEV avisa que a URL nao esta configurada`() {
        val configuracao = ConfiguracaoSupabase(ConfiguracaoSupabase.URL_SEM_CONFIGURACAO, "")

        assertEquals("URL não configurada", configuracao.problema)
    }

    @Test
    fun `recusa chave vazia, placeholder, secreta e JWT de service_role`() {
        val casos = listOf(
            "" to "chave não configurada",
            "   " to "chave não configurada",
            "TODO_INJETAR_VIA_BUILDCONFIG" to "chave é placeholder (TODO)",
            "sb_secret_exemplo" to "chave secreta (sb_secret_); use a publicável",
            jwtSintetico("service_role") to "JWT com role service_role; use a publicável",
        )

        casos.forEach { (chave, esperado) ->
            assertEquals(esperado, ConfiguracaoSupabase.motivoDeRecusaDaChave(chave), "caso: $esperado")
        }
    }

    @Test
    fun `recusa URL vazia, placeholder e sem https`() {
        assertEquals("URL não configurada", ConfiguracaoSupabase.motivoDeRecusaDaUrl(""))
        assertEquals("URL é placeholder (TODO)", ConfiguracaoSupabase.motivoDeRecusaDaUrl("TODO_URL"))
        assertEquals("URL não usa https", ConfiguracaoSupabase.motivoDeRecusaDaUrl("http://exemplo.supabase.co"))
    }

    @Test
    fun `o motivo e o toString nunca repetem os valores`() {
        val chaveProibida = "sb_secret_exemplo"
        val configuracao = ConfiguracaoSupabase(urlDeExemplo, chaveProibida)

        val problema = configuracao.problema
        assertNotNull(problema)
        assertFalse(problema!!.contains(chaveProibida))
        assertFalse(configuracao.toString().contains(chaveProibida))
        assertFalse(configuracao.toString().contains(urlDeExemplo))
    }
}
