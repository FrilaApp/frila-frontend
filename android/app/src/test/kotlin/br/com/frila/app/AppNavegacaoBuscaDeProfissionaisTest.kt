package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.EstabelecimentoDaContaDto
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.MeuEstabelecimentoDto
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.chamadas.casa.BuscaDeProfissionaisViewModel
import br.com.frila.feature.chamadas.casa.HorarioDaBusca
import br.com.frila.feature.chamadas.casa.RascunhoDeVagaDaBusca
import br.com.frila.feature.chamadas.casa.TextosChamadaCasa
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.perfil.EstadoPerfil
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.StatusPerfil
import br.com.frila.feature.vagas.publicacao.EstabelecimentoDaVaga
import br.com.frila.feature.vagas.publicacao.PublicarVagaViewModel
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertThrows
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Busca de profissionais (tela PROVISÓRIA, F-036.6): o atalho do Perfil e as rotas só existem com a chave
 * `busca_profissionais`; a busca vazia leva ao "Publicar para todos" já com o serviço e o horário buscados.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AppNavegacaoBuscaDeProfissionaisTest {

    @get:Rule
    val rule = createComposeRule()

    private lateinit var nav: NavHostController
    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } returns false
    }
    private val garcom = FuncaoDto("f-garcom", "Garçom", "salao")
    private val buscasCriadas = mutableListOf<String>()
    private var publicacao: PublicarVagaViewModel? = null

    private fun membros(): ServicoMembros = mockk {
        coEvery { listarMeusEstabelecimentos() } returns listOf(EstabelecimentoDaContaDto(id = "casa-1", nome = "Casa 1", papel = "administrador"))
        coEvery { meuEstabelecimento("casa-1") } returns MeuEstabelecimentoDto(
            id = "casa-1", nome = "Casa 1", tipo = "restaurante", endereco = "SCS Quadra 2",
            regiaoAdministrativa = "Plano Piloto", ponto = CoordenadaDto(-15.79, -47.88), papel = "administrador",
        )
    }

    private fun montar(busca: Boolean, servicoMembros: ServicoMembros? = membros(), inicio: String? = null) {
        val entrada = mockk<EntradaViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoEntrada())
        }
        val perfil = mockk<PerfilViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoPerfil(status = StatusPerfil.SUCESSO))
        }
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        viewModel { entrada }
                        viewModel { perfil }
                        viewModel { (estabelecimentoId: String) ->
                            buscasCriadas += estabelecimentoId
                            BuscaDeProfissionaisViewModel(
                                estabelecimentoId = estabelecimentoId,
                                recursoHabilitado = { true },
                                buscarProfissionais = { error("não deveria buscar") },
                                chamarProfissional = { error("não deveria chamar") },
                                listarFuncoes = { listOf(garcom) },
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                        viewModel { (estabelecimento: EstabelecimentoDaVaga) ->
                            PublicarVagaViewModel(
                                estabelecimento = estabelecimento,
                                buscarFuncoes = { listOf(garcom) },
                                enviarVaga = { error("não deveria publicar") },
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            ).also { publicacao = it }
                        }
                    },
                )
            }) {
                nav = rememberNavController()
                AppNavegacao(
                    armazenamentoDeSessao = sessao,
                    monitorDeConectividade = MonitorDeConectividadeFalso(),
                    navController = nav,
                    buscaProfissionaisHabilitada = busca,
                    servicoMembros = servicoMembros,
                )
            }
        }
        inicio?.let { rule.runOnIdle { nav.navigate(it) } }
    }

    private fun rotaAtual() = nav.currentDestination?.route

    @Test
    fun comAChaveLigadaOPerfilDaCasaMostraEncontrarProfissionalEAbreABuscaDaCasa() {
        montar(busca = true, inicio = Rotas.PERFIL)

        rule.waitUntil(5_000) { rule.onAllNodesWithTag("perfil-encontrar-profissional").fetchSemanticsNodes().isNotEmpty() }
        rule.onNodeWithTag("perfil-encontrar-profissional").performScrollTo().performClick()

        rule.runOnIdle {
            assertEquals(RotasChamadaCasa.BUSCA, rotaAtual())
            assertEquals(listOf("casa-1"), buscasCriadas)
        }
        rule.onNodeWithTag("busca-buscar").assertExists()
        rule.onNodeWithText(TextosChamadaCasa.BUSCA_TITULO).assertExists()
    }

    @Test
    fun comAChaveDesligadaNaoHaAtalhoNemRota() {
        montar(busca = false, inicio = Rotas.PERFIL)
        rule.waitForIdle()

        rule.onAllNodesWithTag("perfil-encontrar-profissional").assertCountEquals(0)
        rule.runOnIdle {
            assertThrows(IllegalArgumentException::class.java) { nav.navigate(RotasChamadaCasa.buscar("casa-1")) }
            assertThrows(IllegalArgumentException::class.java) {
                nav.navigate(RotasChamadaCasa.publicarDaBusca(RascunhoDeVagaDaBusca("casa-1", garcom.id)))
            }
        }
    }

    @Test
    fun quemNaoTemCasaNaoVeOAtalhoMesmoComAChaveLigada() {
        montar(busca = true, servicoMembros = null, inicio = Rotas.PERFIL)
        rule.waitForIdle()

        rule.onAllNodesWithTag("perfil-encontrar-profissional").assertCountEquals(0)
    }

    @Test
    fun publicarParaTodosAbreAPublicacaoJaComOServicoEOHorarioDaBusca() {
        val horario = HorarioDaBusca(Instant.parse("2030-01-02T12:00:00Z"), Instant.parse("2030-01-02T16:00:00Z"))
        montar(busca = true, inicio = RotasChamadaCasa.publicarDaBusca(RascunhoDeVagaDaBusca("casa-1", garcom.id, horario = horario)))

        rule.waitUntil(5_000) { publicacao != null }
        rule.waitUntil(5_000) { publicacao?.estado?.value?.funcaoId != null }
        rule.runOnIdle {
            val estado = publicacao!!.estado.value
            assertEquals(garcom.id, estado.funcaoId)
            assertEquals(horario.inicio, estado.inicio)
            assertEquals(horario.fim, estado.fim)
            assertNotNull(rotaAtual())
            assertEquals(RotasChamadaCasa.PUBLICAR_DA_BUSCA, rotaAtual())
        }
    }

    @Test
    fun publicarParaTodosSemHorarioMantemOHorarioPadraoDaPublicacao() {
        montar(busca = true, inicio = RotasChamadaCasa.publicarDaBusca(RascunhoDeVagaDaBusca("casa-1", garcom.id)))

        rule.waitUntil(5_000) { publicacao?.estado?.value?.funcaoId != null }
        rule.runOnIdle {
            val estado = publicacao!!.estado.value
            assertEquals(garcom.id, estado.funcaoId)
            assertEquals(true, estado.fim.isAfter(estado.inicio))
        }
    }
}
