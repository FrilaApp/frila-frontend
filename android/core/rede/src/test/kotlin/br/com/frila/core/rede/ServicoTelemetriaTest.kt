package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.*
import io.ktor.http.content.TextContent
import java.io.IOException
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class ServicoTelemetriaTest {
    @Test
    fun `200 envia POST com apenas os campos do contrato e le registrado`() = runTest {
        val cliente = ClienteSupabase("https://sintetico.supabase.invalid", "chave-sintetica", engine = MockEngine {
            assertEquals("/rest/v1/rpc/registrar_evento", it.url.encodedPath)
            assertEquals(HttpMethod.Post, it.method)
            assertEquals("""{"evento":"vaga_vista","vaga_id":"00000000-0000-0000-0000-000000000001","turno_id":"00000000-0000-0000-0000-000000000002","ocorrido_em":"2026-11-23T12:00:00Z"}""", (it.body as TextContent).text)
            respond("""{"registrado":true}""", headers = headersOf(HttpHeaders.ContentType, "application/json"))
        })
        cliente.use {
            assertTrue(ServicoTelemetria(it).registrarEvento(RegistroDeEventoDto(EventoDeTelemetria.VAGA_VISTA,
                "00000000-0000-0000-0000-000000000001", "00000000-0000-0000-0000-000000000002", "2026-11-23T12:00:00Z")))
        }
    }

    @Test
    fun `422 propaga recusa definitiva e omite opcionais ausentes`() = runTest {
        val cliente = ClienteSupabase("https://sintetico.supabase.invalid", "chave-sintetica", engine = MockEngine {
            assertEquals("""{"evento":"app_aberto"}""", (it.body as TextContent).text)
            respond("""{"code":"campo_invalido","message":"recusado","details":"evento"}""",
                HttpStatusCode.UnprocessableEntity, headersOf(HttpHeaders.ContentType, "application/json"))
        })
        cliente.use {
            val erro = runCatching { ServicoTelemetria(it).registrarEvento(RegistroDeEventoDto(EventoDeTelemetria.APP_ABERTO)) }.exceptionOrNull()
            assertTrue(erro is ErroDaApi)
            assertEquals(CodigoErroAPI.CAMPO_INVALIDO, (erro as ErroDaApi).codigo)
        }
    }

    @Test
    fun `falha de rede propaga sem rede`() = runTest {
        val cliente = ClienteSupabase("https://sintetico.supabase.invalid", "chave-sintetica", engine = MockEngine { throw IOException("sintetico") })
        cliente.use {
            val erro = runCatching { ServicoTelemetria(it).registrarEvento(RegistroDeEventoDto(EventoDeTelemetria.APP_ABERTO)) }.exceptionOrNull()
            assertTrue(erro is ErroDaApi)
            assertEquals(CodigoErroAPI.SEM_REDE, (erro as ErroDaApi).codigo)
        }
    }
    @Test
    fun `422 com codigo desconhecido continua sendo recusa definitiva`() = runTest {
        val cliente = ClienteSupabase("https://sintetico.supabase.invalid", "chave-sintetica", engine = MockEngine {
            respond("""{"code":"codigo_futuro","message":"sintetico"}""", HttpStatusCode.UnprocessableEntity,
                headersOf(HttpHeaders.ContentType, "application/json"))
        })
        cliente.use {
            val erro = runCatching { ServicoTelemetria(it).registrarEvento(RegistroDeEventoDto(EventoDeTelemetria.APP_ABERTO)) }.exceptionOrNull()
            assertTrue(erro is ErroDaApi)
            assertFalse(RegistradorDeTelemetria.deveGuardar(erro as ErroDaApi))
        }
    }

}
