package br.com.frila.feature.turnos

import br.com.frila.core.rede.EventoDeTelemetria
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.network.sockets.ConnectTimeoutException
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Mesma ressalva de `MockEngine` + escopo próprio documentada em `MeusTurnosViewModelTest` e em
 * `br.com.frila.feature.entrada.entrada.EntradaViewModel`: o teste espera o `Job` com `.join()`.
 */
class AvaliacaoViewModelTest {

    private val turnoId = "11111111-1111-1111-1111-111111111111"

    private fun avaliacaoJson(resposta: Boolean) = """
        {
          "turno_id": "$turnoId",
          "resposta": $resposta,
          "criada_em": "2026-11-02T04:00:00Z"
        }
    """.trimIndent()

    private fun viewModelComEngine(engine: MockEngine): AvaliacaoViewModel {
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        return AvaliacaoViewModel(ServicoTurnos(cliente), escopo = CoroutineScope(Dispatchers.Default))
    }

    @Test
    fun `telemetria de avaliacao so registra resposta aceita e seu turno`() = runBlocking {
        val eventos = mutableListOf<Triple<EventoDeTelemetria, String?, String?>>()
        for (aceita in listOf(true, false)) {
            val cliente = ClienteSupabase("https://sintetico.supabase.invalid", "chave-sintetica", engine = MockEngine {
                if (aceita) respond(avaliacaoJson(true), headers = headersOf(HttpHeaders.ContentType, "application/json"))
                else respond("""{"code":"avaliacao_indisponivel","message":"sintetico"}""", HttpStatusCode.Conflict,
                    headersOf(HttpHeaders.ContentType, "application/json"))
            })
            cliente.use {
                val vm = AvaliacaoViewModel(ServicoTurnos(it), escopo = CoroutineScope(Dispatchers.Default),
                    registrarEvento = { evento, vaga, turno -> eventos += Triple(evento, vaga, turno) })
                vm.avaliar(turnoId, true).join()
            }
        }
        assertEquals(listOf(Triple(EventoDeTelemetria.AVALIACAO_ENVIADA, null, turnoId)), eventos)
    }

    @Test
    fun `avaliar com resposta positiva resulta em SUCESSO com resposta registrada verdadeira`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine { respond(content = avaliacaoJson(true), status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json")) },
        )

        viewModel.avaliar(turnoId, true).join()

        assertEquals(StatusAvaliacao.SUCESSO, viewModel.estado.value.status)
        assertEquals(true, viewModel.estado.value.respostaRegistrada)
    }

    @Test
    fun `avaliar com resposta negativa resulta em SUCESSO com resposta registrada falsa`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine { respond(content = avaliacaoJson(false), status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json")) },
        )

        viewModel.avaliar(turnoId, false).join()

        assertEquals(StatusAvaliacao.SUCESSO, viewModel.estado.value.status)
        assertEquals(false, viewModel.estado.value.respostaRegistrada)
    }

    @Test
    fun `avaliar recusado com avaliacao_indisponivel resulta em ERRO com mensagem`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = """{"code":"avaliacao_indisponivel","message":"antes_do_fim"}""",
                    status = HttpStatusCode.UnprocessableEntity,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.avaliar(turnoId, true).join()

        assertEquals(StatusAvaliacao.ERRO, viewModel.estado.value.status)
        assertNotNull(viewModel.estado.value.mensagemErro)
    }

    @Test
    fun `avaliar recusado com avaliacao_ja_registrada encerra em JA_AVALIADO, mesmo sem conseguir reler o turno`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = """{"code":"avaliacao_ja_registrada","message":"resposta diferente da ja gravada"}""",
                    status = HttpStatusCode.Conflict,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.avaliar(turnoId, false).join()

        // Era ERRO com "você já avaliou com uma resposta diferente" e os botões de volta (MO7DkVA2): agora é estado final.
        assertEquals(StatusAvaliacao.JA_AVALIADO, viewModel.estado.value.status)
        assertEquals(null, viewModel.estado.value.mensagemErro)
    }

    @Test
    fun `status comeca OCIOSO antes do toque`() {
        val viewModel = viewModelComEngine(MockEngine { respond(content = avaliacaoJson(true), status = HttpStatusCode.OK) })

        assertEquals(StatusAvaliacao.OCIOSO, viewModel.estado.value.status)
    }

    @Test
    fun `avaliar com resposta 200 ilegivel resulta em ERRO com mensagem`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "<html>portal</html>",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "text/html"),
                )
            },
        )

        viewModel.avaliar(turnoId, true).join()

        assertEquals(StatusAvaliacao.ERRO, viewModel.estado.value.status)
        assertNotNull(viewModel.estado.value.mensagemErro)
    }

    /** Dois toques seguidos ("sim" e "não") com a primeira chamada em voo: só a primeira vai ao servidor. */
    @Test
    fun `segundo toque com a avaliacao em voo nao envia de novo`() = runBlocking {
        val chamadas = java.util.concurrent.atomic.AtomicInteger(0)
        val viewModel = viewModelComEngine(
            MockEngine { request ->
                // Só os envios: ao abrir, o ViewModel também lê `meus_turnos` (288rCCAg), que não é um segundo envio.
                if (request.url.encodedPath.endsWith("/avaliar")) chamadas.incrementAndGet()
                kotlinx.coroutines.delay(200)
                respond(
                    content = avaliacaoJson(true),
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        val primeiro = viewModel.avaliar(turnoId, true)
        val segundo = viewModel.avaliar(turnoId, false)
        primeiro.join()
        segundo.join()

        assertEquals(1, chamadas.get())
        assertEquals(StatusAvaliacao.SUCESSO, viewModel.estado.value.status)
        assertEquals(true, viewModel.estado.value.respostaRegistrada)
    }

    // MO7DkVA2: 409 `avaliacao_ja_registrada` encerra a pergunta (como o iOS: `jaAvaliado`), relê o turno e mostra `avaliacao.resposta`.

    private fun turnoComAvaliacaoJson(resposta: Boolean?, id: String = turnoId) = """
        {
          "id": "$id", "posicao_id": "posicao-1",
          "vaga": {"id": "vaga-1", "funcao": "garçom", "local": "CLS 405 Bloco C", "regiao_administrativa": "Plano Piloto",
                   "inicio_em": "2026-11-01T21:00:00Z", "fim_em": "2026-11-02T03:00:00Z", "valor_centavos": 16000},
          "contraparte": {"id": "e1", "tipo": "estabelecimento", "nome": "Bar do Zé",
                          "reputacao": {"positivas": 1, "total": 1, "turnos_considerados": 1, "turnos_realizados": 1}},
          "verificacao": "verificado", "valor_acordado_centavos": 16000, "pode_avaliar": false, "estado": "cumprida",
          "avaliacao": ${resposta?.let { """{"turno_id": "$id", "resposta": $it, "criada_em": "2026-11-02T04:00:00Z"}""" } ?: "null"},
          "cancelamento": null
        }
    """.trimIndent()

    private val jsonCabecalho = headersOf(HttpHeaders.ContentType, "application/json")

    /** `avaliar` responde 409 e `meus_turnos` devolve `turnos`; guarda os caminhos chamados. */
    private fun viewModelComConflito(turnos: String?, caminhos: MutableList<String>): AvaliacaoViewModel {
        val engine = MockEngine { request ->
            val caminho = request.url.encodedPath
            caminhos += caminho
            when {
                caminho.endsWith("/avaliar") -> respond(
                    """{"code":"avaliacao_ja_registrada","message":"sintetico"}""", HttpStatusCode.Conflict, jsonCabecalho,
                )
                caminho.endsWith("/meus_turnos") && turnos != null -> respond(turnos, HttpStatusCode.OK, jsonCabecalho)
                else -> respond("""{"code":"erro_interno","message":"sintetico"}""", HttpStatusCode.InternalServerError, jsonCabecalho)
            }
        }
        return viewModelComEngine(engine)
    }

    @Test
    fun `409 avaliacao_ja_registrada vai a JA_AVALIADO, sem erro, e mostra a resposta gravada relida do turno`() = runBlocking {
        for (gravada in listOf(true, false)) {
            val caminhos = mutableListOf<String>()
            // Um turno de outro id, com a resposta oposta, vem antes: a releitura tem de achar o turno desta tela.
            val outro = turnoComAvaliacaoJson(!gravada, id = "99999999-9999-9999-9999-999999999999")
            val viewModel = viewModelComConflito("[$outro,${turnoComAvaliacaoJson(gravada)}]", caminhos)

            // Pede o contrário do que está gravado: é o caso do 409 (resposta diferente).
            viewModel.avaliar(turnoId, !gravada).join()

            assertEquals(StatusAvaliacao.JA_AVALIADO, viewModel.estado.value.status, "gravada=$gravada")
            assertEquals(gravada, viewModel.estado.value.respostaRegistrada, "mostra a resposta do servidor, não a tentativa")
            assertEquals(null, viewModel.estado.value.mensagemErro)
            assertTrue(caminhos.any { it.endsWith("/meus_turnos") }, "relê o turno: $caminhos")
        }
    }

    @Test
    fun `409 com a releitura do turno falhando ainda encerra em JA_AVALIADO, sem inventar a resposta`() = runBlocking {
        val viewModel = viewModelComConflito(turnos = null, caminhos = mutableListOf())

        viewModel.avaliar(turnoId, true).join()

        assertEquals(StatusAvaliacao.JA_AVALIADO, viewModel.estado.value.status)
        assertEquals(null, viewModel.estado.value.respostaRegistrada)
        assertEquals(null, viewModel.estado.value.mensagemErro)
    }

    @Test
    fun `409 com o turno sem avaliacao na lista encerra em JA_AVALIADO sem resposta`() = runBlocking {
        val viewModel = viewModelComConflito("[${turnoComAvaliacaoJson(null)}]", mutableListOf())

        viewModel.avaliar(turnoId, true).join()

        assertEquals(StatusAvaliacao.JA_AVALIADO, viewModel.estado.value.status)
        assertEquals(null, viewModel.estado.value.respostaRegistrada)
    }

    @Test
    fun `depois do 409 um novo toque nao envia de novo`() = runBlocking {
        val caminhos = mutableListOf<String>()
        val viewModel = viewModelComConflito("[${turnoComAvaliacaoJson(true)}]", caminhos)

        viewModel.avaliar(turnoId, false).join()
        val enviosAntes = caminhos.count { it.endsWith("/avaliar") }
        viewModel.avaliar(turnoId, false).join()
        viewModel.avaliar(turnoId, true).join()

        assertEquals(1, enviosAntes)
        assertEquals(1, caminhos.count { it.endsWith("/avaliar") }, "estado final: nenhum envio novo")
        assertEquals(StatusAvaliacao.JA_AVALIADO, viewModel.estado.value.status)
    }

    @Test
    fun `outros erros continuam em ERRO com os botoes (so o 409 encerra)`() = runBlocking {
        val engine = MockEngine {
            respond("""{"code":"avaliacao_indisponivel","message":"sintetico"}""", HttpStatusCode.UnprocessableEntity, jsonCabecalho)
        }
        val viewModel = viewModelComEngine(engine)

        viewModel.avaliar(turnoId, true).join()

        assertEquals(StatusAvaliacao.ERRO, viewModel.estado.value.status)
    }

    // 288rCCAg: ao abrir, lê Turno.avaliacao; e a leitura da casa leva `estabelecimento_id` (meus_turnos sem ele é vazio para o contratante).

    private val casaId = "casa-0001"

    /**
     * `meus_turnos` devolve [turnos] só quando a chamada leva (ou não leva) o `estabelecimento_id` esperado; caso contrário, lista
     * vazia, como o servidor faz com a conta de contratante sem a casa. `avaliar` responde [aoAvaliar].
     */
    private fun viewModelQueAbre(
        turnos: String,
        estabelecimentoEsperado: String? = null,
        pedidos: MutableList<String> = mutableListOf(),
        atrasoDaLeitura: Long = 0,
        aoAvaliar: () -> String = { avaliacaoJson(true) },
    ): AvaliacaoViewModel {
        val engine = MockEngine { request ->
            val caminho = request.url.encodedPath
            pedidos += caminho + (request.url.parameters["estabelecimento_id"]?.let { "?estabelecimento_id=$it" } ?: "")
            when {
                caminho.endsWith("/avaliar") -> respond(aoAvaliar(), HttpStatusCode.OK, jsonCabecalho)
                caminho.endsWith("/meus_turnos") -> {
                    if (atrasoDaLeitura > 0) kotlinx.coroutines.delay(atrasoDaLeitura)
                    val casa = request.url.parameters["estabelecimento_id"]
                    respond(if (casa == estabelecimentoEsperado) turnos else "[]", HttpStatusCode.OK, jsonCabecalho)
                }
                else -> respond("{}", HttpStatusCode.NotFound, jsonCabecalho)
            }
        }
        return viewModelComEngine(engine)
    }

    private suspend fun esperar(viewModel: AvaliacaoViewModel, status: StatusAvaliacao) {
        kotlinx.coroutines.withTimeout(5_000) { viewModel.estado.first { it.status == status } }
    }

    @Test
    fun `ao abrir, turno que ja tem avaliacao vai direto a JA_AVALIADO com a resposta, sem enviar nada`() = runBlocking {
        for (gravada in listOf(true, false)) {
            val pedidos = mutableListOf<String>()
            val viewModel = viewModelQueAbre("[${turnoComAvaliacaoJson(gravada)}]", pedidos = pedidos)

            viewModel.observar(turnoId)
            esperar(viewModel, StatusAvaliacao.JA_AVALIADO)

            assertEquals(gravada, viewModel.estado.value.respostaRegistrada, "gravada=$gravada")
            assertEquals(null, viewModel.estado.value.mensagemErro)
            assertTrue(pedidos.none { it.endsWith("/avaliar") }, "abrir não avalia: $pedidos")
        }
    }

    @Test
    fun `ao abrir, turno sem avaliacao, de outro id ou com a leitura falhando segue na pergunta`() = runBlocking {
        val casos = mapOf(
            "sem avaliação" to "[${turnoComAvaliacaoJson(null)}]",
            "só há outro turno, esse sim com avaliação" to "[${turnoComAvaliacaoJson(true, id = "99999999-9999-9999-9999-999999999999")}]",
            "lista vazia" to "[]",
        )
        for ((nome, turnos) in casos) {
            val pedidos = mutableListOf<String>()
            val viewModel = viewModelQueAbre(turnos, pedidos = pedidos)
            viewModel.observar(turnoId)
            kotlinx.coroutines.withTimeout(5_000) { while (pedidos.none { it.endsWith("/meus_turnos") }) kotlinx.coroutines.delay(10) }
            kotlinx.coroutines.delay(150)
            assertEquals(StatusAvaliacao.OCIOSO, viewModel.estado.value.status, nome)
            assertEquals(null, viewModel.estado.value.respostaRegistrada, nome)
        }
        // Leitura que falha (500): a pergunta segue, como antes.
        val viewModel = viewModelComEngine(
            MockEngine { respond("""{"code":"erro_interno","message":"x"}""", HttpStatusCode.InternalServerError, jsonCabecalho) },
        )
        viewModel.observar(turnoId)
        kotlinx.coroutines.delay(300)
        assertEquals(StatusAvaliacao.OCIOSO, viewModel.estado.value.status)
    }

    @Test
    fun `a leitura de abertura que chega depois de um envio nao sobrescreve o resultado do envio`() = runBlocking {
        // `meus_turnos` demora e traz avaliação oposta; o envio já terminou em SUCESSO com "sim".
        val viewModel = viewModelQueAbre(
            "[${turnoComAvaliacaoJson(false)}]", atrasoDaLeitura = 400, aoAvaliar = { avaliacaoJson(true) },
        )

        viewModel.observar(turnoId)
        viewModel.avaliar(turnoId, true).join()
        assertEquals(StatusAvaliacao.SUCESSO, viewModel.estado.value.status)
        kotlinx.coroutines.delay(900)

        assertEquals(StatusAvaliacao.SUCESSO, viewModel.estado.value.status)
        assertEquals(true, viewModel.estado.value.respostaRegistrada)
    }

    @Test
    fun `na casa a leitura leva estabelecimento_id, e sem a casa nao leva`() = runBlocking {
        // Com a casa: o servidor só devolve os turnos se o parâmetro vier.
        val pedidosCasa = mutableListOf<String>()
        val daCasa = viewModelQueAbre("[${turnoComAvaliacaoJson(true)}]", estabelecimentoEsperado = casaId, pedidos = pedidosCasa)
        daCasa.observar(turnoId, casaId)
        esperar(daCasa, StatusAvaliacao.JA_AVALIADO)
        assertTrue(pedidosCasa.any { it.endsWith("/meus_turnos?estabelecimento_id=$casaId") }, "$pedidosCasa")

        // Sem a casa (profissional): sem o parâmetro.
        val pedidosProf = mutableListOf<String>()
        val doProfissional = viewModelQueAbre("[${turnoComAvaliacaoJson(true)}]", pedidos = pedidosProf)
        doProfissional.observar(turnoId)
        esperar(doProfissional, StatusAvaliacao.JA_AVALIADO)
        assertTrue(pedidosProf.all { !it.contains("estabelecimento_id") }, "$pedidosProf")
    }

    @Test
    fun `na casa, a releitura do 409 tambem leva estabelecimento_id e acha a resposta gravada`() = runBlocking {
        // A leitura de abertura ainda não vê a avaliação (lista vazia); ela aparece depois, quando o 409 manda reler.
        val leituras = java.util.concurrent.atomic.AtomicInteger(0)
        val engine = MockEngine { request ->
            val caminho = request.url.encodedPath
            when {
                caminho.endsWith("/avaliar") -> respond(
                    """{"code":"avaliacao_ja_registrada","message":"x"}""", HttpStatusCode.Conflict, jsonCabecalho,
                )
                caminho.endsWith("/meus_turnos") -> {
                    val n = leituras.incrementAndGet()
                    val daCasa = request.url.parameters["estabelecimento_id"] == casaId
                    respond(if (n > 1 && daCasa) "[${turnoComAvaliacaoJson(false)}]" else "[]", HttpStatusCode.OK, jsonCabecalho)
                }
                else -> respond("{}", HttpStatusCode.NotFound, jsonCabecalho)
            }
        }
        val viewModel = viewModelComEngine(engine)

        viewModel.observar(turnoId, casaId)
        kotlinx.coroutines.withTimeout(5_000) { while (leituras.get() < 1) kotlinx.coroutines.delay(10) }
        kotlinx.coroutines.delay(100)
        assertEquals(StatusAvaliacao.OCIOSO, viewModel.estado.value.status)

        viewModel.avaliar(turnoId, true).join()

        assertEquals(StatusAvaliacao.JA_AVALIADO, viewModel.estado.value.status)
        assertEquals(false, viewModel.estado.value.respostaRegistrada, "a resposta gravada, achada pela releitura com a casa")
        assertEquals(2, leituras.get())
    }


    // ---- 403 sem_permissao e sem rede ao avaliar (cartão Gk6JX2wW, 103): só teste, o mapeamento já existe ----

    @Test
    fun `avaliar recusado com 403 sem_permissao mostra que nao ha permissao para avaliar este turno`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = """{"code":"sem_permissao","message":"x","details":null}""",
                    status = HttpStatusCode.Forbidden,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.avaliar(turnoId, true).join()

        assertEquals(StatusAvaliacao.ERRO, viewModel.estado.value.status)
        assertEquals("Você não tem permissão para avaliar este turno.", viewModel.estado.value.mensagemErro)
    }

    @Test
    fun `avaliar sem rede mostra a mensagem de sem conexao`() = runBlocking {
        // O cliente converte a falha de conexão em ErroDaApi(SEM_REDE) (ClienteSupabase, HttpResponseValidator).
        val viewModel = viewModelComEngine(MockEngine { throw ConnectTimeoutException("sem rede") })

        viewModel.avaliar(turnoId, true).join()

        assertEquals(StatusAvaliacao.ERRO, viewModel.estado.value.status)
        assertEquals("Sem conexão. Verifique sua internet e tente de novo.", viewModel.estado.value.mensagemErro)
    }
}
