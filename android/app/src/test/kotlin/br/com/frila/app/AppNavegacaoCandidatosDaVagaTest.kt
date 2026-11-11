package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.rede.CandidatoDto
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.ResultadoConfirmacaoDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.vagas.candidatos.CandidatosDaVagaViewModel
import br.com.frila.feature.vagas.candidatos.TextosCandidatosDaVaga
import io.mockk.every
import io.mockk.mockk
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
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
 * Cartão 6LkwUVYr: a rota de candidatos existe no grafo, fica atrás da guarda biométrica e leva o que a
 * tela de origem sabe da vaga (id, posições abertas, início) até o ViewModel certo.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AppNavegacaoCandidatosDaVagaTest {

    @get:Rule
    val rule = createComposeRule()

    private lateinit var nav: NavHostController

    private class ParametrosRecebidos(val vagaId: String, val posicoesAbertas: Int?, val inicioDaVaga: Instant?)

    private val criados = mutableListOf<ParametrosRecebidos>()
    private val lidos = mutableListOf<String>()
    private val escolhidos = mutableListOf<String>()
    private var biometria = false
    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } answers { biometria }
    }

    private fun candidato(id: String, nome: String) = CandidatoDto(
        candidaturaId = id,
        profissional = PerfilPublicoDto(
            id = "p-$id", tipo = "profissional", nome = nome,
            reputacao = ReputacaoDto(positivas = 1, total = 1, turnosConsiderados = 1, turnosRealizados = 1),
        ),
        criadaEm = "2026-11-10T12:00:00Z",
    )

    private fun montar(inicio: String? = null) {
        val entrada = mockk<EntradaViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoEntrada())
        }
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        // A tela de desbloqueio (alvo do redirecionamento da guarda) lê a sessão do grafo.
                        single<ArmazenamentoDeSessao> { sessao }
                        viewModel { entrada }
                        viewModel { (vagaId: String, posicoesAbertas: Int?, inicioDaVaga: Instant?) ->
                            criados += ParametrosRecebidos(vagaId, posicoesAbertas, inicioDaVaga)
                            CandidatosDaVagaViewModel(
                                vagaId = vagaId,
                                buscar = { id -> lidos += id; listOf(candidato("c1", "Ana"), candidato("c2", "Beto")) },
                                escolher = { id -> escolhidos += id; ResultadoConfirmacaoDto("confirmada", "pos-1", "t1") },
                                posicoesAbertas = posicoesAbertas,
                                inicioDaVaga = inicioDaVaga,
                                escopo = CoroutineScope(Dispatchers.Unconfined),
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
                    servicoMembros = null,
                )
            }
        }
        inicio?.let { rule.runOnIdle { nav.navigate(it) } }
    }

    private fun rotaAtual() = nav.currentDestination?.route

    private fun esperarCandidatos() {
        rule.waitUntil(5_000) { rule.onAllNodesWithText("Ana").fetchSemanticsNodes().isNotEmpty() }
    }

    @Test
    fun `a rota de candidatos abre a tela, le a vaga do argumento e mostra os candidatos`() {
        montar(inicio = Rotas.candidatosDaVaga("vaga-9", posicoesAbertas = 2, inicioDaVaga = Instant.parse("2026-11-12T18:00:00Z")))

        esperarCandidatos()

        rule.runOnIdle {
            assertEquals(Rotas.CANDIDATOS_DA_VAGA, rotaAtual())
            assertEquals("vaga-9", nav.currentBackStackEntry?.arguments?.getString("vagaId"))
            assertEquals(listOf("vaga-9"), lidos)
        }
        rule.onNodeWithText(TextosCandidatosDaVaga.TITULO).assertExists()
        rule.onNodeWithText("Beto").assertExists()
    }

    @Test
    fun `posicoes abertas e inicio da vaga chegam ao ViewModel e viram o banner de prazo`() {
        montar(inicio = Rotas.candidatosDaVaga("vaga-9", posicoesAbertas = 2, inicioDaVaga = Instant.parse("2026-11-12T18:00:00Z")))

        esperarCandidatos()

        rule.runOnIdle {
            val recebido = criados.single()
            assertEquals("vaga-9", recebido.vagaId)
            assertEquals(2, recebido.posicoesAbertas)
            assertEquals(Instant.parse("2026-11-12T18:00:00Z"), recebido.inicioDaVaga)
        }
        rule.onNodeWithText("Escolha até 11/11/2026 às 15:00, quando a vaga fecha.").assertExists()
    }

    @Test
    fun `sem parametros opcionais o ViewModel recebe nulos e nao ha banner de prazo`() {
        montar(inicio = Rotas.candidatosDaVaga("vaga-9"))

        esperarCandidatos()

        rule.runOnIdle {
            assertNull(criados.single().posicoesAbertas)
            assertNull(criados.single().inicioDaVaga)
        }
        assertTrue(rule.onAllNodesWithText("Escolha até", substring = true).fetchSemanticsNodes().isEmpty())
    }

    @Test
    fun `parametros ilegiveis ou negativos viram nao informado em vez de chegar ao ViewModel`() {
        montar(inicio = "candidatos_da_vaga/vaga-9?posicoesAbertas=abc&inicioDaVaga=ontem")
        esperarCandidatos()
        rule.runOnIdle {
            assertNull(criados.single().posicoesAbertas)
            assertNull(criados.single().inicioDaVaga)
        }
    }

    @Test
    fun `posicoes negativas viram nao informado`() {
        montar(inicio = "candidatos_da_vaga/vaga-9?posicoesAbertas=-3")
        esperarCandidatos()
        rule.runOnIdle { assertNull(criados.single().posicoesAbertas) }
    }

    @Test
    fun `com uma posicao aberta escolher mostra o aviso da ultima posicao e confirmar chama a escolha`() {
        montar(inicio = Rotas.candidatosDaVaga("vaga-9", posicoesAbertas = 1))
        esperarCandidatos()

        rule.onNodeWithContentDescription("Escolher Ana").performClick()
        rule.onNodeWithText(
            "Você vai confirmar Ana nesta vaga. É a última posição: os outros candidatos serão avisados de que não foram escolhidos.",
        ).assertExists()
        rule.onNodeWithText(TextosCandidatosDaVaga.CONFIRMAR).performClick()

        rule.runOnIdle { assertEquals(listOf("c1"), escolhidos) }
        rule.onNodeWithText("Você confirmou Ana. Os outros candidatos foram avisados.").assertExists()
    }

    @Test
    fun `voltar devolve a tela anterior`() {
        montar(inicio = Rotas.candidatosDaVaga("vaga-9"))
        esperarCandidatos()

        rule.onNodeWithContentDescription(TextosCandidatosDaVaga.ROTULO_VOLTAR).performClick()

        rule.runOnIdle { assertEquals(Rotas.ENTRADA, rotaAtual()) }
    }

    @Test
    fun `id com caracteres especiais chega inteiro ao ViewModel`() {
        montar(inicio = Rotas.candidatosDaVaga("vaga com espaco"))
        esperarCandidatos()

        rule.runOnIdle { assertEquals("vaga com espaco", criados.single().vagaId) }
    }

    @Test
    fun `com biometria ativada a rota redireciona para o desbloqueio sem criar o ViewModel nem ler a vaga`() {
        biometria = true
        montar(inicio = Rotas.candidatosDaVaga("vaga-9", posicoesAbertas = 1))
        rule.waitForIdle()

        rule.runOnIdle {
            assertEquals(Rotas.DESBLOQUEIO, rotaAtual())
            assertTrue(criados.isEmpty())
            assertTrue(lidos.isEmpty())
        }
    }

    @Test
    fun `construtor de rota monta e codifica o caminho`() {
        assertEquals("candidatos_da_vaga/vaga-1", Rotas.candidatosDaVaga("vaga-1"))
        assertEquals("candidatos_da_vaga/vaga-1?posicoesAbertas=2", Rotas.candidatosDaVaga("vaga-1", posicoesAbertas = 2))
        assertEquals(
            "candidatos_da_vaga/vaga-1?inicioDaVaga=2026-11-12T18%3A00%3A00Z",
            Rotas.candidatosDaVaga("vaga-1", inicioDaVaga = Instant.parse("2026-11-12T18:00:00Z")),
        )
        assertEquals(
            "candidatos_da_vaga/vaga-1?posicoesAbertas=0&inicioDaVaga=2026-11-12T18%3A00%3A00Z",
            Rotas.candidatosDaVaga("vaga-1", 0, Instant.parse("2026-11-12T18:00:00Z")),
        )
        assertEquals("candidatos_da_vaga/a%20b", Rotas.candidatosDaVaga("a b"))
        assertEquals(
            "candidatos_da_vaga/{vagaId}?posicoesAbertas={posicoesAbertas}&inicioDaVaga={inicioDaVaga}",
            Rotas.CANDIDATOS_DA_VAGA,
        )
    }
}
