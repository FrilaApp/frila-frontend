package br.com.frila.feature.entrada.entrada

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
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoAutenticacao
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
class TelaEntradaTest {

    @get:Rule
    val rule = createComposeRule()

    private fun criarViewModel(statusHttp: HttpStatusCode = HttpStatusCode.OK): EntradaViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond("{}", statusHttp, headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )
        return EntradaViewModel(
            servicoAutenticacao = ServicoAutenticacao(cliente),
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    @Test
    fun tituloPossuiSemanticaDeCabecalho() {
        val viewModel = criarViewModel()
        rule.setContent {
            FrilaTheme {
                TelaEntrada(viewModel = viewModel, aoReceberCodigo = {})
            }
        }

        rule.onNodeWithText("Bem-vindo ao Frila")
            .assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))

        rule.onNodeWithText("Entre com seu e-mail para receber o código de acesso.")
            .assertIsDisplayed()
    }

    @Test
    fun botoesPossuemAlvoMinimoDeToqueDe48dp() {
        val viewModel = criarViewModel()
        rule.setContent {
            FrilaTheme {
                TelaEntrada(viewModel = viewModel, aoReceberCodigo = {})
            }
        }

        rule.onNodeWithText("Receber código")
            .assertIsDisplayed()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)

        rule.onNodeWithText("Entrar em modo demonstração")
            .assertIsDisplayed()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
    }

    @Test
    fun aoDigitarEmailInvalidoESolicitarCodigoExibeErroComLiveRegionAssertive() {
        val viewModel = criarViewModel()
        rule.setContent {
            FrilaTheme {
                TelaEntrada(viewModel = viewModel, aoReceberCodigo = {})
            }
        }

        rule.onNodeWithText("E-mail").performTextInput("email-invalido")
        rule.onNodeWithText("Receber código").performClick()
        rule.waitForIdle()

        rule.onNodeWithText("Informe um e-mail válido.").assertIsDisplayed()
        rule.onNode(
            SemanticsMatcher.expectValue(SemanticsProperties.LiveRegion, LiveRegionMode.Assertive),
            useUnmergedTree = true,
        ).assertIsDisplayed()
    }

    @Test
    fun aoClicarModoDemonstracaoPreencheEmailEAvancaParaCodigo() {
        var avancou = false
        val viewModel = criarViewModel()
        rule.setContent {
            FrilaTheme {
                TelaEntrada(viewModel = viewModel, aoReceberCodigo = { avancou = true })
            }
        }

        rule.onNodeWithText("Entrar em modo demonstração").performClick()
        rule.waitForIdle()

        assertTrue(viewModel.estado.value.otpSolicitado)
        assertTrue(avancou)
    }

    @Test
    fun aoDigitarEmailValidoESolicitarCodigoChamaApiEInvocaCallback() {
        var avancou = false
        val viewModel = criarViewModel()
        rule.setContent {
            FrilaTheme {
                TelaEntrada(viewModel = viewModel, aoReceberCodigo = { avancou = true })
            }
        }

        rule.onNodeWithText("E-mail").performTextInput("profissional@exemplo.com")
        rule.onNodeWithText("Receber código").performClick()

        rule.waitUntil(5000) { viewModel.estado.value.otpSolicitado }
        rule.waitForIdle()

        assertTrue(viewModel.estado.value.otpSolicitado)
        assertTrue(avancou)
    }
}
