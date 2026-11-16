package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.content.TextContent
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.runBlocking
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

    private fun erroDeSolicitarOtp(status: HttpStatusCode, corpo: String, tipo: String = "application/json"): ErroDaApi {
        val engine = MockEngine {
            respond(content = corpo, status = status, headers = headersOf(HttpHeaders.ContentType, tipo))
        }
        val servico = ServicoAutenticacao(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine))
        val excecao = runCatching { runBlocking { servico.solicitarOtp("profissional@exemplo.com") } }.exceptionOrNull()
        assertTrue(excecao is ErroDaApi, "esperava ErroDaApi, veio $excecao")
        return excecao as ErroDaApi
    }

    @Test
    fun `solicitarOtp 429 do Auth com code numerico e sem message vira LIMITE_EXCEDIDO`() {
        val erro = erroDeSolicitarOtp(HttpStatusCode.TooManyRequests, """{"code":429,"error_code":"over_email_send_rate_limit"}""")

        assertEquals(CodigoErroAPI.LIMITE_EXCEDIDO, erro.codigo)
        assertEquals("over_email_send_rate_limit", erro.codigoOriginal)
    }

    @Test
    fun `solicitarOtp 429 do Auth no formato completo usa msg como mensagem crua`() {
        val erro = erroDeSolicitarOtp(
            HttpStatusCode.TooManyRequests,
            """{"code":429,"error_code":"over_email_send_rate_limit","msg":"email rate limit exceeded"}""",
        )

        assertEquals(CodigoErroAPI.LIMITE_EXCEDIDO, erro.codigo)
        assertEquals("email rate limit exceeded", erro.mensagemCrua)
    }

    @Test
    fun `solicitarOtp over_request_rate_limit vira LIMITE_EXCEDIDO mesmo sem status 429`() {
        val erro = erroDeSolicitarOtp(HttpStatusCode.BadRequest, """{"error_code":"over_request_rate_limit"}""")

        assertEquals(CodigoErroAPI.LIMITE_EXCEDIDO, erro.codigo)
    }

    @Test
    fun `corpo de erro vazio ou que nao e json vira ErroDaApi em vez de excecao de serializacao`() {
        assertEquals(CodigoErroAPI.DESCONHECIDO, erroDeSolicitarOtp(HttpStatusCode.InternalServerError, "").codigo)
        assertEquals(
            CodigoErroAPI.DESCONHECIDO,
            erroDeSolicitarOtp(HttpStatusCode.BadGateway, "<html>Bad Gateway</html>", "text/html").codigo,
        )
        assertEquals(CodigoErroAPI.LIMITE_EXCEDIDO, erroDeSolicitarOtp(HttpStatusCode.TooManyRequests, "").codigo)
    }

    @Test
    fun `envelope PostgREST completo continua mapeado pelo code do dominio`() {
        val erro = erroDeSolicitarOtp(
            HttpStatusCode.TooManyRequests,
            """{"code":"limite_de_chamadas","message":"x","details":"d"}""",
        )

        assertEquals(CodigoErroAPI.LIMITE_DE_CHAMADAS, erro.codigo)
        assertEquals("d", erro.detalhes)
    }
}
