package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.MotivoCancelamento
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.mockk
import io.mockk.verify
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * `MockEngine` processa a resposta num dispatcher real por baixo dos panos mesmo em teste —
 * por isso o ViewModel devolve o `Job` de [MeusTurnosViewModel.carregar] e o teste espera com
 * `.join()` de verdade (ver a nota detalhada em
 * `br.com.frila.feature.entrada.entrada.EntradaViewModel`).
 */
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
        monitorizador: MonitorizadorDeTurnosProximos? = null,
    ): MeusTurnosViewModel {
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        return MeusTurnosViewModel(
            ServicoTurnos(cliente),
            relogio = relogio,
            escopo = CoroutineScope(Dispatchers.Default),
            monitorizador = monitorizador,
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
    fun `cancelamento bem sucedido remove o alerta de aproximacao do turno (RNF04)`() = runBlocking {
        val engine = MockEngine { request ->
            if (request.url.encodedPath.endsWith("meus_turnos")) {
                respond(
                    content = "[${turnoJson("a", "confirmada")} ]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            } else {
                respond(
                    content = """{"posicao_id":"posicao-a","falta":false,"reaberta":true,"nova_posicao_id":"nova-a"}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            }
        }
        val monitorizador = mockk<MonitorizadorDeTurnosProximos>(relaxed = true)
        val viewModel = viewModelComEngine(engine, monitorizador = monitorizador)
        viewModel.carregar().join()
        viewModel.abrirCancelamento(viewModel.estado.value.agendados.first())
        viewModel.selecionarMotivo(MotivoCancelamento.SAUDE)

        viewModel.confirmarCancelamento()!!.join()

        verify(exactly = 1) { monitorizador.removerAlerta("a") }
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
}
