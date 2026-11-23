package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.net.UnknownHostException
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class ServicoExportarMeusDadosTest {
    @Test
    fun `exporta bytes intactos com POST autenticado`() = runTest {
        // Campos desconhecidos, espaços e UTF-8 precisam permanecer idênticos.
        val dados = """{ "campo_futuro": ["ação"], "nome": "Pessoa Teste" }""".toByteArray()
        val engine = MockEngine { pedido ->
            assertEquals("/functions/v1/exportar-meus-dados", pedido.url.encodedPath)
            assertEquals(HttpMethod.Post, pedido.method)
            assertEquals("Bearer token-sintetico", pedido.headers[HttpHeaders.Authorization])
            respond(dados, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        ClienteSupabase("https://sintetico.invalid", "chave-teste", ProvedorDeToken { "token-sintetico" }, engine = engine).use {
            assertArrayEquals(dados, ServicoConta(it).exportarMeusDados())
        }
    }

    @Test
    fun `mapeia 401 404 e 405 pela resposta comum`() = runTest {
        for ((status, codigo) in listOf(
            HttpStatusCode.Unauthorized to CodigoErroAPI.NAO_AUTENTICADO,
            HttpStatusCode.NotFound to CodigoErroAPI.NAO_ENCONTRADO,
            HttpStatusCode.MethodNotAllowed to CodigoErroAPI.DESCONHECIDO,
        )) {
            val engine = MockEngine {
                val codigoOriginal = when (status) {
                    HttpStatusCode.Unauthorized -> "nao_autenticado"
                    HttpStatusCode.NotFound -> "nao_encontrado"
                    else -> "metodo_nao_permitido"
                }
                respond("""{"code":"$codigoOriginal","message":"recusa sintética","details":null}""", status, headersOf(HttpHeaders.ContentType, "application/json"))
            }
            ClienteSupabase("https://sintetico.invalid", "chave-teste", engine = engine).use {
                val erro = runCatching { ServicoConta(it).exportarMeusDados() }.exceptionOrNull()
                assertEquals(codigo, (erro as ErroDaApi).codigo)
            }
        }
    }

    @Test
    fun `mapeia falha de rede`() = runTest {
        val engine = MockEngine { throw UnknownHostException("host sintético") }
        ClienteSupabase("https://sintetico.invalid", "chave-teste", engine = engine).use {
            val erro = runCatching { ServicoConta(it).exportarMeusDados() }.exceptionOrNull()
            assertEquals(CodigoErroAPI.SEM_REDE, (erro as ErroDaApi).codigo)
        }
    }
}
