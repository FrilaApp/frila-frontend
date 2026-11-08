package br.com.frila.core.rede

import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.get
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.ktor.http.content.TextContent
import io.ktor.http.isSuccess
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.util.concurrent.atomic.AtomicInteger

class ClienteSupabaseRefreshTest {

    private val sessaoInicial = Sessao(
        accessToken = "access-antigo",
        refreshToken = "refresh-antigo",
        tokenType = "bearer",
        expiresIn = 3_600L,
        vinculoId = "vinculo-preservado",
    )

    @Test
    fun `401 renova tokens persiste sessao e repete requisicao original`() = runTest {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(sessaoInicial) }
        val autorizacoes = mutableListOf<String?>()
        var chamadasDeRefresh = 0

        val engine = MockEngine { request ->
            when (request.url.encodedPath) {
                "/auth/v1/token" -> {
                    chamadasDeRefresh++
                    assertEquals(HttpMethod.Post, request.method)
                    assertEquals("refresh_token", request.url.parameters["grant_type"])
                    assertEquals("chave-anonima-de-teste", request.headers["apikey"])
                    assertEquals(
                        """{"refresh_token":"refresh-antigo"}""",
                        (request.body as TextContent).text,
                    )
                    respond(
                        content = """{"access_token":"access-novo","refresh_token":"refresh-novo","token_type":"bearer","expires_in":7200}""",
                        status = HttpStatusCode.OK,
                        headers = headersOf(HttpHeaders.ContentType, "application/json"),
                    )
                }
                else -> {
                    autorizacoes += request.headers[HttpHeaders.Authorization]
                    if (autorizacoes.size == 1) {
                        respond(
                            content = """{"code":"PGRST301","message":"JWT expired"}""",
                            status = HttpStatusCode.Unauthorized,
                            headers = headersOf(HttpHeaders.WWWAuthenticate, "Bearer"),
                        )
                    } else {
                        respond(content = "{}", status = HttpStatusCode.OK)
                    }
                }
            }
        }
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-anonima-de-teste",
            armazenamentoDeSessao = armazenamento,
            engine = engine,
        )

        val resposta = cliente.http.get(cliente.urlRpc("minha_conta"))

        assertTrue(resposta.status.isSuccess())
        assertEquals(1, chamadasDeRefresh)
        assertEquals(listOf("Bearer access-antigo", "Bearer access-novo"), autorizacoes)
        assertEquals(
            sessaoInicial.copy(
                accessToken = "access-novo",
                refreshToken = "refresh-novo",
                expiresIn = 7_200L,
            ),
            armazenamento.obterSessao(),
        )
    }

    @Test
    fun `falha no refresh limpa sessao e mantem resposta nao autorizada`() = runTest {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(sessaoInicial) }
        var chamadasDeRefresh = 0

        val engine = MockEngine { request ->
            if (request.url.encodedPath == "/auth/v1/token") {
                chamadasDeRefresh++
                respond(
                    content = """{"error":"invalid_grant"}""",
                    status = HttpStatusCode.BadRequest,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            } else {
                respond(
                    content = """{"code":"PGRST301","message":"JWT expired"}""",
                    status = HttpStatusCode.Unauthorized,
                    headers = headersOf(HttpHeaders.WWWAuthenticate, "Bearer"),
                )
            }
        }
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-anonima-de-teste",
            armazenamentoDeSessao = armazenamento,
            engine = engine,
        )

        val resposta = cliente.http.get(cliente.urlRpc("minha_conta"))

        assertEquals(HttpStatusCode.Unauthorized, resposta.status)
        assertEquals(1, chamadasDeRefresh)
        assertNull(armazenamento.obterSessao())
        assertFalse(armazenamento.estaAutenticado())
    }

    @Test
    fun `requisicoes concorrentes com 401 compartilham uma unica renovacao`() = runTest {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(sessaoInicial) }
        val chamadasDeRefresh = AtomicInteger(0)

        val engine = MockEngine { request ->
            when {
                request.url.encodedPath == "/auth/v1/token" -> {
                    chamadasDeRefresh.incrementAndGet()
                    delay(50)
                    respond(
                        content = """{"access_token":"access-novo","refresh_token":"refresh-novo","token_type":"bearer","expires_in":7200}""",
                        status = HttpStatusCode.OK,
                        headers = headersOf(HttpHeaders.ContentType, "application/json"),
                    )
                }
                request.headers[HttpHeaders.Authorization] == "Bearer access-antigo" -> respond(
                    content = """{"code":"PGRST301","message":"JWT expired"}""",
                    status = HttpStatusCode.Unauthorized,
                    headers = headersOf(HttpHeaders.WWWAuthenticate, "Bearer"),
                )
                else -> respond(content = "{}", status = HttpStatusCode.OK)
            }
        }
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-anonima-de-teste",
            armazenamentoDeSessao = armazenamento,
            engine = engine,
        )

        val respostas = coroutineScope {
            listOf("primeira", "segunda").map { nome ->
                async { cliente.http.get(cliente.urlRpc(nome)) }
            }.awaitAll()
        }

        assertTrue(respostas.all { it.status.isSuccess() })
        assertEquals(1, chamadasDeRefresh.get())
    }
}
