package br.com.frila.app

import android.app.Application
import android.content.ActivityNotFoundException
import android.content.ContextWrapper
import android.content.Intent
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.perfil.EnderecosOficiais
import br.com.frila.feature.perfil.EstadoPerfil
import br.com.frila.feature.perfil.TextosAjudaPerfil
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.VerificacaoIdentidadeViewModel
import br.com.frila.feature.perfil.EstadoVerificacaoIdentidade
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.robolectric.Shadows.shadowOf
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AppNavegacaoAjudaIntegracaoTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // C0-6b: testReleaseUnitTest

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private lateinit var nav: NavHostController

    private fun montar(semEmail: Boolean = false, semNavegador: Boolean = false) {
        val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
            every { estaAutenticado() } returns false
            every { isBiometriaAtivada() } returns false
        }
        val entrada = mockk<EntradaViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoEntrada())
        }
        val perfil = mockk<PerfilViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoPerfil())
        }
        val selo = mockk<VerificacaoIdentidadeViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoVerificacaoIdentidade())
        }

        rule.setContent {
            val origem = LocalContext.current
            val contexto = object : ContextWrapper(origem) {
                override fun startActivity(intent: Intent) {
                    if (semEmail && intent.action == Intent.ACTION_SENDTO) {
                        throw ActivityNotFoundException("Sonda: aparelho sem cliente de e-mail")
                    }
                    if (semNavegador && intent.action == Intent.ACTION_VIEW) {
                        throw ActivityNotFoundException("Sonda: aparelho sem navegador")
                    }
                    super.startActivity(intent)
                }
            }
            KoinApplication(application = {
                modules(
                    module {
                        viewModel { entrada }
                        viewModel { perfil }
                        viewModel { selo }
                    },
                )
            }) {
                CompositionLocalProvider(LocalContext provides contexto) {
                    nav = rememberNavController()
                    AppNavegacao(
                        armazenamentoDeSessao = sessao,
                        monitorDeConectividade = MonitorDeConectividadeFalso(),
                        navController = nav,
                    )
                }
            }
        }
        rule.runOnIdle { nav.navigate(Rotas.PERFIL) }
        rule.onNodeWithTag("botao-ajuda-barra").performClick()
    }

    @Test
    fun perfilAbreAjudaLicencasEVolta() {
        montar()
        rule.onNodeWithText("Licenças de código aberto").performScrollTo().performClick()
        rule.runOnIdle { assertEquals(Rotas.LICENCAS, nav.currentDestination?.route) }
        rule.onNodeWithContentDescription("Voltar").performClick()
        rule.runOnIdle { assertEquals(Rotas.AJUDA, nav.currentDestination?.route) }
        rule.onNodeWithContentDescription("Voltar").performClick()
        rule.runOnIdle { assertEquals(Rotas.PERFIL, nav.currentDestination?.route) }
    }

    @Test
    fun suporteSemAplicativoDeEmailNaoDeveDerrubarAjuda() {
        montar(semEmail = true)
        rule.onNodeWithText("Fale com o suporte").performClick()
        rule.runOnIdle { assertEquals(Rotas.AJUDA, nav.currentDestination?.route) }
    }

    @Test
    fun suporteSemAplicativoDeEmailAvisaComOEnderecoParaCopiar() {
        montar(semEmail = true)
        rule.onNodeWithText("Fale com o suporte").performClick()

        rule.onNodeWithText(AvisoDeAberturaExterna.semEmail("suporte@frilabr.com").mensagem).assertExists()
        rule.onNodeWithTag("aviso-abertura-externa-endereco").assertTextEquals("suporte@frilabr.com")
    }

    @Test
    fun termosEPrivacidadeSemNavegadorAvisamComOEndereco() {
        montar(semNavegador = true)
        rule.onNodeWithText(TextosAjudaPerfil.TERMOS_DE_USO).performScrollTo().performClick()
        rule.onNodeWithTag("aviso-abertura-externa-endereco").assertTextEquals(EnderecosOficiais.padrao.termosDeUso)
        rule.onNodeWithText(TextosAberturaExterna.FECHAR).performClick()
        rule.onAllNodesWithTag("aviso-abertura-externa").assertCountEquals(0)

        rule.onNodeWithText(TextosAjudaPerfil.POLITICA_PRIVACIDADE).performScrollTo().performClick()
        rule.onNodeWithTag("aviso-abertura-externa-endereco").assertTextEquals(EnderecosOficiais.padrao.politicaDePrivacidade)
    }

    @Test
    fun termosComNavegadorNaoMostramAviso() {
        montar()
        rule.onNodeWithText(TextosAjudaPerfil.TERMOS_DE_USO).performScrollTo().performClick()
        rule.onAllNodesWithTag("aviso-abertura-externa").assertCountEquals(0)
    }

    // Cartão MXpMy3sw (item 258): os testes acima só conferem o caminho "sem aplicativo". Aqui, o pedido que de fato chega ao sistema: a ação, o
    // endereço e a flag. Sem isto, tirar o `mailto:` ou trocar o endereço da privacidade passava em silêncio.
    private val aplicativo get() = ApplicationProvider.getApplicationContext<Application>()

    private fun esvaziarPedidos() {
        while (shadowOf(aplicativo).nextStartedActivity != null) { /* só o que o toque pedir */ }
    }

    private fun pedidoAoSistema(): Intent {
        rule.waitForIdle()
        return requireNotNull(shadowOf(aplicativo).nextStartedActivity) { "o toque não pediu nada ao sistema" }
    }

    @Test
    fun suporteAbreOEmailDeVerdadeComMailtoEOEnderecoOficial() {
        montar()
        esvaziarPedidos()

        rule.onNodeWithText("Fale com o suporte").performClick()

        val pedido = pedidoAoSistema()
        assertEquals(Intent.ACTION_SENDTO, pedido.action)
        assertEquals("mailto:" + EnderecosOficiais.padrao.emailSuporte, pedido.dataString)
        assertEquals("mailto", pedido.data?.scheme)
        assertEquals(EnderecosOficiais.padrao.emailSuporte, pedido.data?.schemeSpecificPart)
        assertEquals(Intent.FLAG_ACTIVITY_NEW_TASK, pedido.flags and Intent.FLAG_ACTIVITY_NEW_TASK)
        assertNull("um toque, um pedido", shadowOf(aplicativo).nextStartedActivity)
    }

    @Test
    fun oEnderecoDeEmailDaAjudaAbreOMesmoPedido() {
        montar()
        esvaziarPedidos()

        rule.onNodeWithText(EnderecosOficiais.padrao.emailSuporte).performClick()

        val pedido = pedidoAoSistema()
        assertEquals(Intent.ACTION_SENDTO, pedido.action)
        assertEquals("mailto:" + EnderecosOficiais.padrao.emailSuporte, pedido.dataString)
    }

    @Test
    fun termosAbremNoNavegadorComOEnderecoDosTermos() {
        montar()
        esvaziarPedidos()

        rule.onNodeWithText(TextosAjudaPerfil.TERMOS_DE_USO).performScrollTo().performClick()

        val pedido = pedidoAoSistema()
        assertEquals(Intent.ACTION_VIEW, pedido.action)
        assertEquals(EnderecosOficiais.padrao.termosDeUso, pedido.dataString)
        assertEquals(Intent.FLAG_ACTIVITY_NEW_TASK, pedido.flags and Intent.FLAG_ACTIVITY_NEW_TASK)
        assertNull("um toque, um pedido", shadowOf(aplicativo).nextStartedActivity)
    }

    @Test
    fun privacidadeAbreNoNavegadorComOEnderecoDaPolitica() {
        montar()
        esvaziarPedidos()

        rule.onNodeWithText(TextosAjudaPerfil.POLITICA_PRIVACIDADE).performScrollTo().performClick()

        val pedido = pedidoAoSistema()
        assertEquals(Intent.ACTION_VIEW, pedido.action)
        assertEquals(EnderecosOficiais.padrao.politicaDePrivacidade, pedido.dataString)
        assertNotEquals("não pode abrir os termos no lugar da política", EnderecosOficiais.padrao.termosDeUso, pedido.dataString)
        assertEquals(Intent.FLAG_ACTIVITY_NEW_TASK, pedido.flags and Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    @Test
    fun licencasNaoPedemNadaAoSistema() {
        montar()
        esvaziarPedidos()

        rule.onNodeWithText(TextosAjudaPerfil.LICENCAS_TERCEIROS).performScrollTo().performClick()
        rule.waitForIdle()

        assertNull("as licenças abrem dentro do app", shadowOf(aplicativo).nextStartedActivity)
    }
}
