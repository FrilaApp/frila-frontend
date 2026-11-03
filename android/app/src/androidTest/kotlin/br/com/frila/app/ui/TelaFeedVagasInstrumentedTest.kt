package br.com.frila.app.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.vagas.feed.OpcaoOrdenacaoVagas
import br.com.frila.feature.vagas.feed.TelaFeedVagas
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Teste de UI instrumentado Compose para a Tela do Feed de Vagas (Cartão 60).
 * Executa em dispositivo Android ou emulador através do AndroidJUnitRunner.
 */
@RunWith(AndroidJUnit4::class)
class TelaFeedVagasInstrumentedTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private class ProvedorDeLocalizacaoFake(
        private val coordenada: Coordenada? = Coordenada(-15.7942, -47.8822),
    ) : ProvedorDeLocalizacao {
        override suspend fun obterCoordenadaAtual(): Coordenada? = coordenada
        override fun temPermissaoDeLocalizacao(): Boolean = true
        override fun isGpsAtivado(): Boolean = true
    }

    private fun vagaJson(
        id: String = "11111111-1111-1111-1111-111111111111",
        funcao: String = "Garçom",
        estabelecimento: String = "Bar do Lago",
        distanciaKm: Double = 2.5,
        inicioEm: String = "2026-11-01T20:00:00Z",
        fimEm: String = "2026-11-02T02:00:00Z",
        valorCentavos: Long = 18_000L,
    ) = """
        {
          "id": "$id",
          "funcao": {"id": "22222222-2222-2222-2222-222222222222", "nome": "$funcao", "categoria": "Salão"},
          "estabelecimento": {
            "id": "33333333-3333-3333-3333-333333333333",
            "tipo": "estabelecimento",
            "nome": "$estabelecimento",
            "reputacao": {"positivas": 7, "total": 7, "taxa_comparecimento": 1.0, "turnos_considerados": 7, "turnos_realizados": 7}
          },
          "inicio_em": "$inicioEm",
          "fim_em": "$fimEm",
          "local": "SQS 405",
          "regiao_administrativa": "Asa Sul",
          "distancia_km": $distanciaKm,
          "valor_centavos": $valorCentavos,
          "posicoes_abertas": 2,
          "inclusos": {"inclui_refeicao": true, "inclui_transporte": false, "exige_material_proprio": false},
          "modo": "selecao"
        }
    """.trimIndent()

    private fun respostaVagasJson() = "[\n${vagaJson()}\n]"

    private fun criarViewModel(respostaJson: String = respostaVagasJson()): FeedVagasViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-feed-instrumentado",
            engine = MockEngine {
                respond(
                    content = respostaJson,
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        return FeedVagasViewModel(
            servicoVagas = ServicoVagas(cliente),
            provedorDeLocalizacao = ProvedorDeLocalizacaoFake(),
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    @Test
    fun renderizaBarraSuperiorEFiltrosDeOrdenacao() {
        val viewModel = criarViewModel()

        composeTestRule.setContent {
            FrilaTheme {
                TelaFeedVagas(
                    viewModel = viewModel,
                    aoAbrirDetalhe = {},
                    aoAbrirPerfil = {},
                )
            }
        }

        composeTestRule.onNodeWithText("Vagas abertas")
            .assertIsDisplayed()

        composeTestRule.onNodeWithText("Buscar vagas ou funções")
            .assertIsDisplayed()

        composeTestRule.onNodeWithText("Menor distância")
            .assertIsDisplayed()

        composeTestRule.onNodeWithText("Maior valor")
            .assertIsDisplayed()
    }

    @Test
    fun aoClicarFiltroMaiorValorAlteraOrdenacaoNoEstado() {
        val viewModel = criarViewModel()

        composeTestRule.setContent {
            FrilaTheme {
                TelaFeedVagas(
                    viewModel = viewModel,
                    aoAbrirDetalhe = {},
                )
            }
        }

        composeTestRule.onNodeWithText("Maior valor")
            .performClick()

        composeTestRule.waitForIdle()

        assertEquals(OpcaoOrdenacaoVagas.MAIOR_VALOR, viewModel.estado.value.opcaoOrdenacao)
    }

    @Test
    fun aoClicarFiltroMenorDistanciaAlteraOrdenacaoNoEstado() {
        val viewModel = criarViewModel()
        viewModel.aoSelecionarOrdenacao(OpcaoOrdenacaoVagas.MAIOR_VALOR)

        composeTestRule.setContent {
            FrilaTheme {
                TelaFeedVagas(
                    viewModel = viewModel,
                    aoAbrirDetalhe = {},
                )
            }
        }

        composeTestRule.onNodeWithText("Menor distância")
            .performClick()

        composeTestRule.waitForIdle()

        assertEquals(OpcaoOrdenacaoVagas.MENOR_DISTANCIA, viewModel.estado.value.opcaoOrdenacao)
    }

    @Test
    fun exibeVagaCarregadaComNomeDaFuncao() {
        val viewModel = criarViewModel()
        runBlocking {
            viewModel.carregar().join()
        }

        composeTestRule.setContent {
            FrilaTheme {
                TelaFeedVagas(
                    viewModel = viewModel,
                    aoAbrirDetalhe = {},
                )
            }
        }

        composeTestRule.waitForIdle()

        composeTestRule.onNodeWithText("Garçom")
            .assertIsDisplayed()
    }

    @Test
    fun aoRolarAteVagaEClicarNoCardInvocaCallbackComId() {
        val vagasJson = (1..10).joinToString(prefix = "[\n", separator = ",\n", postfix = "\n]") { i ->
            vagaJson(
                id = "vaga-$i",
                funcao = if (i == 10) "Sommelier Especialista" else "Função $i",
                estabelecimento = "Restaurante $i",
                distanciaKm = i * 1.5,
                valorCentavos = 10_000L + i * 1_000L,
            )
        }

        val viewModel = criarViewModel(respostaJson = vagasJson)
        runBlocking {
            viewModel.carregar().join()
        }

        var idVagaAberta: String? = null

        composeTestRule.setContent {
            FrilaTheme {
                TelaFeedVagas(
                    viewModel = viewModel,
                    aoAbrirDetalhe = { idVagaAberta = it },
                )
            }
        }

        composeTestRule.waitForIdle()

        composeTestRule.onNodeWithText("Sommelier Especialista")
            .performScrollTo()
            .performClick()

        composeTestRule.waitForIdle()

        assertEquals("vaga-10", idVagaAberta)
    }
}
