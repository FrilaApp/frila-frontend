package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ServicoDispositivoTest {

    @Test
    fun `registrarDispositivo chama POST rpc registrar_dispositivo com token_fcm e plataforma`() = runTest {
        var caminhoChamado: String? = null
        var metodoChamado: HttpMethod? = null
        var corpoEnviado: String? = null
        val engine = MockEngine { request ->
            caminhoChamado = request.url.encodedPath
            metodoChamado = request.method
            corpoEnviado = (request.body as io.ktor.http.content.TextContent).text
            respond(
                content = """{"plataforma":"android","atualizado_em":"2026-10-22T10:00:00Z","vinculo_id":"vinculo-abc"}""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoDispositivo(cliente)

        val dispositivo = servico.registrarDispositivo(tokenFcm = "token-fcm-de-teste-com-mais-de-20-chars")

        assertEquals("/rest/v1/rpc/registrar_dispositivo", caminhoChamado)
        assertEquals(HttpMethod.Post, metodoChamado)
        assertTrue(corpoEnviado!!.contains("token-fcm-de-teste-com-mais-de-20-chars"))
        assertTrue(corpoEnviado!!.contains("android"))
        assertEquals("android", dispositivo.plataforma)
        assertEquals("vinculo-abc", dispositivo.vinculoId)
    }

    @Test
    fun `registrarDispositivo com servidor anterior a 0_2_30 decodifica vinculo_id nulo`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"plataforma":"android","atualizado_em":"2026-10-22T10:00:00Z"}""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoDispositivo(cliente)

        val dispositivo = servico.registrarDispositivo(tokenFcm = "token-fcm-de-teste-com-mais-de-20-chars")

        assertNull(dispositivo.vinculoId)
    }

    @Test
    fun `registrarDispositivo com conta suspensa ainda registra (200, nao 403)`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"plataforma":"android","atualizado_em":"2026-10-22T10:00:00Z","vinculo_id":"vinculo-xyz"}""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoDispositivo(cliente)

        val dispositivo = servico.registrarDispositivo(tokenFcm = "token-fcm-de-teste-com-mais-de-20-chars")

        assertEquals("android", dispositivo.plataforma)
    }

    @Test
    fun `registrarDispositivo propaga NAO_AUTENTICADO em 401`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"nao_autenticado","message":"JWT ausente"}""",
                status = HttpStatusCode.Unauthorized,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoDispositivo(cliente)

        val excecao = runCatching { servico.registrarDispositivo(tokenFcm = "token-fcm-de-teste-com-mais-de-20-chars") }
            .exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        assertEquals(CodigoErroAPI.NAO_AUTENTICADO, (excecao as ErroDaApi).codigo)
    }
}
