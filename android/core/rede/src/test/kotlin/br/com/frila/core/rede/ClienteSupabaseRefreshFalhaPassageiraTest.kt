package br.com.frila.core.rede

import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.get
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import java.net.UnknownHostException

/**
 * Falha passageira na renovação do token (DNS, tempo esgotado, 5xx) não pode apagar a sessão.
 * Só o Auth recusando o token (400, 401 ou 403) desloga; esse caso está em
 * `ClienteSupabaseRefreshTest` ("falha no refresh limpa sessao").
 */
class ClienteSupabaseRefreshFalhaPassageiraTest {

    private val sessaoInicial = Sessao(
        accessToken = "access-antigo",
        refreshToken = "refresh-antigo",
        tokenType = "bearer",
        expiresIn = 3_600L,
        vinculoId = "vinculo-preservado",
    )

    private fun cliente(armazenamento: ArmazenamentoDeSessaoEmMemoria, renovacao: suspend () -> Unit) =
        ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-anonima-de-teste",
            armazenamentoDeSessao = armazenamento,
            engine = MockEngine { request ->
                if (request.url.encodedPath == "/auth/v1/token") {
                    renovacao()
                    respond(content = "<html>503</html>", status = HttpStatusCode.ServiceUnavailable)
                } else {
                    respond(
                        content = """{"code":"PGRST301","message":"JWT expired"}""",
                        status = HttpStatusCode.Unauthorized,
                        headers = headersOf(HttpHeaders.WWWAuthenticate, "Bearer"),
                    )
                }
            },
        )

    @Test
    fun `dns caido na renovacao mantem a sessao`() = runTest {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(sessaoInicial) }
        val c = cliente(armazenamento) { throw UnknownHostException("frila.supabase.co") }

        runCatching { c.http.get(c.urlRpc("minha_conta")) }

        assertEquals(sessaoInicial, armazenamento.obterSessao())
    }

    @Test
    fun `servidor fora do ar na renovacao mantem a sessao`() = runTest {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(sessaoInicial) }
        val c = cliente(armazenamento) { }

        runCatching { c.http.get(c.urlRpc("minha_conta")) }

        assertEquals(sessaoInicial, armazenamento.obterSessao())
    }
}
