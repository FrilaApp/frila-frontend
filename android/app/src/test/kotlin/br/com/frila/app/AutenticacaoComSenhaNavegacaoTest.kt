package br.com.frila.app

import android.app.Application
import androidx.activity.ComponentActivity
import androidx.compose.ui.test.ComposeTimeoutException
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.DemonstracaoContas
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.rede.ServicoConta
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.core.rede.ServicoPerfil
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.feature.entrada.cadastro.CadastroViewModel
import br.com.frila.feature.entrada.codigo.CodigoViewModel
import br.com.frila.feature.entrada.codigo.ModoCodigo
import br.com.frila.feature.entrada.criar.CriarContaViewModel
import br.com.frila.feature.entrada.recuperacao.RecuperacaoSenhaViewModel
import br.com.frila.feature.entrada.senha.DefinirSenhaViewModel
import br.com.frila.feature.entrada.senha.EntradaComSenhaViewModel
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import java.util.concurrent.CopyOnWriteArrayList
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AutenticacaoComSenhaNavegacaoTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste()

    @get:Rule(order = 1)
    val rule = createAndroidComposeRule<ComponentActivity>()

    private lateinit var nav: NavHostController
    private val sessao = ArmazenamentoDeSessaoEmMemoria()
    private val chamadas = CopyOnWriteArrayList<String>()
    private val corposOtp = CopyOnWriteArrayList<String>()
    private val corposDemo = CopyOnWriteArrayList<String>()

    private val usuarioProfissional =
        """{"id":"11111111-1111-4111-8111-111111111111","perfil":"profissional","nome":"Conta Teste","telefone":"61999990000","email":"conta@exemplo.test","nascimento":"1990-01-01","estado":"ativa"}"""
    private val perfilProfissional =
        """{"id":"22222222-2222-4222-8222-222222222222","usuario_id":"11111111-1111-4111-8111-111111111111","funcoes":[],"disponibilidades":[],"reputacao":{"positivas":0,"total":0,"turnos_considerados":0,"turnos_realizados":0}}"""

    private fun montarApp(contaExiste: Boolean, otpDesativado: Boolean = false) {
        val engine = MockEngine { req ->
            val path = req.url.encodedPath
            chamadas += path
            if (path == "/auth/v1/otp") {
                corposOtp += (req.body as TextContent).text
            }
            if (path == "/functions/v1/entrar-demonstracao") {
                corposDemo += (req.body as TextContent).text
            }
            val (corpo, status) = when {
                path == "/auth/v1/otp" && otpDesativado ->
                    """{"code":422,"error_code":"otp_disabled","msg":"Signups not allowed for otp"}""" to HttpStatusCode.UnprocessableEntity
                path == "/auth/v1/otp" -> "{}" to HttpStatusCode.OK
                path == "/functions/v1/entrar-demonstracao" -> {
                    val email = Regex("\"email\":\"([^\"]+)\"").find(corposDemo.last())?.groupValues?.get(1).orEmpty()
                    """{"access_token":"tok-demo-$email","refresh_token":"ref-demo","token_type":"bearer","expires_in":3600}""" to HttpStatusCode.OK
                }
                path == "/auth/v1/verify" ->
                    """{"access_token":"tok-otp","refresh_token":"ref-otp","token_type":"bearer","expires_in":3600}""" to HttpStatusCode.OK
                path == "/functions/v1/confirmar-dispositivo-otp" ->
                    """{"sessao":{"access_token":"tok-otp","refresh_token":"ref-otp","token_type":"bearer","expires_in":3600},"precisa_definir_senha":true}""" to HttpStatusCode.OK
                path == "/auth/v1/token" ->
                    """{"access_token":"tok-senha","refresh_token":"ref-senha","token_type":"bearer","expires_in":3600}""" to HttpStatusCode.OK
                path == "/functions/v1/autenticar-senha" ->
                    """{"status":"autenticado","sessao":{"access_token":"tok-senha","refresh_token":"ref-senha","token_type":"bearer","expires_in":3600},"precisa_definir_senha":false}""" to HttpStatusCode.OK
                path == "/auth/v1/user" -> """{"id":"11111111-1111-4111-8111-111111111111"}""" to HttpStatusCode.OK
                path == "/functions/v1/definir-senha" ->
                    """{"ok":true,"precisa_definir_senha":false,"dispositivos_revogados":1,"sessao":null}""" to HttpStatusCode.OK
                path.endsWith("/rpc/minha_conta") ->
                    if (contaExiste) usuarioProfissional to HttpStatusCode.OK
                    else """{"code":"nao_encontrado","message":"nao_encontrado","details":null}""" to HttpStatusCode.NotFound
                path.endsWith("/rpc/situacao_da_conta") -> """{"estado":"ativa"}""" to HttpStatusCode.OK
                path.endsWith("/rpc/meu_perfil_profissional") -> perfilProfissional to HttpStatusCode.OK
                path.endsWith("/rpc/vagas_abertas") -> "[]" to HttpStatusCode.OK
                else -> "{}" to HttpStatusCode.OK
            }
            respond(corpo, status, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val cliente = ClienteSupabase("https://frila.supabase.co", "chave", armazenamentoDeSessao = sessao, engine = engine)
        val servicoAuth = ServicoAutenticacao(cliente)
        val servicoConta = ServicoConta(cliente)
        val servicoPerfil = ServicoPerfil(cliente)
        val servicoMembros = ServicoMembros(cliente)
        val servicoVagas = ServicoVagas(cliente)
        val escopo = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        val avaliador = AvaliadorDeDestino(
            descobrir = {
                avaliarDestinoDaConta(
                    buscarConta = servicoConta::minhaConta,
                    buscarPerfilProfissional = servicoPerfil::obterMeuPerfilProfissional,
                    listarCasas = servicoMembros::listarMeusEstabelecimentos,
                    buscarSituacao = servicoConta::situacaoDaConta,
                )
            },
            guardado = object : DestinoGuardado {
                override fun obter(): DestinoDaConta? = null
                override fun salvar(destino: DestinoDaConta) {}
                override fun limpar() {}
            },
            sessaoGuardada = sessao::estaAutenticado,
        )

        rule.setContent {
            KoinApplication(
                application = {
                    modules(
                        module {
                            single { servicoAuth }
                            single { servicoConta }
                            single { servicoPerfil }
                            single { servicoMembros }
                            single { servicoVagas }
                            viewModel { EntradaComSenhaViewModel(servicoAuth, sessao, escopo = escopo) }
                            viewModel { params -> CriarContaViewModel(servicoAuth, escopo = escopo, emailInicial = params.getOrNull<String>().orEmpty()) }
                            viewModel { params -> RecuperacaoSenhaViewModel(servicoAuth, escopo = escopo, emailInicial = params.getOrNull<String>().orEmpty()) }
                            viewModel { DefinirSenhaViewModel(servicoAuth, sessao, escopo = escopo) }
                            viewModel { params ->
                                CodigoViewModel(
                                    email = params.get(),
                                    servicoAutenticacao = servicoAuth,
                                    armazenamentoDeSessao = sessao,
                                    escopo = escopo,
                                    modo = params.getOrNull<ModoCodigo>() ?: ModoCodigo.ENTRADA,
                                )
                            }
                            viewModel { CadastroViewModel(servicoConta) }
                            viewModel { FeedVagasViewModel(servicoVagas) }
                        },
                    )
                },
            ) {
                nav = rememberNavController()
                AppNavegacao(
                    armazenamentoDeSessao = sessao,
                    monitorDeConectividade = MonitorDeConectividadeFalso(),
                    navController = nav,
                    avaliadorDeDestino = avaliador,
                )
            }
        }
    }

    private fun rotaAtual(): String? = rule.runOnIdle { nav.currentDestination?.route }

    private fun aguardar(tempoMs: Long = 5_000, condicao: () -> Boolean): Boolean =
        try {
            rule.waitUntil(tempoMs) { rule.runOnIdle { }; condicao() }
            true
        } catch (_: ComposeTimeoutException) {
            false
        }

    @Test
    fun loginRotineiroPorSenhaEntraNoDestinoDaContaSemPedirNovoOtp() {
        montarApp(contaExiste = true)

        rule.onNodeWithText("E-mail").performTextInput("conta@exemplo.test")
        rule.onNodeWithText("Senha").performTextInput("SenhaSintetica#2026")
        rule.onNodeWithText("Entrar").performClick()

        assertTrue("esperava FEED, ficou em ${rotaAtual()}", aguardar { rotaAtual() == Rotas.FEED })
        assertFalse("login por senha não deve chamar /auth/v1/otp", chamadas.contains("/auth/v1/otp"))
        assertTrue(chamadas.contains("/functions/v1/autenticar-senha"))
    }

    @Test
    fun criacaoDeContaUsaOtpUmaVezDefineSenhaECaiNoDestinoDaContaCadastro() {
        montarApp(contaExiste = false)

        rule.onNodeWithText("Criar conta").performScrollTo().performClick()
        assertTrue(aguardar { rotaAtual() == Rotas.CRIAR_CONTA })

        rule.onNodeWithText("E-mail").performTextInput("novo@exemplo.test")
        rule.onNodeWithText("Receber código").performClick()
        assertTrue(aguardar { rotaAtual() == Rotas.CODIGO })
        assertTrue(corposOtp.single().contains("\"create_user\":true"))

        rule.onNodeWithContentDescription("Código de 6 dígitos").performTextInput("123456")
        assertTrue("esperava DEFINIR_SENHA, ficou em ${rotaAtual()}", aguardar { rotaAtual() == Rotas.DEFINIR_SENHA })

        rule.onNodeWithText("Nova senha").performTextInput("SenhaNova#2026")
        rule.onNodeWithText("Confirmar senha").performTextInput("SenhaNova#2026")
        rule.onNodeWithText("Salvar senha").performClick()

        assertTrue("esperava CADASTRO via DestinoDaConta, ficou em ${rotaAtual()}", aguardar { rotaAtual() == Rotas.CADASTRO })
        assertTrue(chamadas.contains("/functions/v1/definir-senha"))
    }

    @Test
    fun migracaoLegadaOtpOnlyUsaCreateUserFalseDefineSenhaEPreservaContaExistenteNoFeed() {
        montarApp(contaExiste = true)

        rule.onNodeWithText("Esqueci ou ainda não tenho senha").performScrollTo().performClick()
        assertTrue(aguardar { rotaAtual() == Rotas.RECUPERAR_SENHA })

        rule.onNodeWithText("E-mail").performTextInput("legado@exemplo.test")
        rule.onNodeWithText("Enviar código").performClick()
        assertTrue(aguardar { rotaAtual() == Rotas.CODIGO })
        assertTrue(corposOtp.single().contains("\"create_user\":false"))

        rule.onNodeWithContentDescription("Código de 6 dígitos").performTextInput("123456")
        assertTrue(aguardar { rotaAtual() == Rotas.DEFINIR_SENHA })

        rule.onNodeWithText("Nova senha").performTextInput("SenhaLegada#2026")
        rule.onNodeWithText("Confirmar senha").performTextInput("SenhaLegada#2026")
        rule.onNodeWithText("Salvar senha").performClick()

        assertTrue("esperava FEED preservando a conta, ficou em ${rotaAtual()}", aguardar { rotaAtual() == Rotas.FEED })
        assertEquals(1, corposOtp.size)
        assertTrue(chamadas.contains("/functions/v1/definir-senha"))
    }

    private fun recuperarSenhaDe(email: String) {
        rule.onNodeWithText("Esqueci ou ainda não tenho senha").performScrollTo().performClick()
        assertTrue(aguardar { rotaAtual() == Rotas.RECUPERAR_SENHA })
        rule.onNodeWithText("E-mail").performTextInput(email)
        rule.onNodeWithText("Enviar código").performClick()
    }

    private val textoNeutroDaRecuperacao =
        "Se houver uma conta com este e-mail, enviamos um código de 6 dígitos para legado@exemplo.test."

    @Test
    fun recuperacaoComContaAvancaParaOCodigoComOTextoNeutro() {
        montarApp(contaExiste = true)

        recuperarSenhaDe("legado@exemplo.test")

        assertTrue("esperava CODIGO, ficou em ${rotaAtual()}", aguardar { rotaAtual() == Rotas.CODIGO })
        rule.onNodeWithText(textoNeutroDaRecuperacao).assertIsDisplayed()
        assertEquals(1, corposOtp.size)
        assertTrue(corposOtp.single().contains("\"create_user\":false"))
    }

    @Test
    fun recuperacaoSemContaAvancaParaOMesmoCodigoComOMesmoTextoNeutro() {
        montarApp(contaExiste = false, otpDesativado = true)

        recuperarSenhaDe("legado@exemplo.test")

        assertTrue("esperava CODIGO, ficou em ${rotaAtual()}", aguardar { rotaAtual() == Rotas.CODIGO })
        rule.onNodeWithText(textoNeutroDaRecuperacao).assertIsDisplayed()
        assertEquals(1, corposOtp.size)
        assertTrue(corposOtp.single().contains("\"create_user\":false"))
    }

    private fun entrarNaDemonstracaoComEmailDigitado(emailDigitado: String?) {
        if (emailDigitado != null) rule.onNodeWithText("E-mail").performTextInput(emailDigitado)
        rule.onNodeWithText("Entrar em modo demonstração").performScrollTo().performClick()
        assertTrue("esperava CODIGO, ficou em ${rotaAtual()}", aguardar { rotaAtual() == Rotas.CODIGO })
        rule.onNodeWithContentDescription("Código de 6 dígitos").performTextInput("123456")
        assertTrue("esperava FEED, ficou em ${rotaAtual()}", aguardar { rotaAtual() == Rotas.FEED })
    }

    @Test
    fun demonstracaoDoProfissionalEntraNaContaDoProfissional() {
        montarApp(contaExiste = true)

        entrarNaDemonstracaoComEmailDigitado(null)

        assertEquals(1, corposDemo.size)
        assertTrue(corposDemo.single().contains("\"email\":\"${DemonstracaoContas.EMAIL_PROFISSIONAL}\""))
        assertEquals("tok-demo-${DemonstracaoContas.EMAIL_PROFISSIONAL}", sessao.obterSessao()?.accessToken)
        assertFalse("demo não usa senha", chamadas.contains("/auth/v1/token"))
        assertFalse("demo não pede OTP", chamadas.contains("/auth/v1/otp"))
    }

    @Test
    fun demonstracaoDoContratanteEntraNaContaDoContratanteSemSenha() {
        montarApp(contaExiste = true)

        entrarNaDemonstracaoComEmailDigitado(DemonstracaoContas.EMAIL_CONTRATANTE)

        assertEquals(1, corposDemo.size)
        assertTrue(corposDemo.single().contains("\"email\":\"${DemonstracaoContas.EMAIL_CONTRATANTE}\""))
        assertEquals("tok-demo-${DemonstracaoContas.EMAIL_CONTRATANTE}", sessao.obterSessao()?.accessToken)
        assertFalse("demo não usa senha", chamadas.contains("/auth/v1/token"))
        assertFalse("demo não pede OTP", chamadas.contains("/auth/v1/otp"))
    }

    @Test
    fun demonstracaoDoContratanteTambemEntraPeloBotaoEntrarComOEmailDigitado() {
        montarApp(contaExiste = true)

        rule.onNodeWithText("E-mail").performTextInput(DemonstracaoContas.EMAIL_CONTRATANTE)
        rule.onNodeWithText("Entrar").performClick()
        assertTrue("esperava CODIGO, ficou em ${rotaAtual()}", aguardar { rotaAtual() == Rotas.CODIGO })
        rule.onNodeWithContentDescription("Código de 6 dígitos").performTextInput("123456")
        assertTrue("esperava FEED, ficou em ${rotaAtual()}", aguardar { rotaAtual() == Rotas.FEED })

        assertTrue(corposDemo.single().contains("\"email\":\"${DemonstracaoContas.EMAIL_CONTRATANTE}\""))
        assertFalse(chamadas.contains("/auth/v1/token"))
    }
}
