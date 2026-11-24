package br.com.frila.feature.entrada.senha

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
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
        var clicouDemo = false

        rule.setContent {
            FrilaTheme {
                TelaEntradaComSenha(
                    viewModel = vm,
                    aoAutenticar = {},
                    aoCriarConta = { clicouCriar = true },
                    aoRecuperarSenha = { clicouRecuperar = true },
                    aoEntrarDemonstracao = { clicouDemo = true },
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
        assertTrue(clicouDemo)
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
}
