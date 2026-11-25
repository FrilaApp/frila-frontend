package br.com.frila.app

import android.app.Application
import android.content.ComponentName
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.dialog
import androidx.navigation.compose.rememberNavController
import androidx.test.core.app.ActivityScenario
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.SituacaoDaContaDto
import br.com.frila.core.rede.SuspensaoDaContaDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.conta.ContaSuspensaViewModel
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.perfil.EstadoPerfil
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.StatusPerfil
import br.com.frila.feature.vagas.detalhe.AberturaDeVagaViewModel
import br.com.frila.feature.vagas.detalhe.ControleSessaoNotificacao
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
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.ExternalResource
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.core.context.stopKoin
import org.koin.dsl.module
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * Activity dedicada para permitir `ActivityScenario.recreate()` (rotação) mantendo a restauração
 * real do `NavHostController` e do `ViewModelStore` dos `NavBackStackEntry`.
 */
class ActivityDetalheEventosDeTeste : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val configuracao = configuracaoAtual ?: error("Configure o cenário antes de subir a Activity")
        setContent {
            KoinApplication(application = { modules(configuracao.modulo) }) {
                val nav = rememberNavController()
                navAtual = nav
                AppNavegacao(
                    armazenamentoDeSessao = configuracao.sessao,
                    monitorDeConectividade = MonitorDeConectividadeFalso(),
                    navController = nav,
                )
            }
        }
    }

    internal data class Configuracao(
        val sessao: ArmazenamentoDeSessao,
        val modulo: org.koin.core.module.Module,
    )

    internal companion object {
        var configuracaoAtual: Configuracao? = null
        var navAtual: NavHostController? = null
    }
}

class RegistraActivityDetalheEventosDeTeste : ExternalResource() {
    override fun before() {
        val app = RuntimeEnvironment.getApplication()
        shadowOf(app.packageManager).addActivityIfNotPresent(
            ComponentName(app, ActivityDetalheEventosDeTeste::class.java),
        )
    }
}

/**
 * Prova na navegação real (`AppNavegacao`) que todos os 5 eventos do detalhe da vaga disparam
 * uma única vez por candidatura — na 1ª tentativa, na volta (`popBackStack`), no 2º clique e
 * após recriar a Activity (rotação).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class, qualifiers = "w411dp-h2400dp")
class AppNavegacaoDetalheEventosUmaVezTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste()

    @get:Rule(order = 1)
    val registraActivityDeTeste = RegistraActivityDetalheEventosDeTeste()

    @get:Rule(order = 2)
    val rule = createEmptyComposeRule()

    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } returns false
    }

    private val pedidos = mutableListOf<String>()

    @Before
    fun limparAntes() {
        pedidos.clear()
        ControleSessaoNotificacao.resetarParaTestes()
        runCatching { stopKoin() }
    }

    @After
    fun limparDepois() {
        ActivityDetalheEventosDeTeste.configuracaoAtual = null
        ActivityDetalheEventosDeTeste.navAtual = null
        runCatching { stopKoin() }
    }

    private fun servicoComResposta(status: HttpStatusCode, corpo: String): ServicoVagas {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine { request ->
                pedidos += request.url.encodedPath
                respond(
                    content = corpo,
                    status = status,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        return ServicoVagas(cliente)
    }

    private fun prepararCenario(status: HttpStatusCode, corpo: String) {
        val entrada = mockk<EntradaViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoEntrada())
        }
        val perfil = mockk<PerfilViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoPerfil(status = StatusPerfil.SUCESSO))
        }
        val feed = mockk<FeedVagasViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoFeed(status = StatusFeed.SUCESSO))
            every { encontrarVagaPorId(VAGA_ID) } returns vagaDaLista(VAGA_ID)
        }
        val servico = servicoComResposta(status, corpo)
        val escopo = CoroutineScope(Dispatchers.Unconfined)
        val modulo = module {
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
        }
        ActivityDetalheEventosDeTeste.configuracaoAtual = ActivityDetalheEventosDeTeste.Configuracao(sessao, modulo)
    }

    private fun nav(): NavHostController =
        ActivityDetalheEventosDeTeste.navAtual ?: error("NavHostController não inicializado")

    private fun abrirDetalhe(aPartirDoFeed: Boolean) {
        rule.waitForIdle()
        if (aPartirDoFeed) {
            rule.runOnIdle { nav().navigate(Rotas.FEED) }
        }
        rule.runOnIdle { nav().navigate(Rotas.detalhe(VAGA_ID)) }
        rule.waitForIdle()
    }

    private fun candidatar() {
        rule.waitUntil(5_000) { rule.onAllNodesWithText(BOTAO_CANDIDATAR).fetchSemanticsNodes().isNotEmpty() }
        rule.onNodeWithText(BOTAO_CANDIDATAR).performClick()
    }

    private fun esperarDestinoUnicoAcimaDoDetalhe(rotaDestino: String) {
        rule.waitUntil(5_000) { nav().currentDestination?.route == rotaDestino }
        rule.waitForIdle()
        rule.runOnIdle {
            val rotas = nav().currentBackStack.value.mapNotNull { it.destination.route }
            val acima = rotas.dropWhile { it != Rotas.DETALHE }.drop(1)
            assertTrue("o detalhe tem de estar na pilha: $rotas", Rotas.DETALHE in rotas)
            assertEquals("exatamente 1 rota ($rotaDestino) acima do detalhe: $rotas", listOf(rotaDestino), acima)
        }
    }

    private fun voltarAoDetalheSemReempilhar(rotaDestino: String) {
        rule.runOnIdle { nav().popBackStack() }
        rule.waitForIdle()
        rule.runOnIdle {
            val rotas = nav().currentBackStack.value.mapNotNull { it.destination.route }
            assertEquals("o voltar para no detalhe: $rotas", Rotas.DETALHE, nav().currentDestination?.route)
            assertTrue("$rotaDestino não pode voltar à pilha: $rotas", rotaDestino !in rotas)
        }
    }

    private fun exercitarIdaEVolta(
        status: HttpStatusCode,
        corpo: String,
        rotaDestino: String,
        aPartirDoFeed: Boolean,
        verificacaoExtraNoDetalhe: (() -> Unit)? = null,
    ) {
        prepararCenario(status, corpo)
        ActivityScenario.launch(ActivityDetalheEventosDeTeste::class.java).use {
            abrirDetalhe(aPartirDoFeed)
            candidatar()
            esperarDestinoUnicoAcimaDoDetalhe(rotaDestino)
            voltarAoDetalheSemReempilhar(rotaDestino)
            verificacaoExtraNoDetalhe?.invoke()
        }
    }

    private fun exercitarSegundoClique(status: HttpStatusCode, corpo: String, rotaDestino: String) {
        prepararCenario(status, corpo)
        ActivityScenario.launch(ActivityDetalheEventosDeTeste::class.java).use {
            abrirDetalhe(aPartirDoFeed = false)
            candidatar()
            esperarDestinoUnicoAcimaDoDetalhe(rotaDestino)
            assertEquals(1, pedidos.count { it.endsWith("/rpc/candidatar") })

            voltarAoDetalheSemReempilhar(rotaDestino)
            candidatar()
            esperarDestinoUnicoAcimaDoDetalhe(rotaDestino)
            assertEquals(2, pedidos.count { it.endsWith("/rpc/candidatar") })
        }
    }

    private fun exercitarRotacaoNoDestinoEVolta(
        status: HttpStatusCode,
        corpo: String,
        rotaDestino: String,
        aPartirDoFeed: Boolean,
    ) {
        prepararCenario(status, corpo)
        ActivityScenario.launch(ActivityDetalheEventosDeTeste::class.java).use { scenario ->
            abrirDetalhe(aPartirDoFeed)
            candidatar()
            esperarDestinoUnicoAcimaDoDetalhe(rotaDestino)

            scenario.recreate()
            rule.waitForIdle()

            esperarDestinoUnicoAcimaDoDetalhe(rotaDestino)
            voltarAoDetalheSemReempilhar(rotaDestino)
        }
    }

    // (a) + (b): ida única acima do detalhe e popBackStack sem reempilhar, cobrindo feed e abertura por id

    @Test
    fun `confirmada pelo feed navega uma vez e popBackStack volta ao detalhe mantendo status confirmada`() {
        exercitarIdaEVolta(
            status = HttpStatusCode.OK,
            corpo = CORPO_CONFIRMADA,
            rotaDestino = Rotas.TURNO_CONFIRMADO,
            aPartirDoFeed = true,
            verificacaoExtraNoDetalhe = {
                rule.onNodeWithText("Candidatura confirmada").assertExists()
            },
        )
    }

    @Test
    fun `confirmada aberta pelo id navega uma vez e popBackStack volta ao detalhe`() {
        exercitarIdaEVolta(
            status = HttpStatusCode.OK,
            corpo = CORPO_CONFIRMADA,
            rotaDestino = Rotas.TURNO_CONFIRMADO,
            aPartirDoFeed = false,
        )
    }

    @Test
    fun `conflito de horario pelo feed navega uma vez e popBackStack volta ao detalhe`() {
        exercitarIdaEVolta(
            status = HttpStatusCode.UnprocessableEntity,
            corpo = ERRO_CONFLITO,
            rotaDestino = Rotas.CONFLITO_HORARIO,
            aPartirDoFeed = true,
        )
    }

    @Test
    fun `vaga preenchida aberta pelo id navega uma vez e popBackStack volta ao detalhe`() {
        exercitarIdaEVolta(
            status = HttpStatusCode.Conflict,
            corpo = ERRO_PREENCHIDA,
            rotaDestino = Rotas.VAGA_PREENCHIDA,
            aPartirDoFeed = false,
        )
    }

    @Test
    fun `vaga encerrada aberta pelo id navega uma vez e popBackStack volta ao detalhe`() {
        exercitarIdaEVolta(
            status = HttpStatusCode.Conflict,
            corpo = ERRO_ENCERRADA,
            rotaDestino = Rotas.VAGA_ENCERRADA,
            aPartirDoFeed = false,
        )
    }

    // (c): 2º clique após popBackStack

    @Test
    fun `segundo clique apos popBackStack em conflito de horario navega uma vez de novo`() {
        exercitarSegundoClique(HttpStatusCode.UnprocessableEntity, ERRO_CONFLITO, Rotas.CONFLITO_HORARIO)
    }

    @Test
    fun `segundo clique apos popBackStack em vaga preenchida navega uma vez de novo`() {
        exercitarSegundoClique(HttpStatusCode.Conflict, ERRO_PREENCHIDA, Rotas.VAGA_PREENCHIDA)
    }

    @Test
    fun `segundo clique apos popBackStack em vaga encerrada navega uma vez de novo`() {
        exercitarSegundoClique(HttpStatusCode.Conflict, ERRO_ENCERRADA, Rotas.VAGA_ENCERRADA)
    }

    @Test
    fun `segundo clique apos popBackStack em conta suspensa navega uma vez de novo`() {
        exercitarSegundoClique(HttpStatusCode.Forbidden, ERRO_CONTA_SUSPENSA, Rotas.CONTA_SUSPENSA)
    }

    // (d): rotação (recreate) no destino e volta ao detalhe

    @Test
    fun `rotacao em turno confirmado e volta ao detalhe nao reempilha o destino`() {
        exercitarRotacaoNoDestinoEVolta(HttpStatusCode.OK, CORPO_CONFIRMADA, Rotas.TURNO_CONFIRMADO, aPartirDoFeed = true)
    }

    @Test
    fun `rotacao em conflito de horario e volta ao detalhe nao reempilha o destino`() {
        exercitarRotacaoNoDestinoEVolta(
            HttpStatusCode.UnprocessableEntity,
            ERRO_CONFLITO,
            Rotas.CONFLITO_HORARIO,
            aPartirDoFeed = false,
        )
    }

    @Test
    fun `rotacao em vaga preenchida e volta ao detalhe nao reempilha o destino`() {
        exercitarRotacaoNoDestinoEVolta(HttpStatusCode.Conflict, ERRO_PREENCHIDA, Rotas.VAGA_PREENCHIDA, aPartirDoFeed = false)
    }

    @Test
    fun `rotacao em vaga encerrada e volta ao detalhe nao reempilha o destino`() {
        exercitarRotacaoNoDestinoEVolta(HttpStatusCode.Conflict, ERRO_ENCERRADA, Rotas.VAGA_ENCERRADA, aPartirDoFeed = false)
    }

    @Test
    fun `rotacao em conta suspensa e volta ao detalhe nao reempilha o destino`() {
        exercitarRotacaoNoDestinoEVolta(HttpStatusCode.Forbidden, ERRO_CONTA_SUSPENSA, Rotas.CONTA_SUSPENSA, aPartirDoFeed = false)
    }

    // (e): restauração após morte do processo (saveInstanceState + nova Activity com ViewModels vazios)

    private fun exercitarRestauracaoMorteDoProcesso(
        status: HttpStatusCode,
        corpo: String,
        rotaDestino: String,
        aPartirDoFeed: Boolean,
        verificarTelaRestaurada: () -> Unit,
    ) {
        prepararCenario(status, corpo)
        val estadoSalvo = Bundle()
        val controller1 = Robolectric.buildActivity(ActivityDetalheEventosDeTeste::class.java).setup()
        try {
            abrirDetalhe(aPartirDoFeed)
            candidatar()
            esperarDestinoUnicoAcimaDoDetalhe(rotaDestino)
            controller1.saveInstanceState(estadoSalvo)
        } finally {
            controller1.pause().stop().destroy()
            ActivityDetalheEventosDeTeste.navAtual = null
            runCatching { stopKoin() }
        }

        val controller2 = Robolectric.buildActivity(ActivityDetalheEventosDeTeste::class.java)
            .create(estadoSalvo)
            .start()
            .resume()
            .visible()
        try {
            rule.waitUntil(5_000) { nav().currentDestination?.route == rotaDestino }
            rule.waitForIdle()
            rule.runOnIdle { assertEquals(rotaDestino, nav().currentDestination?.route) }
            verificarTelaRestaurada()
        } finally {
            controller2.pause().stop().destroy()
        }
    }

    @Test
    fun `restauracao apos morte do processo em turno confirmado pelo feed exibe a vaga sem quebrar`() {
        exercitarRestauracaoMorteDoProcesso(
            status = HttpStatusCode.OK,
            corpo = CORPO_CONFIRMADA,
            rotaDestino = Rotas.TURNO_CONFIRMADO,
            aPartirDoFeed = true,
        ) {
            rule.onNodeWithTag("resultado-confirmada").assertExists()
            rule.onNodeWithText("garçom, Bar do Zé").assertExists()
        }
    }

    @Test
    fun `restauracao apos morte do processo em turno confirmado pelo id exibe a vaga sem quebrar`() {
        exercitarRestauracaoMorteDoProcesso(
            status = HttpStatusCode.OK,
            corpo = CORPO_CONFIRMADA,
            rotaDestino = Rotas.TURNO_CONFIRMADO,
            aPartirDoFeed = false,
        ) {
            rule.onNodeWithTag("resultado-confirmada").assertExists()
            rule.onNodeWithText("Garçom, Bar do Zé").assertExists()
        }
    }

    @Test
    fun `restauracao apos morte do processo em conflito de horario pelo id exibe a vaga sem quebrar`() {
        exercitarRestauracaoMorteDoProcesso(
            status = HttpStatusCode.UnprocessableEntity,
            corpo = ERRO_CONFLITO,
            rotaDestino = Rotas.CONFLITO_HORARIO,
            aPartirDoFeed = false,
        ) {
            rule.onNodeWithTag("resultado-turno-sobreposto").assertExists()
            rule.onNodeWithText("Garçom, Bar do Zé").assertExists()
        }
    }

    @Test
    fun `restauracao apos morte do processo em vaga preenchida pelo feed e pelo id exibe a vaga sem quebrar`() {
        exercitarRestauracaoMorteDoProcesso(
            status = HttpStatusCode.Conflict,
            corpo = ERRO_PREENCHIDA,
            rotaDestino = Rotas.VAGA_PREENCHIDA,
            aPartirDoFeed = true,
        ) {
            rule.onNodeWithText(TextosVagaIndisponivel.PREENCHIDA_TITULO).assertExists()
            rule.onNodeWithText(TextosVagaIndisponivel.PREENCHIDA_MENSAGEM_SELECAO).assertExists()
        }
        pedidos.clear()
        runCatching { stopKoin() }
        exercitarRestauracaoMorteDoProcesso(
            status = HttpStatusCode.Conflict,
            corpo = ERRO_PREENCHIDA,
            rotaDestino = Rotas.VAGA_PREENCHIDA,
            aPartirDoFeed = false,
        ) {
            rule.onNodeWithText(TextosVagaIndisponivel.PREENCHIDA_TITULO).assertExists()
            rule.onNodeWithText(TextosVagaIndisponivel.PREENCHIDA_MENSAGEM_SELECAO).assertExists()
        }
    }

    // (f): fallback sem vaga na entrada e sem FEED na pilha; e volta ao topo depois

    private fun exercitarFallbackSemVagaESemFeed(rotaComVagaAusente: String, padraoRota: String) {
        prepararCenario(HttpStatusCode.OK, CORPO_CONFIRMADA)
        ActivityScenario.launch(ActivityDetalheEventosDeTeste::class.java).use {
            rule.waitForIdle()
            rule.runOnIdle { nav().navigate(rotaComVagaAusente) }
            rule.waitUntil(5_000) { nav().currentDestination?.route == Rotas.FEED }
            rule.waitForIdle()
            rule.runOnIdle {
                val rotas = nav().currentBackStack.value.mapNotNull { it.destination.route }
                assertEquals(Rotas.FEED, nav().currentDestination?.route)
                assertTrue("a rota sem vaga ($padraoRota) tem de sair da pilha: $rotas", padraoRota !in rotas)
            }
        }
    }

    @Test
    fun `fallback em turno confirmado sem vaga e sem feed na pilha vai ao feed e remove a rota da pilha`() {
        exercitarFallbackSemVagaESemFeed(Rotas.turnoConfirmado(VAGA_ID), Rotas.TURNO_CONFIRMADO)
    }

    @Test
    fun `fallback em conflito de horario sem vaga e sem feed na pilha vai ao feed e remove a rota da pilha`() {
        exercitarFallbackSemVagaESemFeed(Rotas.conflitoHorario(VAGA_ID), Rotas.CONFLITO_HORARIO)
    }

    @Test
    fun `fallback reavalia e roda quando a rota sem vaga nao estava no topo na primeira composicao e volta ao topo depois`() {
        val controller = Robolectric.buildActivity(ComponentActivity::class.java).setup()
        var navLocal: NavHostController? = null
        var composicoesSemVaga = 0
        try {
            val activity = controller.get()
            activity.runOnUiThread {
                activity.setContent {
                    val nav = rememberNavController()
                    navLocal = nav
                    NavHost(navController = nav, startDestination = "inicio") {
                        composable("inicio") {}
                        composable(Rotas.FEED) {}
                        composable(Rotas.TURNO_CONFIRMADO) { entrada ->
                            composicoesSemVaga++
                            FallbackVoltarAoFeed(nav, entrada)
                        }
                        dialog("sobreposta") {}
                    }
                }
            }
            rule.waitForIdle()

            // Abre a rota sem vaga já coberta por um dialog no topo: na 1ª composição ela não é o topo.
            rule.runOnIdle {
                val nav = navLocal!!
                nav.navigate(Rotas.turnoConfirmado(VAGA_ID))
                nav.navigate("sobreposta")
            }
            rule.waitForIdle()
            rule.runOnIdle {
                val nav = navLocal!!
                val rotas = nav.currentBackStack.value.mapNotNull { it.destination.route }
                assertTrue("o fallback compôs embaixo do dialog", composicoesSemVaga >= 1)
                assertEquals("sobreposta", nav.currentDestination?.route)
                assertTrue("enquanto não está no topo, a rota fica na pilha: $rotas", Rotas.TURNO_CONFIRMADO in rotas)
            }

            // Fecha o dialog: a rota sem vaga volta ao topo mantendo a mesma composição e dispara o fallback.
            rule.runOnIdle { navLocal!!.popBackStack() }
            rule.waitUntil(5_000) { navLocal?.currentDestination?.route == Rotas.FEED }
            rule.waitForIdle()
            rule.runOnIdle {
                val nav = navLocal!!
                val rotas = nav.currentBackStack.value.mapNotNull { it.destination.route }
                assertEquals(Rotas.FEED, nav.currentDestination?.route)
                assertTrue("ao voltar ao topo, a rota sem vaga sai da pilha: $rotas", Rotas.TURNO_CONFIRMADO !in rotas)
            }
        } finally {
            controller.pause().stop().destroy()
        }
    }

    private companion object {
        const val VAGA_ID = "vaga-9"
        const val BOTAO_CANDIDATAR = "Candidatar-se"
        const val CORPO_CONFIRMADA =
            """{"estado":"confirmada","candidatura_id":"c1","posicao_id":"p1","turno_id":"t1","contato":{"nome":"Bar do Zé","telefone":"+5561999990000"}}"""
        const val ERRO_CONFLITO =
            """{"code":"inelegivel","message":"inelegivel","details":"turno_sobreposto"}"""
        const val ERRO_PREENCHIDA =
            """{"code":"posicao_ja_preenchida","message":"preenchida","details":null}"""
        const val ERRO_ENCERRADA =
            """{"code":"vaga_encerrada","message":"encerrada","details":null}"""
        const val ERRO_CONTA_SUSPENSA =
            """{"code":"sem_permissao","message":"sem_permissao","details":"conta_suspensa","hint":null}"""
        val SITUACAO_SUSPENSA = SituacaoDaContaDto(
            estado = "suspensa",
            suspensao = SuspensaoDaContaDto(motivo = "Assédio confirmado", desde = "2026-11-09T15:00:00Z"),
        )
    }
}
