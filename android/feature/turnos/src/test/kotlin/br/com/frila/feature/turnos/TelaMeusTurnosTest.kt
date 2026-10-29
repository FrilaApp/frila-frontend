package br.com.frila.feature.turnos

import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.Coordenada
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

    private fun criarCheckin(turnoId: String): CheckinViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine { respond("") },
        )
        return CheckinViewModel(
            turnoId = turnoId,
            coordenadaDaVaga = null,
            servicoTurnos = ServicoTurnos(cliente),
            provedorDeLocalizacao = provedorDeLocalizacaoFalso,
        )
    }

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
}
