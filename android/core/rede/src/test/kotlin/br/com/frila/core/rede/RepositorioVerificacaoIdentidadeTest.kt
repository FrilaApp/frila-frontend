package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.ConsentimentoBiometriaLGPD
import br.com.frila.core.dominio.modelo.StatusVerificacaoIdentidade
import br.com.frila.core.dominio.modelo.TipoDocumentoIdentidade
import br.com.frila.core.dominio.modelo.TipoParteEvidencia
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class RepositorioVerificacaoIdentidadeTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val consentimento = ConsentimentoBiometriaLGPD(true, "2026-11", "2026-11-06T12:00:00Z")
    private val evidencias = mapOf(
        TipoParteEvidencia.FRENTE to byteArrayOf(1),
        TipoParteEvidencia.VERSO to byteArrayOf(2),
        TipoParteEvidencia.SELFIE to byteArrayOf(3),
    )

    private val uploadTresPartes = """
        {"expira_em":"2026-11-06T14:00:00Z","partes":[
          {"parte":"frente","url":"https://frila.supabase.co/u/frente?token=a"},
          {"parte":"verso","url":"https://frila.supabase.co/u/verso?token=b"},
          {"parte":"selfie","url":"https://frila.supabase.co/u/selfie?token=c"}]}
    """.trimIndent()

    private fun repositorio(engine: MockEngine) = RepositorioVerificacaoIdentidade(
        ServicoVerificacaoIdentidade(
            ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine),
        ),
    )

    /** Registra "METODO caminho" de cada chamada e responde conforme a rota. */
    private fun engineDoFluxo(chamadas: MutableList<String>, aoConfirmar: String = EM_ANALISE) = MockEngine { request ->
        chamadas += "${request.method.value} ${request.url.encodedPath}"
        val corpo = when {
            request.url.encodedPath.endsWith("solicitar_upload_verificacao") -> uploadTresPartes
            request.url.encodedPath.endsWith("confirmar_envio_verificacao") -> aoConfirmar
            else -> "{}"
        }
        respond(content = corpo, status = HttpStatusCode.OK, headers = json)
    }

    @Test
    fun `obterStatus mapeia o DTO para o dominio`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"status_verificacao":"rejeitada","motivo":"Foto ilegível","prazo_envio_ate":null,"identidade_verificada":false}""",
                status = HttpStatusCode.OK,
                headers = json,
            )
        }

        val verificacao = repositorio(engine).obterStatus()

        assertEquals(StatusVerificacaoIdentidade.REJEITADA, verificacao.status)
        assertEquals("Foto ilegível", verificacao.motivo)
        assertFalse(verificacao.identidadeVerificada)
    }

    @Test
    fun `obterStatus com status desconhecido falha com resposta invalida`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"status_verificacao":"suspensa","motivo":null,"prazo_envio_ate":null,"identidade_verificada":false}""",
                status = HttpStatusCode.OK,
                headers = json,
            )
        }

        val excecao = runCatching { repositorio(engine).obterStatus() }.exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        assertEquals(CodigoErroAPI.RESPOSTA_INVALIDA, (excecao as ErroDaApi).codigo)
    }

    @Test
    fun `enviarEvidencias solicita, envia as tres partes e so entao confirma`() = runTest {
        val chamadas = mutableListOf<String>()

        val verificacao = repositorio(engineDoFluxo(chamadas)).enviarEvidencias(
            TipoDocumentoIdentidade.RG,
            evidencias,
            consentimento,
        )

        assertEquals(
            listOf(
                "POST /rest/v1/rpc/solicitar_upload_verificacao",
                "PUT /u/frente",
                "PUT /u/verso",
                "PUT /u/selfie",
                "POST /rest/v1/rpc/confirmar_envio_verificacao",
            ),
            chamadas,
        )
        assertEquals(StatusVerificacaoIdentidade.EM_ANALISE, verificacao.status)
    }

    @Test
    fun `enviarEvidencias sem consentimento nao faz nenhuma chamada de rede`() = runTest {
        val chamadas = mutableListOf<String>()

        val excecao = runCatching {
            repositorio(engineDoFluxo(chamadas)).enviarEvidencias(TipoDocumentoIdentidade.RG, evidencias, null)
        }.exceptionOrNull()

        assertTrue(excecao is IllegalStateException)

        assertTrue(chamadas.isEmpty())
    }

    @Test
    fun `enviarEvidencias com parte sem imagem falha antes de qualquer upload e nao confirma`() = runTest {
        val chamadas = mutableListOf<String>()
        val semSelfie = evidencias - TipoParteEvidencia.SELFIE

        val excecao = runCatching {
            repositorio(engineDoFluxo(chamadas)).enviarEvidencias(TipoDocumentoIdentidade.RG, semSelfie, consentimento)
        }.exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        excecao as ErroDaApi
        assertEquals(CodigoErroAPI.EVIDENCIA_INCOMPLETA, excecao.codigo)
        assertEquals("selfie", excecao.detalhes)
        assertEquals(listOf("POST /rest/v1/rpc/solicitar_upload_verificacao"), chamadas)
    }

    @Test
    fun `enviarEvidencias com upload recusado nao confirma o envio`() = runTest {
        val chamadas = mutableListOf<String>()
        val engine = MockEngine { request ->
            chamadas += "${request.method.value} ${request.url.encodedPath}"
            when {
                request.url.encodedPath.endsWith("solicitar_upload_verificacao") ->
                    respond(uploadTresPartes, HttpStatusCode.OK, json)
                request.method == HttpMethod.Put && request.url.encodedPath.endsWith("verso") ->
                    respond("{}", HttpStatusCode.PayloadTooLarge, json)
                else -> respond("{}", HttpStatusCode.OK, json)
            }
        }

        val excecao = runCatching {
            repositorio(engine).enviarEvidencias(TipoDocumentoIdentidade.CNH, evidencias, consentimento)
        }.exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        assertEquals("http_413", (excecao as ErroDaApi).codigoOriginal)
        assertFalse(chamadas.any { it.endsWith("confirmar_envio_verificacao") })
        assertFalse(chamadas.contains("PUT /u/selfie"))
    }

    private companion object {
        const val EM_ANALISE =
            """{"status_verificacao":"em_analise","motivo":null,"prazo_envio_ate":null,"identidade_verificada":false}"""
    }
}
