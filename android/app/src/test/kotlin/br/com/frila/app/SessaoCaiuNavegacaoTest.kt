package br.com.frila.app

import android.app.Application
import android.content.Intent
import android.net.Uri
import androidx.activity.ComponentActivity
import androidx.compose.ui.test.ComposeTimeoutException
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
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
import java.util.concurrent.atomic.AtomicInteger
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
 * C0-8 (achados N3 e N16 da auditoria A-001): a rota inicial era decidida uma vez e nada olhava a sessão
 * depois. Apagada (o Auth recusou o token, C0-2), a pessoa ficava nas telas de dentro vendo "Sua sessão
 * expirou" sem saída; e um link `frila://` aberto sem conta entrava direto numa tela que só falha. O iOS
 * observa o fim da sessão e volta à entrada (`FrilaApp.swift:519`, `SupabaseApiCliente.swift:749-761`).
 *
 * A sessão é a [SessaoComCacheVagas] do grafo de produção (o único [ArmazenamentoDeSessao] do Koin, por onde
 * passam o cliente de rede e o `CoordenadorDeLogout`); a navegação é a [AppNavegacao] real, que lê do Koin,
 * como no app, de onde vêm os avisos de sessão apagada.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class SessaoCaiuNavegacaoTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // C0-6b: testReleaseUnitTest

    @get:Rule(order = 1)
    val rule = createAndroidComposeRule<ComponentActivity>()

    private lateinit var nav: NavHostController

    private val sessao = SessaoComCacheVagas(ArmazenamentoDeSessaoEmMemoria(), CacheVagasDaSessao(raiz = null))

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
    private fun contarChegadasNaEntrada(): AtomicInteger {
        val chegadas = AtomicInteger()
        rule.runOnIdle {
            nav.addOnDestinationChangedListener { _, destino, _ -> if (destino.route == Rotas.ENTRADA) chegadas.incrementAndGet() }
        }
        return chegadas
    }

    @Test
    fun `sessao apagada numa tela de dentro leva a Entrada com a pilha limpa`() {
        montar()
        entrarNaConta()
        rule.runOnIdle { nav.navigate(Rotas.AJUDA) }
        rule.waitForIdle()
        assertEquals(Rotas.AJUDA, rotaAtual())

        // O Auth recusou o token: o cliente de rede apaga a sessão fora da thread principal (ClienteSupabase.renovarTokens).
        Thread { sessao.limparSessao() }.apply { start(); join() }

        assertTrue("a sessão apagada deixou a pessoa em ${rotaAtual()}", aguardar { rotaAtual() == Rotas.ENTRADA })
        assertNull("a pilha de dentro ficou embaixo da entrada", rotaAbaixo())
        rule.onNodeWithText("Bem-vindo ao Frila").assertExists()
    }

    @Test
    fun `link frila meus_turnos aberto sem sessao abre a Entrada`() {
        montar(link = "frila://meus_turnos")

        assertTrue("o link abriu ${rotaAtual()} sem sessão", aguardar { rotaAtual() == Rotas.ENTRADA })
        assertNull("o link deixou ${rotaAbaixo()} embaixo da entrada", rotaAbaixo())
    }

    @Test
    fun `controle - Sair da conta chega a Entrada uma vez so`() {
        montar()
        entrarNaConta()
        val chegadas = contarChegadasNaEntrada()

        rule.onNodeWithText("Sair da conta").performScrollTo().performClick()
        rule.waitForIdle()

        assertEquals(Rotas.ENTRADA, rotaAtual())
        assertNull(rotaAbaixo())
        assertEquals("a saída navegou mais de uma vez para a entrada", 1, chegadas.get())
    }

    @Test
    fun `controle - exclusao aceita pelo servidor chega a Entrada uma vez so`() {
        montar()
        entrarNaConta()
        rule.runOnIdle { nav.navigate(Rotas.EXCLUSAO_DE_CONTA) }
        rule.waitForIdle()
        val chegadas = contarChegadasNaEntrada()

        // A tela navega quando vê o resultado, e a sessão some no mesmo instante, em `aoConcluir`.
        rule.runOnIdle {
            exclusao.alterarConfirmacao(true)
            exclusao.confirmarExclusao()
        }
        rule.waitForIdle()

        assertEquals(Rotas.ENTRADA, rotaAtual())
        assertNull(rotaAbaixo())
        assertEquals("a exclusão navegou mais de uma vez para a entrada", 1, chegadas.get())
    }
}
