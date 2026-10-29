package br.com.frila.feature.perfil

import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoPerfil
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
        return PerfilViewModel(
            servicoPerfil = ServicoPerfil(cliente),
            armazenamentoDeSessao = armazenamento,
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

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
}
