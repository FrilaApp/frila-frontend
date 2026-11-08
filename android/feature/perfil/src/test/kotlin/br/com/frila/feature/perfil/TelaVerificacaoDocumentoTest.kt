package br.com.frila.feature.perfil

import android.content.Context
import android.net.Uri
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertIsOff
import androidx.compose.ui.test.assertIsOn
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import br.com.frila.core.designsystem.componentes.AuditoriaSemanticaAcessibilidade
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.TipoParteEvidencia
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.RepositorioVerificacaoIdentidade
import br.com.frila.core.rede.ServicoVerificacaoIdentidade
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.mockk
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@OptIn(ExperimentalTestApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h891dp")
class TelaVerificacaoDocumentoTest {

    @get:Rule
    val rule = createComposeRule()

    private val contexto = mockk<Context>(relaxed = true)
    private val uri = mockk<Uri>(relaxed = true)

    private fun statusJson(valor: String, motivo: String? = null) =
        """{"status_verificacao":"$valor","motivo":${motivo?.let { "\"$it\"" } ?: "null"},""" +
            """"prazo_envio_ate":null,"identidade_verificada":${valor == "aprovada"}}"""

    private val chamadas = java.util.Collections.synchronizedList(mutableListOf<String>())

    private fun criarViewModel(statusHttp: HttpStatusCode = HttpStatusCode.OK, corpo: String): VerificacaoIdentidadeViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine { request ->
                chamadas += "${request.method.value} ${request.url.encodedPath}"
                respond(corpo, statusHttp, headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )
        return VerificacaoIdentidadeViewModel(
            repositorio = RepositorioVerificacaoIdentidade(ServicoVerificacaoIdentidade(cliente)),
            escopo = CoroutineScope(Dispatchers.Default),
            lerBytes = { _, _ -> byteArrayOf(1, 2, 3) },
        )
    }

    private fun mostrar(vm: VerificacaoIdentidadeViewModel) {
        rule.setContent { FrilaTheme { TelaVerificacaoDocumento(viewModel = vm, aoVoltar = {}) } }
    }

    private fun esperarTag(tag: String) = rule.waitUntilExactlyOneExists(androidx.compose.ui.test.hasTestTag(tag), 5_000)

    @Test
    fun `sem consentimento mostra o termo antes do formulario e nao toca na rede alem de ler o estado`() {
        val vm = criarViewModel(corpo = statusJson("nao_exigida"))
        mostrar(vm)

        esperarTag("consentimento-confirmar")

        rule.onNodeWithTag("consentimento-checkbox").assertIsOff()
        rule.onNodeWithTag("consentimento-confirmar").assertIsNotEnabled()
        rule.onNodeWithTag("verificacao-enviar").assertDoesNotExistCompat()
        assertEquals(listOf("GET /rest/v1/rpc/minha_identidade_status"), chamadas.toList())
    }

    @Test
    fun `marcar o checkbox habilita o botao e confirmar leva ao formulario`() {
        val vm = criarViewModel(corpo = statusJson("nao_exigida"))
        mostrar(vm)
        esperarTag("consentimento-confirmar")

        rule.onNodeWithTag("consentimento-checkbox").performClick()
        rule.onNodeWithTag("consentimento-checkbox").assertIsOn()
        rule.onNodeWithTag("consentimento-confirmar").assertIsEnabled().performClick()

        esperarTag("verificacao-enviar")
        rule.onNodeWithTag("verificacao-enviar").assertIsNotEnabled()
        assertEquals(TermoBiometria.VERSAO, vm.estado.value.consentimento?.versaoTermo)
    }

    @Test
    fun `botao de enviar so habilita com as tres partes escolhidas`() {
        val vm = criarViewModel(corpo = statusJson("nao_exigida"))
        vm.confirmarConsentimento()
        mostrar(vm)
        esperarTag("verificacao-enviar")

        runBlocking {
            vm.escolherParte(contexto, TipoParteEvidencia.FRENTE, uri).join()
            vm.escolherParte(contexto, TipoParteEvidencia.VERSO, uri).join()
        }
        rule.waitForIdle()
        rule.onNodeWithTag("verificacao-enviar").assertIsNotEnabled()

        runBlocking { vm.escolherParte(contexto, TipoParteEvidencia.SELFIE, uri).join() }
        rule.waitUntil(5_000) { vm.estado.value.todasAsPartesEscolhidas }
        rule.waitForIdle()
        rule.onNodeWithTag("verificacao-enviar").assertIsEnabled()
    }

    @Test
    fun `aprovada mostra o resultado e esconde o formulario`() {
        val vm = criarViewModel(corpo = statusJson("aprovada"))
        mostrar(vm)

        esperarTag("verificacao-situacao")

        rule.onNodeWithText(TextosVerificacaoDocumento.APROVADA, substring = true).assertIsDisplayed()
        rule.onNodeWithTag("verificacao-enviar").assertDoesNotExistCompat()
    }

    @Test
    fun `em analise mostra espera e esconde o formulario`() {
        val vm = criarViewModel(corpo = statusJson("em_analise"))
        mostrar(vm)

        esperarTag("verificacao-situacao")

        rule.onNodeWithText(TextosVerificacaoDocumento.EM_ANALISE, substring = true).assertIsDisplayed()
        rule.onNodeWithTag("verificacao-enviar").assertDoesNotExistCompat()
    }

    @Test
    fun `rejeitada mostra o motivo e permite enviar de novo depois do consentimento`() {
        val vm = criarViewModel(corpo = statusJson("rejeitada", "Foto ilegível"))
        vm.confirmarConsentimento()
        mostrar(vm)

        esperarTag("verificacao-situacao")

        rule.onNodeWithText("Motivo: Foto ilegível", substring = true).assertIsDisplayed()
        rule.onNodeWithTag("verificacao-enviar").performScrollTo().assertIsDisplayed()
        AuditoriaSemanticaAcessibilidade.assertSemanticaValida(rule.onRoot().fetchSemanticsNode())
    }

    @Test
    fun `botoes de foto dizem a parte para o leitor de tela e mudam para trocar depois de escolher`() {
        val vm = criarViewModel(corpo = statusJson("nao_exigida"))
        vm.confirmarConsentimento()
        mostrar(vm)
        esperarTag("verificacao-enviar")

        TipoParteEvidencia.entries.forEach { parte ->
            rule.onNodeWithContentDescription(
                "Escolher foto: ${TextosVerificacaoDocumento.rotuloParte(parte)}",
            ).performScrollTo().assertIsDisplayed()
        }

        runBlocking { vm.escolherParte(contexto, TipoParteEvidencia.SELFIE, uri).join() }
        rule.waitUntil(5_000) { TipoParteEvidencia.SELFIE in vm.estado.value.partesEscolhidas }
        rule.waitForIdle()

        rule.onNodeWithContentDescription("Trocar foto: Selfie").performScrollTo().assertIsDisplayed()
        rule.onNodeWithContentDescription("Escolher foto: Frente do documento").assertIsDisplayed()
        AuditoriaSemanticaAcessibilidade.assertSemanticaValida(rule.onRoot().fetchSemanticsNode())
    }

    @Test
    fun `FLAG_SECURE fica ligada enquanto a tela de verificacao esta visivel e sai com ela`() {
        val vm = criarViewModel(corpo = statusJson("nao_exigida"))
        var janela: android.view.Window? = null
        var visivel by androidx.compose.runtime.mutableStateOf(true)
        rule.setContent {
            janela = LocalContext.current.encontrarActivity()?.window
            if (visivel) FrilaTheme { TelaVerificacaoDocumento(viewModel = vm, aoVoltar = {}) }
        }
        rule.waitForIdle()

        assertNotNull(janela)
        assertTrue(
            "FLAG_SECURE deveria estar ligada com a tela visível",
            janela!!.attributes.flags and android.view.WindowManager.LayoutParams.FLAG_SECURE != 0,
        )

        visivel = false
        rule.waitForIdle()

        assertTrue(
            "FLAG_SECURE deveria sair junto com a tela",
            janela!!.attributes.flags and android.view.WindowManager.LayoutParams.FLAG_SECURE == 0,
        )
    }

    @Test
    fun `janela que ja era segura continua segura depois que a tela sai`() {
        val vm = criarViewModel(corpo = statusJson("nao_exigida"))
        var janela: android.view.Window? = null
        var visivel by androidx.compose.runtime.mutableStateOf(true)
        rule.setContent {
            janela = LocalContext.current.encontrarActivity()?.window
            // Uma vez só (remember): a janela já nasce segura por outro motivo, antes da tela do selo.
            androidx.compose.runtime.remember {
                janela?.addFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
                0
            }
            if (visivel) FrilaTheme { TelaVerificacaoDocumento(viewModel = vm, aoVoltar = {}) }
        }
        rule.waitForIdle()

        visivel = false
        rule.waitForIdle()

        assertTrue(janela!!.attributes.flags and android.view.WindowManager.LayoutParams.FLAG_SECURE != 0)
    }

    @Test
    fun `erro ao carregar oferece tentar de novo`() {
        val vm = criarViewModel(
            statusHttp = HttpStatusCode.Unauthorized,
            corpo = """{"code":"nao_autenticado","message":"x"}""",
        )
        mostrar(vm)

        esperarTag("verificacao-tentar-novamente")

        rule.onNodeWithText("Sua sessão expirou. Entre de novo.").assertIsDisplayed()
    }

    @Test
    fun `tela de consentimento tem alvos de toque minimos e semantica valida`() {
        rule.setContent {
            FrilaTheme { TelaConsentimentoSelo(aoConfirmar = {}, aoVoltar = {}) }
        }

        rule.onNodeWithTag("consentimento-checkbox").assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
        rule.onNodeWithTag("consentimento-voltar").assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
        rule.onNodeWithTag("consentimento-confirmar").assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
        AuditoriaSemanticaAcessibilidade.assertSemanticaValida(rule.onRoot().fetchSemanticsNode())
    }

    @Test
    fun `confirmar so dispara o callback com a caixa marcada`() {
        var confirmacoes = 0
        rule.setContent {
            FrilaTheme { TelaConsentimentoSelo(aoConfirmar = { confirmacoes++ }, aoVoltar = {}) }
        }

        rule.onNodeWithTag("consentimento-confirmar").performClick()
        assertEquals(0, confirmacoes)

        rule.onNodeWithTag("consentimento-checkbox").performClick()
        rule.onNodeWithTag("consentimento-confirmar").performClick()
        assertEquals(1, confirmacoes)
    }

    private fun androidx.compose.ui.test.SemanticsNodeInteraction.assertDoesNotExistCompat() {
        assertTrue(!this.isPresent())
    }

    private fun androidx.compose.ui.test.SemanticsNodeInteraction.isPresent(): Boolean =
        try {
            fetchSemanticsNode()
            true
        } catch (_: AssertionError) {
            false
        }
}
