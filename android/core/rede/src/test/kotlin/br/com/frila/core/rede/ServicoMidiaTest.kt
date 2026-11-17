package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.OutgoingContent
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertArrayEquals
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** L1-0b: a foto de perfil no servidor (`solicitar_upload_midia`, `enviar-midia`, `confirmar_upload_midia`, `remover_midia`, `pedir_nova_analise_midia`, `minhas_midias`). */
class ServicoMidiaTest {

    private val idDaMidia = "33333333-3333-3333-3333-333333333333"
    private val urlDeUpload = "https://frila.supabase.co/functions/v1/enviar-midia?midia_id=$idDaMidia&token=SEGREDO-DO-TOKEN"

    private fun midiaJson(estado: String = "em_analise", extras: String = "") =
        """{"id":"$idDaMidia","tipo":"foto_perfil","estado":"$estado","pode_pedir_nova_analise":false$extras}"""

    /** O que o servidor falso viu do último pedido. */
    private class Visto {
        var vezes = 0
        var metodo: HttpMethod? = null
        var caminho: String? = null
        var url: String? = null
        var corpo: JsonObject? = null
        var corpoBytes: ByteArray? = null
        var tipoDoCorpo: String? = null
        var temAuthorization = false
        var temApikey = false
    }

    private fun servico(status: HttpStatusCode, conteudo: String, visto: Visto = Visto()): ServicoMidia {
        val engine = MockEngine { request ->
            visto.vezes++
            visto.metodo = request.method
            visto.caminho = request.url.encodedPath
            visto.url = request.url.toString()
            visto.temAuthorization = request.headers.contains(HttpHeaders.Authorization)
            visto.temApikey = request.headers.contains("apikey")
            when (val corpo = request.body) {
                is TextContent -> visto.corpo = ClienteSupabase.jsonFrila.parseToJsonElement(corpo.text).jsonObject
                // O PUT chega como `OutgoingContent.ByteArrayContent` (classe anônima do Ktor), não como `ByteArrayContent`.
                is OutgoingContent.ByteArrayContent -> {
                    visto.corpoBytes = corpo.bytes()
                    visto.tipoDoCorpo = corpo.contentType?.toString()
                }
                else -> Unit
            }
            respond(conteudo, status, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        return ServicoMidia(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine))
    }

    private suspend fun recusa(status: HttpStatusCode, codigo: String, detalhes: String? = null, chamada: suspend (ServicoMidia) -> Unit): ErroDaApi {
        val extra = detalhes?.let { ""","details":"$it"""" } ?: ""
        val s = servico(status, """{"code":"$codigo","message":"x"$extra}""")
        return runCatching { chamada(s) }.exceptionOrNull() as ErroDaApi
    }

    // ---- solicitar_upload_midia ----

    @Test
    fun `solicitarUploadMidia faz POST com tipo, mime e bytes, sem estabelecimento_id, e decodifica a URL de upload`() = runTest {
        val visto = Visto()
        val s = servico(
            HttpStatusCode.OK,
            """{"midia_id":"$idDaMidia","upload_url":"$urlDeUpload","expira_em":"2026-11-17T05:00:00+00:00"}""",
            visto,
        )

        val upload = s.solicitarUploadMidia(mime = "image/jpeg", bytes = 482_113)

        assertEquals(HttpMethod.Post, visto.metodo)
        assertEquals("/rest/v1/rpc/solicitar_upload_midia", visto.caminho)
        assertEquals(setOf("tipo", "mime", "bytes"), visto.corpo!!.keys)
        assertEquals("foto_perfil", visto.corpo!!["tipo"]!!.jsonPrimitive.content)
        assertEquals("image/jpeg", visto.corpo!!["mime"]!!.jsonPrimitive.content)
        assertEquals("482113", visto.corpo!!["bytes"]!!.jsonPrimitive.content)
        assertEquals(idDaMidia, upload.midiaId)
        assertEquals(urlDeUpload, upload.uploadUrl)
        assertEquals("2026-11-17T05:00:00+00:00", upload.expiraEm)
    }

    @Test
    fun `solicitarUploadMidia da casa manda estabelecimento_id`() = runTest {
        val visto = Visto()
        val s = servico(HttpStatusCode.OK, """{"midia_id":"$idDaMidia","upload_url":"$urlDeUpload","expira_em":"2026-11-17T05:00:00Z"}""", visto)

        s.solicitarUploadMidia(mime = "image/jpeg", bytes = 10, estabelecimentoId = "e1")

        assertEquals(setOf("tipo", "mime", "bytes", "estabelecimento_id"), visto.corpo!!.keys)
        assertEquals("e1", visto.corpo!!["estabelecimento_id"]!!.jsonPrimitive.content)
    }

    @Test
    fun `solicitarUploadMidia propaga cada recusa do contrato`() = runTest {
        val ligar: suspend (ServicoMidia) -> Unit = { it.solicitarUploadMidia(mime = "image/jpeg", bytes = 10) }

        assertEquals(CodigoErroAPI.NAO_AUTENTICADO, recusa(HttpStatusCode.Unauthorized, "nao_autenticado", chamada = ligar).codigo)
        val suspensa = recusa(HttpStatusCode.Forbidden, "sem_permissao", "conta_suspensa", ligar)
        assertEquals(CodigoErroAPI.SEM_PERMISSAO, suspensa.codigo)
        assertEquals("conta_suspensa", suspensa.detalhes)
        val desligado = recusa(HttpStatusCode.Forbidden, "sem_permissao", "recurso_desligado", ligar)
        assertEquals("recurso_desligado", desligado.detalhes)
        for (motivo in listOf("formato", "tamanho", "tipo_indisponivel")) {
            val erro = recusa(HttpStatusCode.UnprocessableEntity, "midia_invalida", motivo, ligar)
            assertEquals("midia_invalida", erro.codigoOriginal, motivo)
            assertEquals(motivo, erro.detalhes, motivo)
        }
    }

    // ---- enviar-midia (PUT na URL de uso único) ----

    @Test
    fun `enviarFoto faz PUT do JPEG na URL, sem Authorization nem apikey, e 2xx quer dizer gravado`() = runTest {
        val visto = Visto()
        val s = servico(HttpStatusCode.NoContent, "", visto)
        val jpeg = byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 1, 2, 3, 0xFF.toByte(), 0xD9.toByte())

        s.enviarFoto(urlDeUpload, jpeg)

        assertEquals(HttpMethod.Put, visto.metodo)
        assertEquals("/functions/v1/enviar-midia", visto.caminho)
        assertEquals(urlDeUpload, visto.url)
        assertEquals("image/jpeg", visto.tipoDoCorpo)
        assertArrayEquals(jpeg, visto.corpoBytes)
        assertFalse(visto.temAuthorization)
        assertFalse(visto.temApikey)
    }

    @Test
    fun `enviarFoto com resposta que nao e 2xx lanca so com o status, sem a URL nem o token nem o corpo`() = runTest {
        for (status in listOf(HttpStatusCode.Forbidden, HttpStatusCode.Gone, HttpStatusCode.PayloadTooLarge, HttpStatusCode.InternalServerError)) {
            val s = servico(status, """{"erro":"caminho secreto midia-perfil/abc"}""")

            val erro = runCatching { s.enviarFoto(urlDeUpload, byteArrayOf(1)) }.exceptionOrNull() as ErroDaApi

            assertEquals("http_${status.value}", erro.codigoOriginal)
            assertNull(erro.detalhes)
            val tudo = listOfNotNull(erro.message, erro.mensagemCrua, erro.codigoOriginal, erro.detalhes).joinToString(" ")
            assertFalse(tudo.contains("SEGREDO-DO-TOKEN"), "token vazou no erro de ${status.value}")
            assertFalse(tudo.contains("enviar-midia"), "URL vazou no erro de ${status.value}")
            assertFalse(tudo.contains("caminho secreto"), "corpo vazou no erro de ${status.value}")
        }
    }

    @Test
    fun `enviarFoto com falha de rede vira sem_rede sem citar a URL nem o token`() = runTest {
        val engine = MockEngine { request ->
            // O Ktor cita a URL inteira na mensagem das falhas de rede (ex.: ConnectTimeoutException).
            throw java.io.IOException("Connect timeout has expired [url=${request.url}, connect_timeout=60000 ms]")
        }
        val s = ServicoMidia(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine))

        val erro = runCatching { s.enviarFoto(urlDeUpload, byteArrayOf(1)) }.exceptionOrNull() as ErroDaApi

        assertEquals(CodigoErroAPI.SEM_REDE, erro.codigo)
        val tudo = listOfNotNull(erro.message, erro.mensagemCrua, erro.codigoOriginal, erro.detalhes, erro.cause?.message).joinToString(" ")
        assertFalse(tudo.contains("SEGREDO-DO-TOKEN"), "token vazou na falha de rede")
        assertFalse(tudo.contains("enviar-midia"), "URL vazou na falha de rede")
        assertNull(erro.cause)
    }

    @Test
    fun `enviarFoto nunca repete sozinho, a URL e de uso unico`() = runTest {
        val visto = Visto()
        val s = servico(HttpStatusCode.ServiceUnavailable, "", visto)

        runCatching { s.enviarFoto(urlDeUpload, byteArrayOf(1)) }

        assertEquals(1, visto.vezes)
    }

    // ---- confirmar_upload_midia, remover_midia, pedir_nova_analise_midia ----

    @Test
    fun `confirmarUploadMidia faz POST so com midia_id e decodifica a midia em analise`() = runTest {
        val visto = Visto()
        val s = servico(HttpStatusCode.OK, midiaJson("em_analise"), visto)

        val midia = s.confirmarUploadMidia(idDaMidia)

        assertEquals("/rest/v1/rpc/confirmar_upload_midia", visto.caminho)
        assertEquals(HttpMethod.Post, visto.metodo)
        assertEquals(setOf("midia_id"), visto.corpo!!.keys)
        assertEquals(idDaMidia, visto.corpo!!["midia_id"]!!.jsonPrimitive.content)
        assertEquals("em_analise", midia.estado)
        assertEquals("foto_perfil", midia.tipo)
    }

    @Test
    fun `confirmarUploadMidia propaga cada recusa do contrato`() = runTest {
        val ligar: suspend (ServicoMidia) -> Unit = { it.confirmarUploadMidia(idDaMidia) }

        assertEquals(CodigoErroAPI.NAO_AUTENTICADO, recusa(HttpStatusCode.Unauthorized, "nao_autenticado", chamada = ligar).codigo)
        assertEquals(CodigoErroAPI.SEM_PERMISSAO, recusa(HttpStatusCode.Forbidden, "sem_permissao", chamada = ligar).codigo)
        assertEquals(CodigoErroAPI.NAO_ENCONTRADO, recusa(HttpStatusCode.NotFound, "nao_encontrado", chamada = ligar).codigo)
        assertEquals(CodigoErroAPI.EVIDENCIA_INCOMPLETA, recusa(HttpStatusCode.UnprocessableEntity, "evidencia_incompleta", chamada = ligar).codigo)
        for (motivo in listOf("formato", "metadados")) {
            val erro = recusa(HttpStatusCode.UnprocessableEntity, "midia_invalida", motivo, ligar)
            assertEquals("midia_invalida", erro.codigoOriginal, motivo)
            assertEquals(motivo, erro.detalhes, motivo)
        }
    }

    @Test
    fun `removerMidia faz POST so com midia_id e decodifica a midia removida`() = runTest {
        val visto = Visto()
        val s = servico(HttpStatusCode.OK, midiaJson("removida"), visto)

        val midia = s.removerMidia(idDaMidia)

        assertEquals("/rest/v1/rpc/remover_midia", visto.caminho)
        assertEquals(HttpMethod.Post, visto.metodo)
        assertEquals(setOf("midia_id"), visto.corpo!!.keys)
        assertEquals("removida", midia.estado)
    }

    @Test
    fun `removerMidia propaga cada recusa do contrato`() = runTest {
        val ligar: suspend (ServicoMidia) -> Unit = { it.removerMidia(idDaMidia) }

        assertEquals(CodigoErroAPI.NAO_AUTENTICADO, recusa(HttpStatusCode.Unauthorized, "nao_autenticado", chamada = ligar).codigo)
        assertEquals(CodigoErroAPI.SEM_PERMISSAO, recusa(HttpStatusCode.Forbidden, "sem_permissao", chamada = ligar).codigo)
        assertEquals(CodigoErroAPI.NAO_ENCONTRADO, recusa(HttpStatusCode.NotFound, "nao_encontrado", chamada = ligar).codigo)
    }

    @Test
    fun `pedirNovaAnaliseMidia faz POST so com midia_id e decodifica a volta a em_analise`() = runTest {
        val visto = Visto()
        val s = servico(HttpStatusCode.OK, midiaJson("em_analise"), visto)

        val midia = s.pedirNovaAnaliseMidia(idDaMidia)

        assertEquals("/rest/v1/rpc/pedir_nova_analise_midia", visto.caminho)
        assertEquals(HttpMethod.Post, visto.metodo)
        assertEquals(setOf("midia_id"), visto.corpo!!.keys)
        assertEquals("em_analise", midia.estado)
    }

    @Test
    fun `pedirNovaAnaliseMidia propaga cada recusa do contrato`() = runTest {
        val ligar: suspend (ServicoMidia) -> Unit = { it.pedirNovaAnaliseMidia(idDaMidia) }

        assertEquals(CodigoErroAPI.NAO_AUTENTICADO, recusa(HttpStatusCode.Unauthorized, "nao_autenticado", chamada = ligar).codigo)
        assertEquals(CodigoErroAPI.SEM_PERMISSAO, recusa(HttpStatusCode.Forbidden, "sem_permissao", chamada = ligar).codigo)
        assertEquals(CodigoErroAPI.NAO_ENCONTRADO, recusa(HttpStatusCode.NotFound, "nao_encontrado", chamada = ligar).codigo)
        for (motivo in listOf("estado_invalido", "expurgada")) {
            val erro = recusa(HttpStatusCode.Conflict, "midia_indisponivel", motivo, ligar)
            assertEquals("midia_indisponivel", erro.codigoOriginal, motivo)
            assertEquals(motivo, erro.detalhes, motivo)
        }
    }

    // ---- minhas_midias ----

    @Test
    fun `minhasMidias faz POST com corpo vazio, para o servidor devolver a url da foto aprovada, e decodifica a lista`() = runTest {
        val visto = Visto()
        val lista = "[" + midiaJson(
            "aprovada",
            ""","url":"https://frila.supabase.co/ler-midia?token=abc","enviada_em":"2026-11-16T20:00:00+00:00","decidida_em":"2026-11-16T20:01:00+00:00"""",
        ) + "," + midiaJson(
            "recusada",
            ""","motivo_recusa":"rosto_nao_visivel","pode_pedir_nova_analise":true""",
        ).replace(""","pode_pedir_nova_analise":false""", "") + "]"
        val s = servico(HttpStatusCode.OK, lista, visto)

        val midias = s.minhasMidias()

        assertEquals("/rest/v1/rpc/minhas_midias", visto.caminho)
        assertEquals(HttpMethod.Post, visto.metodo)
        assertTrue(visto.corpo!!.isEmpty())
        assertEquals(2, midias.size)
        assertEquals("aprovada", midias[0].estado)
        assertEquals("https://frila.supabase.co/ler-midia?token=abc", midias[0].url)
        assertEquals("2026-11-16T20:01:00+00:00", midias[0].decididaEm)
        assertEquals("recusada", midias[1].estado)
        assertEquals("rosto_nao_visivel", midias[1].motivoRecusa)
        assertTrue(midias[1].podePedirNovaAnalise)
        assertNull(midias[1].url)
    }

    @Test
    fun `minhasMidias sem nenhuma foto devolve lista vazia`() = runTest {
        assertTrue(servico(HttpStatusCode.OK, "[]").minhasMidias().isEmpty())
    }

    @Test
    fun `estado, tipo e motivo novos do servidor nao derrubam a leitura`() = runTest {
        val s = servico(
            HttpStatusCode.OK,
            """[{"id":"$idDaMidia","tipo":"logo","estado":"em_quarentena","motivo_recusa":"motivo_novo","pode_pedir_nova_analise":false,"campo_novo":1}]""",
        )

        val midia = s.minhasMidias().single()

        assertEquals("em_quarentena", midia.estado)
        assertEquals("logo", midia.tipo)
        assertEquals("motivo_novo", midia.motivoRecusa)
    }

    @Test
    fun `minhasMidias propaga as recusas do contrato`() = runTest {
        val ligar: suspend (ServicoMidia) -> Unit = { it.minhasMidias() }

        assertEquals(CodigoErroAPI.NAO_AUTENTICADO, recusa(HttpStatusCode.Unauthorized, "nao_autenticado", chamada = ligar).codigo)
        assertEquals(CodigoErroAPI.SEM_PERMISSAO, recusa(HttpStatusCode.Forbidden, "sem_permissao", chamada = ligar).codigo)
    }
}
