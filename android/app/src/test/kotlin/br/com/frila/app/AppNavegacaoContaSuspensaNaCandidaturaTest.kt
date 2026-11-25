package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.SituacaoDaContaDto
import br.com.frila.core.rede.SuspensaoDaContaDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.conta.ContaSuspensaViewModel
import br.com.frila.feature.conta.TextosContaSuspensa
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
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
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
 * Cartão Jh3jhl21: da tela de detalhe da vaga, a candidatura recusada com `403` de conta suspensa leva à tela de conta suspensa.
 *
 * O teste parte da rota do detalhe e deixa o resto real: o [ServicoVagas] fala com um motor HTTP falso que responde `403`, o erro
 * vira `ErroDaApi`, o [DetalheVagaViewModel] marca a conta suspensa e a [AppNavegacao] decide a rota. Só a rede é falsa. Cobre
 * os dois pontos de [AppNavegacao] que ligam `aoNavegarParaContaSuspensa`: o detalhe vindo do feed e o detalhe aberto pelo id.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class, qualifiers = "w411dp-h2400dp")
class AppNavegacaoContaSuspensaNaCandidaturaTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // C0-6b: testReleaseUnitTest

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private lateinit var nav: NavHostController
    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } returns false
    }

    /** Pedidos que o motor falso recebeu, para provar que a candidatura chegou à rede antes da navegação. */
    private val pedidos = mutableListOf<String>()

    /** Corpo do erro como o contrato declara (`403 sem_permissao` com `details: conta_suspensa`), ou o código direto. */
    private fun clienteQueRecusaCom(corpo: String) = ClienteSupabase(
        baseUrl = "https://frila.supabase.co",
        apiKey = "chave-teste",
        engine = MockEngine { request ->
            pedidos += request.url.encodedPath
            respond(
                content = corpo,
                status = HttpStatusCode.Forbidden,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        },
    )

    private fun montar(inicio: String, corpoDoErro: String, aPartirDoFeed: Boolean = false) {
        val entrada = mockk<EntradaViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoEntrada()) }
        val perfil = mockk<PerfilViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoPerfil(status = StatusPerfil.SUCESSO))
        }
        val feed = mockk<FeedVagasViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoFeed(status = StatusFeed.SUCESSO))
            every { encontrarVagaPorId(VAGA_ID) } returns vagaDaLista(VAGA_ID)
        }
        val servico = ServicoVagas(clienteQueRecusaCom(corpoDoErro))
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
                        viewModel { params ->
                            DetalheVagaViewModel(
                                params.get(),
                                servico,
                                detalhe = params.getOrNull(),
                                escopo = escopo,
                            )
                        }
                        viewModel { (aoReativar: () -> Unit) ->
                            ContaSuspensaViewModel(
                                buscarSituacao = { SITUACAO_SUSPENSA },
                                contestar = { error("o teste não contesta") },
                                aoReativar = aoReativar,
                                escopo = escopo,
                            )
                        }
                    },
                )
            }) {
                nav = rememberNavController()
                AppNavegacao(
                    armazenamentoDeSessao = sessao,
                    monitorDeConectividade = MonitorDeConectividadeFalso(),
                    navController = nav,
                )
            }
        }
        if (aPartirDoFeed) {
            rule.runOnIdle { nav.navigate(Rotas.FEED) }
        }
        rule.runOnIdle { nav.navigate(inicio) }
    }

    private fun candidatar() {
        rule.waitUntil(5_000) { rule.onAllNodesWithText(BOTAO_CANDIDATAR).fetchSemanticsNodes().isNotEmpty() }
        rule.onNodeWithText(BOTAO_CANDIDATAR).performClick()
    }

    /**
     * Chegou na conta suspensa uma vez só: entre o detalhe e o topo da pilha há exatamente uma rota, a conta suspensa. Conferir a
     * pilha, e não só a rota final, importa por dois motivos. Uma navegação errada (para o feed, por exemplo) recompõe o detalhe,
     * que dispara a outra ligação da `AppNavegacao` e chega na conta suspensa pelo caminho errado, com a rota final igual. E a
     * mesma candidatura recusada não pode empilhar a conta suspensa duas vezes (o voltar a mostraria de novo).
     */
    private fun esperarContaSuspensa() {
        rule.waitUntil(5_000) { nav.currentDestination?.route == Rotas.CONTA_SUSPENSA }
        rule.waitForIdle()
        rule.runOnIdle {
            val rotas = nav.currentBackStack.value.mapNotNull { it.destination.route }
            val acima = rotas.dropWhile { it != Rotas.DETALHE }.drop(1)
            assertTrue("o detalhe tem de estar na pilha: $rotas", Rotas.DETALHE in rotas)
            assertEquals("só uma conta suspensa acima do detalhe: $rotas", listOf(Rotas.CONTA_SUSPENSA), acima)
        }
    }

    @Test
    fun `candidatar a partir do feed com 403 sem_permissao e detalhes conta_suspensa abre a conta suspensa`() {
        montar(Rotas.detalhe(VAGA_ID), ERRO_SEM_PERMISSAO_CONTA_SUSPENSA, aPartirDoFeed = true)
        rule.runOnIdle { assertEquals(Rotas.DETALHE, nav.currentDestination?.route) }

        candidatar()
        esperarContaSuspensa()

        rule.runOnIdle {
            assertEquals(Rotas.CONTA_SUSPENSA, nav.currentDestination?.route)
            assertTrue("a candidatura tem de ter chegado à rede", pedidos.any { it.endsWith("/rpc/candidatar") })
        }
        rule.onNodeWithText(TextosContaSuspensa.TITULO).assertExists()
    }

    @Test
    fun `candidatar numa vaga aberta pelo id com 403 sem_permissao e detalhes conta_suspensa abre a conta suspensa`() {
        montar(Rotas.detalhe(VAGA_ID), ERRO_SEM_PERMISSAO_CONTA_SUSPENSA)

        candidatar()
        esperarContaSuspensa()

        rule.runOnIdle {
            assertEquals(Rotas.CONTA_SUSPENSA, nav.currentDestination?.route)
            assertTrue("a candidatura tem de ter chegado à rede", pedidos.any { it.endsWith("/rpc/candidatar") })
        }
        rule.onNodeWithText(TextosContaSuspensa.TITULO).assertExists()
    }

    @Test
    fun `candidatar numa vaga aberta pelo id com 403 de codigo conta_suspensa abre a conta suspensa`() {
        montar(Rotas.detalhe(VAGA_ID), ERRO_CODIGO_CONTA_SUSPENSA)

        candidatar()
        esperarContaSuspensa()

        rule.runOnIdle { assertEquals(Rotas.CONTA_SUSPENSA, nav.currentDestination?.route) }
    }

    @Test
    fun `voltar da conta suspensa leva ao detalhe e nao a empilha de novo`() {
        montar(Rotas.detalhe(VAGA_ID), ERRO_SEM_PERMISSAO_CONTA_SUSPENSA)
        candidatar()
        esperarContaSuspensa()

        rule.runOnIdle { nav.popBackStack() }
        rule.waitForIdle()

        rule.runOnIdle {
            val rotas = nav.currentBackStack.value.mapNotNull { it.destination.route }
            assertEquals("o voltar para no detalhe: $rotas", Rotas.DETALHE, nav.currentDestination?.route)
            assertTrue("a conta suspensa não volta à pilha: $rotas", Rotas.CONTA_SUSPENSA !in rotas)
        }
    }

    private companion object {
        const val VAGA_ID = "vaga-9"
        const val BOTAO_CANDIDATAR = "Candidatar-se"
        const val ERRO_SEM_PERMISSAO_CONTA_SUSPENSA =
            """{"code":"sem_permissao","message":"sem_permissao","details":"conta_suspensa","hint":null}"""
        const val ERRO_CODIGO_CONTA_SUSPENSA =
            """{"code":"conta_suspensa","message":"conta_suspensa","details":null,"hint":null}"""
        val SITUACAO_SUSPENSA = SituacaoDaContaDto(
            estado = "suspensa",
            suspensao = SuspensaoDaContaDto(motivo = "Assédio confirmado", desde = "2026-11-09T15:00:00Z"),
        )
    }
}
