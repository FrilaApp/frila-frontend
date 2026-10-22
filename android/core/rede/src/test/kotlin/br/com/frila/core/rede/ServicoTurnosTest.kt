package br.com.frila.core.rede

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ServicoTurnosTest {

    private val turnoJson = """
        {
          "turno_id": "11111111-1111-1111-1111-111111111111",
          "vaga_id": "22222222-2222-2222-2222-222222222222",
          "posicao_id": "33333333-3333-3333-3333-333333333333",
          "funcao": {"id": "f1", "nome": "garçom", "categoria": "Salão"},
          "contraparte": {
            "id": "e1", "tipo": "estabelecimento", "nome": "Bar do Zé",
            "reputacao": {"positivas": 7, "total": 7, "turnos_considerados": 7, "turnos_realizados": 7}
          },
          "inicio_em": "2026-11-01T21:00:00Z",
          "fim_em": "2026-11-02T03:00:00Z",
          "valor_centavos": 16000,
          "estado": "confirmada"
        }
    """.trimIndent()

    @Test
    fun `listarMeusTurnos chama GET rpc meus_turnos e decodifica a lista`() = runTest {
        var caminhoChamado: String? = null
        val engine = MockEngine { request ->
            caminhoChamado = request.url.encodedPath
            respond(
                content = "[$turnoJson]",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoTurnos(cliente)

        val turnos = servico.listarMeusTurnos()

        assertEquals("/rest/v1/rpc/meus_turnos", caminhoChamado)
        assertEquals(1, turnos.size)
        assertEquals("confirmada", turnos.first().estado)
        assertEquals("garçom", turnos.first().funcao.nome)
    }

    @Test
    fun `turno cancelado (RN12) continua na lista, nao e filtrado pelo servico`() = runTest {
        val engine = MockEngine {
            respond(
                content = """[${turnoJson.replace("\"confirmada\"", "\"cancelada\"")}]""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoTurnos(cliente)

        val turnos = servico.listarMeusTurnos()

        assertEquals(1, turnos.size)
        assertEquals("cancelada", turnos.first().estado)
    }

    @Test
    fun `checkin e avaliacao nulos decodificam sem erro quando ausentes`() = runTest {
        val engine = MockEngine {
            respond(content = "[$turnoJson]", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoTurnos(cliente)

        val turno = servico.listarMeusTurnos().first()

        assertNull(turno.checkin)
        assertNull(turno.avaliacao)
    }

    @Test
    fun `lista vazia decodifica sem erro`() = runTest {
        val engine = MockEngine {
            respond(content = "[]", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoTurnos(cliente)

        assertTrue(servico.listarMeusTurnos().isEmpty())
    }
}
