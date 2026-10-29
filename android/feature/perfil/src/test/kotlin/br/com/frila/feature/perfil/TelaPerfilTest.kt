package br.com.frila.feature.perfil

import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.Dinheiro
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoPerfil
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.mockk
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaPerfilTest {

    @get:Rule
    val rule = createComposeRule()

    private val perfilJson = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "usuario_id": "22222222-2222-2222-2222-222222222222",
          "funcoes": [{"id": "f1", "nome": "Garçom", "categoria": "Salão"}],
          "ponto_base": {"latitude": -15.7942, "longitude": -47.8822},
          "disponibilidades": [],
          "reputacao": {
            "positivas": 7, "total": 7, "taxa_comparecimento": 0.95,
            "turnos_considerados": 8, "turnos_realizados": 8
          }
        }
    """.trimIndent()

    private fun criarViewModel(
        respostaJson: String = perfilJson,
        statusHttp: HttpStatusCode = HttpStatusCode.OK,
        armazenamento: ArmazenamentoDeSessao = mockk(relaxed = true),
        respostaTurnosJson: String = "[]",
    ): PerfilViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(
                    content = respostaJson,
                    status = statusHttp,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        val clienteTurnos = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(
                    content = respostaTurnosJson,
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        return PerfilViewModel(
            servicoPerfil = ServicoPerfil(cliente),
            servicoTurnos = ServicoTurnos(clienteTurnos),
            armazenamentoDeSessao = armazenamento,
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    private fun turnoJson(id: String, estado: String, valorAcordadoCentavos: Long) = """
        {
          "id": "$id",
          "posicao_id": "posicao-$id",
          "vaga": {
            "id": "vaga-$id",
            "funcao": "garçom",
            "local": "SQN 108",
            "regiao_administrativa": "Asa Norte",
            "inicio_em": "2026-11-01T21:00:00Z",
            "fim_em": "2026-11-02T03:00:00Z",
            "valor_centavos": $valorAcordadoCentavos
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
          "valor_acordado_centavos": $valorAcordadoCentavos,
          "pode_avaliar": false,
          "estado": "$estado",
          "avaliacao": null,
          "cancelamento": null
        }
    """.trimIndent()

    @Test
    fun titulosPossuemSemanticaDeCabecalho() {
        runBlocking {
            val viewModel = criarViewModel()
            viewModel.carregar().join()

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(viewModel = viewModel, aoDeslogar = {})
                }
            }
            rule.waitForIdle()

            rule.onNodeWithText("Meu Perfil").assertIsDisplayed()
                .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))

            rule.onNodeWithText("Reputação").assertIsDisplayed()
                .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))

            rule.onNodeWithText("Funções cadastradas").performScrollTo().assertIsDisplayed()
                .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        }
    }

    @Test
    fun filterChipsDeEspecialidadesPossuemAlvoMinimoEStateDescription() {
        runBlocking {
            val viewModel = criarViewModel()
            viewModel.carregar().join()

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(viewModel = viewModel, aoDeslogar = {})
                }
            }
            rule.waitForIdle()

            val chip = rule.onNodeWithText("Coquetelaria clássica")
            chip.performScrollTo().assertIsDisplayed()

            chip.assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)

            // Inicialmente não selecionada via stateDescription
            chip.assert(SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "não selecionada"))

            // Ao clicar, transiciona para selecionada
            chip.performClick()
            rule.waitForIdle()

            chip.assert(SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "selecionada"))
        }
    }

    @Test
    fun erroDeCarregamentoExibeMensagemComLiveRegionAssertive() {
        runBlocking {
            val viewModel = criarViewModel(
                respostaJson = """{"code":"nao_encontrado","message":"perfil nao existe"}""",
                statusHttp = HttpStatusCode.NotFound,
            )
            viewModel.carregar().join()

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(viewModel = viewModel, aoDeslogar = {})
                }
            }
            rule.waitForIdle()

            rule.onNode(
                SemanticsMatcher.expectValue(SemanticsProperties.LiveRegion, LiveRegionMode.Assertive),
                useUnmergedTree = true,
            ).assertIsDisplayed()

            rule.onNodeWithText("Tentar novamente")
                .assertIsDisplayed()
                .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
        }
    }

    @Test
    fun blocoDeRemuneracoesExibeValoresFormatadosComSemanticaDeCabecalho() {
        runBlocking {
            val turnosJson = "[" + listOf(
                turnoJson(id = "a", estado = "cumprida", valorAcordadoCentavos = 128_000L),
                turnoJson(id = "b", estado = "confirmada", valorAcordadoCentavos = 32_000L),
                turnoJson(id = "c", estado = "cancelada", valorAcordadoCentavos = 999_999L),
            ).joinToString(",") + "]"
            val viewModel = criarViewModel(respostaTurnosJson = turnosJson)
            viewModel.carregar().join()

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(viewModel = viewModel, aoDeslogar = {})
                }
            }
            rule.waitForIdle()

            rule.onNodeWithText("Remunerações acordadas").performScrollTo().assertIsDisplayed()
                .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
            rule.onNodeWithText("Valores combinados diretamente com os estabelecimentos (RN09)")
                .performScrollTo().assertIsDisplayed()
            rule.onNodeWithText("Concluído: ${Dinheiro(128_000L).formatado()} (1 turnos cumpridos)")
                .performScrollTo().assertIsDisplayed()
            rule.onNodeWithText("Pendente: ${Dinheiro(32_000L).formatado()} (1 turnos agendados)")
                .performScrollTo().assertIsDisplayed()
            rule.onNodeWithText("Total acumulado: ${Dinheiro(160_000L).formatado()}")
                .performScrollTo().assertIsDisplayed()
        }
    }

    @Test
    fun blocoDeRemuneracoesSemHistoricoExibeTextoNeutroSemZerosArtificiais() {
        runBlocking {
            val viewModel = criarViewModel()
            viewModel.carregar().join()

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(viewModel = viewModel, aoDeslogar = {})
                }
            }
            rule.waitForIdle()

            rule.onNodeWithText("Remunerações acordadas").performScrollTo().assertIsDisplayed()
            rule.onNodeWithText("Nenhum turno realizado ou agendado ainda").performScrollTo().assertIsDisplayed()
            assertTrue(rule.onAllNodesWithText("Exportar extrato em PDF").fetchSemanticsNodes().isEmpty())
        }
    }

    @Test
    fun botaoExportarExtratoApareceComAlvoMinimoQuandoHaHistorico() {
        runBlocking {
            val turnosJson = "[${turnoJson(id = "a", estado = "cumprida", valorAcordadoCentavos = 16_000L)}]"
            val viewModel = criarViewModel(respostaTurnosJson = turnosJson)
            viewModel.carregar().join()

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(viewModel = viewModel, aoDeslogar = {})
                }
            }
            rule.waitForIdle()

            rule.onNodeWithText("Exportar extrato em PDF")
                .performScrollTo()
                .assertIsDisplayed()
                .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
        }
    }
}
