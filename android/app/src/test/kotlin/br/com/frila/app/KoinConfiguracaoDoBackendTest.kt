package br.com.frila.app

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.GestorClienteKtor
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import org.koin.core.context.GlobalContext
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.dsl.module

class KoinConfiguracaoDoBackendTest {
    @AfterEach
    fun depois() {
        stopKoin()
    }

    @Test
    fun `o cliente de rede do grafo real usa a URL do BuildConfig`() {
        startKoin { modules(moduloSeguranca, moduloRede) }

        val cliente = GlobalContext.get().get<GestorClienteKtor>().clienteAtual

        assertEquals(BuildConfig.SUPABASE_URL.trim(), cliente.baseUrl)
    }

    @Test
    fun `a URL do cliente vem da configuracao registrada no grafo, nao de literal`() {
        val sintetica = ConfiguracaoDoBackend.validar("https://exemplo.invalid", "sb_publishable_sintetica")
        startKoin { modules(moduloSeguranca, moduloRede, module { single { sintetica } }) }

        val cliente = GlobalContext.get().get<GestorClienteKtor>().clienteAtual

        assertEquals("https://exemplo.invalid", cliente.baseUrl)
    }

    @Test
    fun `a chave publicavel do cliente vem da configuracao registrada no grafo, nao de literal`() {
        val sintetica = ConfiguracaoDoBackend.validar("https://exemplo.invalid", "sb_publishable_sintetica")
        startKoin { modules(moduloSeguranca, moduloRede, module { single { sintetica } }) }

        val cliente = GlobalContext.get().get<GestorClienteKtor>().clienteAtual

        // `apiKey` é privada em ClienteSupabase e nenhum motor de teste entra pelo grafo real.
        val campo = ClienteSupabase::class.java.getDeclaredField("apiKey").apply { isAccessible = true }
        assertEquals("sb_publishable_sintetica", campo.get(cliente))
    }

    @Test
    fun `os valores do BuildConfig desta variante passam na validacao`() {
        val configuracao = configuracaoDoBackend()

        assertEquals(BuildConfig.SUPABASE_URL.trim(), configuracao.url)
        assertEquals(BuildConfig.SUPABASE_PUBLISHABLE_KEY.trim(), configuracao.chavePublicavel)
    }
}
