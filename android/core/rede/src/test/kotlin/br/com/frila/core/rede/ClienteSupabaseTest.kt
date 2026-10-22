package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.get
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

class ClienteSupabaseTest {

    private fun clienteCom(engine: MockEngine) = ClienteSupabase(
        baseUrl = "https://frila.supabase.co",
        apiKey = "chave-anonima-de-teste",
        provedorDeToken = ProvedorDeToken { "token-de-sessao-123" },
        engine = engine,
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
}
