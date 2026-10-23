package br.com.frila.feature.vagas.feed

import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.unit.dp
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
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class BuscaTextualVagasTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `campo filtra lista limpa busca e expoe semantica acessivel`() {
        val resposta = """
            [
              ${vagaJson(id = "vaga-bar", funcao = "garçom", estabelecimento = "Bar do Zé")},
              ${vagaJson(id = "vaga-bistro", funcao = "cozinheiro", estabelecimento = "Bistrô Central")}
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
        val viewModel = FeedVagasViewModel(
            ServicoVagas(cliente),
            escopo = CoroutineScope(Dispatchers.Default),
        )
        runBlocking { viewModel.carregar().join() }

        compose.setContent {
            FrilaTheme {
                TelaFeedVagas(viewModel = viewModel, aoAbrirDetalhe = {})
            }
        }

        val campo = compose.onNodeWithContentDescription("Buscar vagas por função ou estabelecimento")
        campo
            .assertIsDisplayed()
            .assertHeightIsAtLeast(48.dp)
            .assert(SemanticsMatcher.keyIsDefined(SemanticsActions.SetText))
            .performTextInput("bistrô")

        compose.onNodeWithText("Bistrô Central").assertIsDisplayed()
        compose.onNodeWithText("Bar do Zé").assertDoesNotExist()

        compose.onNodeWithContentDescription("Limpar busca")
            .assertHasClickAction()
            .assertHeightIsAtLeast(48.dp)
            .performClick()

        compose.onNodeWithText("Bistrô Central").assertIsDisplayed()
        compose.onNodeWithText("Bar do Zé").assertIsDisplayed()

        campo.performTextInput("inexistente")
        compose.onNodeWithText("Nenhuma vaga encontrada para \"inexistente\".")
            .assertIsDisplayed()
    }

    private fun vagaJson(
        id: String,
        funcao: String,
        estabelecimento: String,
    ) = """
        {
          "id": "$id",
          "funcao": {"id": "funcao-$id", "nome": "$funcao", "categoria": "Salão"},
          "estabelecimento": {
            "id": "estabelecimento-$id",
            "tipo": "estabelecimento",
            "nome": "$estabelecimento",
            "reputacao": {"positivas": 7, "total": 7, "taxa_comparecimento": 1.0, "turnos_considerados": 7, "turnos_realizados": 7}
          },
          "inicio_em": "2026-11-01T21:00:00Z",
          "fim_em": "2026-11-02T03:00:00Z",
          "local": "SQN 108",
          "regiao_administrativa": "Asa Norte",
          "distancia_km": 4.2,
          "valor_centavos": 16000,
          "posicoes_abertas": 2,
          "inclusos": {"inclui_refeicao": true, "inclui_transporte": false, "exige_material_proprio": false},
          "modo": "selecao"
        }
    """.trimIndent()
}
