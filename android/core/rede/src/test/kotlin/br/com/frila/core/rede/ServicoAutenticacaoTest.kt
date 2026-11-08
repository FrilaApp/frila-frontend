package br.com.frila.core.rede

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.content.TextContent
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ServicoAutenticacaoTest {

    @Test
    fun `solicitarOtp chama auth v1 otp com o email no corpo`() = runTest {
        var caminhoChamado: String? = null
        var corpoEnviado: String? = null
        val engine = MockEngine { request ->
            caminhoChamado = request.url.encodedPath
            corpoEnviado = (request.body as TextContent).text
            respond(content = "{}", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoAutenticacao(cliente)

        servico.solicitarOtp("profissional@exemplo.com")

        assertEquals("/auth/v1/otp", caminhoChamado)
        assertTrue(corpoEnviado!!.contains("profissional@exemplo.com"))
    }

    @Test
    fun `verificarOtp chama auth v1 verify e devolve a sessao decodificada`() = runTest {
        val engine = MockEngine { request ->
            respond(
                content = """{"access_token":"tok123","refresh_token":"ref456","token_type":"bearer","expires_in":3600}""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoAutenticacao(cliente)

        val sessao = servico.verificarOtp("profissional@exemplo.com", "123456")

        assertEquals("tok123", sessao.accessToken)
        assertEquals("bearer", sessao.tokenType)
    }

    @Test
    fun `verificarOtp propaga ErroDaApi quando o codigo esta errado`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"campo_invalido","message":"codigo invalido","details":"token"}""",
                status = HttpStatusCode.BadRequest,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoAutenticacao(cliente)

        val excecao = runCatching { servico.verificarOtp("profissional@exemplo.com", "000000") }
            .exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
    }
}
