package br.com.frila.app

import br.com.frila.app.falhas.DestinoDeFalhas
import br.com.frila.app.falhas.TelemetriaDeFalhas
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.GestorClienteKtor
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.get
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.mockk
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.dsl.module
import org.koin.test.KoinTest
import org.koin.test.get

/** L1-7d: o cliente de rede do grafo real avisa a telemetria de falhas, e ela sai com a coleta desligada (manifesto), como o iOS 1.1. */
class KoinTelemetriaDeFalhasTest : KoinTest {

    private class Espiao : DestinoDeFalhas {
        val gravados = mutableListOf<Triple<String, String, Long>>()
        override fun gravar(codigo: String, rpc: String, duracaoNs: Long) { gravados += Triple(codigo, rpc, duracaoNs) }
    }

    @AfterEach
    fun depois() = stopKoin()

    private val modulosDeTeste = module {
        single<ProvedorDeLocalizacao> { mockk(relaxed = true) }
    }

    private suspend fun respostaDeErro() =
        ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine { respond("""{"code":"sem_permissao","message":"x"}""", HttpStatusCode.Forbidden, headersOf(HttpHeaders.ContentType, "application/json")) },
        ).http.get("https://frila.supabase.co/rest/v1/rpc/minha_conta?token=SEGREDO")

    @Test
    fun `sem Context o grafo sai com a coleta desligada e nada chega ao destino`() = runBlocking {
        val espiao = Espiao()
        startKoin { modules(listOf(moduloSeguranca, moduloRede, moduloNotificacoes, modulosDeTeste, moduloFeatures) + module { single<DestinoDeFalhas> { espiao } }) }
        get<GestorClienteKtor>().clienteAtual.erroDaResposta(respostaDeErro())
        assertTrue(espiao.gravados.isEmpty())
    }

    @Test
    fun `com a coleta ligada o erro da resposta chega ao destino so com codigo, rota e duracao`() = runBlocking {
        val espiao = Espiao()
        startKoin {
            modules(
                listOf(moduloSeguranca, moduloRede, moduloNotificacoes, modulosDeTeste, moduloFeatures) +
                    module { single { TelemetriaDeFalhas(coletaLigada = true, destino = espiao) } },
            )
        }
        get<GestorClienteKtor>().clienteAtual.erroDaResposta(respostaDeErro())
        val (codigo, rpc, duracao) = espiao.gravados.single()
        assertEquals("sem_permissao", codigo)
        assertEquals("minha_conta", rpc)
        assertTrue(duracao >= 0)
    }
}
