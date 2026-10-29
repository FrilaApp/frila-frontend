package br.com.frila.feature.entrada.codigo

import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaCodigoTest {

    @get:Rule
    val rule = createComposeRule()

    private fun criarViewModel(
        email: String = "profissional@exemplo.com",
        respostaJson: String = """{"access_token":"tok123","refresh_token":"ref456","token_type":"bearer","expires_in":3600}""",
        statusHttp: HttpStatusCode = HttpStatusCode.OK,
    ): Pair<CodigoViewModel, ArmazenamentoDeSessaoEmMemoria> {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(respostaJson, statusHttp, headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )
        val armazenamento = ArmazenamentoDeSessaoEmMemoria()
        val viewModel = CodigoViewModel(
            email = email,
            servicoAutenticacao = ServicoAutenticacao(cliente),
            armazenamentoDeSessao = armazenamento,
            escopo = CoroutineScope(Dispatchers.Default),
        )
        return viewModel to armazenamento
    }

    @Test
    fun tituloPossuiSemanticaDeCabecalhoEExibeEmail() {
        val (viewModel, _) = criarViewModel(email = "teste@frila.app")
        rule.setContent {
            FrilaTheme {
                TelaCodigo(viewModel = viewModel, aoAutenticar = {})
            }
        }

        rule.onNodeWithText("Confirme seu código")
            .assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))

        rule.onNodeWithText("Enviamos um código de 6 dígitos para teste@frila.app.")
            .assertIsDisplayed()
    }

    @Test
    fun botoesPossuemAlvoMinimoDeToqueDe48dp() {
        val (viewModel, _) = criarViewModel()
        rule.setContent {
            FrilaTheme {
                TelaCodigo(viewModel = viewModel, aoAutenticar = {})
            }
        }

        rule.onNodeWithText("Confirmar código")
            .assertIsDisplayed()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)

        rule.onNodeWithText("Reenviar código")
            .assertIsDisplayed()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
    }

    @Test
    fun aoDigitarMenosDe6DigitosExibeErroComLiveRegionAssertive() {
        val (viewModel, _) = criarViewModel()
        rule.setContent {
            FrilaTheme {
                TelaCodigo(viewModel = viewModel, aoAutenticar = {})
            }
        }

        rule.onNodeWithText("Código de 6 dígitos").performTextInput("123")
        rule.onNodeWithText("Confirmar código").performClick()
        rule.waitForIdle()

        rule.onNodeWithText("Informe os 6 dígitos do código.").assertIsDisplayed()
        rule.onNode(
            SemanticsMatcher.expectValue(SemanticsProperties.LiveRegion, LiveRegionMode.Assertive),
            useUnmergedTree = true,
        ).assertIsDisplayed()
    }

    @Test
    fun aoClicarReenviarCodigoExibeMensagemComLiveRegionPolite() {
        val (viewModel, _) = criarViewModel()
        rule.setContent {
            FrilaTheme {
                TelaCodigo(viewModel = viewModel, aoAutenticar = {})
            }
        }

        rule.onNodeWithText("Reenviar código").performClick()
        rule.waitUntil(5000) { viewModel.estado.value.reenviado }
        rule.waitForIdle()

        rule.onNodeWithText("Código reenviado.").assertIsDisplayed()
        rule.onNode(
            SemanticsMatcher.expectValue(SemanticsProperties.LiveRegion, LiveRegionMode.Polite),
            useUnmergedTree = true,
        ).assertIsDisplayed()
    }

    @Test
    fun aoDigitarCodigoValidoEConfirmarChamaApiEInvocaCallback() {
        var autenticou = false
        val (viewModel, _) = criarViewModel()
        rule.setContent {
            FrilaTheme {
                TelaCodigo(viewModel = viewModel, aoAutenticar = { autenticou = true })
            }
        }

        rule.onNodeWithText("Código de 6 dígitos").performTextInput("123456")
        rule.onNodeWithText("Confirmar código").performClick()

        rule.waitUntil(5000) { viewModel.estado.value.autenticado }
        rule.waitForIdle()

        assertTrue(viewModel.estado.value.autenticado)
        assertTrue(autenticou)
    }
}
