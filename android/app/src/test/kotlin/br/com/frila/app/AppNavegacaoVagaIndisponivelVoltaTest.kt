package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.vagas.candidaturas.MinhasCandidaturasViewModel
import br.com.frila.feature.vagas.detalhe.AberturaDeVagaViewModel
import br.com.frila.feature.vagas.detalhe.TextosVagaIndisponivel
import br.com.frila.feature.vagas.feed.EstadoFeed
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.vagas.feed.StatusFeed
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
 * Cartão kNHS9OQ6 (item 274): a vaga aberta pela aba Candidaturas e já indisponível oferece "Ver minhas candidaturas" e volta para a
 * aba, como o iOS (`FluxoDoProfissional.swift:248-256`). Aberta de outro lugar (link, aviso), segue para as vagas perto.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AppNavegacaoVagaIndisponivelVoltaTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // C0-6b: testReleaseUnitTest

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private lateinit var nav: NavHostController
    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } returns false
    }

    private fun montar(daAbaCandidaturas: Boolean) {
        val entrada = mockk<EntradaViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoEntrada()) }
        val feed = mockk<FeedVagasViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoFeed(status = StatusFeed.SUCESSO)) }
        val escopo = CoroutineScope(Dispatchers.Unconfined)
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        single<ArmazenamentoDeSessao> { sessao }
                        viewModel { entrada }
                        viewModel { feed }
                        viewModel { MinhasCandidaturasViewModel(buscar = { emptyList() }, escopo = escopo) }
                        viewModel { (vagaId: String) ->
                            AberturaDeVagaViewModel(
                                vagaId,
                                buscarDetalhe = { vagaDoServidor(vagaId, estado = "preenchida", posicoesAbertas = 0) },
                                escopo = escopo,
                            )
                        }
                    },
                )
            }) {
                nav = rememberNavController()
                AppNavegacao(armazenamentoDeSessao = sessao, monitorDeConectividade = MonitorDeConectividadeFalso(), navController = nav)
            }
        }
        if (daAbaCandidaturas) rule.runOnIdle { nav.navigate(Rotas.MINHAS_CANDIDATURAS) }
        rule.runOnIdle { nav.navigate(Rotas.detalhe("vaga-1")) }
    }

    private fun rotaAtual(): String? {
        var rota: String? = null
        rule.runOnIdle { rota = nav.currentDestination?.route }
        return rota
    }

    private fun esperarOBotao(texto: String) =
        rule.waitUntil(5_000) { rule.onAllNodesWithText(texto).fetchSemanticsNodes().isNotEmpty() }

    @Test
    fun `aberta pela aba Candidaturas, a vaga indisponivel oferece ver as candidaturas e volta para a aba`() {
        montar(daAbaCandidaturas = true)
        esperarOBotao(TextosVagaIndisponivel.BOTAO_VER_MINHAS_CANDIDATURAS)
        assertEquals(0, rule.onAllNodesWithText(TextosVagaIndisponivel.BOTAO_VOLTAR_PADRAO).fetchSemanticsNodes().size)

        rule.onNodeWithText(TextosVagaIndisponivel.BOTAO_VER_MINHAS_CANDIDATURAS).performScrollTo().performClick()

        rule.waitUntil(5_000) { rotaAtual() == Rotas.MINHAS_CANDIDATURAS }
        assertEquals(Rotas.MINHAS_CANDIDATURAS, rotaAtual())
    }

    @Test
    fun `aberta de outro lugar, a vaga indisponivel segue oferecendo as vagas perto e vai ao feed`() {
        montar(daAbaCandidaturas = false)
        esperarOBotao(TextosVagaIndisponivel.BOTAO_VOLTAR_PADRAO)
        assertEquals(0, rule.onAllNodesWithText(TextosVagaIndisponivel.BOTAO_VER_MINHAS_CANDIDATURAS).fetchSemanticsNodes().size)

        rule.onNodeWithText(TextosVagaIndisponivel.BOTAO_VOLTAR_PADRAO).performScrollTo().performClick()

        rule.waitUntil(5_000) { rotaAtual() == Rotas.FEED }
        assertEquals(Rotas.FEED, rotaAtual())
    }
}
