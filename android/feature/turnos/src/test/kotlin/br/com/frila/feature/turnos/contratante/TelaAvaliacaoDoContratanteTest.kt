package br.com.frila.feature.turnos.contratante

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.feature.turnos.AvaliacaoViewModel
import br.com.frila.feature.turnos.StatusAvaliacao
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaAvaliacaoDoContratanteTest {

    @get:Rule
    val compose = createComposeRule()

    private val turnoId = "turno-contratante-999"

    private fun criarViewModel(
        respostaJson: String = """{"turno_id":"$turnoId","resposta":true,"criada_em":"2026-11-21T04:00:00Z"}""",
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
    fun aoCarregarExibePerguntaDoContratanteEOpcoesBinarias() {
        val vm = criarViewModel()

        compose.setContent {
            FrilaTheme {
                TelaAvaliacaoDoContratante(
                    turnoId = turnoId,
                    viewModel = vm,
                    aoVoltar = {},
                )
            }
        }

        compose.onNodeWithTag("pergunta-avaliacao-contratante").assertIsDisplayed()
        compose.onNodeWithText("Chamaria este profissional de novo?").assertIsDisplayed()
        compose.onNodeWithText(
            "Sua resposta é anônima e compõe a reputação do profissional no Frila. Cada turno concluído conta para o índice de recomendação.",
        ).assertIsDisplayed()
        compose.onNodeWithText("Sim, chamaria").assertIsDisplayed()
        compose.onNodeWithText("Não chamaria").assertIsDisplayed()
    }

    @Test
    fun aoResponderSimRegistraAvaliacaoEExibeConfirmacao() {
        val vm = criarViewModel()
        var voltou = false

        compose.setContent {
            FrilaTheme {
                TelaAvaliacaoDoContratante(
                    turnoId = turnoId,
                    viewModel = vm,
                    aoVoltar = { voltou = true },
                )
            }
        }

        compose.onNodeWithText("Sim, chamaria").performClick()
        compose.waitUntil(5000) { vm.estado.value.status == StatusAvaliacao.SUCESSO }
        compose.waitForIdle()

        compose.onNodeWithText("Avaliação registrada").assertIsDisplayed()
        compose.onNodeWithText("Você recomendou este profissional.").assertIsDisplayed()

        compose.onNodeWithTag("voltar-avaliacao-contratante").assertIsDisplayed().performClick()
        assertTrue(voltou)
    }

    @Test
    fun aoResponderNaoRegistraAvaliacaoEExibeConfirmacaoNegativa() {
        val vm = criarViewModel(
            respostaJson = """{"turno_id":"$turnoId","resposta":false,"criada_em":"2026-11-21T04:00:00Z"}""",
        )

        compose.setContent {
            FrilaTheme {
                TelaAvaliacaoDoContratante(
                    turnoId = turnoId,
                    viewModel = vm,
                    aoVoltar = {},
                )
            }
        }

        compose.onNodeWithText("Não chamaria").performClick()
        compose.waitUntil(5000) { vm.estado.value.status == StatusAvaliacao.SUCESSO }
        compose.waitForIdle()

        compose.onNodeWithText("Avaliação registrada").assertIsDisplayed()
        compose.onNodeWithText("Você não recomendou este profissional.").assertIsDisplayed()
    }

    @Test
    fun erroDeRedePermiteTentarNovamente() {
        val vm = criarViewModel(
            respostaJson = """{"code":"sem_rede","message":"Sem rede"}""",
            statusHttp = HttpStatusCode.InternalServerError,
        )

        compose.setContent {
            FrilaTheme {
                TelaAvaliacaoDoContratante(
                    turnoId = turnoId,
                    viewModel = vm,
                    aoVoltar = {},
                )
            }
        }

        compose.onNodeWithText("Sim, chamaria").performClick()
        compose.waitUntil(5000) { vm.estado.value.status == StatusAvaliacao.ERRO }
        compose.waitForIdle()

        assertEquals(StatusAvaliacao.ERRO, vm.estado.value.status)
        compose.onNodeWithText("Sem conexão. Verifique sua internet e tente de novo.").assertIsDisplayed()
        compose.onNodeWithText("Sim, chamaria").assertIsDisplayed()
    }
}
