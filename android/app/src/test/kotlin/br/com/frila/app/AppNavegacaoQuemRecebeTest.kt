package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.InclusosDto
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.VagaAbertaDto
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.turnos.QuemRecebeDasVagas
import io.mockk.every
import io.mockk.mockk
import java.io.IOException
import kotlinx.coroutines.CompletableDeferred
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
 * Cartão rZF1F6ws (item 272): no turno confirmado, "Quem recebe" mostra o responsável do local (`vaga.responsavel_local`, lido do detalhe
 * da vaga pelo cache `QuemRecebeDasVagas`), como o iOS (`TelasDaCandidatura.swift:312-325`), e não o nome da casa; se a leitura falha, fica
 * o nome da casa. O contato da candidatura é descontinuado e não entra. Fora: o detalhe da vaga.
 *
 * JUnit: nenhum método devolve valor (um `@Test` que devolve valor é ignorado).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AppNavegacaoQuemRecebeTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // C0-6b: testReleaseUnitTest

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } returns false
    }

    private val vaga = VagaAbertaDto(
        id = "vaga-123",
        funcao = FuncaoDto(id = "f1", nome = "Garçom", categoria = "salao"),
        estabelecimento = PerfilPublicoDto("est-1", "estabelecimento", "Restaurante Panelinha", null, ReputacaoDto(30, 28, null, 28, 28)),
        inicioEm = "2026-11-21T18:00:00Z",
        fimEm = "2026-11-22T00:00:00Z",
        local = "CLN 402 Bloco B",
        regiaoAdministrativa = "Asa Norte",
        distanciaKm = 2.5,
        valorCentavos = 18000,
        posicoesAbertas = 1,
        inclusos = InclusosDto(incluiRefeicao = true, incluiTransporte = false, exigeMaterialProprio = false),
        modo = "urgencia",
    )

    private val lidas = mutableListOf<String>()

    private fun montar(ler: suspend (String) -> String?): NavHostController {
        lateinit var nav: NavHostController
        val cache = QuemRecebeDasVagas { id -> lidas += id; ler(id) }
        val entrada = mockk<EntradaViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoEntrada()) }
        rule.setContent {
            KoinApplication(application = { modules(module { viewModel { entrada } }) }) {
                nav = rememberNavController()
                AppNavegacao(
                    armazenamentoDeSessao = sessao,
                    monitorDeConectividade = MonitorDeConectividadeFalso(),
                    navController = nav,
                    quemRecebeDasVagas = cache,
                )
            }
        }
        // Como o `navegarComVaga` do app: navega e guarda a vaga serializada no `SavedStateHandle` da entrada nova.
        rule.runOnIdle {
            nav.navigate(Rotas.turnoConfirmado(vaga.id))
            nav.currentBackStackEntry?.savedStateHandle?.set(
                "vaga_aberta_json",
                ClienteSupabase.jsonFrila.encodeToString(VagaAbertaDto.serializer(), vaga),
            )
        }
        rule.waitForIdle()
        return nav
    }

    private val casa = "Quem recebe: Restaurante Panelinha"

    @Test
    fun `com o responsavel lido do detalhe da vaga, o turno confirmado diz quem recebe, e nao o nome da casa`() {
        montar { "Lia Souza" }

        rule.waitUntil(5_000) { rule.onAllNodesWithText("Quem recebe: Lia Souza").fetchSemanticsNodes().isNotEmpty() }
        rule.onNodeWithText("Quem recebe: Lia Souza").assertExists()
        rule.onAllNodesWithText(casa).assertCountEquals(0)
    }

    @Test
    fun `a leitura e da vaga do turno, uma so, pelo cache`() {
        montar { "Lia Souza" }
        rule.waitUntil(5_000) { rule.onAllNodesWithText("Quem recebe: Lia Souza").fetchSemanticsNodes().isNotEmpty() }

        assertEquals(listOf("vaga-123"), lidas)
    }

    @Test
    fun `sem responsavel no detalhe, fica o nome da casa`() {
        montar { null }
        rule.waitForIdle()

        rule.onNodeWithText(casa).assertExists()
    }

    @Test
    fun `responsavel em branco, fica o nome da casa`() {
        montar { "   " }
        rule.waitForIdle()

        rule.onNodeWithText(casa).assertExists()
    }

    @Test
    fun `leitura que falha, fica o nome da casa e o turno confirmado aparece do mesmo jeito`() {
        montar { throw IOException("sem rede") }
        rule.waitForIdle()

        rule.onNodeWithText(casa).assertExists()
        rule.onNodeWithText("Garçom, Restaurante Panelinha").assertExists()
    }

    @Test
    fun `enquanto a leitura nao volta mostra o nome da casa, e troca para o responsavel quando volta`() {
        val liberar = CompletableDeferred<Unit>()
        montar { liberar.await(); "Lia Souza" }
        rule.waitForIdle()
        rule.onNodeWithText(casa).assertExists()

        liberar.complete(Unit)

        rule.waitUntil(5_000) { rule.onAllNodesWithText("Quem recebe: Lia Souza").fetchSemanticsNodes().isNotEmpty() }
        rule.onAllNodesWithText(casa).assertCountEquals(0)
    }
}
