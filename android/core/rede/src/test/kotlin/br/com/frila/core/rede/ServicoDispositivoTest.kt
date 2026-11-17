package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
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
    fun `registrarDispositivo manda versao_app quando conhecida e omite o campo quando nao (0_2_56)`() = runTest {
        val corpos = mutableListOf<String>()
        val engine = MockEngine { request ->
            corpos += (request.body as io.ktor.http.content.TextContent).text
            respond(
                content = """{"plataforma":"android","atualizado_em":"2026-10-22T10:00:00Z","vinculo_id":"vinculo-abc"}""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoDispositivo(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine))

        servico.registrarDispositivo(tokenFcm = "token-fcm-de-teste-com-mais-de-20-chars", versaoApp = "1.2.0")
        servico.registrarDispositivo(tokenFcm = "token-fcm-de-teste-com-mais-de-20-chars")

        assertEquals(2, corpos.size)
        assertTrue(corpos[0].contains("\"versao_app\":\"1.2.0\""), "com a versão, ela vai no corpo")
        assertTrue(!corpos[1].contains("versao_app"), "sem a versão, o campo não vai (nem como null)")
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

    @Test
    fun `removerDispositivo chama POST rpc remover_dispositivo com token_fcm`() = runTest {
        var caminhoChamado: String? = null
        var metodoChamado: HttpMethod? = null
        var corpoEnviado: String? = null
        val engine = MockEngine { request ->
            caminhoChamado = request.url.encodedPath
            metodoChamado = request.method
            corpoEnviado = (request.body as io.ktor.http.content.TextContent).text
            respond(
                content = """{"removido":true}""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoDispositivo(
            ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine),
        )

        servico.removerDispositivo(tokenFcm = "token-fcm-de-teste-com-mais-de-20-chars")

        assertEquals("/rest/v1/rpc/remover_dispositivo", caminhoChamado)
        assertEquals(HttpMethod.Post, metodoChamado)
        assertEquals("""{"token_fcm":"token-fcm-de-teste-com-mais-de-20-chars"}""", corpoEnviado)
    }

    @Test
    fun `removerDispositivo com removido falso nao e erro`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"removido":false}""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoDispositivo(
            ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine),
        )

        servico.removerDispositivo(tokenFcm = "token-fcm-de-teste-com-mais-de-20-chars")
    }

    @Test
    fun `removerDispositivo com erro da API lanca ErroDaApi`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"nao_autenticado","message":"jwt expirado"}""",
                status = HttpStatusCode.Unauthorized,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoDispositivo(
            ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine),
        )

        val erro = org.junit.jupiter.api.assertThrows<ErroDaApi> {
            servico.removerDispositivo(tokenFcm = "token-fcm-de-teste-com-mais-de-20-chars")
        }

        assertEquals(CodigoErroAPI.NAO_AUTENTICADO, erro.codigo)
    }

    @Test
    fun `removerDispositivo envia Authorization Bearer da sessao e apikey`() = runTest {
        var cabecalhos: Map<String, List<String>>? = null
        val engine = MockEngine { request ->
            cabecalhos = request.headers.entries().associate { it.key.lowercase() to it.value }
            respond(
                content = """{"removido":true}""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply {
            salvarSessao(Sessao(accessToken = "jwt-casa", refreshToken = "ref-casa", tokenType = "bearer", expiresIn = 3_600L))
        }
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            armazenamentoDeSessao = armazenamento,
            engine = engine,
        )

        ServicoDispositivo(cliente).removerDispositivo(tokenFcm = "token-fcm-de-teste-com-mais-de-20-chars")

        assertEquals(listOf("Bearer jwt-casa"), cabecalhos!!["authorization"])
        assertEquals(listOf("chave-teste"), cabecalhos!!["apikey"])
    }
}
