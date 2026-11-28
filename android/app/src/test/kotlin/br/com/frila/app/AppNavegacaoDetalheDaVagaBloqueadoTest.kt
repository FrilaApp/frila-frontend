package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.dominio.modelo.AlvoBloqueado
import br.com.frila.core.dominio.modelo.BloqueiosDaSessao
import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.vagas.detalhe.AberturaDeVagaViewModel
import br.com.frila.feature.vagas.detalhe.DetalheVagaViewModel
import br.com.frila.feature.vagas.detalhe.TextosVagaIndisponivel
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
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * I1PonzKJ, fatia 3: o detalhe da vaga aberto pelo id (link, aviso, candidatura) lê o conjunto da sessão. Vaga de estabelecimento que o
 * profissional bloqueou vira "não está mais disponível", como o iOS (`naoEncontradaView`); sem bloqueio, o detalhe abre normalmente.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class, qualifiers = "w411dp-h2400dp")
class AppNavegacaoDetalheDaVagaBloqueadoTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste()

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private lateinit var nav: NavHostController
    private val bloqueios = BloqueiosDaSessao()
    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } returns false
    }

    // A casa da vaga do servidor é "e1" (casaDeTeste); o detalhe não vem da lista do feed.
    private fun montar(registrarOConjunto: Boolean = true) {
        val entrada = mockk<EntradaViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoEntrada()) }
        val feed = mockk<FeedVagasViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoFeed(status = StatusFeed.SUCESSO))
            every { encontrarVagaPorId(any()) } returns null
        }
        val servico = ServicoVagas(
            ClienteSupabase(
                baseUrl = "https://frila.supabase.co", apiKey = "chave-teste",
                engine = MockEngine { respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) },
            ),
        )
        val escopo = CoroutineScope(Dispatchers.Unconfined)
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        single<ArmazenamentoDeSessao> { sessao }
                        if (registrarOConjunto) single { bloqueios }
                        viewModel { entrada }
                        viewModel { feed }
                        viewModel { (vagaId: String) ->
                            AberturaDeVagaViewModel(vagaId, buscarDetalhe = { vagaDoServidor(vagaId) }, escopo = escopo)
                        }
                        viewModel { params -> DetalheVagaViewModel(params.get(), servico, detalhe = params.getOrNull(), escopo = escopo) }
                    },
                )
            }) {
                nav = rememberNavController()
                AppNavegacao(
                    armazenamentoDeSessao = sessao, monitorDeConectividade = MonitorDeConectividadeFalso(), navController = nav,
                )
            }
        }
        rule.runOnIdle { nav.navigate(Rotas.detalhe("vaga-7")) }
    }

    private fun indisponivel() = rule.onAllNodesWithText(TextosVagaIndisponivel.NAO_ENCONTRADA_MENSAGEM).fetchSemanticsNodes().isNotEmpty()
    private fun detalheAberto() = rule.onAllNodesWithText("Candidatar-se").fetchSemanticsNodes().isNotEmpty()

    @Test
    fun `sem bloqueio, a vaga aberta pelo id abre o detalhe`() {
        montar()

        rule.waitUntil(5_000) { detalheAberto() }
        assertEquals(false, indisponivel())
    }

    @Test
    fun `vaga de estabelecimento bloqueado na sessao abre como nao disponivel e sem o botao de candidatar`() {
        bloqueios.registrar(AlvoBloqueado(TipoDeAlvo.ESTABELECIMENTO, "e1"))
        montar()

        rule.waitUntil(5_000) { indisponivel() }
        assertEquals(false, detalheAberto())
    }

    @Test
    fun `bloquear com o detalhe aberto troca o detalhe pela tela de nao disponivel`() {
        montar()
        rule.waitUntil(5_000) { detalheAberto() }

        rule.runOnIdle { bloqueios.registrar(AlvoBloqueado(TipoDeAlvo.ESTABELECIMENTO, "e1")) }

        rule.waitUntil(5_000) { indisponivel() }
        assertEquals(false, detalheAberto())
    }

    @Test
    fun `o mesmo id com outro tipo nao esconde o detalhe`() {
        bloqueios.registrar(AlvoBloqueado(TipoDeAlvo.PROFISSIONAL, "e1"))
        montar()

        rule.waitUntil(5_000) { detalheAberto() }
        assertEquals(false, indisponivel())
    }

    @Test
    fun `um grafo sem o conjunto registrado segue abrindo o detalhe`() {
        montar(registrarOConjunto = false)

        rule.waitUntil(5_000) { detalheAberto() }
    }
}
