package br.com.frila.feature.turnos

import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onParent
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.MotivoOcorrencia
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
class TelaOcorrenciaTest {

    @get:Rule
    val compose = createComposeRule()

    private fun criarViewModel(
        respostaJson: String = """{"ocorrencia_id":"6f1c2a4e-2b7d-4c5e-9a1f-3d2e1c0b9a88","tipo":"suporte","criada_em":"2026-10-08T14:00:00Z","prazo_resposta_ate":"2026-10-15"}""",
    ): OcorrenciaTurnoViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(
                    content = respostaJson,
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        return OcorrenciaTurnoViewModel(
            turnoId = "turno-123",
            servicoTurnos = ServicoTurnos(cliente),
            geradorDeChave = { "chave-fixa" },
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    @Test
    fun `tela inicial exibe todos os motivos normativos e botao enviar desabilitado sem selecao`() {
        val viewModel = criarViewModel()

        compose.setContent {
            FrilaTheme {
                TelaOcorrencia(viewModel = viewModel)
            }
        }

        compose.onNodeWithText("Relatar ocorrência").assertIsDisplayed()
        compose.onNodeWithText("O que aconteceu?").assertIsDisplayed()

        MotivoOcorrencia.entries.forEach { motivo ->
            compose.onNodeWithText(motivo.descricao).assertIsDisplayed()
        }

        compose.onNodeWithText("Enviar").assertIsNotEnabled()
    }

    @Test
    fun `ao selecionar motivo o botao enviar e habilitado`() {
        val viewModel = criarViewModel()

        compose.setContent {
            FrilaTheme {
                TelaOcorrencia(viewModel = viewModel)
            }
        }

        compose.onNodeWithText(MotivoOcorrencia.PROBLEMA_NO_LOCAL.descricao).performClick()
        compose.onNodeWithText("Enviar").assertIsEnabled()
    }

    @Test
    fun `em caso de sucesso exibe confirmacao com protocolo curto de 8 caracteres em maiusculas`() = runBlocking {
        val viewModel = criarViewModel()
        var protocoloEnviado: String? = null

        compose.setContent {
            FrilaTheme {
                TelaOcorrencia(
                    viewModel = viewModel,
                    aoAbrirEmailDeSuporte = { protocoloEnviado = it },
                )
            }
        }

        // Seleciona motivo e envia aguardando conclusão da coroutine
        viewModel.selecionarMotivo(MotivoOcorrencia.RISCO_SEGURANCA)
        viewModel.enviar()?.join()
        compose.waitForIdle()

        // 6f1c2a4e-2b7d -> take(8) = "6f1c2a4e" -> uppercase = "6F1C2A4E"
        compose.onNodeWithText("Chamado aberto. Protocolo #6F1C2A4E").assertIsDisplayed()

        // Clique em abrir email
        compose.onNodeWithText("Abrir e-mail de suporte").assertIsDisplayed().assertHasClickAction().performClick()
        assertEquals("6F1C2A4E", protocoloEnviado)
    }

    @Test
    fun `clique em voltar invoca callback aoVoltar`() = runBlocking {
        val viewModel = criarViewModel()
        var voltou = false

        compose.setContent {
            FrilaTheme {
                TelaOcorrencia(
                    viewModel = viewModel,
                    aoVoltar = { voltou = true },
                )
            }
        }

        // Simula estado de sucesso
        viewModel.selecionarMotivo(MotivoOcorrencia.OUTRO)
        viewModel.enviar()?.join()
        compose.waitForIdle()

        compose.onNodeWithText("Voltar").assertIsDisplayed().performClick()
        assertTrue(voltou)
    }
}
