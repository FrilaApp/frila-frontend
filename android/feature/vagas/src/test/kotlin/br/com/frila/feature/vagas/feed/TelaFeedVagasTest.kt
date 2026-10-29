package br.com.frila.feature.vagas.feed

import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoVagas
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
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
class TelaFeedVagasTest {

    @get:Rule
    val compose = createComposeRule()

    private fun vagaJson(
        id: String = "11111111-1111-1111-1111-111111111111",
        funcao: String = "garçom",
        estabelecimento: String = "Bar do Zé",
        distanciaKm: Double = 4.2,
        inicioEm: String = "2026-11-01T21:00:00Z",
        fimEm: String = "2026-11-02T03:00:00Z",
        valorCentavos: Long = 16_000L,
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
          "local": "SQN 108",
          "regiao_administrativa": "Asa Norte",
          "distancia_km": $distanciaKm,
          "valor_centavos": $valorCentavos,
          "posicoes_abertas": 2,
          "inclusos": {"inclui_refeicao": true, "inclui_transporte": false, "exige_material_proprio": false},
          "modo": "selecao"
        }
    """.trimIndent()

    private fun criarViewModel(
        respostaJson: String = "[]",
        status: HttpStatusCode = HttpStatusCode.OK,
    ): FeedVagasViewModel {
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
        return FeedVagasViewModel(
            servicoVagas = ServicoVagas(cliente),
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    @Test
    fun `exibe titulo Vagas abertas e botao de perfil que dispara acao`() {
        var abriuPerfil = false
        val viewModel = criarViewModel()

        compose.setContent {
            FrilaTheme {
                TelaFeedVagas(
                    viewModel = viewModel,
                    aoAbrirDetalhe = {},
                    aoAbrirPerfil = { abriuPerfil = true },
                )
            }
        }

        compose.onNodeWithText("Vagas abertas").assertIsDisplayed()
        compose.onNodeWithContentDescription("Meu perfil").assertIsDisplayed().performClick()
        assertTrue(abriuPerfil)
    }

    @Test
    fun `quando feed esta vazio exibe mensagem de estado vazio`() {
        runBlocking {
            val viewModel = criarViewModel("[]")
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaFeedVagas(
                        viewModel = viewModel,
                        aoAbrirDetalhe = {},
                    )
                }
            }

            compose.waitForIdle()
            compose.onNodeWithText("Nenhuma vaga encontrada com esses filtros.").assertIsDisplayed()
        }
    }

    @Test
    fun `quando api retorna erro exibe mensagem de erro e botao tentar novamente`() {
        runBlocking {
            val erroJson = """{"code":"PGRST500","message":"erro"}"""
            val viewModel = criarViewModel(erroJson, HttpStatusCode.InternalServerError)
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaFeedVagas(
                        viewModel = viewModel,
                        aoAbrirDetalhe = {},
                    )
                }
            }

            compose.waitForIdle()
            compose.onNodeWithText("Tentar novamente").assertIsDisplayed().assertHasClickAction()
        }
    }

    @Test
    fun `quando possui vagas abertas exibe lista e ao clicar abre detalhe`() {
        runBlocking {
            val json = "[${vagaJson(id = "vaga-abc", funcao = "Garçom", estabelecimento = "Restaurante Central")}]"
            val viewModel = criarViewModel(json)
            viewModel.carregar().join()

            var vagaIdClicada: String? = null

            compose.setContent {
                FrilaTheme {
                    TelaFeedVagas(
                        viewModel = viewModel,
                        aoAbrirDetalhe = { vagaIdClicada = it },
                    )
                }
            }

            compose.waitForIdle()
            compose.onNodeWithText("Restaurante Central").assertIsDisplayed().performClick()
            assertEquals("vaga-abc", vagaIdClicada)
        }
    }

    @Test
    fun `campo de busca permite digitar texto e limpar busca`() {
        runBlocking {
            val viewModel = criarViewModel("[]")
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaFeedVagas(
                        viewModel = viewModel,
                        aoAbrirDetalhe = {},
                    )
                }
            }

            compose.waitForIdle()
            val campoBusca = compose.onNodeWithContentDescription("Buscar vagas por função ou estabelecimento")
            campoBusca.assertIsDisplayed()
            campoBusca.performTextInput("Barista")
            compose.waitForIdle()

            assertEquals("Barista", viewModel.estado.value.textoBusca)

            // Botão limpar aparece quando há texto
            compose.onNodeWithContentDescription("Limpar busca").assertIsDisplayed().performClick()
            compose.waitForIdle()

            assertEquals("", viewModel.estado.value.textoBusca)
        }
    }
}
