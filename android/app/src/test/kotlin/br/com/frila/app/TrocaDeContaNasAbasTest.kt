package br.com.frila.app

import android.app.Application
import android.content.Intent
import android.net.Uri
import androidx.activity.ComponentActivity
import androidx.compose.ui.test.ComposeTimeoutException
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ExclusaoDeContaDto
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import br.com.frila.feature.conta.ExclusaoDeContaViewModel
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.perfil.EstadoPerfil
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.StatusPerfil
import br.com.frila.feature.turnos.MeusTurnosViewModel
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
import org.junit.Assert.assertNull
import org.junit.After
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
 * RN: nada de uma conta pode reaparecer para a conta seguinte pelas abas da raiz, e as entradas do Perfil que não
 * dependem dele (bloqueados, contestar o despacho) continuam ao alcance com o Perfil em erro.
 *
 * Nasceram como sondas da revisão de risco alto do #988: com o estado das abas guardado na troca de aba
 * (`saveState`/`restoreState`), a aba de A voltava para B depois de sair e entrar, com a candidatura de A à vista
 * quando a leitura nova falhava. Usam o `AppNavegacao` e a `BarraDaRaiz` de verdade; dados e tokens são sintéticos.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class TrocaDeContaNasAbasTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // C0-6b: testReleaseUnitTest

    @get:Rule(order = 1)
    val rule = createAndroidComposeRule<ComponentActivity>()

    private lateinit var nav: NavHostController

    private val sessao = SessaoComCacheVagas(ArmazenamentoDeSessaoEmMemoria(), CacheVagasDaSessao(raiz = null))
    private var contaDaSonda = "A"

    /** O "servidor" recusa tudo com 401, como recusa quem chega sem sessão válida. */
    private val cliente = ClienteSupabase(
        baseUrl = "https://frila.supabase.co",
        apiKey = "chave-teste",
        engine = MockEngine {
            respond(
                """{"code":"nao_autenticado","message":"nao_autenticado","details":null}""",
                HttpStatusCode.Unauthorized,
                headersOf(HttpHeaders.ContentType, "application/json"),
            )
        },
    )

    /** "Sair da conta" limpa a sessão como o `CoordenadorDeLogout` e só então a tela navega. */
    private val perfil = mockk<PerfilViewModel>(relaxed = true) {
        every { estado } returns MutableStateFlow(EstadoPerfil(status = StatusPerfil.SUCESSO))
        every { aoDeslogar() } answers { sessao.limparSessao() }
    }

    /** Como no grafo de produção: a exclusão aceita pelo servidor limpa a sessão em `aoConcluir`. */
    private val exclusao = ExclusaoDeContaViewModel(
        excluir = { ExclusaoDeContaDto(perfilRemovidoEm = "2026-11-16T12:00:00Z", dadosApagadosAte = "2026-12-16T12:00:00Z", turnosCancelados = 0) },
        aoConcluir = { sessao.limparSessao() },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    /** Intent de partida da Activity, devolvido no fim: o ActivityScenario só reconhece a Activity por ele. */
    private var intentOriginal: Intent? = null

    @After
    fun devolverIntentOriginal() {
        intentOriginal?.let { original -> rule.runOnUiThread { rule.activity.intent = original } }
    }

    private fun montar(link: String? = null) {
        // O link chega como chega ao app: no intent da Activity, que o NavController lê ao criar o grafo.
        link?.let {
            rule.runOnUiThread {
                intentOriginal = rule.activity.intent
                rule.activity.intent = Intent(Intent.ACTION_VIEW, Uri.parse(it))
            }
        }
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        single<ArmazenamentoDeSessao> { sessao }
                        viewModel { EntradaViewModel(ServicoAutenticacao(cliente), CoroutineScope(Dispatchers.Default)) }
                        viewModel { perfil }
                        viewModel { exclusao }
                        viewModel { MeusTurnosViewModel(ServicoTurnos { cliente }) }
                        viewModel { br.com.frila.feature.vagas.feed.FeedVagasViewModel(br.com.frila.core.rede.ServicoVagas(cliente)) }
                        viewModel {
                            br.com.frila.feature.vagas.candidaturas.MinhasCandidaturasViewModel(buscar = {
                                if (contaDaSonda != "A") throw java.io.IOException("Sem rede na conta B, sonda sintética")
                                listOf(br.com.frila.core.rede.CandidaturaDto(
                                    id = "candidatura-A", estado = "pendente", criadaEm = "2026-11-17T12:00:00Z",
                                    vaga = br.com.frila.core.rede.VagaResumoDto(
                                        "vaga-A", "FUNCAO PRIVADA DA CONTA A", "LOCAL SINTETICO DE A", "Asa Norte",
                                        "2026-12-01T21:00:00Z", "2026-12-02T03:00:00Z", 16000,
                                    ),
                                ))
                            })
                        }
                    },
                )
            }) {
                nav = rememberNavController()
                AppNavegacao(
                    armazenamentoDeSessao = sessao,
                    monitorDeConectividade = MonitorDeConectividadeFalso(),
                    navController = nav,
                    servicoMembros = null,
                    servicoVagas = null,
                    avaliadorDeDestino = null,
                )
            }
        }
        rule.waitForIdle()
    }

    /** Como depois do código: sessão guardada e o Perfil na raiz da pilha. */
    private fun entrarNaConta() {
        sessao.salvarSessao(Sessao("tok", "ref", "bearer", 3600))
        rule.runOnIdle { nav.navigate(Rotas.PERFIL) { popUpTo(Rotas.ENTRADA) { inclusive = true } } }
        rule.waitForIdle()
    }

    private fun rotaAtual(): String? {
        var rota: String? = null
        rule.runOnIdle { rota = nav.currentDestination?.route }
        return rota
    }

    /** Rota imediatamente abaixo da atual na pilha (nulo se a atual é a raiz). */
    private fun rotaAbaixo(): String? {
        var rota: String? = null
        rule.runOnIdle { rota = nav.previousBackStackEntry?.destination?.route }
        return rota
    }

    /** Espera até [prazoMs] pela condição; devolve se ela ficou verdadeira (sem lançar). */
    private fun aguardar(prazoMs: Long = 4_000, condicao: () -> Boolean): Boolean =
        try {
            rule.waitUntil(prazoMs) { rule.runOnIdle { }; condicao() }
            true
        } catch (_: ComposeTimeoutException) {
            false
        }

    /** Conta cada chegada à entrada daqui em diante (o ouvinte é chamado na hora com a rota atual, que não é ela). */

    @Test
    fun `RN - estado de aba da conta A nao pode restaurar na conta B`() {
        montar()
        sessao.salvarSessao(Sessao("sintetico-A", "refresh-A", "bearer", 3600))
        rule.runOnIdle { nav.navigate(Rotas.FEED) { popUpTo(0) { inclusive = true } } }
        rule.waitForIdle()
        rule.onNodeWithText(TextosDasAbas.MEUS_TURNOS).performClick()
        rule.waitForIdle()
        var idDeA: String? = null
        rule.runOnIdle {
            idDeA = nav.currentBackStackEntry!!.id
            nav.currentBackStackEntry!!.savedStateHandle["sonda-conta"] = "A"
        }
        // A troca de aba usa a BarraDaRaiz real e guarda a entrada de Meus turnos de A.
        rule.onNodeWithText(TextosDasAbas.CONTA).performClick()
        rule.waitForIdle()
        sessao.limparSessao()
        assertTrue(aguardar { rotaAtual() == Rotas.ENTRADA })
        assertNull(rotaAbaixo())
        // Como após autenticar B e a abertura escolher seu destino normal.
        sessao.salvarSessao(Sessao("sintetico-B", "refresh-B", "bearer", 3600))
        rule.runOnIdle { nav.navigate(Rotas.FEED) { popUpTo(0) { inclusive = true } } }
        rule.waitForIdle()
        rule.onNodeWithText(TextosDasAbas.MEUS_TURNOS).performClick()
        rule.waitForIdle()
        rule.runOnIdle {
            assertNull("Meus turnos de A reapareceu em B (id A=$idDeA; id B=${nav.currentBackStackEntry!!.id})", nav.currentBackStackEntry!!.savedStateHandle.get<String>("sonda-conta"))
        }
    }

    @Test
    fun `RN - Bloqueados permanece acessivel com Perfil em erro`() {
        montar()
        entrarNaConta()
        // Controle: com o perfil carregado, a linha foi integrada ao grupo da conta.
        rule.onNodeWithTag(ENTRADA_BLOQUEIOS).performScrollTo().assertExists()
        rule.runOnIdle {
            (perfil.estado as MutableStateFlow<EstadoPerfil>).value = EstadoPerfil(
                status = StatusPerfil.ERRO,
                mensagemErro = "Sem rede (sonda sintética)",
            )
        }
        rule.waitForIdle()
        rule.onNodeWithText("Sem rede (sonda sintética)").assertExists()
        // Na main o wrapper ComEntradasProvisorias mantinha esta entrada fora do estado do Perfil.
        rule.onNodeWithTag(ENTRADA_BLOQUEIOS).assertExists()
    }

    @Test
    fun `RN - Contestar permanece acessivel com Perfil em erro`() {
        montar()
        entrarNaConta()
        rule.onNodeWithTag(ENTRADA_CONTESTAR_DESPACHO).performScrollTo().assertExists()
        rule.runOnIdle {
            (perfil.estado as MutableStateFlow<EstadoPerfil>).value = EstadoPerfil(
                status = StatusPerfil.ERRO,
                mensagemErro = "Sem rede (sonda sintética)",
            )
        }
        rule.waitForIdle()
        rule.onNodeWithText("Sem rede (sonda sintética)").assertExists()
        rule.onNodeWithTag(ENTRADA_CONTESTAR_DESPACHO).assertExists()
    }

    @Test
    fun `RN - Candidaturas da conta A nao podem aparecer na conta B sem rede`() {
        montar()
        sessao.salvarSessao(Sessao("sintetico-A", "refresh-A", "bearer", 3600))
        rule.runOnIdle { nav.navigate(Rotas.FEED) { popUpTo(0) { inclusive = true } } }
        rule.waitForIdle()
        rule.onNodeWithText("Candidaturas").performClick()
        rule.waitForIdle()
        rule.onNodeWithText("FUNCAO PRIVADA DA CONTA A").assertExists()
        rule.onNodeWithText(TextosDasAbas.CONTA).performClick()
        rule.waitForIdle()
        sessao.limparSessao()
        assertTrue(aguardar { rotaAtual() == Rotas.ENTRADA })
        assertNull(rotaAbaixo())
        contaDaSonda = "B"
        sessao.salvarSessao(Sessao("sintetico-B", "refresh-B", "bearer", 3600))
        rule.runOnIdle { nav.navigate(Rotas.FEED) { popUpTo(0) { inclusive = true } } }
        rule.waitForIdle()
        rule.onNodeWithText("Candidaturas").performClick()
        rule.waitForIdle()
        rule.onNodeWithText("FUNCAO PRIVADA DA CONTA A").assertDoesNotExist()
    }
}
