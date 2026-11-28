package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.dominio.modelo.AlvoBloqueado
import br.com.frila.core.dominio.modelo.BloqueiosDaSessao
import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.rede.MembroDaEquipeDto
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.PainelDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.PosicaoNoPainelDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.VagaNoPainelDto
import br.com.frila.core.rede.VagaResumoDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.equipe.IncluirNaEquipeViewModel
import br.com.frila.feature.equipe.TextosEquipe
import br.com.frila.feature.turnos.contratante.AcompanhamentoContratanteViewModel
import br.com.frila.feature.turnos.contratante.ContextoDoTurnoContratante
import br.com.frila.feature.turnos.contratante.TextosTurnoDoContratante
import io.mockk.coEvery
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
 * I1PonzKJ, fatia 2: o turno do contratante lê o conjunto da sessão. Presença verificada oferece "Incluir na equipe"; se a casa bloqueou o
 * profissional (D-14 do iOS: não oferecer incluir na equipe profissional bloqueado), o bloco some e a tela diz que ele foi bloqueado.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class, qualifiers = "w411dp-h2400dp")
class AppNavegacaoTurnoDoContratanteBloqueadoTest {

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

    private val painel = PainelDto(
        estabelecimentoId = "est-1",
        checkinsPendentes = emptyList(),
        vagas = listOf(
            VagaNoPainelDto(
                vaga = VagaResumoDto("v1", "Garçom", "SQN 108", "Asa Norte", "2026-11-12T21:00:00Z", "2026-11-13T03:00:00Z", 16_000),
                modo = "urgencia", estado = "publicada", oculta = false, alertaVagaVazia = false, candidatosPendentes = 0,
                posicoes = listOf(
                    PosicaoNoPainelDto(
                        id = "p1", estado = "confirmada", turnoId = "t1", verificacao = "verificado", emAtraso = false,
                        checkinEm = "2026-11-12T21:02:00Z", checkinTipo = "manual",
                        profissional = PerfilPublicoDto("pr1", "profissional", "Ana", reputacao = ReputacaoDto(1, 1, null, 1, 1)),
                    ),
                ),
            ),
        ),
    )

    private fun montar(registrarOConjunto: Boolean = true) {
        val entrada = mockk<EntradaViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoEntrada()) }
        val servicoVagas = mockk<ServicoVagas> { coEvery { painelEstabelecimento(any(), any(), any()) } returns Result.success(painel) }
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        single<ArmazenamentoDeSessao> { sessao }
                        if (registrarOConjunto) single { bloqueios }
                        viewModel { entrada }
                        viewModel { (contexto: ContextoDoTurnoContratante) ->
                            AcompanhamentoContratanteViewModel(
                                contexto = contexto, confirmar = { error("nao confirma") }, escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                        viewModel { (estabelecimentoId: String, profissionalId: String) ->
                            IncluirNaEquipeViewModel(
                                estabelecimentoId = estabelecimentoId, profissionalId = profissionalId,
                                listar = { emptyList() },
                                incluirMembro = { e, p -> MembroDaEquipeDto(e, p) },
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                    },
                )
            }) {
                nav = rememberNavController()
                AppNavegacao(
                    armazenamentoDeSessao = sessao, monitorDeConectividade = MonitorDeConectividadeFalso(), navController = nav,
                    biometriaHabilitada = true, servicoMembros = null, servicoVagas = servicoVagas,
                )
            }
        }
        rule.runOnIdle { nav.navigate(Rotas.turnoDoContratante("est-1", "v1", "p1")) }
        rule.waitUntil(5_000) { rule.onAllNodesWithText("Garçom").fetchSemanticsNodes().isNotEmpty() }
    }

    private fun incluirNaEquipeVisivel() = rule.onAllNodesWithText(TextosEquipe.INCLUIR).fetchSemanticsNodes().isNotEmpty()

    @Test
    fun `com presenca verificada e sem bloqueio, o turno oferece Incluir na equipe e nao diz que bloqueou`() {
        montar()

        rule.waitUntil(5_000) { incluirNaEquipeVisivel() }
        assertEquals(0, rule.onAllNodesWithText(TextosTurnoDoContratante.VOCE_BLOQUEOU_PROFISSIONAL).fetchSemanticsNodes().size)
    }

    @Test
    fun `profissional ja bloqueado na sessao, some o Incluir na equipe e a tela diz que foi bloqueado`() {
        bloqueios.registrar(AlvoBloqueado(TipoDeAlvo.PROFISSIONAL, "pr1"))
        montar()

        rule.onNodeWithText(TextosTurnoDoContratante.VOCE_BLOQUEOU_PROFISSIONAL).performScrollTo().assertIsDisplayed()
        assertEquals(false, incluirNaEquipeVisivel())
    }

    @Test
    fun `bloquear com o turno aberto troca o Incluir na equipe pelo aviso, sem recarregar`() {
        montar()
        rule.waitUntil(5_000) { incluirNaEquipeVisivel() }

        rule.runOnIdle { bloqueios.registrar(AlvoBloqueado(TipoDeAlvo.PROFISSIONAL, "pr1")) }

        rule.waitUntil(5_000) { !incluirNaEquipeVisivel() }
        rule.onNodeWithText(TextosTurnoDoContratante.VOCE_BLOQUEOU_PROFISSIONAL).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun `um grafo sem o conjunto registrado segue oferecendo Incluir na equipe`() {
        montar(registrarOConjunto = false)

        rule.waitUntil(5_000) { incluirNaEquipeVisivel() }
    }
}
