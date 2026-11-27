package br.com.frila.app

import android.app.Application
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.chamadas.casa.PerfilPublicoViewModel
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.perfil.EstadoPerfil
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.StatusPerfil
import br.com.frila.feature.vagas.detalhe.AberturaDeVagaViewModel
import br.com.frila.feature.vagas.detalhe.DetalheVagaViewModel
import br.com.frila.feature.vagas.feed.EstadoFeed
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.vagas.feed.StatusFeed
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão 3k9E6ojp: no detalhe da vaga, tocar no nome da casa abre o perfil público dela, uma vez só, nos dois pontos da
 * [AppNavegacao] que montam o detalhe (vindo do feed e aberto pelo id). Voltar do perfil devolve ao detalhe, e o nome volta a abrir.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class, qualifiers = "w411dp-h2400dp")
class AppNavegacaoPerfilDaCasaTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste()

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private lateinit var nav: NavHostController
    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } returns false
    }
    private val perfisPedidos = mutableListOf<String>()

    private fun montar(aPartirDoFeed: Boolean) {
        val entrada = mockk<EntradaViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoEntrada()) }
        val perfil = mockk<PerfilViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoPerfil(status = StatusPerfil.SUCESSO))
        }
        val feed = mockk<FeedVagasViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoFeed(status = StatusFeed.SUCESSO))
            every { encontrarVagaPorId(VAGA_ID) } returns vagaDaLista(VAGA_ID)
        }
        val servico = ServicoVagas(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = MockEngine { respond("{}") }))
        val escopo = CoroutineScope(Dispatchers.Unconfined)
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        single<ArmazenamentoDeSessao> { sessao }
                        viewModel { entrada }
                        viewModel { perfil }
                        viewModel { feed }
                        viewModel { (vagaId: String) ->
                            AberturaDeVagaViewModel(vagaId, buscarDetalhe = { vagaDoServidor(vagaId) }, escopo = escopo)
                        }
                        viewModel { params -> DetalheVagaViewModel(params.get(), servico, detalhe = params.getOrNull(), escopo = escopo) }
                        viewModel { (id: String) ->
                            PerfilPublicoViewModel(id = id, buscar = { perfisPedidos += it; casaDeTeste(it) }, escopo = escopo)
                        }
                    },
                )
            }) {
                nav = rememberNavController()
                AppNavegacao(armazenamentoDeSessao = sessao, monitorDeConectividade = MonitorDeConectividadeFalso(), navController = nav)
            }
        }
        if (aPartirDoFeed) rule.runOnIdle { nav.navigate(Rotas.FEED) }
        rule.runOnIdle { nav.navigate(Rotas.detalhe(VAGA_ID)) }
        rule.waitUntil(5_000) { rule.onAllNodesWithTag(TAG).fetchSemanticsNodes().isNotEmpty() }
    }

    private fun rotasAcimaDoDetalhe(): List<String> =
        nav.currentBackStack.value.mapNotNull { it.destination.route }.dropWhile { it != Rotas.DETALHE }.drop(1)

    private fun verificarAbreUmaVezEVolta() {
        // Dois toques no mesmo quadro, antes de a navegação tirar o detalhe da tela: um perfil só na pilha.
        val tocar = rule.onNodeWithTag(TAG).fetchSemanticsNode().config[SemanticsActions.OnClick].action!!
        rule.runOnIdle {
            tocar()
            tocar()
        }
        rule.waitForIdle()
        rule.runOnIdle {
            assertEquals(listOf(Rotas.PERFIL_DA_CASA), rotasAcimaDoDetalhe())
            assertEquals("e1", nav.currentBackStackEntry?.arguments?.getString("estabelecimentoId"))
        }
        rule.waitUntil(5_000) { perfisPedidos.isNotEmpty() }
        assertEquals(listOf("e1"), perfisPedidos)

        // Voltou do perfil: o detalhe está ativo de novo, e o nome volta a abrir.
        rule.runOnIdle { nav.popBackStack() }
        rule.waitForIdle()
        rule.runOnIdle { assertEquals(Rotas.DETALHE, nav.currentDestination?.route) }
        rule.onNodeWithTag(TAG).performClick()
        rule.waitForIdle()
        rule.runOnIdle { assertEquals(listOf(Rotas.PERFIL_DA_CASA), rotasAcimaDoDetalhe()) }
    }

    @Test
    fun `detalhe vindo do feed abre o perfil da casa uma vez e volta`() {
        montar(aPartirDoFeed = true)
        verificarAbreUmaVezEVolta()
    }

    @Test
    fun `detalhe aberto pelo id abre o perfil da casa uma vez e volta`() {
        montar(aPartirDoFeed = false)
        verificarAbreUmaVezEVolta()
    }

    private companion object {
        const val VAGA_ID = "vaga-9"
        const val TAG = "abrir-perfil-estabelecimento"
    }
}
