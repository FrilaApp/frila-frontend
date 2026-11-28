package br.com.frila.feature.entrada.senha

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.DemonstracaoContas
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import br.com.frila.feature.entrada.criar.CriarContaViewModel
import br.com.frila.feature.entrada.recuperacao.RecuperacaoSenhaViewModel
import br.com.frila.feature.entrada.recuperacao.TelaRecuperacaoSenha
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelasSenhaComposeTest {

    @get:Rule
    val rule = createComposeRule()

    @Test
    fun telaEntradaComSenhaExibeAcoesDeSenhaCriarContaRecuperarEDemoSemOtpRotineiro() {
        val servico = ServicoAutenticacao(
            ClienteSupabase(
                "https://frila.supabase.co",
                "chave",
                engine = MockEngine { respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) },
            ),
        )
        val vm = EntradaComSenhaViewModel(
            servico,
            ArmazenamentoDeSessaoEmMemoria(),
            escopo = CoroutineScope(SupervisorJob() + Dispatchers.Default),
        )
        var clicouCriar = false
        var clicouRecuperar = false
        var emailDaDemo: String? = null

        rule.setContent {
            FrilaTheme {
                TelaEntradaComSenha(
                    viewModel = vm,
                    aoAutenticar = {},
                    aoCriarConta = { clicouCriar = true },
                    aoRecuperarSenha = { clicouRecuperar = true },
                    aoEntrarDemonstracao = { email -> emailDaDemo = email },
                )
            }
        }

        rule.onNodeWithText("E-mail").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("Senha").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("Entrar").assertIsDisplayed()
        rule.onNodeWithText("Esqueci ou ainda não tenho senha").performScrollTo().performClick()
        rule.onNodeWithText("Criar conta").performScrollTo().performClick()
        rule.onNodeWithText("Entrar em modo demonstração").performScrollTo().performClick()

        assertTrue(clicouRecuperar)
        assertTrue(clicouCriar)
        assertEquals(DemonstracaoContas.EMAIL_PROFISSIONAL, emailDaDemo)
    }

    @Test
    fun telaEntradaComSenhaAbreADemoDoContratanteQuandoEleFoiDigitadoETambemPeloBotaoEntrar() {
        val servico = ServicoAutenticacao(
            ClienteSupabase(
                "https://frila.supabase.co",
                "chave",
                engine = MockEngine { respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) },
            ),
        )
        val vm = EntradaComSenhaViewModel(
            servico,
            ArmazenamentoDeSessaoEmMemoria(),
            escopo = CoroutineScope(SupervisorJob() + Dispatchers.Default),
        )
        val demos = mutableListOf<String>()

        rule.setContent {
            FrilaTheme {
                TelaEntradaComSenha(
                    viewModel = vm,
                    aoAutenticar = {},
                    aoCriarConta = {},
                    aoRecuperarSenha = {},
                    aoEntrarDemonstracao = { email -> demos += email },
                )
            }
        }

        rule.onNodeWithText("E-mail").performTextInput(DemonstracaoContas.EMAIL_CONTRATANTE)
        rule.onNodeWithText("Entrar em modo demonstração").performScrollTo().performClick()
        rule.onNodeWithText("Entrar").performClick()

        assertEquals(listOf(DemonstracaoContas.EMAIL_CONTRATANTE, DemonstracaoContas.EMAIL_CONTRATANTE), demos)
    }

    @Test
    fun telaRecuperacaoAvancaParaOCodigoTambemQuandoNaoHaContaSemMostrarErro() {
        val servico = ServicoAutenticacao(
            ClienteSupabase(
                "https://frila.supabase.co",
                "chave",
                engine = MockEngine {
                    respond(
                        content = """{"code":422,"error_code":"otp_disabled"}""",
                        status = HttpStatusCode.UnprocessableEntity,
                        headers = headersOf(HttpHeaders.ContentType, "application/json"),
                    )
                },
            ),
        )
        val vm = RecuperacaoSenhaViewModel(servico, escopo = CoroutineScope(SupervisorJob() + Dispatchers.Default))
        var emailQueAvancou: String? = null

        rule.setContent {
            FrilaTheme {
                TelaRecuperacaoSenha(
                    viewModel = vm,
                    aoAvancarParaCodigo = { emailQueAvancou = it },
                    aoVoltarParaLogin = {},
                )
            }
        }

        rule.onNodeWithText("E-mail").performTextInput("naoexiste@exemplo.test")
        rule.onNodeWithText("Enviar código").performClick()
        rule.waitUntil(timeoutMillis = 3_000) { emailQueAvancou != null }

        assertEquals("naoexiste@exemplo.test", emailQueAvancou)
        assertNull(vm.estado.value.erro)
    }

    @Test
    fun telaDefinirSenhaRenderizaCamposPrincipais() {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply {
            salvarSessao(Sessao("tok", "ref", "bearer", 3600))
        }
        val servico = ServicoAutenticacao(
            ClienteSupabase(
                "https://frila.supabase.co",
                "chave",
                armazenamentoDeSessao = armazenamento,
                engine = MockEngine { respond("""{"id":"uid-1"}""", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) },
            ),
        )
        val criarVm = CriarContaViewModel(servico, escopo = CoroutineScope(SupervisorJob() + Dispatchers.Default))
        val definirVm = DefinirSenhaViewModel(servico, armazenamento, escopo = CoroutineScope(SupervisorJob() + Dispatchers.Default))

        rule.setContent {
            FrilaTheme {
                TelaDefinirSenha(viewModel = definirVm, aoConcluir = {})
            }
        }

        rule.onNodeWithText("Definir senha").assertIsDisplayed()
        rule.onNodeWithText("Nova senha").assertIsDisplayed()
        rule.onNodeWithText("Confirmar senha").assertIsDisplayed()
        rule.onNodeWithText("Salvar senha").assertIsDisplayed()
        assertTrue(criarVm.estado.value.email.isEmpty())
    }

    @Test
    fun mascaraComRevelacaoBreveUsaSelectionECompositionEPreservaCaracteresRepetidosNoMeio() {
        val t = { s: String, sel: Int, comp: androidx.compose.ui.text.TextRange? ->
            androidx.compose.ui.text.input.TextFieldValue(s, androidx.compose.ui.text.TextRange(sel), comp)
        }
        // Inserção no fim
        org.junit.Assert.assertEquals(3..3, intervaloCaractereRecemDigitado(t("abc", 3, null), t("abcd", 4, null)))
        // Inserção de caractere repetido no MEIO ("aaaa" -> "aaaaa" no índice 2) revela índice 2, não 4
        org.junit.Assert.assertEquals(2..2, intervaloCaractereRecemDigitado(t("aaaa", 2, null), t("aaaaa", 3, null)))
        // Composição IME ativa não revela
        org.junit.Assert.assertNull(intervaloCaractereRecemDigitado(t("abc", 3, null), t("abcd", 4, androidx.compose.ui.text.TextRange(3, 4))))
        // Colagem (>=2 chars), exclusão e substituição de seleção não revelam
        org.junit.Assert.assertNull(intervaloCaractereRecemDigitado(t("ab", 2, null), t("abcdef", 6, null)))
        org.junit.Assert.assertNull(intervaloCaractereRecemDigitado(t("abcd", 4, null), t("abc", 3, null)))
        org.junit.Assert.assertNull(
            intervaloCaractereRecemDigitado(
                androidx.compose.ui.text.input.TextFieldValue("abcd", androidx.compose.ui.text.TextRange(1, 3)),
                t("aXd", 2, null),
            ),
        )

        val reveladoMeio = MascaramentoDeSenhaComRevelacaoBreve(intervaloRevelado = 2..2)
            .filter(androidx.compose.ui.text.AnnotatedString("aaaaa"))
        org.junit.Assert.assertEquals("••a••", reveladoMeio.text.text)

        val tudoMascarado = MascaramentoDeSenhaComRevelacaoBreve(intervaloRevelado = null)
            .filter(androidx.compose.ui.text.AnnotatedString("aaaaa"))
        org.junit.Assert.assertEquals("•••••", tudoMascarado.text.text)
    }

    @Test
    fun definirSenhaAceitaDigitacaoNosDoisCamposSemBotaoDeRevelar() {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply {
            salvarSessao(Sessao("tok", "ref", "bearer", 3600))
        }
        val servico = ServicoAutenticacao(
            ClienteSupabase(
                "https://frila.supabase.co",
                "chave",
                armazenamentoDeSessao = armazenamento,
                engine = MockEngine { respond("""{"id":"uid-1"}""", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) },
            ),
        )
        val definirVm = DefinirSenhaViewModel(servico, armazenamento, escopo = CoroutineScope(SupervisorJob() + Dispatchers.Default))
        rule.setContent {
            FrilaTheme {
                TelaDefinirSenha(viewModel = definirVm, aoConcluir = {})
            }
        }

        rule.onNodeWithText("Nova senha").performTextInput("a")
        rule.waitForIdle()
        rule.mainClock.advanceTimeBy(ATRASO_MASCARAMENTO_CARACTERE_SENHA_MS + 100)
        rule.waitForIdle()

        rule.onNodeWithText("Confirmar senha").performTextInput("a")
        rule.waitForIdle()
        rule.mainClock.advanceTimeBy(ATRASO_MASCARAMENTO_CARACTERE_SENHA_MS + 100)
        rule.waitForIdle()

        org.junit.Assert.assertEquals("a", definirVm.estado.value.senha)
        org.junit.Assert.assertEquals("a", definirVm.estado.value.confirmacao)
    }

    @Test
    fun definirSenhaTemBotoesIndependentesMostrarOcultarPreservandoValor() {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply {
            salvarSessao(Sessao("tok", "ref", "bearer", 3600))
        }
        val servico = ServicoAutenticacao(
            ClienteSupabase(
                "https://frila.supabase.co",
                "chave",
                armazenamentoDeSessao = armazenamento,
                engine = MockEngine { respond("""{"id":"uid-1"}""", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) },
            ),
        )
        val definirVm = DefinirSenhaViewModel(servico, armazenamento, escopo = CoroutineScope(SupervisorJob() + Dispatchers.Default))
        rule.setContent {
            FrilaTheme {
                TelaDefinirSenha(viewModel = definirVm, aoConcluir = {})
            }
        }

        // Padrão sempre oculto nos dois campos: 2 botões "Mostrar senha", 0 "Ocultar senha"
        org.junit.Assert.assertEquals(2, rule.onAllNodes(androidx.compose.ui.test.hasContentDescription("Mostrar senha")).fetchSemanticsNodes().size)
        org.junit.Assert.assertEquals(0, rule.onAllNodes(androidx.compose.ui.test.hasContentDescription("Ocultar senha")).fetchSemanticsNodes().size)

        rule.onNodeWithText("Nova senha").performTextInput("Abc12345")
        rule.waitForIdle()

        // Alternar o primeiro botão muda só o primeiro campo para "Ocultar senha" e preserva o valor
        rule.onAllNodes(androidx.compose.ui.test.hasContentDescription("Mostrar senha"))[0].performClick()
        rule.waitForIdle()
        org.junit.Assert.assertEquals(1, rule.onAllNodes(androidx.compose.ui.test.hasContentDescription("Ocultar senha")).fetchSemanticsNodes().size)
        org.junit.Assert.assertEquals(1, rule.onAllNodes(androidx.compose.ui.test.hasContentDescription("Mostrar senha")).fetchSemanticsNodes().size)
        org.junit.Assert.assertEquals("Abc12345", definirVm.estado.value.senha)

        // Tocar novamente volta para oculto sem perder o valor
        rule.onAllNodes(androidx.compose.ui.test.hasContentDescription("Ocultar senha"))[0].performClick()
        rule.waitForIdle()
        org.junit.Assert.assertEquals(2, rule.onAllNodes(androidx.compose.ui.test.hasContentDescription("Mostrar senha")).fetchSemanticsNodes().size)
        org.junit.Assert.assertEquals("Abc12345", definirVm.estado.value.senha)
    }

    @Test
    fun coordenadorFlagSecureMantemProtecaoEnquantoOutroCampoVisivelENaoRemoveOrigemExterna() {
        val activity = org.robolectric.Robolectric.buildActivity(androidx.activity.ComponentActivity::class.java).setup().get()
        val window = activity.window
        val flagSecure = android.view.WindowManager.LayoutParams.FLAG_SECURE
        window.clearFlags(flagSecure)

        // Sequência: mostrar Nova -> mostrar Confirmar -> ocultar Nova => FLAG_SECURE permanece ativo
        CoordenadorFlagSecureJanela.adquirir(window) // Nova visível (1)
        org.junit.Assert.assertTrue((window.attributes.flags and flagSecure) != 0)
        CoordenadorFlagSecureJanela.adquirir(window) // Confirmar visível (2)
        org.junit.Assert.assertTrue((window.attributes.flags and flagSecure) != 0)
        CoordenadorFlagSecureJanela.liberar(window) // Nova oculta (1 ainda visível)
        org.junit.Assert.assertTrue((window.attributes.flags and flagSecure) != 0)
        CoordenadorFlagSecureJanela.liberar(window) // Confirmar oculta (0)
        org.junit.Assert.assertTrue((window.attributes.flags and flagSecure) == 0)

        // Se FLAG_SECURE já veio de outra origem, não é removido ao liberar todos os campos
        window.addFlags(flagSecure)
        CoordenadorFlagSecureJanela.adquirir(window)
        CoordenadorFlagSecureJanela.liberar(window)
        org.junit.Assert.assertTrue((window.attributes.flags and flagSecure) != 0)
        window.clearFlags(flagSecure)
    }

    @Test
    fun definirSenhaVoltaParaOcultoAoIrParaSegundoPlano() {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply {
            salvarSessao(Sessao("tok", "ref", "bearer", 3600))
        }
        val servico = ServicoAutenticacao(
            ClienteSupabase(
                "https://frila.supabase.co",
                "chave",
                armazenamentoDeSessao = armazenamento,
                engine = MockEngine { respond("""{"id":"uid-1"}""", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) },
            ),
        )
        val definirVm = DefinirSenhaViewModel(servico, armazenamento, escopo = CoroutineScope(SupervisorJob() + Dispatchers.Default))
        lateinit var registry: androidx.lifecycle.LifecycleRegistry
        val lifecycleOwner = object : androidx.lifecycle.LifecycleOwner {
            override val lifecycle: androidx.lifecycle.Lifecycle
                get() = registry
        }
        registry = androidx.lifecycle.LifecycleRegistry(lifecycleOwner).apply {
            handleLifecycleEvent(androidx.lifecycle.Lifecycle.Event.ON_CREATE)
            handleLifecycleEvent(androidx.lifecycle.Lifecycle.Event.ON_START)
            handleLifecycleEvent(androidx.lifecycle.Lifecycle.Event.ON_RESUME)
        }

        rule.setContent {
            androidx.compose.runtime.CompositionLocalProvider(
                androidx.lifecycle.compose.LocalLifecycleOwner provides lifecycleOwner,
            ) {
                FrilaTheme {
                    TelaDefinirSenha(viewModel = definirVm, aoConcluir = {})
                }
            }
        }

        // Mostrar os dois campos
        rule.onAllNodes(androidx.compose.ui.test.hasContentDescription("Mostrar senha"))[0].performClick()
        rule.waitForIdle()
        rule.onAllNodes(androidx.compose.ui.test.hasContentDescription("Mostrar senha"))[0].performClick()
        rule.waitForIdle()
        org.junit.Assert.assertEquals(2, rule.onAllNodes(androidx.compose.ui.test.hasContentDescription("Ocultar senha")).fetchSemanticsNodes().size)

        // Ir para segundo plano (ON_PAUSE / ON_STOP) volta ambos para oculto
        rule.runOnIdle {
            registry.handleLifecycleEvent(androidx.lifecycle.Lifecycle.Event.ON_PAUSE)
            registry.handleLifecycleEvent(androidx.lifecycle.Lifecycle.Event.ON_STOP)
        }
        rule.waitForIdle()
        org.junit.Assert.assertEquals(2, rule.onAllNodes(androidx.compose.ui.test.hasContentDescription("Mostrar senha")).fetchSemanticsNodes().size)
        org.junit.Assert.assertEquals(0, rule.onAllNodes(androidx.compose.ui.test.hasContentDescription("Ocultar senha")).fetchSemanticsNodes().size)
    }
}
