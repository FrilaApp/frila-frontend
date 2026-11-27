package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.MotivoOcorrencia
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Mesma ressalva de `MockEngine` + escopo próprio documentada em `MeusTurnosViewModelTest` e em
 * `br.com.frila.feature.entrada.entrada.EntradaViewModel`: o teste espera o `Job` com `.join()`.
 */
class OcorrenciaTurnoViewModelTest {

    private val turnoId = "t-1"

    private fun protocoloJson() = """
        {
          "ocorrencia_id": "6f1c2a4e-2b7d-4c5e-9a1f-3d2e1c0b9a88",
          "tipo": "suporte",
          "criada_em": "2026-10-08T14:00:00Z",
          "prazo_resposta_ate": "2026-10-15"
        }
    """.trimIndent()

    private fun viewModelComEngine(engine: MockEngine, chave: String = "chave-fixa"): OcorrenciaTurnoViewModel {
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        return OcorrenciaTurnoViewModel(
            turnoId = turnoId,
            servicoTurnos = ServicoTurnos(cliente),
            geradorDeChave = { chave },
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    @Test
    fun `cada motivo normativo pode ser selecionado e reflete no estado`() {
        val viewModel = viewModelComEngine(MockEngine { respond(content = protocoloJson(), status = HttpStatusCode.OK) })

        MotivoOcorrencia.entries.forEach { motivo ->
            viewModel.selecionarMotivo(motivo)
            assertEquals(motivo, viewModel.estado.value.motivo)
        }
    }

    @Test
    fun `enviar sem motivo selecionado nao chama a API e devolve Job nulo`() {
        var chamadas = 0
        val viewModel = viewModelComEngine(
            MockEngine { chamadas++; respond(content = protocoloJson(), status = HttpStatusCode.OK) },
        )

        val job = viewModel.enviar()

        assertNull(job)
        assertEquals(0, chamadas)
    }

    @Test
    fun `enviar com motivo chama abrir_suporte com turno_id e categoria corretos`() = runBlocking {
        var caminhoChamado: String? = null
        var corpoChamado: String? = null
        val engine = MockEngine { request ->
            caminhoChamado = request.url.encodedPath
            corpoChamado = (request.body as io.ktor.http.content.TextContent).text
            respond(
                content = protocoloJson(),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val viewModel = viewModelComEngine(engine)
        viewModel.selecionarMotivo(MotivoOcorrencia.RISCO_SEGURANCA)

        viewModel.enviar()?.join()

        assertEquals("/rest/v1/rpc/abrir_suporte", caminhoChamado)
        assertTrue(corpoChamado!!.contains("\"turno_id\":\"t-1\""))
        assertTrue(corpoChamado!!.contains("\"categoria\":\"seguranca\""))
        assertTrue(corpoChamado!!.contains("\"chave\":\"chave-fixa\""))
        assertEquals(StatusOcorrencia.SUCESSO, viewModel.estado.value.status)
    }

    @Test
    fun `depois do sucesso, enviar de novo nao abre outro chamado`() = runBlocking {
        val chaves = mutableListOf<String>()
        var chamadas = 0
        val engine = MockEngine { request ->
            chamadas++
            val corpo = (request.body as io.ktor.http.content.TextContent).text
            chaves += Regex("\"chave\"\\s*:\\s*\"([^\"]+)\"").find(corpo)?.groupValues?.get(1).orEmpty()
            respond(content = protocoloJson(), status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
        }
        var sequencia = 0
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val viewModel = OcorrenciaTurnoViewModel(
            turnoId = turnoId,
            servicoTurnos = ServicoTurnos(cliente),
            geradorDeChave = { "chave-${++sequencia}" },
            escopo = CoroutineScope(Dispatchers.Default),
        )
        viewModel.selecionarMotivo(MotivoOcorrencia.entries.first())
        viewModel.enviar()!!.join()
        assertEquals(StatusOcorrencia.SUCESSO, viewModel.estado.value.status)
        val protocolo = viewModel.estado.value.protocolo

        viewModel.enviar()?.join()

        assertEquals("o segundo enviar() abriu outro chamado, com as chaves $chaves", 1, chamadas)
        assertEquals(StatusOcorrencia.SUCESSO, viewModel.estado.value.status)
        assertEquals(protocolo, viewModel.estado.value.protocolo)
    }

    @Test
    fun `com um envio em voo, enviar de novo nao manda um segundo pedido`() = runBlocking {
        val liberar = kotlinx.coroutines.CompletableDeferred<Unit>()
        var chamadas = 0
        val viewModel = viewModelComEngine(
            MockEngine {
                chamadas++
                liberar.await()
                respond(content = protocoloJson(), status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )
        viewModel.selecionarMotivo(MotivoOcorrencia.entries.first())

        val primeiro = viewModel.enviar()!!
        val segundo = viewModel.enviar()
        liberar.complete(Unit)
        primeiro.join()
        segundo?.join()

        assertEquals(1, chamadas)
        assertEquals(StatusOcorrencia.SUCESSO, viewModel.estado.value.status)
    }

    @Test
    fun `o relato e cortado no limite que o e-mail aguenta`() {
        val viewModel = viewModelComEngine(MockEngine { respond(content = protocoloJson(), status = HttpStatusCode.OK) })

        viewModel.atualizarRelato("a".repeat(TextosOcorrencia.LIMITE_DO_RELATO + 500))

        assertEquals(TextosOcorrencia.LIMITE_DO_RELATO, viewModel.estado.value.relato.length)
    }

    @Test
    fun `relato e anexo de foto nunca entram no corpo da requisicao`() = runBlocking {
        var corpoChamado: String? = null
        val engine = MockEngine { request ->
            corpoChamado = (request.body as io.ktor.http.content.TextContent).text
            respond(content = protocoloJson(), status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val viewModel = viewModelComEngine(engine)
        viewModel.selecionarMotivo(MotivoOcorrencia.OUTRO)
        viewModel.atualizarRelato("Fui agredido verbalmente pelo contratante")
        viewModel.anexarFoto("content://media/foto-prova.jpg")

        viewModel.enviar()?.join()

        assertEquals(false, corpoChamado!!.contains("agredido"))
        assertEquals(false, corpoChamado!!.contains("media/foto-prova"))
    }

    @Test
    fun `erro da API resulta em status ERRO com mensagem amigavel`() = runBlocking {
        val engine = MockEngine {
            respond(
                content = """{"code":"limite_excedido","message":"maximo de chamados diarios atingido"}""",
                status = HttpStatusCode.TooManyRequests,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val viewModel = viewModelComEngine(engine)
        viewModel.selecionarMotivo(MotivoOcorrencia.ATRASO_OU_IMPREVISTO)

        viewModel.enviar()?.join()

        assertEquals(StatusOcorrencia.ERRO, viewModel.estado.value.status)
        assertTrue(viewModel.estado.value.mensagemErro != null)
    }

    @Test
    fun `resposta 200 ilegivel resulta em status ERRO com mensagem amigavel`() = runBlocking {
        val engine = MockEngine {
                respond(
                    content = "<html>portal</html>",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "text/html"),
                )
        }
        val viewModel = viewModelComEngine(engine)
        viewModel.selecionarMotivo(MotivoOcorrencia.ATRASO_OU_IMPREVISTO)

        viewModel.enviar()?.join()

        assertEquals(StatusOcorrencia.ERRO, viewModel.estado.value.status)
        assertTrue(viewModel.estado.value.mensagemErro != null)
    }

    /**
     * Revisão do #813: o chamado é idempotente pela chave. Depois de uma resposta 200 ilegível o chamado já
     * existe no servidor; se o "Tente de novo" gerasse chave nova, abriria um segundo. A chave fica guardada
     * até dar certo, como no iOS (`SuporteTurnoViewModel.chaveIdempotente`).
     */
    @Test
    fun `depois de uma resposta 200 ilegivel, tentar de novo manda a mesma chave`() = runBlocking {
        val corpos = java.util.concurrent.CopyOnWriteArrayList<String>()
        val contador = java.util.concurrent.atomic.AtomicInteger(0)
        val engine = MockEngine { request ->
            corpos += (request.body as io.ktor.http.content.TextContent).text
            if (corpos.size == 1) {
                respond("<html>portal</html>", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "text/html"))
            } else {
                respond(protocoloJson(), HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
            }
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val viewModel = OcorrenciaTurnoViewModel(
            turnoId = turnoId,
            servicoTurnos = ServicoTurnos(cliente),
            geradorDeChave = { "chave-${contador.incrementAndGet()}" },
            escopo = CoroutineScope(Dispatchers.Default),
        )
        viewModel.selecionarMotivo(MotivoOcorrencia.ATRASO_OU_IMPREVISTO)

        viewModel.enviar()?.join()
        assertEquals(StatusOcorrencia.ERRO, viewModel.estado.value.status)
        viewModel.enviar()?.join()
        assertEquals(StatusOcorrencia.SUCESSO, viewModel.estado.value.status)

        assertEquals(2, corpos.size)
        assertTrue(corpos[0].contains("\"chave\":\"chave-1\""))
        assertTrue(corpos[1].contains("\"chave\":\"chave-1\""))
    }
}
