package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.StateRestorationTester
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.app.seguranca.CoordenadorDeLogout
import br.com.frila.core.designsystem.componentes.TextosConfirmarSaida
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
import br.com.frila.core.rede.SituacaoDaContaDto
import br.com.frila.feature.conta.ContaSuspensaViewModel
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

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // C0-6b: testReleaseUnitTest

    @get:Rule(order = 1)
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

    /** [trava] nula usa o padrão da AppNavegacao (desligada), como o app. */
    private fun montar(trava: Boolean? = true): NavHostController {
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
                        // L2-5: a tela da suspensão lê a situação da conta.
                        viewModel { (aoReativar: () -> Unit) ->
                            ContaSuspensaViewModel(
                                buscarSituacao = { SituacaoDaContaDto(estado = "suspensa") },
                                contestar = { error("o teste não contesta") },
                                aoReativar = aoReativar,
                            )
                        }
                    },
                )
            }) {
                if (trava == null) {
                    AppNavegacao(
                        monitorDeConectividade = MonitorDeConectividadeFalso(StatusConectividade.CONECTADO),
                        navController = navController,
                    )
                } else {
                    AppNavegacao(
                        monitorDeConectividade = MonitorDeConectividadeFalso(StatusConectividade.CONECTADO),
                        navController = navController,
                        biometriaHabilitada = trava,
                    )
                }
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
        rule.onNodeWithTag(TextosConfirmarSaida.TAG_SAIR).performClick()
        rule.waitForIdle()

        assertEquals(Rotas.ENTRADA, navController.currentDestination?.route)
        assertNull(sessao.obterSessao())
        assertTrue("o cliente Ktor da conta suspensa tem de ser fechado", clienteDeA.estaFechado)
    }

    /** C0-11: quem ligou a biometria antes (flag guardada) não é mais travado ao abrir; o iOS não tem esse bloqueio. */
    @Test
    fun `C0-11 - biometria guardada nao pede digital ao abrir o app`() {
        sessao.definirBiometriaAtivada(true)
        val navController = montar(trava = null)

        assertEquals(Rotas.FEED, navController.currentDestination?.route)
        rule.onAllNodesWithText("Entrar com outra conta").assertCountEquals(0)
    }

    /**
     * C0-11, achado P2 do Lince no #854: o Android restaura a pilha salva (morte do processo, rotação). Quem estava
     * no desbloqueio no app antigo (trava ligada) não pode voltar a ele no app atualizado (trava desligada): a tela
     * pediria a digital sozinha. O esperado é o destino normal da conta, o feed.
     */
    @Test
    fun `C0-11 - pilha restaurada no desbloqueio com a trava desligada segue para o feed`() {
        sessao.definirBiometriaAtivada(true)
        val feedViewModel = mockk<FeedVagasViewModel>(relaxed = true)
        every { feedViewModel.estado } returns MutableStateFlow(EstadoFeed(status = StatusFeed.SUCESSO))
        var trava = true
        lateinit var navController: NavHostController
        val restaurador = StateRestorationTester(rule)
        restaurador.setContent {
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
                    biometriaHabilitada = trava,
                )
            }
        }
        rule.waitForIdle()
        assertEquals("o app antigo abre no desbloqueio", Rotas.DESBLOQUEIO, navController.currentDestination?.route)

        trava = false // o app atualizado, com a pilha antiga salva
        restaurador.emulateSavedInstanceStateRestore()
        rule.waitForIdle()

        assertEquals(Rotas.FEED, navController.currentDestination?.route)
        rule.onAllNodesWithText("Entrar com outra conta").assertCountEquals(0)
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
