package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
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

    private fun denuncia(chamadaId: String?, midiaId: String? = null) = DenunciarDto(
        alvoTipo = "estabelecimento",
        alvoId = "11111111-1111-1111-1111-111111111111",
        motivo = "assedio",
        relato = "Relato com mais de dez caracteres.",
        chave = "22222222-2222-2222-2222-222222222222",
        chamadaId = chamadaId,
        midiaId = midiaId,
    )

    /** Manda [dto] por `denunciar` e devolve o corpo que saiu. */
    private suspend fun corpoEnviado(dto: DenunciarDto): JsonObject {
        var corpo: JsonObject? = null
        val engine = MockEngine { request ->
            corpo = ClienteSupabase.jsonFrila.parseToJsonElement((request.body as TextContent).text).jsonObject
            respond(protocoloJson, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        ServicoConfianca(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine)).denunciar(dto)
        return corpo!!
    }

    @Test
    fun `denuncia sobre a foto manda midia_id no corpo`() = runTest {
        val corpo = corpoEnviado(denuncia(chamadaId = null, midiaId = "44444444-4444-4444-4444-444444444444"))

        assertEquals("44444444-4444-4444-4444-444444444444", corpo["midia_id"]!!.jsonPrimitive.content)
    }

    @Test
    fun `denuncia sobre o perfil nao manda midia_id, porque o contrato nao aceita null`() = runTest {
        val corpo = corpoEnviado(denuncia(chamadaId = null, midiaId = null))

        assertFalse(corpo.containsKey("midia_id"))
        assertEquals("assedio", corpo["motivo"]!!.jsonPrimitive.content)
    }

    @Test
    fun `midia_id que nao e foto do alvo propaga 422 campo_invalido com o campo em details`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"campo_invalido","message":"midia nao e do alvo","details":"midia_id"}""",
                status = HttpStatusCode.UnprocessableEntity,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoConfianca(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val excecao = runCatching { servico.denunciar(denuncia(chamadaId = null, midiaId = "55555555-5555-5555-5555-555555555555")) }
            .exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        assertEquals(CodigoErroAPI.CAMPO_INVALIDO, (excecao as ErroDaApi).codigo)
        assertEquals("midia_id", excecao.detalhes)
    }

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
    fun `denunciar sem chamada_id nao manda o campo no corpo, como o iOS`() = runTest {
        var corpo: JsonObject? = null
        val engine = MockEngine { request ->
            corpo = ClienteSupabase.jsonFrila.parseToJsonElement((request.body as TextContent).text).jsonObject
            respond(protocoloJson, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val servico = ServicoConfianca(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        servico.denunciar(denuncia(chamadaId = null))

        // Com "chamada_id": null o servidor de hoje responde 404 PGRST202 (não conhece o parâmetro).
        assertFalse(corpo!!.containsKey("chamada_id"))
        assertEquals("estabelecimento", corpo!!["alvo_tipo"]!!.jsonPrimitive.content)
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

    @Test
    fun `bloquear chama POST rpc bloquear com o par e decodifica o Bloqueio`() = runTest {
        var caminho: String? = null
        var corpo: JsonObject? = null
        val engine = MockEngine { request ->
            caminho = request.url.encodedPath
            corpo = ClienteSupabase.jsonFrila.parseToJsonElement((request.body as TextContent).text).jsonObject
            respond(
                """{"alvo_tipo":"estabelecimento","alvo_id":"11111111-1111-1111-1111-111111111111","criado_em":"2026-11-10T12:00:00Z"}""",
                HttpStatusCode.OK,
                headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoConfianca(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val bloqueio = servico.bloquear("estabelecimento", "11111111-1111-1111-1111-111111111111")

        assertEquals("/rest/v1/rpc/bloquear", caminho)
        assertEquals(setOf("alvo_tipo", "alvo_id"), corpo!!.keys)
        assertEquals("estabelecimento", bloqueio.alvoTipo)
        assertEquals("2026-11-10T12:00:00Z", bloqueio.criadoEm)
    }

    @Test
    fun `bloquear a si mesmo propaga 422 campo_invalido com alvo_id em details`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"campo_invalido","message":"nao pode bloquear a si mesmo","details":"alvo_id"}""",
                status = HttpStatusCode.UnprocessableEntity,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoConfianca(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val excecao = runCatching { servico.bloquear("profissional", "11111111-1111-1111-1111-111111111111") }.exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        assertEquals(CodigoErroAPI.CAMPO_INVALIDO, (excecao as ErroDaApi).codigo)
        assertEquals("alvo_id", excecao.detalhes)
    }

    @Test
    fun `equipeDeConfianca chama POST rpc equipe_de_confianca com estabelecimento_id e decodifica os perfis`() = runTest {
        var metodo: io.ktor.http.HttpMethod? = null
        var caminho: String? = null
        var corpo: JsonObject? = null
        val engine = MockEngine { request ->
            metodo = request.method
            caminho = request.url.encodedPath
            corpo = ClienteSupabase.jsonFrila.parseToJsonElement((request.body as TextContent).text).jsonObject
            respond(
                """
                [{"id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","tipo":"profissional","nome":"Ana","funcoes":["garçom"],
                  "reputacao":{"positivas":3,"total":4,"turnos_considerados":4,"turnos_realizados":4}}]
                """.trimIndent(),
                HttpStatusCode.OK,
                headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoConfianca(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val equipe = servico.equipeDeConfianca("11111111-1111-1111-1111-111111111111")

        assertEquals(io.ktor.http.HttpMethod.Post, metodo)
        assertEquals("/rest/v1/rpc/equipe_de_confianca", caminho)
        assertEquals(setOf("estabelecimento_id"), corpo!!.keys)
        assertEquals("Ana", equipe.single().nome)
        assertEquals(3, equipe.single().reputacao.positivas)
    }

    @Test
    fun `equipeDeConfianca de casa sem membros devolve lista vazia, nao erro`() = runTest {
        val engine = MockEngine { respond("[]", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) }
        val servico = ServicoConfianca(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        assertTrue(servico.equipeDeConfianca("11111111-1111-1111-1111-111111111111").isEmpty())
    }

    @Test
    fun `removerDaEquipe manda o par e decodifica o MembroDaEquipe devolvido`() = runTest {
        var caminho: String? = null
        var corpo: JsonObject? = null
        val engine = MockEngine { request ->
            caminho = request.url.encodedPath
            corpo = ClienteSupabase.jsonFrila.parseToJsonElement((request.body as TextContent).text).jsonObject
            respond(
                """{"estabelecimento_id":"11111111-1111-1111-1111-111111111111","profissional_id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"}""",
                HttpStatusCode.OK,
                headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoConfianca(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val removido = servico.removerDaEquipe("11111111-1111-1111-1111-111111111111", "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")

        assertEquals("/rest/v1/rpc/remover_da_equipe", caminho)
        assertEquals(setOf("estabelecimento_id", "profissional_id"), corpo!!.keys)
        assertEquals("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", removido.profissionalId)
    }

    @Test
    fun `removerDaEquipe por quem nao e administrador propaga 403 sem_permissao`() = runTest {
        val engine = MockEngine {
            respond(
                """{"code":"sem_permissao","message":"so administrador"}""",
                HttpStatusCode.Forbidden,
                headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoConfianca(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val excecao = runCatching { servico.removerDaEquipe("11111111-1111-1111-1111-111111111111", "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa") }
            .exceptionOrNull()

        assertEquals(CodigoErroAPI.SEM_PERMISSAO, (excecao as ErroDaApi).codigo)
    }
}
