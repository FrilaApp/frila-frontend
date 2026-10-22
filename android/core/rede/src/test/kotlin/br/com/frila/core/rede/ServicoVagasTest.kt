package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ServicoVagasTest {

    private val vagaJson = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "funcao": {"id": "22222222-2222-2222-2222-222222222222", "nome": "garçom", "categoria": "Salão"},
          "estabelecimento": {
            "id": "33333333-3333-3333-3333-333333333333",
            "tipo": "estabelecimento",
            "nome": "Bar do Zé",
            "reputacao": {"positivas": 7, "total": 7, "taxa_comparecimento": 1.0, "turnos_considerados": 7, "turnos_realizados": 7}
          },
          "inicio_em": "2026-11-01T21:00:00Z",
          "fim_em": "2026-11-02T03:00:00Z",
          "local": "SQN 108",
          "regiao_administrativa": "Asa Norte",
          "distancia_km": 4.2,
          "valor_centavos": 16000,
          "posicoes_abertas": 2,
          "inclusos": {"inclui_refeicao": true, "inclui_transporte": false, "exige_material_proprio": false},
          "modo": "selecao"
        }
    """.trimIndent()

    @Test
    fun `listarVagasAbertas chama GET rpc vagas_abertas e decodifica a lista`() = runTest {
        var caminhoChamado: String? = null
        val engine = MockEngine { request ->
            caminhoChamado = request.url.encodedPath
            respond(
                content = "[$vagaJson]",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoVagas(cliente)

        val vagas = servico.listarVagasAbertas()

        assertEquals("/rest/v1/rpc/vagas_abertas", caminhoChamado)
        assertEquals(1, vagas.size)
        assertEquals("garçom", vagas.first().funcao.nome)
        assertEquals(16_000L, vagas.first().valorCentavos)
        assertEquals(2, vagas.first().posicoesAbertas)
    }

    @Test
    fun `listarVagasAbertas com conta de contratante propaga PERFIL_INCOMPATIVEL`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"perfil_incompativel","message":"conta de contratante"}""",
                status = HttpStatusCode.UnprocessableEntity,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoVagas(cliente)

        val excecao = runCatching { servico.listarVagasAbertas() }.exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        assertEquals(CodigoErroAPI.PERFIL_INCOMPATIVEL, (excecao as ErroDaApi).codigo)
    }

    @Test
    fun `lista vazia decodifica sem erro`() = runTest {
        val engine = MockEngine {
            respond(content = "[]", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoVagas(cliente)

        val vagas = servico.listarVagasAbertas()

        assertTrue(vagas.isEmpty())
    }
}
