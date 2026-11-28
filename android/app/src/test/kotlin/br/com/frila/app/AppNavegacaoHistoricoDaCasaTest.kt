package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.rede.EstabelecimentoDaContaDto
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.perfil.EstadoPerfil
import br.com.frila.feature.perfil.HistoricoDeTurnosViewModel
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.StatusPerfil
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
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
 * rUFapFEL: o histórico de turnos da casa no grafo. A linha entra no Perfil de quem é membro de uma casa (administrador ou
 * operador, o servidor recusa quem não é), não aparece para conta sem casa, e abrir a linha leva ao histórico com o id da casa
 * e só o CSV.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class, qualifiers = "w411dp-h2400dp")
class AppNavegacaoHistoricoDaCasaTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste()

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private lateinit var nav: NavHostController
    private val idsDoHistorico = mutableListOf<String?>()
    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } returns false
    }

    private fun casa(id: String, papel: String) = EstabelecimentoDaContaDto(id = id, nome = "Casa $id", papel = papel)

    private fun membrosDe(vararg casas: EstabelecimentoDaContaDto): ServicoMembros = mockk {
        coEvery { listarMeusEstabelecimentos() } returns casas.toList()
    }

    private fun montar(servicoMembros: ServicoMembros, inicio: String) {
        val entrada = mockk<EntradaViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoEntrada()) }
        val perfil = mockk<PerfilViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoPerfil(status = StatusPerfil.SUCESSO)) }
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        single<ArmazenamentoDeSessao> { sessao }
                        viewModel { entrada }
                        viewModel { perfil }
                        viewModel { parametros ->
                            val id = parametros.getOrNull<String>()
                            idsDoHistorico += id
                            HistoricoDeTurnosViewModel(servicoTurnos = mockk<ServicoTurnos>(relaxed = true), estabelecimentoId = id)
                        }
                    },
                )
            }) {
                nav = rememberNavController()
                AppNavegacao(
                    armazenamentoDeSessao = sessao,
                    monitorDeConectividade = MonitorDeConectividadeFalso(),
                    navController = nav,
                    biometriaHabilitada = true,
                    servicoMembros = servicoMembros,
                    encerramentosDaSessao = MutableStateFlow(0),
                )
            }
        }
        rule.runOnIdle { nav.navigate(inicio) }
    }

    private fun esperarTag(tag: String) {
        rule.waitUntil(5_000) { rule.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty() }
    }

    @Test
    fun `o administrador de uma casa ve a linha do historico da casa`() {
        montar(membrosDe(casa("casa-1", "administrador")), Rotas.PERFIL)
        esperarTag(ENTRADA_HISTORICO_DA_CASA)
    }

    @Test
    fun `o operador, que nao ve a equipe, ve o historico da casa`() {
        montar(membrosDe(casa("casa-1", "operador")), Rotas.PERFIL)

        esperarTag(ENTRADA_HISTORICO_DA_CASA)
        rule.onAllNodesWithTag(ENTRADA_EQUIPE_DA_CASA).assertCountEquals(0)
    }

    @Test
    fun `contratante sem casa nao ve o historico da casa`() {
        montar(membrosDe(), Rotas.PERFIL)

        esperarTag(ENTRADA_TENHO_UM_CONVITE)
        rule.onAllNodesWithTag(ENTRADA_HISTORICO_DA_CASA).assertCountEquals(0)
    }

    @Test
    fun `abrir a linha leva ao historico com o id da casa e so o CSV`() {
        montar(membrosDe(casa("casa-7", "administrador")), Rotas.PERFIL)
        esperarTag(ENTRADA_HISTORICO_DA_CASA)

        rule.onNodeWithTag(ENTRADA_HISTORICO_DA_CASA).performScrollTo().performClick()
        esperarTag("historico-formato-csv")

        rule.onNodeWithTag("historico-formato-csv").assertIsDisplayed()
        rule.onAllNodesWithTag("historico-formato-pdf").assertCountEquals(0)
        assertEquals(listOf<String?>("casa-7"), idsDoHistorico)
    }
}
