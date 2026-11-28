package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
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
 * Cartão UR07a5pG (item 273): a candidatura que perde a vaga (rotas VAGA_PREENCHIDA e VAGA_ENCERRADA) mostra os textos do iOS por extenso e
 * a "Vaga original" (casa, função, quando, onde, valor por pessoa), em vez da tela de vaga indisponível do aviso, sem o cartão da vaga.
 * Fora: o modo efetivo e a tela de conflito.
 *
 * JUnit: nenhum método devolve valor (um `@Test` que devolve valor é ignorado).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AppNavegacaoVagaPerdidaTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // C0-6b: testReleaseUnitTest

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } returns false
    }

    private var vagaModo = "urgencia"

    private val vaga get() = VagaAbertaDto(
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
        modo = vagaModo,
    )

    private fun montar(rota: String, vagaNaPilha: Boolean = true): NavHostController {
        lateinit var nav: NavHostController
        val entrada = mockk<EntradaViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoEntrada()) }
        rule.setContent {
            KoinApplication(application = { modules(module { viewModel { entrada } }) }) {
                nav = rememberNavController()
                AppNavegacao(armazenamentoDeSessao = sessao, monitorDeConectividade = MonitorDeConectividadeFalso(), navController = nav)
            }
        }
        rule.runOnIdle {
            nav.navigate(rota)
            if (vagaNaPilha) {
                nav.currentBackStackEntry?.savedStateHandle?.set(
                    "vaga_aberta_json",
                    ClienteSupabase.jsonFrila.encodeToString(VagaAbertaDto.serializer(), vaga),
                )
            }
        }
        rule.waitForIdle()
        return nav
    }

    private fun existe(texto: String) = rule.onAllNodesWithText(texto, substring = true).fetchSemanticsNodes().isNotEmpty()

    @Test
    fun `vaga preenchida em urgencia diz o que aconteceu e mostra a vaga original`() {
        montar(Rotas.vagaPreenchida(vaga.id))

        rule.onNodeWithText("Esta vaga já foi preenchida").assertExists()
        rule.onNodeWithText("Foi rápido: outra pessoa aceitou antes. Nada muda na sua reputação.").assertExists()
        rule.onNodeWithText("Vaga original").assertExists()
        rule.onNodeWithText("Restaurante Panelinha").assertExists()
        rule.onNodeWithText("Garçom").assertExists()
        rule.onNodeWithText("CLN 402 Bloco B").assertExists()
        assertTrue("o quando da vaga", existe("das 15:00 às 21:00"))
        assertTrue("o valor por pessoa", existe("180,00 por pessoa"))
        rule.onNodeWithTag("resultado-vaga-preenchida").assertExists()
    }

    @Test
    fun `vaga preenchida em selecao troca so a mensagem`() {
        vagaModo = "selecao"
        montar(Rotas.vagaPreenchida(vaga.id))

        rule.onNodeWithText("Esta vaga já foi preenchida").assertExists()
        rule.onNodeWithText("O estabelecimento já escolheu quem vai trabalhar nesta vaga.").assertExists()
        rule.onAllNodesWithText("Foi rápido: outra pessoa aceitou antes. Nada muda na sua reputação.").assertCountEquals(0)
        rule.onNodeWithText("Vaga original").assertExists()
    }

    @Test
    fun `vaga encerrada diz que foi encerrada e mostra a vaga original`() {
        montar(Rotas.vagaEncerrada(vaga.id))

        rule.onNodeWithText("Esta vaga foi encerrada").assertExists()
        rule.onNodeWithText("Esta vaga foi encerrada, cancelada ou o horário de início já passou.").assertExists()
        rule.onNodeWithText("Vaga original").assertExists()
        rule.onNodeWithText("Restaurante Panelinha").assertExists()
        assertTrue("o valor por pessoa", existe("180,00 por pessoa"))
        rule.onNodeWithTag("resultado-vaga-encerrada").assertExists()
    }

    @Test
    fun `sem a vaga em memoria fica a tela de vaga indisponivel do aviso, sem a vaga original`() {
        montar(Rotas.vagaPreenchida(vaga.id), vagaNaPilha = false)

        rule.onAllNodesWithText("Vaga original").assertCountEquals(0)
        rule.onNodeWithText("Vaga preenchida").assertExists()
    }
}
