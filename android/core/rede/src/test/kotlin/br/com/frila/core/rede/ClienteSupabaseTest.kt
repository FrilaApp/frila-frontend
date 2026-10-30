package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.network.sockets.ConnectTimeoutException
import io.ktor.client.plugins.HttpRequestTimeoutException
import io.ktor.client.request.get
import io.ktor.client.request.post
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.net.UnknownHostException
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ClienteSupabaseTest {

    private fun clienteCom(engine: MockEngine, monitorDeConectividade: MonitorDeConectividade? = null) = ClienteSupabase(
        baseUrl = "https://frila.supabase.co",
        apiKey = "chave-anonima-de-teste",
        provedorDeToken = ProvedorDeToken { "token-de-sessao-123" },
        engine = engine,
        monitorDeConectividade = monitorDeConectividade,
    )

    @Test
    fun `200 OK decodifica o corpo no tipo esperado`() = runTest {
        val engine = MockEngine { request ->
            respond(
                content = """{"access_token":"abc","refresh_token":"def","token_type":"bearer","expires_in":3600}""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = clienteCom(engine)

        val resposta = cliente.http.get(cliente.urlRpc("minha_conta"))
        val sessao: SessaoDto = cliente.corpoOuErro(resposta)

        assertEquals("abc", sessao.accessToken)
        assertEquals(3600L, sessao.expiresIn)
    }

    @Test
    fun `injeta header apikey em toda requisicao`() = runTest {
        var apikeyRecebida: String? = null
        val engine = MockEngine { request ->
            apikeyRecebida = request.headers["apikey"]
            respond(content = "{}", status = HttpStatusCode.OK)
        }
        val cliente = clienteCom(engine)

        cliente.http.get(cliente.urlRpc("minha_conta"))

        assertEquals("chave-anonima-de-teste", apikeyRecebida)
    }

    @Test
    fun `injeta Authorization Bearer quando ha token de sessao`() = runTest {
        var authorizationRecebida: String? = null
        val engine = MockEngine { request ->
            authorizationRecebida = request.headers[HttpHeaders.Authorization]
            respond(content = "{}", status = HttpStatusCode.OK)
        }
        val cliente = clienteCom(engine)

        cliente.http.get(cliente.urlRpc("minha_conta"))

        assertEquals("Bearer token-de-sessao-123", authorizationRecebida)
    }

    @Test
    fun `sem token de sessao nao envia header Authorization`() = runTest {
        var authorizationRecebida: String? = "valor-inicial-nao-sobrescrito"
        val engine = MockEngine { request ->
            authorizationRecebida = request.headers[HttpHeaders.Authorization]
            respond(content = "{}", status = HttpStatusCode.OK)
        }
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-anonima-de-teste",
            engine = engine,
        )

        cliente.http.get(cliente.urlRpc("minha_conta"))

        assertNull(authorizationRecebida)
    }

    @Test
    fun `400 campo_invalido mapeia para CodigoErroAPI CAMPO_INVALIDO`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"campo_invalido","message":"limite fora do intervalo","details":"limite"}""",
                status = HttpStatusCode.BadRequest,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = clienteCom(engine)
        val resposta = cliente.http.get(cliente.urlRpc("vagas_abertas"))

        val erro = runCatching { cliente.corpoOuErro<List<VagaAbertaDto>>(resposta) }
            .exceptionOrNull() as? ErroDaApi

        assertEquals(CodigoErroAPI.CAMPO_INVALIDO, erro?.codigo)
        assertEquals("limite", erro?.detalhes)
    }

    @Test
    fun `401 nao_autenticado mapeia para CodigoErroAPI NAO_AUTENTICADO`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"nao_autenticado","message":"JWT ausente"}""",
                status = HttpStatusCode.Unauthorized,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = clienteCom(engine)
        val resposta = cliente.http.get(cliente.urlRpc("minha_conta"))

        val erro = runCatching { cliente.corpoOuErro<SessaoDto>(resposta) }
            .exceptionOrNull() as? ErroDaApi

        assertEquals(CodigoErroAPI.NAO_AUTENTICADO, erro?.codigo)
    }

    @Test
    fun `401 com PGRST301 (JWT expirado) tambem mapeia para NAO_AUTENTICADO`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"PGRST301","message":"JWT expired"}""",
                status = HttpStatusCode.Unauthorized,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = clienteCom(engine)
        val resposta = cliente.http.get(cliente.urlRpc("minha_conta"))

        val erro = runCatching { cliente.corpoOuErro<SessaoDto>(resposta) }
            .exceptionOrNull() as? ErroDaApi

        assertEquals(CodigoErroAPI.NAO_AUTENTICADO, erro?.codigo)
        assertEquals("PGRST301", erro?.codigoOriginal)
    }

    @Test
    fun `422 perfil_incompativel mapeia para CodigoErroAPI PERFIL_INCOMPATIVEL`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"perfil_incompativel","message":"conta de contratante"}""",
                status = HttpStatusCode.UnprocessableEntity,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = clienteCom(engine)
        val resposta = cliente.http.get(cliente.urlRpc("vagas_abertas"))

        val erro = runCatching { cliente.corpoOuErro<List<VagaAbertaDto>>(resposta) }
            .exceptionOrNull() as? ErroDaApi

        assertEquals(CodigoErroAPI.PERFIL_INCOMPATIVEL, erro?.codigo)
    }

    @Test
    fun `codigo de erro desconhecido do backend mapeia para DESCONHECIDO sem derrubar o parse`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"um_codigo_que_ainda_nao_existe","message":"erro novo do backend"}""",
                status = HttpStatusCode.UnprocessableEntity,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = clienteCom(engine)
        val resposta = cliente.http.get(cliente.urlRpc("vagas_abertas"))

        val erro = runCatching { cliente.corpoOuErro<List<VagaAbertaDto>>(resposta) }
            .exceptionOrNull() as? ErroDaApi

        assertEquals(CodigoErroAPI.DESCONHECIDO, erro?.codigo)
        assertEquals("um_codigo_que_ainda_nao_existe", erro?.codigoOriginal)
    }

    // RNF01/RNF04: timeout adaptativo + retry exponencial para leitura, nunca para mutação.

    @Test
    fun `GET com 503 nas duas primeiras tentativas e sucesso na terceira retenta automaticamente`() = runTest {
        val tentativas = AtomicInteger(0)
        val engine = MockEngine {
            if (tentativas.incrementAndGet() < 3) {
                respond(content = "", status = HttpStatusCode.ServiceUnavailable)
            } else {
                respond(
                    content = """{"id":"f1","nome":"garçom","categoria":"Salão"}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            }
        }
        val cliente = clienteCom(engine)

        val resposta = cliente.http.get(cliente.urlRpc("vagas_abertas"))

        assertEquals(3, tentativas.get())
        assertEquals(HttpStatusCode.OK, resposta.status)
    }

    @Test
    fun `POST com 503 nunca e retentado - mutacao critica nao pode duplicar efeito`() = runTest {
        val tentativas = AtomicInteger(0)
        val engine = MockEngine {
            tentativas.incrementAndGet()
            respond(content = "", status = HttpStatusCode.ServiceUnavailable)
        }
        val cliente = clienteCom(engine)

        cliente.http.post(cliente.urlRpc("candidatar"))

        assertEquals(1, tentativas.get())
    }

    @Test
    fun `GET com 400 nao e retentado`() = runTest {
        val tentativas = AtomicInteger(0)
        val engine = MockEngine {
            tentativas.incrementAndGet()
            respond(
                content = """{"code":"campo_invalido","message":"erro"}""",
                status = HttpStatusCode.BadRequest,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = clienteCom(engine)

        cliente.http.get(cliente.urlRpc("vagas_abertas"))

        assertEquals(1, tentativas.get())
    }

    @Test
    fun `GET com 401 nao e retentado`() = runTest {
        val tentativas = AtomicInteger(0)
        val engine = MockEngine {
            tentativas.incrementAndGet()
            respond(content = """{"code":"nao_autenticado","message":"erro"}""", status = HttpStatusCode.Unauthorized)
        }
        val cliente = clienteCom(engine)

        cliente.http.get(cliente.urlRpc("minha_conta"))

        assertEquals(1, tentativas.get())
    }

    @Test
    fun `GET com 422 nao e retentado`() = runTest {
        val tentativas = AtomicInteger(0)
        val engine = MockEngine {
            tentativas.incrementAndGet()
            respond(content = """{"code":"perfil_incompativel","message":"erro"}""", status = HttpStatusCode.UnprocessableEntity)
        }
        val cliente = clienteCom(engine)

        cliente.http.get(cliente.urlRpc("vagas_abertas"))

        assertEquals(1, tentativas.get())
    }

    @Test
    fun `ConnectTimeoutException e convertida em ErroDaApi SEM_REDE sem derrubar o app`() = runTest {
        val engine = MockEngine { throw ConnectTimeoutException("sem rota para o host", null) }
        val cliente = clienteCom(engine)

        val erro = runCatching { cliente.http.get(cliente.urlRpc("vagas_abertas")) }
            .exceptionOrNull() as? ErroDaApi

        assertEquals(CodigoErroAPI.SEM_REDE, erro?.codigo)
    }

    @Test
    fun `SocketTimeoutException e convertida em ErroDaApi SEM_REDE sem derrubar o app`() = runTest {
        val engine = MockEngine { throw io.ktor.client.network.sockets.SocketTimeoutException("conexão caiu", null) }
        val cliente = clienteCom(engine)

        val erro = runCatching { cliente.http.get(cliente.urlRpc("vagas_abertas")) }
            .exceptionOrNull() as? ErroDaApi

        assertEquals(CodigoErroAPI.SEM_REDE, erro?.codigo)
    }

    @Test
    fun `HttpRequestTimeoutException e convertida em ErroDaApi SEM_REDE sem derrubar o app`() = runTest {
        val engine = MockEngine { request -> throw HttpRequestTimeoutException(request) }
        val cliente = clienteCom(engine)

        val erro = runCatching { cliente.http.get(cliente.urlRpc("vagas_abertas")) }
            .exceptionOrNull() as? ErroDaApi

        assertEquals(CodigoErroAPI.SEM_REDE, erro?.codigo)
    }

    @Test
    fun `UnknownHostException e convertida em ErroDaApi SEM_REDE sem derrubar o app`() = runTest {
        val engine = MockEngine { throw UnknownHostException("frila.supabase.co") }
        val cliente = clienteCom(engine)

        val erro = runCatching { cliente.http.get(cliente.urlRpc("vagas_abertas")) }
            .exceptionOrNull() as? ErroDaApi

        assertEquals(CodigoErroAPI.SEM_REDE, erro?.codigo)
    }

    @Test
    fun `falha de conectividade tambem e retentada em GET - esgota as tentativas e converte em SEM_REDE`() = runTest {
        val tentativas = AtomicInteger(0)
        val engine = MockEngine {
            tentativas.incrementAndGet()
            throw ConnectTimeoutException("timeout", null)
        }
        val cliente = clienteCom(engine)

        val erro = runCatching { cliente.http.get(cliente.urlRpc("vagas_abertas")) }
            .exceptionOrNull() as? ErroDaApi

        assertEquals(CodigoErroAPI.SEM_REDE, erro?.codigo)
        assertEquals(4, tentativas.get()) // 1 tentativa original + 3 retries
    }

    @Test
    fun `falha de conectividade em POST nao e retentada`() = runTest {
        val tentativas = AtomicInteger(0)
        val engine = MockEngine {
            tentativas.incrementAndGet()
            throw ConnectTimeoutException("timeout", null)
        }
        val cliente = clienteCom(engine)

        runCatching { cliente.http.post(cliente.urlRpc("candidatar")) }

        assertEquals(1, tentativas.get())
    }

    // RNF01/RNF04: fail-fast pré-voo quando o monitor de conectividade já sabe que está offline.

    @Test
    fun `sem conexao conhecida aborta a requisicao sem tocar o engine`() = runTest {
        val tentativas = AtomicInteger(0)
        val engine = MockEngine {
            tentativas.incrementAndGet()
            respond(content = "{}", status = HttpStatusCode.OK)
        }
        val monitor = MonitorDeConectividadeFalso(statusInicial = StatusConectividade.SEM_CONEXAO)
        val cliente = clienteCom(engine, monitor)

        val erro = runCatching { cliente.http.get(cliente.urlRpc("vagas_abertas")) }
            .exceptionOrNull() as? ErroDaApi

        assertEquals(CodigoErroAPI.SEM_REDE, erro?.codigo)
        assertEquals(0, tentativas.get()) { "o engine não deveria ser chamado: fail-fast é 0ms, sem tentar a rede" }
    }

    @Test
    fun `conexao conhecida como ativa nao interfere na requisicao normal`() = runTest {
        val engine = MockEngine { respond(content = "{}", status = HttpStatusCode.OK) }
        val monitor = MonitorDeConectividadeFalso(statusInicial = StatusConectividade.CONECTADO)
        val cliente = clienteCom(engine, monitor)

        val resposta = cliente.http.get(cliente.urlRpc("vagas_abertas"))

        assertEquals(HttpStatusCode.OK, resposta.status)
    }

    @Test
    fun `monitor nulo preserva o comportamento padrao sem fail-fast`() = runTest {
        val engine = MockEngine { respond(content = "{}", status = HttpStatusCode.OK) }
        val cliente = clienteCom(engine, monitorDeConectividade = null)

        val resposta = cliente.http.get(cliente.urlRpc("vagas_abertas"))

        assertEquals(HttpStatusCode.OK, resposta.status)
    }

    @Test
    fun `retry de GET para quando a conectividade cai no meio da requisicao`() = runTest {
        val tentativas = AtomicInteger(0)
        val monitor = MonitorDeConectividadeFalso(statusInicial = StatusConectividade.CONECTADO)
        val engine = MockEngine {
            tentativas.incrementAndGet()
            // A primeira tentativa já derruba a conectividade, simulando a rede caindo
            // no meio da chamada — o retry automático não deve nem tentar de novo.
            monitor.definirStatus(StatusConectividade.SEM_CONEXAO)
            respond(content = "", status = HttpStatusCode.ServiceUnavailable)
        }
        val cliente = clienteCom(engine, monitor)

        runCatching { cliente.http.get(cliente.urlRpc("vagas_abertas")) }

        assertEquals(1, tentativas.get()) { "retry não deveria ocorrer com a conectividade caída" }
    }

    @Test
    fun `retry de GET por excecao de rede para quando a conectividade cai no meio da requisicao`() = runTest {
        // Mesmo cenário do teste acima, mas pelo caminho de retryOnExceptionIf (exceção de rede
        // crua do engine, ex. ConnectTimeoutException) em vez de retryIf (resposta HTTP 503) —
        // ressalva do Shisui, PR #604: o guard de conectividade em retryOnExceptionIf tinha
        // mutante sobrevivente por falta deste teste.
        val tentativas = AtomicInteger(0)
        val monitor = MonitorDeConectividadeFalso(statusInicial = StatusConectividade.CONECTADO)
        val engine = MockEngine {
            tentativas.incrementAndGet()
            monitor.definirStatus(StatusConectividade.SEM_CONEXAO)
            throw ConnectTimeoutException("timeout", null)
        }
        val cliente = clienteCom(engine, monitor)

        val erro = runCatching { cliente.http.get(cliente.urlRpc("vagas_abertas")) }
            .exceptionOrNull() as? ErroDaApi

        assertEquals(1, tentativas.get()) { "retry por excecao não deveria ocorrer com a conectividade caída" }
        assertEquals(CodigoErroAPI.SEM_REDE, erro?.codigo)
    }

    @Test
    fun `CancellationException nunca e convertida em ErroDaApi e propaga intacta`() = runTest {
        val engine = MockEngine { throw kotlinx.coroutines.CancellationException("cancelado") }
        val cliente = clienteCom(engine)

        val excecao = runCatching { cliente.http.get(cliente.urlRpc("vagas_abertas")) }.exceptionOrNull()

        assertTrue(excecao is kotlinx.coroutines.CancellationException)
    }
}
