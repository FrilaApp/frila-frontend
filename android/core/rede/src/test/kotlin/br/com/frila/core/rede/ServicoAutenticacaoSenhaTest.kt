package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ServicoAutenticacaoSenhaTest {

    @Test
    fun `solicitarOtp envia create_user true e solicitarOtpRecuperacao envia create_user false`() = runTest {
        val corpos = mutableListOf<String>()
        val engine = MockEngine { request ->
            assertEquals("/auth/v1/otp", request.url.encodedPath)
            corpos += (request.body as TextContent).text
            respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val servico = ServicoAutenticacao(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        servico.solicitarOtp("novo@exemplo.test")
        servico.solicitarOtpRecuperacao("legado@exemplo.test")

        assertEquals(2, corpos.size)
        assertTrue(corpos[0].contains("\"create_user\":true"), "esperava create_user:true, veio ${corpos[0]}")
        assertTrue(corpos[1].contains("\"create_user\":false"), "esperava create_user:false, veio ${corpos[1]}")
    }

    @Test
    fun `entrarComSenha usa grant_type password e decodifica a sessao`() = runTest {
        var caminho: String? = null
        var query: String? = null
        var corpo: String? = null
        val engine = MockEngine { request ->
            caminho = request.url.encodedPath
            query = request.url.encodedQuery
            corpo = (request.body as TextContent).text
            respond(
                content = """{"access_token":"tok-senha","refresh_token":"ref-senha","token_type":"bearer","expires_in":3600}""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoAutenticacao(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val sessao = servico.entrarComSenha("conta@exemplo.test", "SenhaSintetica#2026")

        assertEquals("/auth/v1/token", caminho)
        assertEquals("grant_type=password", query)
        assertTrue(corpo!!.contains("conta@exemplo.test"))
        assertEquals("tok-senha", sessao.accessToken)
        assertEquals("ref-senha", sessao.refreshToken)
    }

    @Test
    fun `atualizarSenha envia PUT auth v1 user com o Bearer da sessao ativa`() = runTest {
        var metodo: HttpMethod? = null
        var caminho: String? = null
        var authHeader: String? = null
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply {
            salvarSessao(Sessao("tok-sessao-ativa", "ref-1", "bearer", 3600))
        }
        val engine = MockEngine { request ->
            metodo = request.method
            caminho = request.url.encodedPath
            authHeader = request.headers[HttpHeaders.Authorization]
            respond("""{"id":"uid-mesmo"}""", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            armazenamentoDeSessao = armazenamento,
            engine = engine,
        )
        val servico = ServicoAutenticacao(cliente)

        servico.atualizarSenha("NovaSenha#2026")

        assertEquals(HttpMethod.Put, metodo)
        assertEquals("/auth/v1/user", caminho)
        assertEquals("Bearer tok-sessao-ativa", authHeader)
    }

    @Test
    fun `mapearCodigo converte erros de senha e recovery-only do GoTrue corretamente`() = runTest {
        assertEquals(
            CodigoErroAPI.NAO_AUTENTICADO,
            ClienteSupabase.mapearCodigo("400", HttpStatusCode.BadRequest, "invalid_credentials"),
        )
        assertEquals(
            CodigoErroAPI.NAO_AUTENTICADO,
            ClienteSupabase.mapearCodigo("401", HttpStatusCode.Unauthorized, "reauthentication_needed"),
        )
        assertEquals(
            CodigoErroAPI.CAMPO_INVALIDO,
            ClienteSupabase.mapearCodigo("422", HttpStatusCode.UnprocessableEntity, "weak_password"),
        )
        assertEquals(
            CodigoErroAPI.CAMPO_INVALIDO,
            ClienteSupabase.mapearCodigo("422", HttpStatusCode.UnprocessableEntity, "same_password"),
        )
        assertEquals(
            CodigoErroAPI.NAO_ENCONTRADO,
            ClienteSupabase.mapearCodigo("422", HttpStatusCode.UnprocessableEntity, "otp_disabled"),
        )
        assertEquals(
            CodigoErroAPI.NAO_ENCONTRADO,
            ClienteSupabase.mapearCodigo("404", HttpStatusCode.NotFound, "user_not_found"),
        )
        assertEquals(
            CodigoErroAPI.LIMITE_EXCEDIDO,
            ClienteSupabase.mapearCodigo("429", HttpStatusCode.TooManyRequests, "over_email_send_rate_limit"),
        )
    }

    @Test
    fun `entrarComSenha offline falha rapido com SEM_REDE sem bater na rede`() = runTest {
        var chamadas = 0
        val engine = MockEngine {
            chamadas++
            respond("{}", HttpStatusCode.OK)
        }
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            monitorDeConectividade = MonitorDeConectividadeFalso(StatusConectividade.SEM_CONEXAO),
            engine = engine,
        )
        val servico = ServicoAutenticacao(cliente)

        val erro = runCatching { servico.entrarComSenha("conta@exemplo.test", "Senha#2026") }.exceptionOrNull()

        assertTrue(erro is ErroDaApi)
        assertEquals(CodigoErroAPI.SEM_REDE, (erro as ErroDaApi).codigo)
        assertEquals(0, chamadas)
    }
}
