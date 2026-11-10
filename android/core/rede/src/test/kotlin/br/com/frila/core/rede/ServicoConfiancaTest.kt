package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ServicoConfiancaTest {

    private val protocoloJson = """
        {
          "ocorrencia_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
          "tipo": "denuncia",
          "criada_em": "2026-11-09T12:00:00Z",
          "prazo_resposta_ate": "2026-11-16T12:00:00Z"
        }
    """.trimIndent()

    private fun denuncia(chamadaId: String?) = DenunciarDto(
        alvoTipo = "estabelecimento",
        alvoId = "11111111-1111-1111-1111-111111111111",
        motivo = "assedio",
        relato = "Relato com mais de dez caracteres.",
        chave = "22222222-2222-2222-2222-222222222222",
        chamadaId = chamadaId,
    )

    @Test
    fun `denunciar com chamada_id manda o campo no corpo de POST rpc denunciar`() = runTest {
        var caminho: String? = null
        var corpo: JsonObject? = null
        val engine = MockEngine { request ->
            caminho = request.url.encodedPath
            corpo = ClienteSupabase.jsonFrila.parseToJsonElement((request.body as TextContent).text).jsonObject
            respond(protocoloJson, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val servico = ServicoConfianca(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val protocolo = servico.denunciar(denuncia(chamadaId = "33333333-3333-3333-3333-333333333333"))

        assertEquals("/rest/v1/rpc/denunciar", caminho)
        assertEquals("33333333-3333-3333-3333-333333333333", corpo!!["chamada_id"]!!.jsonPrimitive.content)
        assertEquals("estabelecimento", corpo!!["alvo_tipo"]!!.jsonPrimitive.content)
        assertEquals("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", protocolo.ocorrenciaId)
    }

    @Test
    fun `denunciar sem chamada_id manda null, que o contrato aceita`() = runTest {
        var corpo: JsonObject? = null
        val engine = MockEngine { request ->
            corpo = ClienteSupabase.jsonFrila.parseToJsonElement((request.body as TextContent).text).jsonObject
            respond(protocoloJson, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val servico = ServicoConfianca(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        servico.denunciar(denuncia(chamadaId = null))

        assertEquals(JsonNull, corpo!!["chamada_id"])
    }

    @Test
    fun `denunciar com chamada_id de terceiros propaga 422 campo_invalido com o campo em details`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"campo_invalido","message":"chamada nao envolve as partes","details":"chamada_id"}""",
                status = HttpStatusCode.UnprocessableEntity,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoConfianca(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val excecao = runCatching { servico.denunciar(denuncia(chamadaId = "99999999-9999-9999-9999-999999999999")) }
            .exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        assertEquals(CodigoErroAPI.CAMPO_INVALIDO, (excecao as ErroDaApi).codigo)
        assertEquals("chamada_id", excecao.detalhes)
    }

    @Test
    fun `sairDaEquipe chama POST rpc sair_da_equipe com estabelecimento_id e aceita corpo vazio`() = runTest {
        var caminho: String? = null
        var corpo: JsonObject? = null
        val engine = MockEngine { request ->
            caminho = request.url.encodedPath
            corpo = ClienteSupabase.jsonFrila.parseToJsonElement((request.body as TextContent).text).jsonObject
            respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val servico = ServicoConfianca(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        servico.sairDaEquipe("44444444-4444-4444-4444-444444444444")

        assertEquals("/rest/v1/rpc/sair_da_equipe", caminho)
        assertEquals(setOf("estabelecimento_id"), corpo!!.keys)
        assertEquals("44444444-4444-4444-4444-444444444444", corpo!!["estabelecimento_id"]!!.jsonPrimitive.content)
    }

    @Test
    fun `sairDaEquipe de casa em que nao esta na equipe propaga 422 campo_invalido`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"campo_invalido","message":"fora da equipe","details":"estabelecimento_id"}""",
                status = HttpStatusCode.UnprocessableEntity,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoConfianca(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val excecao = runCatching { servico.sairDaEquipe("44444444-4444-4444-4444-444444444444") }.exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        assertEquals(CodigoErroAPI.CAMPO_INVALIDO, (excecao as ErroDaApi).codigo)
        assertEquals("estabelecimento_id", excecao.detalhes)
    }
}
