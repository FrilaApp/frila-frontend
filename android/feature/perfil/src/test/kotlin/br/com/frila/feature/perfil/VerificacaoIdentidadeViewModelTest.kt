package br.com.frila.feature.perfil

import android.content.Context
import android.net.Uri
import br.com.frila.core.dominio.modelo.StatusVerificacaoIdentidade
import br.com.frila.core.dominio.modelo.TipoDocumentoIdentidade
import br.com.frila.core.dominio.modelo.TipoParteEvidencia
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.RepositorioVerificacaoIdentidade
import br.com.frila.core.rede.ServicoVerificacaoIdentidade
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.MockRequestHandleScope
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.client.request.HttpResponseData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.mockk
import java.io.IOException
import java.time.Instant
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class VerificacaoIdentidadeViewModelTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val contexto = mockk<Context>(relaxed = true)
    private val uri = mockk<Uri>(relaxed = true)

    private fun status(valor: String) =
        """{"status_verificacao":"$valor","motivo":null,"prazo_envio_ate":null,"identidade_verificada":false}"""

    private val uploadTresPartes = """
        {"expira_em":"2026-11-06T14:00:00Z","partes":[
          {"parte":"frente","url":"https://frila.supabase.co/u/frente?token=a"},
          {"parte":"verso","url":"https://frila.supabase.co/u/verso?token=b"},
          {"parte":"selfie","url":"https://frila.supabase.co/u/selfie?token=c"}]}
    """.trimIndent()

    private fun MockRequestHandleScope.resposta(codigo: HttpStatusCode, corpo: String): HttpResponseData =
        respond(corpo, codigo, json)

    private fun viewModel(
        chamadas: MutableList<String> = mutableListOf(),
        lerBytes: (Context, Uri) -> ByteArray? = { _, _ -> byteArrayOf(1, 2, 3) },
        manipulador: suspend MockRequestHandleScope.(HttpRequestData) -> HttpResponseData,
    ): VerificacaoIdentidadeViewModel {
        val engine = MockEngine { request ->
            chamadas += "${request.method.value} ${request.url.encodedPath}"
            manipulador(request)
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        return VerificacaoIdentidadeViewModel(
            repositorio = RepositorioVerificacaoIdentidade(ServicoVerificacaoIdentidade(cliente)),
            escopo = CoroutineScope(Dispatchers.Unconfined),
            agora = { Instant.parse("2026-11-06T12:00:00Z") },
            lerBytes = lerBytes,
        )
    }

    private fun VerificacaoIdentidadeViewModel.prepararEnvio() = runBlocking {
        carregar().join()
        confirmarConsentimento()
        TipoParteEvidencia.entries.forEach { escolherParte(contexto, it, uri).join() }
    }

    private fun fluxoFeliz(): suspend MockRequestHandleScope.(HttpRequestData) -> HttpResponseData = { request ->
        val caminho = request.url.encodedPath
        when {
            caminho.endsWith("minha_identidade_status") -> resposta(HttpStatusCode.OK, status("nao_exigida"))
            caminho.endsWith("solicitar_upload_verificacao") -> resposta(HttpStatusCode.OK, uploadTresPartes)
            caminho.endsWith("confirmar_envio_verificacao") -> resposta(HttpStatusCode.OK, status("em_analise"))
            else -> resposta(HttpStatusCode.OK, "{}")
        }
    }

    @Test
    fun `carregar publica o estado da verificacao`() = runBlocking {
        val vm = viewModel { resposta(HttpStatusCode.OK, status("rejeitada")) }

        vm.carregar().join()

        assertEquals(StatusCargaVerificacao.PRONTO, vm.estado.value.carga)
        assertEquals(StatusVerificacaoIdentidade.REJEITADA, vm.estado.value.verificacao?.status)
        assertTrue(vm.estado.value.podeSolicitar)
    }

    @Test
    fun `carregar sem rede mostra mensagem de conexao`() = runBlocking {
        val vm = viewModel { throw IOException("sem sinal") }

        vm.carregar().join()

        assertEquals(StatusCargaVerificacao.ERRO, vm.estado.value.carga)
        assertEquals("Sem conexão. Verifique sua internet e tente de novo.", vm.estado.value.mensagemErro)
    }

    @Test
    fun `aprovada e em analise nao podem solicitar de novo`() = runBlocking {
        listOf("aprovada", "em_analise").forEach { valor ->
            val vm = viewModel { resposta(HttpStatusCode.OK, status(valor)) }
            vm.carregar().join()
            assertFalse(vm.estado.value.podeSolicitar, valor)
        }
    }

    @Test
    fun `confirmar consentimento registra versao do termo e instante`() {
        val vm = viewModel { resposta(HttpStatusCode.OK, status("nao_exigida")) }
        assertTrue(vm.estado.value.precisaConsentimento)

        vm.confirmarConsentimento()

        val consentimento = vm.estado.value.consentimento
        assertNotNull(consentimento)
        assertTrue(consentimento!!.consentido)
        assertEquals(TermoBiometria.VERSAO, consentimento.versaoTermo)
        assertEquals("2026-11-06T12:00:00Z", consentimento.dataHoraIso)
        assertFalse(vm.estado.value.precisaConsentimento)
    }

    @Test
    fun `enviar sem consentimento nao chama a rede`() = runBlocking {
        val chamadas = mutableListOf<String>()
        val vm = viewModel(chamadas, manipulador = fluxoFeliz())
        vm.carregar().join()
        TipoParteEvidencia.entries.forEach { vm.escolherParte(contexto, it, uri).join() }
        chamadas.clear()

        assertNull(vm.enviar())

        assertTrue(chamadas.isEmpty())
    }

    @Test
    fun `enviar com parte faltando nao chama a rede`() = runBlocking {
        val chamadas = mutableListOf<String>()
        val vm = viewModel(chamadas, manipulador = fluxoFeliz())
        vm.carregar().join()
        vm.confirmarConsentimento()
        vm.escolherParte(contexto, TipoParteEvidencia.FRENTE, uri).join()
        chamadas.clear()

        assertNull(vm.enviar())

        assertTrue(chamadas.isEmpty())
    }

    @Test
    fun `fluxo completo envia as tres partes e termina em analise`() = runBlocking {
        val chamadas = mutableListOf<String>()
        val vm = viewModel(chamadas, manipulador = fluxoFeliz())
        vm.prepararEnvio()
        vm.definirDocumento(TipoDocumentoIdentidade.CNH)

        vm.enviar()!!.join()

        assertEquals(StatusEnvioVerificacao.SUCESSO, vm.estado.value.envio)
        assertEquals(StatusVerificacaoIdentidade.EM_ANALISE, vm.estado.value.verificacao?.status)
        assertTrue(vm.estado.value.partesEscolhidas.isEmpty())
        assertEquals(
            listOf(
                "GET /rest/v1/rpc/minha_identidade_status",
                "POST /rest/v1/rpc/solicitar_upload_verificacao",
                "PUT /u/frente",
                "PUT /u/verso",
                "PUT /u/selfie",
                "POST /rest/v1/rpc/confirmar_envio_verificacao",
            ),
            chamadas,
        )
    }

    @Test
    fun `toque duplo durante o envio nao dispara segundo envio`() = runBlocking {
        val chamadas = mutableListOf<String>()
        val liberar = CompletableDeferred<Unit>()
        val vm = viewModel(chamadas) { request ->
            if (request.url.encodedPath.endsWith("solicitar_upload_verificacao")) liberar.await()
            fluxoFeliz()(request)
        }
        vm.prepararEnvio()

        val primeiro = vm.enviar()
        val segundo = vm.enviar()
        liberar.complete(Unit)
        primeiro!!.join()

        assertNull(segundo)
        assertEquals(1, chamadas.count { it.endsWith("solicitar_upload_verificacao") })
    }

    @Test
    fun `409 em analise explica e mantem as imagens para nova tentativa`() = runBlocking {
        val vm = viewModel { request ->
            when {
                request.url.encodedPath.endsWith("minha_identidade_status") -> resposta(HttpStatusCode.OK, status("nao_exigida"))
                else -> resposta(
                    HttpStatusCode.Conflict,
                    """{"code":"verificacao_indisponivel","message":"x","details":"em_analise"}""",
                )
            }
        }
        vm.prepararEnvio()

        vm.enviar()!!.join()

        assertEquals(StatusEnvioVerificacao.ERRO, vm.estado.value.envio)
        assertEquals("Sua verificação já está em análise. Aguarde o resultado.", vm.estado.value.mensagemErro)
        assertTrue(vm.estado.value.todasAsPartesEscolhidas)
    }

    @Test
    fun `422 evidencia incompleta nomeia a parte que falta`() = runBlocking {
        val vm = viewModel { request ->
            val caminho = request.url.encodedPath
            when {
                caminho.endsWith("minha_identidade_status") -> resposta(HttpStatusCode.OK, status("pendente"))
                caminho.endsWith("solicitar_upload_verificacao") -> resposta(HttpStatusCode.OK, uploadTresPartes)
                caminho.endsWith("confirmar_envio_verificacao") -> resposta(
                    HttpStatusCode.UnprocessableEntity,
                    """{"code":"evidencia_incompleta","message":"x","details":"selfie"}""",
                )
                else -> resposta(HttpStatusCode.OK, "{}")
            }
        }
        vm.prepararEnvio()

        vm.enviar()!!.join()

        assertEquals("Faltou enviar a selfie. Escolha a imagem e envie de novo.", vm.estado.value.mensagemErro)
    }

    @Test
    fun `422 campo invalido pede conferir o documento`() = runBlocking {
        val vm = viewModel { request ->
            when {
                request.url.encodedPath.endsWith("minha_identidade_status") -> resposta(HttpStatusCode.OK, status("nao_exigida"))
                else -> resposta(
                    HttpStatusCode.UnprocessableEntity,
                    """{"code":"campo_invalido","message":"x","details":"documento_tipo"}""",
                )
            }
        }
        vm.prepararEnvio()

        vm.enviar()!!.join()

        assertEquals(
            "Os dados enviados não foram aceitos. Confira o documento e tente de novo.",
            vm.estado.value.mensagemErro,
        )
    }

    @Test
    fun `sem rede no envio avisa e permite tentar de novo`() = runBlocking {
        var falhar = false
        val vm = viewModel { request ->
            if (falhar) throw IOException("caiu")
            fluxoFeliz()(request)
        }
        vm.prepararEnvio()
        falhar = true

        vm.enviar()!!.join()

        assertEquals(StatusEnvioVerificacao.ERRO, vm.estado.value.envio)
        assertEquals("Sem conexão. Verifique sua internet e tente de novo.", vm.estado.value.mensagemErro)
        assertTrue(vm.estado.value.podeEnviar)
    }

    @Test
    fun `imagem acima do limite e recusada e a parte nao conta como escolhida`() = runBlocking {
        val vm = viewModel(lerBytes = { _, _ -> null }) { resposta(HttpStatusCode.OK, status("nao_exigida")) }

        vm.escolherParte(contexto, TipoParteEvidencia.FRENTE, uri).join()

        assertEquals(VerificacaoIdentidadeViewModel.MENSAGEM_IMAGEM_INVALIDA, vm.estado.value.mensagemErro)
        assertTrue(vm.estado.value.partesEscolhidas.isEmpty())
    }

    @Test
    fun `carregar com resposta nao JSON do gateway sai do carregando com mensagem generica`() = runBlocking {
        val html = "<html><body>502 proxy interno 10.0.0.7</body></html>"
        val vm = viewModel {
            respond(html, HttpStatusCode.NotFound, headersOf(HttpHeaders.ContentType, "text/html"))
        }

        vm.carregar().join()

        assertEquals(StatusCargaVerificacao.ERRO, vm.estado.value.carga)
        val mensagem = vm.estado.value.mensagemErro
        assertNotNull(mensagem)
        assertFalse(mensagem!!.contains("proxy"))
        assertFalse(mensagem.contains("<html"))
    }

    @Test
    fun `enviar com JSON de campo ausente sai do enviando com mensagem generica e permite tentar de novo`() = runBlocking {
        val vm = viewModel { request ->
            val caminho = request.url.encodedPath
            when {
                caminho.endsWith("minha_identidade_status") -> resposta(HttpStatusCode.OK, status("nao_exigida"))
                caminho.endsWith("solicitar_upload_verificacao") -> resposta(HttpStatusCode.OK, """{"expira_em":"2026-11-06T14:00:00Z"}""")
                else -> resposta(HttpStatusCode.OK, "{}")
            }
        }
        vm.prepararEnvio()

        vm.enviar()!!.join()

        assertEquals(StatusEnvioVerificacao.ERRO, vm.estado.value.envio)
        assertEquals(
            "Não foi possível concluir a verificação. Tente de novo em instantes.",
            vm.estado.value.mensagemErro,
        )
        assertTrue(vm.estado.value.podeEnviar)
    }

    @Test
    fun `enviar com resposta nao JSON na confirmacao sai do enviando`() = runBlocking {
        val vm = viewModel { request ->
            val caminho = request.url.encodedPath
            when {
                caminho.endsWith("minha_identidade_status") -> resposta(HttpStatusCode.OK, status("nao_exigida"))
                caminho.endsWith("solicitar_upload_verificacao") -> resposta(HttpStatusCode.OK, uploadTresPartes)
                caminho.endsWith("confirmar_envio_verificacao") ->
                    respond("<html>erro</html>", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "text/html"))
                else -> resposta(HttpStatusCode.OK, "{}")
            }
        }
        vm.prepararEnvio()

        vm.enviar()!!.join()

        assertEquals(StatusEnvioVerificacao.ERRO, vm.estado.value.envio)
        assertFalse(vm.estado.value.mensagemErro!!.contains("html"))
    }

    @Test
    fun `depois de enviar com sucesso nao reenvia sem nova escolha das imagens`() = runBlocking {
        val chamadas = mutableListOf<String>()
        val vm = viewModel(chamadas) { request ->
            val caminho = request.url.encodedPath
            when {
                caminho.endsWith("minha_identidade_status") -> resposta(HttpStatusCode.OK, status("nao_exigida"))
                caminho.endsWith("solicitar_upload_verificacao") -> resposta(HttpStatusCode.OK, uploadTresPartes)
                // Rejeitada reabre a elegibilidade: isola a guarda das imagens, não a do status.
                caminho.endsWith("confirmar_envio_verificacao") -> resposta(HttpStatusCode.OK, status("rejeitada"))
                else -> resposta(HttpStatusCode.OK, "{}")
            }
        }
        vm.prepararEnvio()
        vm.enviar()!!.join()
        assertTrue(vm.estado.value.podeSolicitar)
        chamadas.clear()

        assertNull(vm.enviar())
        vm.escolherParte(contexto, TipoParteEvidencia.SELFIE, uri).join()
        assertNull(vm.enviar())

        assertTrue(chamadas.isEmpty())
    }
}
