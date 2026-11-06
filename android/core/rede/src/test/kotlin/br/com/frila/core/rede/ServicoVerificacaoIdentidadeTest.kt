package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.engine.mock.toByteArray
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertArrayEquals
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ServicoVerificacaoIdentidadeTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")

    private fun servico(engine: MockEngine) = ServicoVerificacaoIdentidade(
        ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine),
    )

    private fun engineComErro(status: HttpStatusCode, corpo: String) = MockEngine {
        respond(content = corpo, status = status, headers = json)
    }

    @Test
    fun `obterMinhaIdentidadeStatus chama GET rpc e decodifica o estado`() = runTest {
        var metodo: HttpMethod? = null
        var caminho: String? = null
        val engine = MockEngine { request ->
            metodo = request.method
            caminho = request.url.encodedPath
            respond(
                content = """
                    {"status_verificacao":"pendente","motivo":"Apuração de denúncia grave",
                     "prazo_envio_ate":"2026-11-18T23:59:59Z","identidade_verificada":false}
                """.trimIndent(),
                status = HttpStatusCode.OK,
                headers = json,
            )
        }

        val status = servico(engine).obterMinhaIdentidadeStatus()

        assertEquals(HttpMethod.Get, metodo)
        assertEquals("/rest/v1/rpc/minha_identidade_status", caminho)
        assertEquals("pendente", status.statusVerificacao)
        assertEquals("Apuração de denúncia grave", status.motivo)
        assertEquals("2026-11-18T23:59:59Z", status.prazoEnvioAte)
        assertFalse(status.identidadeVerificada)
    }

    @Test
    fun `obterMinhaIdentidadeStatus decodifica nao_exigida com motivo e prazo nulos`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"status_verificacao":"nao_exigida","motivo":null,"prazo_envio_ate":null,"identidade_verificada":false}""",
                status = HttpStatusCode.OK,
                headers = json,
            )
        }

        val status = servico(engine).obterMinhaIdentidadeStatus()

        assertEquals("nao_exigida", status.statusVerificacao)
        assertNull(status.motivo)
        assertNull(status.prazoEnvioAte)
    }

    @Test
    fun `solicitarUploadVerificacao chama POST rpc com documento_tipo e decodifica as partes`() = runTest {
        var metodo: HttpMethod? = null
        var caminho: String? = null
        var corpo: String? = null
        val engine = MockEngine { request ->
            metodo = request.method
            caminho = request.url.encodedPath
            corpo = String(request.body.toByteArray())
            respond(
                content = """
                    {"expira_em":"2026-11-05T14:00:00Z","partes":[
                      {"parte":"frente","url":"https://frila.supabase.co/storage/v1/object/upload/sign/b/frente?token=t1"},
                      {"parte":"verso","url":"https://frila.supabase.co/storage/v1/object/upload/sign/b/verso?token=t2"},
                      {"parte":"selfie","url":"https://frila.supabase.co/storage/v1/object/upload/sign/b/selfie?token=t3"}]}
                """.trimIndent(),
                status = HttpStatusCode.OK,
                headers = json,
            )
        }

        val upload = servico(engine).solicitarUploadVerificacao("rg")

        assertEquals(HttpMethod.Post, metodo)
        assertEquals("/rest/v1/rpc/solicitar_upload_verificacao", caminho)
        assertEquals("""{"documento_tipo":"rg"}""", corpo)
        assertEquals("2026-11-05T14:00:00Z", upload.expiraEm)
        assertEquals(listOf("frente", "verso", "selfie"), upload.partes.map { it.parte })
        assertTrue(upload.partes.first().url.endsWith("frente?token=t1"))
    }

    @Test
    fun `confirmarEnvioVerificacao chama POST rpc com corpo vazio e decodifica em_analise`() = runTest {
        var metodo: HttpMethod? = null
        var caminho: String? = null
        var corpo: String? = null
        val engine = MockEngine { request ->
            metodo = request.method
            caminho = request.url.encodedPath
            corpo = String(request.body.toByteArray())
            respond(
                content = """
                    {"status_verificacao":"em_analise","motivo":null,"prazo_envio_ate":null,"identidade_verificada":false}
                """.trimIndent(),
                status = HttpStatusCode.OK,
                headers = json,
            )
        }

        val status = servico(engine).confirmarEnvioVerificacao()

        assertEquals(HttpMethod.Post, metodo)
        assertEquals("/rest/v1/rpc/confirmar_envio_verificacao", caminho)
        assertEquals("{}", corpo)
        assertEquals("em_analise", status.statusVerificacao)
    }

    @Test
    fun `enviarEvidencia faz PUT na url assinada com os bytes e o mime type`() = runTest {
        var metodo: HttpMethod? = null
        var urlChamada: String? = null
        var tipoConteudo: String? = null
        var recebido: ByteArray? = null
        val engine = MockEngine { request ->
            metodo = request.method
            urlChamada = request.url.toString()
            tipoConteudo = request.body.contentType?.toString()
            recebido = request.body.toByteArray()
            respond(content = """{"Key":"b/frente"}""", status = HttpStatusCode.OK, headers = json)
        }
        val bytes = byteArrayOf(1, 2, 3, 4)

        servico(engine).enviarEvidencia("https://frila.supabase.co/storage/v1/object/upload/sign/b/frente?token=t1", bytes)

        assertEquals(HttpMethod.Put, metodo)
        assertEquals("https://frila.supabase.co/storage/v1/object/upload/sign/b/frente?token=t1", urlChamada)
        assertEquals("image/jpeg", tipoConteudo)
        assertArrayEquals(bytes, recebido)
    }

    @Test
    fun `enviarEvidencia respeita o mime type informado`() = runTest {
        var tipoConteudo: String? = null
        val engine = MockEngine { request ->
            tipoConteudo = request.body.contentType?.toString()
            respond(content = "{}", status = HttpStatusCode.OK, headers = json)
        }

        servico(engine).enviarEvidencia("https://frila.supabase.co/u?token=t", byteArrayOf(9), "image/png")

        assertEquals("image/png", tipoConteudo)
    }

    @Test
    fun `enviarEvidencia com resposta nao 2xx lanca ErroDaApi sem vazar o corpo do Storage`() = runTest {
        val engine = engineComErro(HttpStatusCode.Unauthorized, """{"message":"caminho secreto documentos-identidade/abc"}""")

        val excecao = runCatching {
            servico(engine).enviarEvidencia("https://frila.supabase.co/u?token=t", byteArrayOf(1))
        }.exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        excecao as ErroDaApi
        assertEquals("http_401", excecao.codigoOriginal)
        assertFalse(excecao.mensagemCrua.contains("secreto"))
        assertNull(excecao.detalhes)
    }

    @Test
    fun `solicitarUploadVerificacao 409 propaga verificacao indisponivel`() = runTest {
        val engine = engineComErro(
            HttpStatusCode.Conflict,
            """{"code":"verificacao_indisponivel","message":"em análise","details":"em_analise"}""",
        )

        val excecao = runCatching { servico(engine).solicitarUploadVerificacao("rg") }.exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        excecao as ErroDaApi
        assertEquals(CodigoErroAPI.VERIFICACAO_INDISPONIVEL, excecao.codigo)
        assertEquals("em_analise", excecao.detalhes)
    }

    @Test
    fun `confirmarEnvioVerificacao 409 propaga verificacao indisponivel sem envio solicitado`() = runTest {
        val engine = engineComErro(
            HttpStatusCode.Conflict,
            """{"code":"verificacao_indisponivel","message":"sem upload","details":"sem_envio_solicitado"}""",
        )

        val excecao = runCatching { servico(engine).confirmarEnvioVerificacao() }.exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        excecao as ErroDaApi
        assertEquals(CodigoErroAPI.VERIFICACAO_INDISPONIVEL, excecao.codigo)
        assertEquals("sem_envio_solicitado", excecao.detalhes)
    }

    @Test
    fun `confirmarEnvioVerificacao 422 propaga evidencia incompleta com a parte que falta`() = runTest {
        val engine = engineComErro(
            HttpStatusCode.UnprocessableEntity,
            """{"code":"evidencia_incompleta","message":"falta parte","details":"selfie"}""",
        )

        val excecao = runCatching { servico(engine).confirmarEnvioVerificacao() }.exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        excecao as ErroDaApi
        assertEquals(CodigoErroAPI.EVIDENCIA_INCOMPLETA, excecao.codigo)
        assertEquals("selfie", excecao.detalhes)
    }

    @Test
    fun `solicitarUploadVerificacao 422 propaga campo invalido`() = runTest {
        val engine = engineComErro(
            HttpStatusCode.UnprocessableEntity,
            """{"code":"campo_invalido","message":"documento_tipo recusado","details":"documento_tipo"}""",
        )

        val excecao = runCatching { servico(engine).solicitarUploadVerificacao("passaporte") }.exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        excecao as ErroDaApi
        assertEquals(CodigoErroAPI.CAMPO_INVALIDO, excecao.codigo)
        assertEquals("documento_tipo", excecao.detalhes)
    }
}
