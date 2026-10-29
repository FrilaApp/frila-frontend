package br.com.frila.feature.turnos

import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToIndex
import androidx.compose.runtime.remember
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.dominio.modelo.Dinheiro
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaMeusTurnosTest {

    @get:Rule
    val compose = createComposeRule()

    private val provedorDeLocalizacaoFalso = object : ProvedorDeLocalizacao {
        override suspend fun obterCoordenadaAtual(): Coordenada? = null
        override fun temPermissaoDeLocalizacao(): Boolean = false
        override fun isGpsAtivado(): Boolean = false
    }

    private fun criarViewModel(respostaJson: String, status: HttpStatusCode = HttpStatusCode.OK): MeusTurnosViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(
                    content = respostaJson,
                    status = status,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        return MeusTurnosViewModel(
            servicoTurnos = ServicoTurnos(cliente),
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    private fun criarCheckin(
        turnoId: String,
        provedorDeLocalizacao: ProvedorDeLocalizacao = provedorDeLocalizacaoFalso,
        engine: MockEngine = MockEngine { respond("") },
    ): CheckinViewModel {
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        return CheckinViewModel(
            turnoId = turnoId,
            coordenadaDaVaga = null,
            servicoTurnos = ServicoTurnos(cliente),
            provedorDeLocalizacao = provedorDeLocalizacao,
        )
    }

    private fun resultadoCheckinJson(tipo: String, verificacao: String) = """
        {
          "turno_id": "t1",
          "tipo": "$tipo",
          "verificacao": "$verificacao",
          "registrado_em": "2026-11-01T21:05:00Z",
          "distancia_m": null
        }
    """.trimIndent()

    private fun turnoJson(id: String, estado: String, funcao: String, estabelecimento: String) = """
        {
          "id": "$id",
          "posicao_id": "posicao-$id",
          "vaga": {
            "id": "vaga-$id",
            "funcao": "$funcao",
            "local": "CLS 405 Bloco C",
            "regiao_administrativa": "Plano Piloto",
            "inicio_em": "2026-11-01T21:00:00Z",
            "fim_em": "2026-11-02T03:00:00Z",
            "valor_centavos": 16000
          },
          "contraparte": {
            "id": "e1",
            "tipo": "estabelecimento",
            "nome": "$estabelecimento",
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

    @Test
    fun `tela inicial exibe titulo e abas Agendados e Historico`() {
        val viewModel = criarViewModel("[]")

        compose.setContent {
            FrilaTheme {
                TelaMeusTurnos(
                    viewModel = viewModel,
                    criarCheckinViewModel = { turnoId -> criarCheckin(turnoId) },
                )
            }
        }

        compose.onNodeWithText("Meus Turnos").assertIsDisplayed()
        compose.onNodeWithText("Agendados").assertIsDisplayed().assertHasClickAction()
        compose.onNodeWithText("Histórico").assertIsDisplayed().assertHasClickAction()
    }

    @Test
    fun `quando lista de turnos e vazia exibe mensagem informativa`() {
        runBlocking {
            val viewModel = criarViewModel("[]")
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turnoId -> criarCheckin(turnoId) },
                    )
                }
            }

            compose.waitForIdle()
            compose.onNodeWithText("Você ainda não tem turnos nesta aba.").assertIsDisplayed()
        }
    }

    @Test
    fun `quando ocorre erro exibe mensagem de erro e botao tentar novamente`() {
        runBlocking {
            val erroJson = """{"code":"PGRST500","message":"Erro interno"}"""
            val viewModel = criarViewModel(erroJson, HttpStatusCode.InternalServerError)
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turnoId -> criarCheckin(turnoId) },
                    )
                }
            }

            compose.waitForIdle()
            compose.onNodeWithText("Tentar novamente").assertIsDisplayed().assertHasClickAction()
        }
    }

    @Test
    fun `quando possui turnos agendados exibe cartao com informacoes e status`() {
        runBlocking {
            val json = "[${turnoJson("t1", "confirmada", "Garçom", "Bar do Zé")}]"
            val viewModel = criarViewModel(json)
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turnoId -> criarCheckin(turnoId) },
                        relogio = { Instant.parse("2026-11-01T20:45:00Z") },
                    )
                }
            }

            compose.waitForIdle()
            compose.onNodeWithText("Garçom").assertIsDisplayed()
            compose.onNodeWithText("Bar do Zé").assertIsDisplayed()
            compose.onNodeWithText("Confirmado").assertIsDisplayed()
            compose.onNodeWithText("Cancelar turno").assertExists()
        }
    }

    @Test
    fun `ao alternar para aba Historico exibe turnos cumpridos ou cancelados`() {
        runBlocking {
            val json = """
                [
                  ${turnoJson("t1", "confirmada", "Garçom", "Bar do Zé")},
                  ${turnoJson("t2", "cumprida", "Cozinheiro", "Restaurante Bom Sabor")}
                ]
            """.trimIndent()
            val viewModel = criarViewModel(json)
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turnoId -> criarCheckin(turnoId) },
                        relogio = { Instant.parse("2026-11-01T20:45:00Z") },
                    )
                }
            }

            compose.waitForIdle()
            // Inicialmente na aba Agendados
            compose.onNodeWithText("Garçom").assertIsDisplayed()

            // Clica na aba Histórico
            compose.onNodeWithText("Histórico").performClick()
            compose.waitForIdle()

            compose.onNodeWithText("Cozinheiro").assertIsDisplayed()
            compose.onNodeWithText("Restaurante Bom Sabor").assertIsDisplayed()
            compose.onNodeWithText("Cumprido").assertIsDisplayed()
        }
    }

    @Test
    fun `quando cancelamento e solicitado exibe dialogo com motivo e confirmacao`() {
        runBlocking {
            val json = "[${turnoJson("t1", "confirmada", "Garçom", "Bar do Zé")}]"
            val viewModel = criarViewModel(json)
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turnoId -> criarCheckin(turnoId) },
                        relogio = { Instant.parse("2026-11-01T20:45:00Z") },
                    )
                }
            }

            compose.waitForIdle()
            val turno = viewModel.estado.value.agendados.first()
            viewModel.abrirCancelamento(turno)
            compose.waitForIdle()

            compose.onNodeWithText("Qual é o motivo?").assertIsDisplayed()
            compose.onNodeWithText("Confirmar cancelamento").assertIsDisplayed()
            compose.onNodeWithText("Voltar").assertIsDisplayed()
        }
    }

    @Test
    fun `sem permissao de localizacao, tocar em Fazer check-in exibe dialogo Permissao de localizacao`() {
        runBlocking {
            val json = "[${turnoJson("t1", "confirmada", "Garçom", "Bar do Zé")}]"
            val viewModel = criarViewModel(json)
            viewModel.carregar().join()
            val provedor = object : ProvedorDeLocalizacao {
                override suspend fun obterCoordenadaAtual(): Coordenada? = null
                override fun temPermissaoDeLocalizacao(): Boolean = false
                override fun isGpsAtivado(): Boolean = true
            }

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turnoId -> remember(turnoId) { criarCheckin(turnoId, provedorDeLocalizacao = provedor) } },
                        relogio = { Instant.parse("2026-11-01T20:45:00Z") },
                    )
                }
            }
            compose.waitForIdle()

            compose.onNodeWithText("Fazer check-in").performClick()
            compose.waitForIdle()

            compose.onNodeWithText("Permissão de localização").assertIsDisplayed()
            compose.onNodeWithText("Abrir configurações").assertIsDisplayed().assertHasClickAction()
            compose.onNodeWithText("Continuar manual").assertIsDisplayed().assertHasClickAction()
        }
    }

    @Test
    fun `com GPS desligado, tocar em Fazer check-in exibe dialogo GPS desativado`() {
        runBlocking {
            val json = "[${turnoJson("t1", "confirmada", "Garçom", "Bar do Zé")}]"
            val viewModel = criarViewModel(json)
            viewModel.carregar().join()
            val provedor = object : ProvedorDeLocalizacao {
                override suspend fun obterCoordenadaAtual(): Coordenada? = null
                override fun temPermissaoDeLocalizacao(): Boolean = true
                override fun isGpsAtivado(): Boolean = false
            }

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turnoId -> remember(turnoId) { criarCheckin(turnoId, provedorDeLocalizacao = provedor) } },
                        relogio = { Instant.parse("2026-11-01T20:45:00Z") },
                    )
                }
            }
            compose.waitForIdle()

            compose.onNodeWithText("Fazer check-in").performClick()
            compose.waitForIdle()

            compose.onNodeWithText("GPS desativado").assertIsDisplayed()
            compose.onNodeWithText("Ativar GPS").assertIsDisplayed().assertHasClickAction()
            compose.onNodeWithText("Continuar manual").assertIsDisplayed().assertHasClickAction()
        }
    }

    @Test
    fun `tocar em Continuar manual no dialogo registra check-in manual pendente`() {
        runBlocking {
            val json = "[${turnoJson("t1", "confirmada", "Garçom", "Bar do Zé")}]"
            val viewModel = criarViewModel(json)
            viewModel.carregar().join()
            val provedor = object : ProvedorDeLocalizacao {
                override suspend fun obterCoordenadaAtual(): Coordenada? = null
                override fun temPermissaoDeLocalizacao(): Boolean = false
                override fun isGpsAtivado(): Boolean = true
            }
            val engine = MockEngine {
                respond(
                    content = resultadoCheckinJson(tipo = "manual", verificacao = "pendente"),
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            }

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turnoId -> remember(turnoId) { criarCheckin(turnoId, provedorDeLocalizacao = provedor, engine = engine) } },
                        relogio = { Instant.parse("2026-11-01T20:45:00Z") },
                    )
                }
            }
            compose.waitForIdle()
            compose.onNodeWithText("Fazer check-in").performClick()
            compose.waitForIdle()

            compose.onNodeWithText("Continuar manual").performClick()
            compose.waitForIdle()

            compose.onNodeWithText("Check-in manual, aguardando confirmação do contratante").assertIsDisplayed()
        }
    }

    private fun jsonComHistorico(quantidade: Int): String =
        "[" + (1..quantidade).joinToString(",") { turnoJson("h$it", "cumprida", "Garçom $it", "Bar do Zé") } + "]"

    @Test
    fun `aba Historico exibe itens concluidos com badge de status e valor em BRL`() {
        runBlocking {
            val json = "[${turnoJson("t1", "cumprida", "Garçom", "Bar do Zé")}]"
            val viewModel = criarViewModel(json)
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turnoId -> criarCheckin(turnoId) },
                    )
                }
            }
            compose.waitForIdle()

            compose.onNodeWithText("Histórico").performClick()
            compose.waitForIdle()

            compose.onNodeWithText("Garçom").assertIsDisplayed()
            compose.onNodeWithText("Cumprido").assertIsDisplayed()
            compose.onNodeWithText(Dinheiro(16_000L).formatado()).assertExists()
        }
    }

    @Test
    fun `aba Historico com mais de 10 itens inicia na primeira pagina e rolagem infinita libera o resto (RF16)`() {
        runBlocking {
            val viewModel = criarViewModel(jsonComHistorico(15))
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turnoId -> criarCheckin(turnoId) },
                    )
                }
            }
            compose.waitForIdle()
            compose.onNodeWithText("Histórico").performClick()
            compose.waitForIdle()

            compose.onNodeWithText("Garçom 1").assertIsDisplayed()
            // Medido antes de rolar: a primeira composição (poucos itens visíveis no viewport)
            // ainda não disparou o gatilho de fim de lista — só a primeira página está liberada.
            assertEquals(10, viewModel.estado.value.historicoPaginado.size)
            assertEquals(1, viewModel.estado.value.paginaHistorico)

            // Rolar até o fim da primeira página aciona a rolagem infinita (RF16): o gatilho de
            // "faltam 2 itens" detecta o fim da lista atual e carrega a página seguinte sozinho.
            compose.onNodeWithTag("lista-de-turnos").performScrollToIndex(9)
            compose.waitForIdle()

            assertEquals(15, viewModel.estado.value.historicoPaginado.size)
        }
    }

    @Test
    fun `carregarMaisHistorico libera a segunda pagina na UI`() {
        runBlocking {
            val viewModel = criarViewModel(jsonComHistorico(15))
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turnoId -> criarCheckin(turnoId) },
                    )
                }
            }
            compose.waitForIdle()
            compose.onNodeWithText("Histórico").performClick()
            compose.waitForIdle()
            assertEquals(10, viewModel.estado.value.historicoPaginado.size)

            viewModel.carregarMaisHistorico()!!.join()
            compose.waitForIdle()

            assertEquals(15, viewModel.estado.value.historicoPaginado.size)
            compose.onNodeWithTag("lista-de-turnos").performScrollToIndex(14)
            compose.waitForIdle()
            compose.onNodeWithText("Garçom 15").assertExists()
        }
    }

    @Test
    fun `tela de Meus Turnos expoe PullToRefreshBox com semantica acessivel`() {
        runBlocking {
            val viewModel = criarViewModel("[]")
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turnoId -> criarCheckin(turnoId) },
                    )
                }
            }
            compose.waitForIdle()

            compose.onNodeWithContentDescription("Meus turnos").assertExists()
        }
    }
}
