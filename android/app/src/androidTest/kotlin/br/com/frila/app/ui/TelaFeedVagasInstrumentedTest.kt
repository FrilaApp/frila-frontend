package br.com.frila.app.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.feature.vagas.feed.EstadoFeed
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

    private fun respostaVagasJson() = """
        [
          {
            "id": "11111111-1111-1111-1111-111111111111",
            "funcao": {"id": "22222222-2222-2222-2222-222222222222", "nome": "Garçom", "categoria": "Salão"},
            "estabelecimento": {"nome": "Bar do Lago", "bairro": "Asa Sul", "latitude": -15.80, "longitude": -47.89},
            "inicio_em": "2026-11-01T20:00:00Z",
            "fim_em": "2026-11-02T02:00:00Z",
            "valor_centavos": 18000,
            "distancia_km": 2.5
          }
        ]
    """.trimIndent()

    private fun criarViewModel(): FeedVagasViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-feed-instrumentado",
            engine = MockEngine {
                respond(
                    content = respostaVagasJson(),
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
}
