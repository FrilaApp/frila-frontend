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
          "turno_id": "$id",
          "vaga_id": "vaga-$id",
          "posicao_id": "posicao-$id",
          "funcao": {"id": "f1", "nome": "garçom", "categoria": "Salão"},
          "contraparte": {
            "id": "e1", "tipo": "estabelecimento", "nome": "Bar do Zé",
            "reputacao": {"positivas": 1, "total": 1, "turnos_considerados": 1, "turnos_realizados": 1}
          },
          "inicio_em": "2026-11-01T21:00:00Z",
          "fim_em": "2026-11-02T03:00:00Z",
          "valor_centavos": 16000,
          "estado": "$estado"
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
        assertEquals(2, viewModel.estado.value.historico.size)
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

        assertEquals(1, viewModel.estado.value.historico.size)
        assertEquals("cancelada", viewModel.estado.value.historico.first().estado)
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
        assertEquals("cancelada", viewModel.estado.value.historico.first().estado)
        assertEquals("Turno cancelado e registrado como falta.", viewModel.estado.value.mensagemFeedback)
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
              "turno_id": "turno-chk-1",
              "vaga_id": "vaga-1",
              "posicao_id": "posicao-1",
              "funcao": {"id": "f1", "nome": "garçom", "categoria": "Salão"},
              "contraparte": {
                "id": "e1", "tipo": "estabelecimento", "nome": "Bar do Zé",
                "reputacao": {"positivas": 1, "total": 1, "turnos_considerados": 1, "turnos_realizados": 1}
              },
              "inicio_em": "2026-11-01T21:00:00Z",
              "fim_em": "2026-11-02T03:00:00Z",
              "valor_centavos": 16000,
              "estado": "confirmada",
              "checkin": {
                "feito_em": "2026-11-01T20:55:00Z",
                "distancia_metros": 85.0
              }
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
}
