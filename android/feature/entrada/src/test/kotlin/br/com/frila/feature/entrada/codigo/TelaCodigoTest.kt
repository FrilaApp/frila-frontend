package br.com.frila.feature.entrada.codigo

import androidx.compose.ui.autofill.ContentType
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.test.performTextInput
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.DemonstracaoContas
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
        respostaJson: String = """{"sessao":{"access_token":"tok123","refresh_token":"ref456","token_type":"bearer","expires_in":3600},"precisa_definir_senha":false}""",
        statusHttp: HttpStatusCode = HttpStatusCode.OK,
        /** `true`: o teste já começa depois dos 60 s de espera para reenviar. */
        esperaDeReenvioVencida: Boolean = true,
        modo: ModoCodigo = ModoCodigo.ENTRADA,
    ): Pair<CodigoViewModel, ArmazenamentoDeSessaoEmMemoria> {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(respostaJson, statusHttp, headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )
        val armazenamento = ArmazenamentoDeSessaoEmMemoria()
        var relogio = java.time.Instant.parse("2026-11-16T12:00:00Z")
        val viewModel = CodigoViewModel(
            email = email,
            servicoAutenticacao = ServicoAutenticacao(cliente),
            armazenamentoDeSessao = armazenamento,
            escopo = CoroutineScope(Dispatchers.Default),
            agora = { relogio },
            modo = modo,
        )
        if (esperaDeReenvioVencida) relogio = relogio.plusSeconds(60)
        return viewModel to armazenamento
    }

    private fun contemHintEmailOtp(): SemanticsMatcher = SemanticsMatcher("ContentType contém emailOTPCode") { node ->
        val tipo = node.config.getOrElseNullable(SemanticsProperties.ContentType) { null } ?: return@SemanticsMatcher false
        val campoHints = tipo.javaClass.declaredFields.firstOrNull { it.name == "androidAutofillHints" }?.apply { isAccessible = true }
        val hints = campoHints?.get(tipo) as? Set<*>
        tipo === CONTEUDO_CODIGO_OTP_EMAIL && hints == setOf("emailOTPCode")
    }

    @Test
    fun campoDoCodigoLevaADicaDePreenchimentoAutomaticoDeOtpPorEmailNosModosDeEmail() {
        val (viewModel, _) = criarViewModel(modo = ModoCodigo.CRIACAO)
        rule.setContent {
            FrilaTheme {
                TelaCodigo(viewModel = viewModel, aoAutenticar = {})
            }
        }

        // AndroidX HintConstants.AUTOFILL_HINT_EMAIL_OTP = "emailOTPCode"
        rule.onNodeWithContentDescription("Código de 6 dígitos")
            .assert(contemHintEmailOtp())
    }

    @Test
    fun campoDoCodigoLevaEmailOtpCodeNaRecuperacaoEConfirmaQuandoPreenchidoPeloAutofill() {
        var autenticou = false
        val (viewModel, armazenamento) = criarViewModel(modo = ModoCodigo.RECUPERACAO)
        rule.setContent {
            FrilaTheme {
                TelaCodigo(viewModel = viewModel, aoAutenticar = { autenticou = true })
            }
        }

        val campo = rule.onNodeWithContentDescription("Código de 6 dígitos")
            .assert(contemHintEmailOtp())

        // Simula o preenchimento nativo entregue pelo serviço de Autofill do Android ao BasicTextField
        campo.performSemanticsAction(SemanticsActions.OnAutofillText) { acao ->
            acao(AnnotatedString("654321"))
        }

        rule.waitUntil(5000) { viewModel.estado.value.autenticado }
        rule.waitForIdle()

        assertTrue(autenticou)
        assertTrue(armazenamento.estaAutenticado())
    }

    @Test
    fun campoDoCodigoNaoExibeHintDeEmailOtpNoModoDemonstracao() {
        val (viewModel, _) = criarViewModel(
            email = DemonstracaoContas.EMAIL_PROFISSIONAL,
            modo = ModoCodigo.DEMO,
        )
        rule.setContent {
            FrilaTheme {
                TelaCodigo(viewModel = viewModel, aoAutenticar = {})
            }
        }

        rule.onNodeWithContentDescription("Código de 6 dígitos")
            .assert(SemanticsMatcher.keyNotDefined(SemanticsProperties.ContentType))
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

        rule.onNodeWithContentDescription("Código de 6 dígitos").performTextInput("123")
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

        rule.onNodeWithText("Novo código enviado para seu e-mail.").assertIsDisplayed()
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

        // Completar os 6 dígitos confirma sozinho (como o iOS): não há toque no botão, que nesse momento
        // pode estar em "Confirmando…".
        rule.onNodeWithContentDescription("Código de 6 dígitos").performTextInput("123456")

        rule.waitUntil(5000) { viewModel.estado.value.autenticado }
        rule.waitForIdle()

        assertTrue(viewModel.estado.value.autenticado)
        assertTrue(autenticou)
    }

    /** Igual ao iOS: nos primeiros 60 s o reenvio mostra a contagem e não aceita toque. */
    @Test
    fun reenvioMostraAContagemEFicaDesligadoNosPrimeiros60Segundos() {
        val (viewModel, _) = criarViewModel(esperaDeReenvioVencida = false)
        rule.setContent {
            FrilaTheme {
                TelaCodigo(viewModel = viewModel, aoAutenticar = {})
            }
        }
        rule.waitForIdle()

        rule.onNodeWithText("Reenviar código em 1:00")
            .assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Disabled))
    }
}
