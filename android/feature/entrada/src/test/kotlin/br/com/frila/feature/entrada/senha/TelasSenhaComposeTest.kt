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
    fun mascaraComRevelacaoBreveDetectaInsercaoNoFimEMeioEIgnoraColagemOuExclusao() {
        org.junit.Assert.assertEquals(3, indiceCaractereRecemDigitado("abc", "abcd"))
        org.junit.Assert.assertEquals(2, indiceCaractereRecemDigitado("abd", "abcd"))
        org.junit.Assert.assertNull(indiceCaractereRecemDigitado("ab", "abcdef"))
        org.junit.Assert.assertNull(indiceCaractereRecemDigitado("abcd", "abc"))
        org.junit.Assert.assertNull(indiceCaractereRecemDigitado("abcd", "abXd"))

        val reveladoMeio = MascaramentoDeSenhaComRevelacaoBreve(indiceRevelado = 2)
            .filter(androidx.compose.ui.text.AnnotatedString("abcd"))
        org.junit.Assert.assertEquals("••c•", reveladoMeio.text.text)

        val tudoMascarado = MascaramentoDeSenhaComRevelacaoBreve(indiceRevelado = null)
            .filter(androidx.compose.ui.text.AnnotatedString("abcd"))
        org.junit.Assert.assertEquals("••••", tudoMascarado.text.text)
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
}
