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
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
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
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão DIdiPVtt: o efeito de `TelaDetalheVaga` que navega por `ehConflitoHorario`, `ehVagaPreenchida` e `ehVagaEncerrada` usa o
 * mesmo padrão do que já duplicava a conta suspensa (0nepnX5N). Cada teste provoca o evento uma vez (um único pedido de candidatura
 * recusado) e conta quantas vezes o `NavController` chegou à tela de destino, pelos dois caminhos até o detalhe (vindo do feed e
 * aberto pelo id). O `ServicoVagas` é o real, sobre um motor HTTP falso; só a rede é falsa.
 *
 * A reentrada do efeito depende de tempo (o primeiro teste da JVM é lento e a escondia), então o que vale é a classe inteira.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class, qualifiers = "w411dp-h2400dp")
class AppNavegacaoEfeitosDoDetalheTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // C0-6b: testReleaseUnitTest

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private lateinit var nav: NavHostController
    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } returns false
    }

    /** Quantas vezes o `NavController` chegou a cada rota, na ordem em que as chegadas aconteceram. */
    private val chegadas = mutableListOf<String>()
    private val pedidos = mutableListOf<String>()

    private fun montar(status: HttpStatusCode, corpoDoErro: String, aPartirDoFeed: Boolean) {
        val entrada = mockk<EntradaViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoEntrada()) }
        val perfil = mockk<PerfilViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoPerfil(status = StatusPerfil.SUCESSO))
        }
        val feed = mockk<FeedVagasViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoFeed(status = StatusFeed.SUCESSO))
            every { encontrarVagaPorId(VAGA_ID) } returns vagaDaLista(VAGA_ID)
        }
        val servico = ServicoVagas(
            ClienteSupabase(
                baseUrl = "https://frila.supabase.co",
                apiKey = "chave-teste",
                engine = MockEngine { request ->
                    pedidos += request.url.encodedPath
                    respond(
                        content = corpoDoErro,
                        status = status,
                        headers = headersOf(HttpHeaders.ContentType, "application/json"),
                    )
                },
            ),
        )
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
                            DetalheVagaViewModel(params.get(), servico, detalhe = params.getOrNull(), escopo = escopo)
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
        rule.runOnIdle { nav.addOnDestinationChangedListener { _, destino, _ -> destino.route?.let { chegadas += it } } }
        if (aPartirDoFeed) {
            rule.runOnIdle { nav.navigate(Rotas.FEED) }
        }
        rule.runOnIdle { nav.navigate(Rotas.detalhe(VAGA_ID)) }
    }

    /** Provoca o evento uma vez e devolve quantas vezes o `NavController` chegou em [destino]. */
    private fun chegadasApos(
        status: HttpStatusCode,
        corpoDoErro: String,
        destino: String,
        aPartirDoFeed: Boolean,
    ): Int {
        montar(status, corpoDoErro, aPartirDoFeed)
        rule.waitUntil(5_000) { rule.onAllNodesWithText(BOTAO_CANDIDATAR).fetchSemanticsNodes().isNotEmpty() }
        rule.onNodeWithText(BOTAO_CANDIDATAR).performClick()
        rule.waitUntil(5_000) { chegadas.any { it == destino } }
        rule.waitForIdle()
        rule.runOnIdle { assertEquals("um único pedido de candidatura", 1, pedidos.count { it.endsWith("/rpc/candidatar") }) }
        return chegadas.count { it == destino }
    }

    private fun exigirUmaChegada(
        status: HttpStatusCode,
        corpoDoErro: String,
        destino: String,
        aPartirDoFeed: Boolean,
    ) {
        val total = chegadasApos(status, corpoDoErro, destino, aPartirDoFeed)
        rule.runOnIdle { assertEquals("chegadas em $destino (todas: $chegadas)", 1, total) }
    }

    @Test
    fun `conflito de horario a partir do feed navega uma vez`() =
        exigirUmaChegada(HttpStatusCode.UnprocessableEntity, ERRO_CONFLITO, Rotas.CONFLITO_HORARIO, aPartirDoFeed = true)

    @Test
    fun `conflito de horario com a vaga aberta pelo id navega uma vez`() =
        exigirUmaChegada(HttpStatusCode.UnprocessableEntity, ERRO_CONFLITO, Rotas.CONFLITO_HORARIO, aPartirDoFeed = false)

    @Test
    fun `vaga preenchida a partir do feed navega uma vez`() =
        exigirUmaChegada(HttpStatusCode.Conflict, ERRO_PREENCHIDA, Rotas.VAGA_PREENCHIDA, aPartirDoFeed = true)

    @Test
    fun `vaga preenchida com a vaga aberta pelo id navega uma vez`() =
        exigirUmaChegada(HttpStatusCode.Conflict, ERRO_PREENCHIDA, Rotas.VAGA_PREENCHIDA, aPartirDoFeed = false)

    @Test
    fun `vaga encerrada a partir do feed navega uma vez`() =
        exigirUmaChegada(HttpStatusCode.Conflict, ERRO_ENCERRADA, Rotas.VAGA_ENCERRADA, aPartirDoFeed = true)

    @Test
    fun `vaga encerrada com a vaga aberta pelo id navega uma vez`() =
        exigirUmaChegada(HttpStatusCode.Conflict, ERRO_ENCERRADA, Rotas.VAGA_ENCERRADA, aPartirDoFeed = false)

    private companion object {
        const val VAGA_ID = "vaga-9"
        const val BOTAO_CANDIDATAR = "Candidatar-se"
        const val ERRO_CONFLITO = """{"code":"inelegivel","message":"inelegivel","details":"turno_sobreposto","hint":null}"""
        const val ERRO_PREENCHIDA = """{"code":"posicao_ja_preenchida","message":"posicao_ja_preenchida","details":null,"hint":null}"""
        const val ERRO_ENCERRADA = """{"code":"vaga_encerrada","message":"vaga_encerrada","details":null,"hint":null}"""
    }
}
