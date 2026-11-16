package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.app.seguranca.CoordenadorDeLogout
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.GestorClienteKtor
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.rede.StatusConectividade
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.vagas.feed.EstadoFeed
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.vagas.feed.StatusFeed
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpStatusCode
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * #789 (risco alto: sessão). As saídas que a própria navegação faz ("Sair" da conta suspensa,
 * "Entrar com outra conta" no desbloqueio e, com o #785, o 401 da abertura) usam o armazenamento que
 * o [AppNavegacao] recebe do Koin. Sem parâmetro explícito, como na `MainActivity`, ele tem de ser o
 * [CoordenadorDeLogout]: só ele fecha o cliente Ktor da conta que saiu.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class SaidaDaContaNaNavegacaoTest {

    @get:Rule
    val rule = createComposeRule()

    private val sessao = ArmazenamentoDeSessaoEmMemoria().apply {
        salvarSessao(Sessao("access-A", "refresh-A", "bearer", 3_600L, null))
    }
    private val gestor = GestorClienteKtor {
        ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-anonima-de-teste",
            armazenamentoDeSessao = sessao,
            engine = MockEngine { respond("{}", HttpStatusCode.OK) },
        )
    }
    private val clienteDeA = gestor.clienteAtual

    @After
    fun depois() {
        gestor.close()
    }

    private fun montar(): NavHostController {
        lateinit var navController: NavHostController
        val feedViewModel = mockk<FeedVagasViewModel>(relaxed = true)
        every { feedViewModel.estado } returns MutableStateFlow(EstadoFeed(status = StatusFeed.SUCESSO))
        rule.setContent {
            navController = rememberNavController()
            KoinApplication(application = {
                modules(
                    module {
                        single { mockk<ServicoAutenticacao>(relaxed = true) }
                        single<ArmazenamentoDeSessao> { sessao }
                        single { CoordenadorDeLogout(armazenamentoDeSessao = get(), gestorClienteKtor = gestor) }
                        viewModel { EntradaViewModel(get()) }
                        viewModel { feedViewModel }
                    },
                )
            }) {
                AppNavegacao(
                    monitorDeConectividade = MonitorDeConectividadeFalso(StatusConectividade.CONECTADO),
                    navController = navController,
                )
            }
        }
        rule.waitForIdle()
        return navController
    }

    @Test
    fun `sair da conta suspensa fecha o cliente da conta que saiu`() {
        val navController = montar()
        rule.runOnUiThread { navController.navigate(Rotas.contaSuspensa()) }
        rule.waitForIdle()

        rule.onNodeWithText("Sair da conta").performScrollTo().performClick()
        rule.waitForIdle()

        assertEquals(Rotas.ENTRADA, navController.currentDestination?.route)
        assertNull(sessao.obterSessao())
        assertTrue("o cliente Ktor da conta suspensa tem de ser fechado", clienteDeA.estaFechado)
    }

    @Test
    fun `entrar com outra conta no desbloqueio fecha o cliente da conta anterior`() {
        sessao.definirBiometriaAtivada(true)
        val navController = montar()
        assertEquals(Rotas.DESBLOQUEIO, navController.currentDestination?.route)

        rule.onNodeWithText("Entrar com outra conta").performClick()
        rule.waitForIdle()

        assertEquals(Rotas.ENTRADA, navController.currentDestination?.route)
        assertNull(sessao.obterSessao())
        assertTrue("o cliente Ktor da conta anterior tem de ser fechado", clienteDeA.estaFechado)
    }
}
