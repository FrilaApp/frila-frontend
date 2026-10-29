package br.com.frila.feature.turnos

import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
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
class TelaAvaliacaoTest {

    @get:Rule
    val compose = createComposeRule()

    private val turnoId = "11111111-1111-1111-1111-111111111111"

    private fun criarViewModel(
        respostaJson: String = """{"turno_id":"$turnoId","resposta":true,"criada_em":"2026-11-02T04:00:00Z"}""",
        statusHttp: HttpStatusCode = HttpStatusCode.OK,
    ): AvaliacaoViewModel {
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
        return AvaliacaoViewModel(
            servicoTurnos = ServicoTurnos(cliente),
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    @Test
    fun `tela inicial exibe pergunta, explicacao e botoes com alvo minimo de 48dp`() {
        val viewModel = criarViewModel()

        compose.setContent {
            FrilaTheme {
                TelaAvaliacao(turnoId = turnoId, viewModel = viewModel)
            }
        }

        compose.onNodeWithText("Avaliar turno").assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))

        compose.onNodeWithText("Você trabalharia nesse local de novo?").assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))

        compose.onNodeWithText("A avaliação é só sim ou não, e é anônima para o estabelecimento.")
            .assertIsDisplayed()

        compose.onNodeWithText("Sim, trabalharia")
            .assertIsDisplayed()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)

        compose.onNodeWithText("Não trabalharia")
            .assertIsDisplayed()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
    }

    @Test
    fun `ao avaliar positivamente exibe confirmacao com liveRegion polite e botao voltar`() {
        runBlocking {
            var voltou = false
            val viewModel = criarViewModel(
                respostaJson = """{"turno_id":"$turnoId","resposta":true,"criada_em":"2026-11-02T04:00:00Z"}""",
            )

            compose.setContent {
                FrilaTheme {
                    TelaAvaliacao(turnoId = turnoId, viewModel = viewModel, aoVoltar = { voltou = true })
                }
            }

            compose.onNodeWithText("Sim, trabalharia").performClick()
            compose.waitUntil(5000) { viewModel.estado.value.status == StatusAvaliacao.SUCESSO }
            compose.waitForIdle()

            assertEquals(StatusAvaliacao.SUCESSO, viewModel.estado.value.status)
            assertEquals(true, viewModel.estado.value.respostaRegistrada)

            compose.onNodeWithText("Avaliação registrada").assertIsDisplayed()
                .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))

            compose.onNodeWithText("Você recomendou este local.").assertIsDisplayed()

            compose.onNode(
                SemanticsMatcher.expectValue(SemanticsProperties.LiveRegion, LiveRegionMode.Polite),
                useUnmergedTree = true,
            ).assertIsDisplayed()

            compose.onNodeWithText("Voltar")
                .assertIsDisplayed()
                .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
                .performClick()

            assertTrue(voltou)
        }
    }

    @Test
    fun `ao avaliar negativamente exibe mensagem correspondente com liveRegion polite`() {
        runBlocking {
            val viewModel = criarViewModel(
                respostaJson = """{"turno_id":"$turnoId","resposta":false,"criada_em":"2026-11-02T04:00:00Z"}""",
            )

            compose.setContent {
                FrilaTheme {
                    TelaAvaliacao(turnoId = turnoId, viewModel = viewModel)
                }
            }

            compose.onNodeWithText("Não trabalharia").performClick()
            compose.waitUntil(5000) { viewModel.estado.value.status == StatusAvaliacao.SUCESSO }
            compose.waitForIdle()

            assertEquals(StatusAvaliacao.SUCESSO, viewModel.estado.value.status)
            assertEquals(false, viewModel.estado.value.respostaRegistrada)

            compose.onNodeWithText("Você não recomendou este local.").assertIsDisplayed()

            compose.onNode(
                SemanticsMatcher.expectValue(SemanticsProperties.LiveRegion, LiveRegionMode.Polite),
                useUnmergedTree = true,
            ).assertIsDisplayed()
        }
    }

    @Test
    fun `em caso de erro exibe mensagem com liveRegion assertiva e opcoes de nova tentativa`() {
        runBlocking {
            val viewModel = criarViewModel(
                respostaJson = """{"code":"avaliacao_indisponivel","message":"Turno ainda em andamento"}""",
                statusHttp = HttpStatusCode.UnprocessableEntity,
            )

            compose.setContent {
                FrilaTheme {
                    TelaAvaliacao(turnoId = turnoId, viewModel = viewModel)
                }
            }

            compose.onNodeWithText("Sim, trabalharia").performClick()
            compose.waitUntil(5000) { viewModel.estado.value.status == StatusAvaliacao.ERRO }
            compose.waitForIdle()

            assertEquals(StatusAvaliacao.ERRO, viewModel.estado.value.status)

            compose.onNode(
                SemanticsMatcher.expectValue(SemanticsProperties.LiveRegion, LiveRegionMode.Assertive),
                useUnmergedTree = true,
            ).assertIsDisplayed()

            compose.onNodeWithText("Você trabalharia nesse local de novo?")
                .assertIsDisplayed()
                .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))

            compose.onNodeWithText("Sim, trabalharia")
                .assertIsDisplayed()
                .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)

            compose.onNodeWithText("Não trabalharia")
                .assertIsDisplayed()
                .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
        }
    }
}
