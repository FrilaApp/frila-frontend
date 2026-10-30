package br.com.frila.feature.vagas.feed

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoVagas
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.coEvery
import io.mockk.mockk
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h891dp")
class PullToRefreshVagasTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `feed exibe container de pull to refresh com acessibilidade semantica`() {
        val resposta = """
            [
              ${vagaJson(id = "vaga-1", funcao = "Garçom", estabelecimento = "Bar do Zé")}
            ]
        """.trimIndent()

        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(
                    content = resposta,
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        val provedorDeLocalizacao = mockk<ProvedorDeLocalizacao>()
        coEvery { provedorDeLocalizacao.obterCoordenadaAtual() } returns null
        val viewModel = FeedVagasViewModel(
            ServicoVagas(cliente),
            provedorDeLocalizacao = provedorDeLocalizacao,
            escopo = CoroutineScope(Dispatchers.Default),
        )

        runBlocking { viewModel.carregar().join() }

        compose.setContent {
            FrilaTheme {
                TelaFeedVagas(
                    viewModel = viewModel,
                    aoAbrirDetalhe = {},
                    aoAbrirPerfil = {},
                )
            }
        }

        compose.onNodeWithContentDescription("Feed de vagas abertas").assertExists()
        compose.onNodeWithText("Bar do Zé").assertExists()
    }

    private fun vagaJson(
        id: String,
        funcao: String,
        estabelecimento: String,
    ) = """
        {
          "id": "$id",
          "funcao": {"id": "f1", "nome": "$funcao", "categoria": "Salão"},
          "estabelecimento": {
            "id": "e1",
            "tipo": "estabelecimento",
            "nome": "$estabelecimento",
            "reputacao": {"positivas": 5, "total": 5, "taxa_comparecimento": 1.0, "turnos_considerados": 5, "turnos_realizados": 5}
          },
          "inicio_em": "2026-11-01T20:00:00Z",
          "fim_em": "2026-11-02T02:00:00Z",
          "local": "Asa Norte",
          "regiao_administrativa": "Plano Piloto",
          "distancia_km": 3.0,
          "valor_centavos": 15000,
          "posicoes_abertas": 1,
          "inclusos": {"inclui_refeicao": true, "inclui_transporte": false, "exige_material_proprio": false},
          "modo": "selecao"
        }
    """.trimIndent()
}
