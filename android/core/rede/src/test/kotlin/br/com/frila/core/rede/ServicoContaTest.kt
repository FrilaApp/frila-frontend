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
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Test

class ServicoContaTest {

    private fun servico(corpo: String, status: HttpStatusCode, aoChamar: (String, HttpMethod) -> Unit = { _, _ -> }): ServicoConta {
        val engine = MockEngine { request ->
            aoChamar(request.url.encodedPath, request.method)
            respond(corpo, status, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        return ServicoConta(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine))
    }

    @Test
    fun `minhaConta chama GET rpc minha_conta e le o perfil da conta`() = runTest {
        var caminho: String? = null
        var metodo: HttpMethod? = null
        val servico = servico(
            """{"id":"u1","perfil":"contratante","nome":"Casa Teste","telefone":"61999990000","email":"c@exemplo.com","nascimento":"1990-01-01","estado":"ativa","campo_novo":1}""",
            HttpStatusCode.OK,
        ) { c, m -> caminho = c; metodo = m }

        val conta = servico.minhaConta()

        assertEquals("/rest/v1/rpc/minha_conta", caminho)
        assertEquals(HttpMethod.Get, metodo)
        assertEquals("contratante", conta.perfil)
        assertEquals("u1", conta.id)
    }

    @Test
    fun `minhaConta sem conta no servidor lanca nao_encontrado`() = runTest {
        val servico = servico("""{"code":"nao_encontrado","message":"sem conta","details":null}""", HttpStatusCode.NotFound)

        val erro = assertThrows(ErroDaApi::class.java) { kotlinx.coroutines.runBlocking { servico.minhaConta() } }

        assertEquals(CodigoErroAPI.NAO_ENCONTRADO, erro.codigo)
    }
}
