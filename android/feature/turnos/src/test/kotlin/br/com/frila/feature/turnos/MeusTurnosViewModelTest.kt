package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.MotivoCancelamento
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Timeout

/**
 * `MockEngine` processa a resposta num dispatcher real por baixo dos panos mesmo em teste —
 * por isso o ViewModel devolve o `Job` de [MeusTurnosViewModel.carregar] e o teste espera com
 * `.join()` de verdade (ver a nota detalhada em
 * `br.com.frila.feature.entrada.entrada.EntradaViewModel`).
 *
 * Rede de segurança (UZPsgOMV): um teste que espera por um pedido que não vem falha em 60 s em vez de parar a CI. A folga é
 * larga de propósito; as esperas que dependem do ViewModel têm limite próprio, curto.
 */
@Timeout(60)
class MeusTurnosViewModelTest {

    private fun turnoJson(id: String, estado: String) = """
        {
          "id": "$id",
          "posicao_id": "posicao-$id",
          "vaga": {
            "id": "vaga-$id",
            "funcao": "garçom",
            "local": "CLS 405 Bloco C",
            "regiao_administrativa": "Plano Piloto",
            "inicio_em": "2026-11-01T21:00:00Z",
            "fim_em": "2026-11-02T03:00:00Z",
            "valor_centavos": 16000
          },
          "contraparte": {
            "id": "e1",
            "tipo": "estabelecimento",
            "nome": "Bar do Zé",
            "reputacao": {"positivas": 1, "total": 1, "turnos_considerados": 1, "turnos_realizados": 1}
          },
          "contato_visivel_ate": "2026-11-09T03:00:00Z",
          "a_caminho_em": null,
          "checkin_em": null,
          "checkin_tipo": null,
          "checkin_distancia_m": null,
          "checkin_confirmado_em": null,
          "checkout_em": null,
          "checkout_distancia_m": null,
          "verificacao": "pendente",
          "valor_acordado_centavos": 16000,
          "pode_avaliar": false,
          "estado": "$estado",
          "avaliacao": null,
          "cancelamento": null
        }
    """.trimIndent()

    private fun viewModelComEngine(
        engine: MockEngine,
        relogio: Clock = Clock.systemUTC(),
    ): MeusTurnosViewModel {
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        return MeusTurnosViewModel(
            ServicoTurnos(cliente),
            relogio = relogio,
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    @Test
    fun `carregar separa confirmada em agendados e cumprida-cancelada em historico`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[${turnoJson("a", "confirmada")}, ${turnoJson("b", "cumprida")}, ${turnoJson("c", "cancelada")}]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.carregar().join()

        assertEquals(StatusMeusTurnos.SUCESSO, viewModel.estado.value.status)
        assertEquals(1, viewModel.estado.value.agendados.size)
        assertEquals("a", viewModel.estado.value.agendados.first().turnoId)
        assertEquals(2, viewModel.estado.value.historicoCompleto.size)
    }

    @Test
    fun `turno cancelado (RN12) vai para historico, nunca e descartado`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[${turnoJson("c", "cancelada")}]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.carregar().join()

        assertEquals(1, viewModel.estado.value.historicoCompleto.size)
        assertEquals("cancelada", viewModel.estado.value.historicoCompleto.first().estado)
        assertTrue(viewModel.estado.value.agendados.isEmpty())
    }

    @Test
    fun `itensDaAbaAtual reflete a aba selecionada`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[${turnoJson("a", "confirmada")}, ${turnoJson("b", "cumprida")}]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.carregar().join()
        assertEquals(1, viewModel.estado.value.itensDaAbaAtual.size) // AGENDADOS por padrão

        viewModel.aoSelecionarAba(AbaDeTurnos.HISTORICO)

        assertEquals(1, viewModel.estado.value.itensDaAbaAtual.size)
        assertEquals("b", viewModel.estado.value.itensDaAbaAtual.first().turnoId)
    }

    @Test
    fun `carregar sem turnos resulta em status VAZIO`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine { respond(content = "[]", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json")) },
        )

        viewModel.carregar().join()

        assertEquals(StatusMeusTurnos.VAZIO, viewModel.estado.value.status)
    }

    @Test
    fun `carregar com falha de rede resulta em status ERRO com mensagem`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = """{"code":"sem_permissao","message":"nao e membro do estabelecimento"}""",
                    status = HttpStatusCode.Forbidden,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.carregar().join()

        assertEquals(StatusMeusTurnos.ERRO, viewModel.estado.value.status)
        assertTrue(viewModel.estado.value.mensagemErro != null)
    }

    @Test
    fun `tentarNovamente refaz a chamada de carregar`() = runBlocking {
        var chamadas = 0
        val viewModel = viewModelComEngine(
            MockEngine {
                chamadas++
                respond(content = "[]", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )

        viewModel.carregar().join()
        viewModel.tentarNovamente().join()

        assertEquals(2, chamadas)
    }

    @Test
    fun `status comeca CARREGANDO antes da resposta chegar`() {
        val viewModel = viewModelComEngine(MockEngine { respond(content = "[]", status = HttpStatusCode.OK) })

        assertEquals(StatusMeusTurnos.CARREGANDO, viewModel.estado.value.status)
    }

    @Test
    fun `abrir cancelamento dentro de 24 horas avisa que conta como falta`() = runBlocking {
        val viewModel = viewModelComEngine(
            engine = MockEngine {
                respond(
                    content = "[${turnoJson("a", "confirmada")} ]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
            relogio = Clock.fixed(Instant.parse("2026-10-31T22:00:00Z"), ZoneOffset.UTC),
        )
        viewModel.carregar().join()

        viewModel.abrirCancelamento(viewModel.estado.value.agendados.first())

        assertTrue(viewModel.estado.value.cancelamento!!.contaComoFalta)
    }

    @Test
    fun `abrir cancelamento com 24 horas ou mais nao conta como falta`() = runBlocking {
        val viewModel = viewModelComEngine(
            engine = MockEngine {
                respond(
                    content = "[${turnoJson("a", "confirmada")} ]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
            relogio = Clock.fixed(Instant.parse("2026-10-31T21:00:00Z"), ZoneOffset.UTC),
        )
        viewModel.carregar().join()

        viewModel.abrirCancelamento(viewModel.estado.value.agendados.first())

        assertEquals(false, viewModel.estado.value.cancelamento!!.contaComoFalta)
    }

    @Test
    fun `confirmar outro motivo envia detalhes e move turno cancelado para historico`() = runBlocking {
        var corpoCancelamento: String? = null
        val engine = MockEngine { request ->
            if (request.url.encodedPath.endsWith("meus_turnos")) {
                respond(
                    content = "[${turnoJson("a", "confirmada")} ]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            } else {
                corpoCancelamento = (request.body as io.ktor.http.content.TextContent).text
                respond(
                    content = """{"posicao_id":"posicao-a","falta":true,"reaberta":true,"nova_posicao_id":"nova-a"}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            }
        }
        val viewModel = viewModelComEngine(engine)
        viewModel.carregar().join()
        viewModel.abrirCancelamento(viewModel.estado.value.agendados.first())
        viewModel.selecionarMotivo(MotivoCancelamento.OUTRO)
        viewModel.atualizarDetalhes("Preciso acompanhar um familiar")

        viewModel.confirmarCancelamento()!!.join()

        assertTrue(corpoCancelamento!!.contains("\"posicao_id\":\"posicao-a\""))
        assertTrue(corpoCancelamento!!.contains("\"motivo\":\"Preciso acompanhar um familiar\""))
        assertTrue(viewModel.estado.value.agendados.isEmpty())
        assertEquals("cancelada", viewModel.estado.value.historicoCompleto.first().estado)
        assertEquals("Turno cancelado e registrado como falta.", viewModel.estado.value.mensagemFeedback)
        assertEquals(null, viewModel.estado.value.cancelamento)
    }

    @Test
    fun `confirmar cancelamento direto sem preencher motivo envia motivo padrao e cancela com sucesso (contrato sem motivo)`() = runBlocking {
        var corpoCancelamento: String? = null
        val engine = MockEngine { request ->
            if (request.url.encodedPath.endsWith("meus_turnos")) {
                respond(
                    content = "[${turnoJson("a", "confirmada")} ]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            } else {
                corpoCancelamento = (request.body as io.ktor.http.content.TextContent).text
                respond(
                    content = """{"posicao_id":"posicao-a","falta":false,"reaberta":true,"nova_posicao_id":"nova-a"}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            }
        }
        val viewModel = viewModelComEngine(engine)
        viewModel.carregar().join()
        viewModel.abrirCancelamento(viewModel.estado.value.agendados.first())

        // Confirmação direta sem selecionar motivo (modal sem campos de motivo)
        viewModel.confirmarCancelamento()!!.join()

        assertTrue(corpoCancelamento!!.contains("\"posicao_id\":\"posicao-a\""))
        assertTrue(corpoCancelamento!!.contains("\"motivo\":\"Cancelamento pelo profissional\""))
        assertTrue(viewModel.estado.value.agendados.isEmpty())
        assertEquals("cancelada", viewModel.estado.value.historicoCompleto.first().estado)
        assertEquals("Turno cancelado sem penalidade de reputação.", viewModel.estado.value.mensagemFeedback)
        assertEquals(null, viewModel.estado.value.cancelamento)
    }

    @Test
    fun `falha posicao nao cancelavel mantem dialogo aberto com mensagem`() = runBlocking {
        val engine = MockEngine { request ->
            if (request.url.encodedPath.endsWith("meus_turnos")) {
                respond(
                    content = "[${turnoJson("a", "confirmada")} ]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            } else {
                respond(
                    content = """{"code":"posicao_nao_cancelavel","message":"turno em andamento"}""",
                    status = HttpStatusCode.Conflict,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            }
        }
        val viewModel = viewModelComEngine(engine)
        viewModel.carregar().join()
        viewModel.abrirCancelamento(viewModel.estado.value.agendados.first())
        viewModel.selecionarMotivo(MotivoCancelamento.SAUDE)

        viewModel.confirmarCancelamento()!!.join()

        assertEquals(false, viewModel.estado.value.cancelamento!!.enviando)
        assertTrue(viewModel.estado.value.cancelamento!!.mensagemErro!!.contains("não pode mais ser cancelado"))
        assertEquals(1, viewModel.estado.value.agendados.size)
    }

    @Test
    fun `turno com checkin existente mapeia comprovante preservando codigo verificador e status`() = runBlocking {
        val jsonTurnoComCheckin = """
            {
              "id": "turno-chk-1",
              "posicao_id": "posicao-1",
              "vaga": {
                "id": "vaga-1",
                "funcao": "garçom",
                "local": "CLS 405 Bloco C",
                "regiao_administrativa": "Plano Piloto",
                "inicio_em": "2026-11-01T21:00:00Z",
                "fim_em": "2026-11-02T03:00:00Z",
                "valor_centavos": 16000
              },
              "contraparte": {
                "id": "e1",
                "tipo": "estabelecimento",
                "nome": "Bar do Zé",
                "reputacao": {"positivas": 1, "total": 1, "turnos_considerados": 1, "turnos_realizados": 1}
              },
              "contato_visivel_ate": "2026-11-09T03:00:00Z",
              "a_caminho_em": "2026-11-01T20:30:00Z",
              "checkin_em": "2026-11-01T20:55:00Z",
              "checkin_tipo": "geolocalizado",
              "checkin_distancia_m": 85,
              "checkin_confirmado_em": "2026-11-01T20:55:05Z",
              "checkout_em": null,
              "checkout_distancia_m": null,
              "verificacao": "verificado",
              "valor_acordado_centavos": 16000,
              "pode_avaliar": false,
              "estado": "confirmada",
              "avaliacao": null,
              "cancelamento": null
            }
        """.trimIndent()

        val engine = MockEngine {
            respond(
                content = "[$jsonTurnoComCheckin]",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val viewModel = viewModelComEngine(engine)
        viewModel.carregar().join()

        val turno = viewModel.estado.value.agendados.first()
        org.junit.jupiter.api.Assertions.assertNotNull(turno.comprovante)
        assertEquals(br.com.frila.core.dominio.modelo.TipoVerificacaoCheckin.GEOLOCALIZADO, turno.comprovante!!.tipoVerificacao)
        assertTrue(turno.comprovante!!.codigoAutenticacao.startsWith("CHK-"))
    }

    private fun jsonComHistorico(quantidade: Int): String =
        "[" + (1..quantidade).joinToString(",") { turnoJson("h$it", "cumprida") } + "]"

    @Test
    fun `carregar com mais de 10 turnos no historico limita primeira pagina a 10 itens`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(content = jsonComHistorico(15), status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )

        viewModel.carregar().join()

        assertEquals(15, viewModel.estado.value.historicoCompleto.size)
        assertEquals(10, viewModel.estado.value.historicoPaginado.size)
        assertTrue(viewModel.estado.value.temMaisHistorico)
    }

    @Test
    fun `carregarMaisHistorico adiciona proxima fatia de itens ate esgotar historicoCompleto`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(content = jsonComHistorico(15), status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )
        viewModel.carregar().join()
        assertEquals(10, viewModel.estado.value.historicoPaginado.size)

        viewModel.carregarMaisHistorico()!!.join()

        assertEquals(15, viewModel.estado.value.historicoPaginado.size)
        assertTrue(!viewModel.estado.value.temMaisHistorico)
        assertEquals(false, viewModel.estado.value.carregandoMaisHistorico)
    }

    @Test
    fun `carregarMaisHistorico nao faz nada quando nao ha mais historico`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(content = jsonComHistorico(5), status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )
        viewModel.carregar().join()
        assertEquals(5, viewModel.estado.value.historicoPaginado.size)

        val job = viewModel.carregarMaisHistorico()

        assertEquals(null, job)
        assertEquals(1, viewModel.estado.value.paginaHistorico)
    }

    @Test
    fun `quando historico tem menos de TAMANHO_PAGINA_HISTORICO itens, temMaisHistorico e falso`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(content = jsonComHistorico(3), status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )

        viewModel.carregar().join()

        assertEquals(3, viewModel.estado.value.historicoPaginado.size)
        assertTrue(!viewModel.estado.value.temMaisHistorico)
    }

    @Test
    fun `atualizar recarrega a lista da rede e reseta a pagina do historico para 1`() = runBlocking {
        var chamada = 0
        val viewModel = viewModelComEngine(
            MockEngine {
                chamada++
                val json = if (chamada == 1) jsonComHistorico(15) else jsonComHistorico(20)
                respond(content = json, status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )
        viewModel.carregar().join()
        viewModel.carregarMaisHistorico()!!.join()
        assertEquals(2, viewModel.estado.value.paginaHistorico)

        viewModel.atualizar().join()

        assertEquals(20, viewModel.estado.value.historicoCompleto.size)
        assertEquals(1, viewModel.estado.value.paginaHistorico)
        assertEquals(10, viewModel.estado.value.historicoPaginado.size)
        assertEquals(false, viewModel.estado.value.atualizando)
    }

    @Test
    fun `atualizar com falha mantem dados anteriores e expoe mensagem de erro`() = runBlocking {
        var chamada = 0
        val viewModel = viewModelComEngine(
            MockEngine {
                chamada++
                if (chamada == 1) {
                    respond(content = jsonComHistorico(5), status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
                } else {
                    respond(
                        content = """{"code":"500","message":"erro interno"}""",
                        status = HttpStatusCode.InternalServerError,
                        headers = headersOf(HttpHeaders.ContentType, "application/json"),
                    )
                }
            },
        )
        viewModel.carregar().join()
        assertEquals(5, viewModel.estado.value.historicoCompleto.size)

        viewModel.atualizar().join()

        assertEquals(5, viewModel.estado.value.historicoCompleto.size)
        assertEquals(false, viewModel.estado.value.atualizando)
        assertTrue(viewModel.estado.value.mensagemErro != null)
    }

    /** Resposta 200 que não é a lista esperada não é `ErroDaApi`: sem o catch geral a tela ficava em "carregando". */
    @Test
    fun `carregar com resposta 200 ilegivel sai de carregando com erro`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "<html>portal</html>",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "text/html"),
                )
            },
        )

        viewModel.carregar().join()

        assertEquals(StatusMeusTurnos.ERRO, viewModel.estado.value.status)
        assertTrue(viewModel.estado.value.mensagemErro != null)
    }

    @Test
    fun `atualizarSemPiscar troca a lista sem passar pelo carregando`() = runBlocking {
        val chamadas = java.util.concurrent.atomic.AtomicInteger(0)
        val viewModel = viewModelComEngine(
            MockEngine {
                val corpo = if (chamadas.incrementAndGet() == 1) "[${turnoJson("a", "confirmada")}]"
                else "[${turnoJson("a", "confirmada")}, ${turnoJson("b", "confirmada")}]"
                respond(corpo, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )
        viewModel.carregar().join()
        val vistos = java.util.concurrent.CopyOnWriteArrayList<StatusMeusTurnos>()
        val coleta = viewModel.estado.onEach { vistos += it.status }.launchIn(kotlinx.coroutines.CoroutineScope(Dispatchers.Unconfined))

        viewModel.atualizarSemPiscar().join()
        coleta.cancel()

        assertEquals(listOf("a", "b"), viewModel.estado.value.agendados.map { it.turnoId })
        assertTrue(StatusMeusTurnos.CARREGANDO !in vistos, "a lista não pode virar o esqueleto de carregamento: $vistos")
    }

    @Test
    fun `atualizarSemPiscar que falha deixa a lista como estava`() = runBlocking {
        val chamadas = java.util.concurrent.atomic.AtomicInteger(0)
        val viewModel = viewModelComEngine(
            MockEngine {
                if (chamadas.incrementAndGet() == 1) {
                    respond("[${turnoJson("a", "confirmada")}]", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
                } else {
                    respond("{}", HttpStatusCode.InternalServerError, headersOf(HttpHeaders.ContentType, "application/json"))
                }
            },
        )
        viewModel.carregar().join()

        viewModel.atualizarSemPiscar().join()

        assertEquals(StatusMeusTurnos.SUCESSO, viewModel.estado.value.status)
        assertEquals(listOf("a"), viewModel.estado.value.agendados.map { it.turnoId })
    }

    // ── Cartão YGSOToXy: uma linha ruim não derruba a tela inteira ────────────────────────────────────────────────────────

    private fun turnoComInicioIlegivel(id: String, estado: String) =
        turnoJson(id, estado).replace("\"inicio_em\": \"2026-11-01T21:00:00Z\"", "\"inicio_em\": \"ontem\"")

    private fun viewModelComUmaLinhaRuim(descartadas: MutableList<String>): MeusTurnosViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(
                    "[${turnoJson("bom", "confirmada")}, ${turnoComInicioIlegivel("ruim", "confirmada")}, " +
                        "${turnoJson("antigo", "cumprida")}, ${turnoComInicioIlegivel("antigo-ruim", "cancelada")}]",
                    HttpStatusCode.OK,
                    headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        return MeusTurnosViewModel(
            ServicoTurnos(cliente),
            escopo = CoroutineScope(Dispatchers.Default),
            registrarLinhaDescartada = { descartadas += it },
        )
    }

    @Test
    fun `carregar com uma linha de inicio ilegivel mostra as outras e registra a descartada`() = runBlocking {
        val descartadas = mutableListOf<String>()
        val viewModel = viewModelComUmaLinhaRuim(descartadas)

        viewModel.carregar().join()

        assertEquals(StatusMeusTurnos.SUCESSO, viewModel.estado.value.status)
        assertEquals(listOf("bom"), viewModel.estado.value.agendados.map { it.turnoId })
        assertEquals(listOf("antigo"), viewModel.estado.value.historicoCompleto.map { it.turnoId })
        assertEquals(listOf("ruim", "antigo-ruim"), descartadas)
    }

    @Test
    fun `atualizar com uma linha ruim mantem as outras, sem mensagem de erro`() = runBlocking {
        val descartadas = mutableListOf<String>()
        val viewModel = viewModelComUmaLinhaRuim(descartadas)

        viewModel.atualizar().join()

        assertEquals(StatusMeusTurnos.SUCESSO, viewModel.estado.value.status)
        assertEquals(listOf("bom"), viewModel.estado.value.agendados.map { it.turnoId })
        assertEquals(null, viewModel.estado.value.mensagemErro)
    }

    @Test
    fun `atualizarSemPiscar com uma linha ruim mantem as outras`() = runBlocking {
        val descartadas = mutableListOf<String>()
        val viewModel = viewModelComUmaLinhaRuim(descartadas)
        // A releitura só vale com a lista na tela (HaRJJ0L0): a carga vem antes, e o registro das linhas ruins recomeça para medir só a releitura.
        viewModel.carregar().join()
        descartadas.clear()

        viewModel.atualizarSemPiscar().join()

        assertEquals(StatusMeusTurnos.SUCESSO, viewModel.estado.value.status)
        assertEquals(listOf("bom"), viewModel.estado.value.agendados.map { it.turnoId })
        assertEquals(listOf("ruim", "antigo-ruim"), descartadas.toList(), "a releitura também descarta as linhas ruins")
    }

    @Test
    fun `se todas as linhas sao ruins a lista fica vazia mas a tela nao vira erro`() = runBlocking {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond("[${turnoComInicioIlegivel("ruim", "confirmada")}]", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )
        val viewModel = MeusTurnosViewModel(ServicoTurnos(cliente), escopo = CoroutineScope(Dispatchers.Default))

        viewModel.carregar().join()

        assertEquals(StatusMeusTurnos.SUCESSO, viewModel.estado.value.status)
        assertTrue(viewModel.estado.value.agendados.isEmpty())
    }

    @Test
    fun `cancelamento recusado por campo_invalido ou campo_obrigatorio diz que o motivo nao foi aceito`() = runBlocking {
        for (codigo in listOf("campo_invalido", "campo_obrigatorio")) {
            val engine = MockEngine { request ->
                if (request.url.encodedPath.endsWith("meus_turnos")) {
                    respond("[${turnoJson("a", "confirmada")}]", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
                } else {
                    respond("""{"code":"$codigo","message":"x","details":"motivo"}""", HttpStatusCode.UnprocessableEntity,
                        headersOf(HttpHeaders.ContentType, "application/json"))
                }
            }
            val viewModel = viewModelComEngine(engine)
            viewModel.carregar().join()
            viewModel.abrirCancelamento(viewModel.estado.value.agendados.first())
            viewModel.selecionarMotivo(MotivoCancelamento.SAUDE)

            viewModel.confirmarCancelamento()!!.join()

            assertEquals("O motivo não foi aceito. Revise o texto e tente novamente.", viewModel.estado.value.cancelamento!!.mensagemErro, codigo)
            assertEquals(false, viewModel.estado.value.cancelamento!!.enviando, codigo)
        }
    }

    private val jsonDaResposta = headersOf(HttpHeaders.ContentType, "application/json")

    @Test
    fun `atualizarSemPiscar nao rele antes da carga nem com a tela em ERRO, e nao mexe no estado (HaRJJ0L0)`() = runBlocking {
        var pedidos = 0
        var falhar = true
        val viewModel = viewModelComEngine(
            MockEngine {
                pedidos++
                if (falhar) {
                    respond("""{"code": "500", "message": "erro"}""", HttpStatusCode.InternalServerError, jsonDaResposta)
                } else {
                    respond("[${turnoJson("a", "confirmada")}]", HttpStatusCode.OK, jsonDaResposta)
                }
            },
        )

        // Antes da carga (CARREGANDO): nada de pedido.
        viewModel.atualizarSemPiscar().join()
        assertEquals(0, pedidos)
        assertEquals(StatusMeusTurnos.CARREGANDO, viewModel.estado.value.status)

        // Em ERRO: nada de pedido, e a mensagem de erro fica onde estava.
        viewModel.carregar().join()
        assertEquals(StatusMeusTurnos.ERRO, viewModel.estado.value.status)
        val mensagem = viewModel.estado.value.mensagemErro
        val pedidosAntes = pedidos
        falhar = false
        viewModel.atualizarSemPiscar().join()
        assertEquals(pedidosAntes, pedidos)
        assertEquals(StatusMeusTurnos.ERRO, viewModel.estado.value.status)
        assertEquals(mensagem, viewModel.estado.value.mensagemErro)

        // Com a lista na tela, relê: um pedido a mais. O status e a mensagem sozinhos não provam a releitura, porque a carga de
        // antes já os deixa assim.
        viewModel.carregar().join()
        val pedidosDaCarga = pedidos
        viewModel.atualizarSemPiscar().join()
        assertEquals(pedidosDaCarga + 1, pedidos, "com a lista na tela, a releitura pede de novo")
        assertEquals(StatusMeusTurnos.SUCESSO, viewModel.estado.value.status)
        assertEquals(null, viewModel.estado.value.mensagemErro)
    }

    @Test
    fun `atualizarSemPiscar nao aplica o que leu se uma carga virou a tela para ERRO enquanto lia (HaRJJ0L0)`() = runBlocking {
        val portao = kotlinx.coroutines.CompletableDeferred<Unit>()
        var chamada = 0
        val viewModel = viewModelComEngine(
            MockEngine {
                when (++chamada) {
                    1 -> respond("[${turnoJson("a", "confirmada")}]", HttpStatusCode.OK, jsonDaResposta)
                    2 -> { portao.await(); respond("[${turnoJson("b", "confirmada")}]", HttpStatusCode.OK, jsonDaResposta) }
                    else -> respond("""{"code": "500", "message": "erro"}""", HttpStatusCode.InternalServerError, jsonDaResposta)
                }
            },
        )
        viewModel.carregar().join()
        val silenciosa = viewModel.atualizarSemPiscar()
        // Com limite: se a releitura não pedir nada, o teste falha aqui em segundos em vez de esperar para sempre (UZPsgOMV).
        withTimeout(5_000) { while (chamada < 2) kotlinx.coroutines.delay(5) }

        viewModel.carregar().join()
        assertEquals(StatusMeusTurnos.ERRO, viewModel.estado.value.status)
        portao.complete(Unit)
        silenciosa.join()

        assertEquals(StatusMeusTurnos.ERRO, viewModel.estado.value.status, "a releitura que chegou depois não desfaz o erro")
    }
}
