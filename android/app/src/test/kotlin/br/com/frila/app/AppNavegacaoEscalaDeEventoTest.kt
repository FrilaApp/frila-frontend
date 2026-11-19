package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.EstabelecimentoDaContaDto
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.MeuEstabelecimentoDto
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.perfil.EstadoPerfil
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.StatusPerfil
import br.com.frila.feature.vagas.escala.EscalaDeEventoViewModel
import br.com.frila.feature.vagas.escala.TextosEscala
import br.com.frila.feature.vagas.publicacao.EstabelecimentoDaVaga
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Pedido 18-02: a escala de evento existe no grafo, a entrada do Perfil só aparece para quem é de uma casa e a rota leva a casa lida do servidor. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AppNavegacaoEscalaDeEventoTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // C0-6b: testReleaseUnitTest

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private lateinit var nav: NavHostController
    private val casasRecebidas = mutableListOf<EstabelecimentoDaVaga>()
    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } returns false
    }

    private fun contratanteCom(vararg ids: String): ServicoMembros = mockk {
        coEvery { listarMeusEstabelecimentos() } returns
            ids.map { EstabelecimentoDaContaDto(id = it, nome = "Casa $it", papel = "operador") }
        coEvery { meuEstabelecimento(any()) } answers {
            MeuEstabelecimentoDto(firstArg(), "Bar da Lia", "food_service", "CLS 408, Bloco B, Loja 12", "Plano Piloto", CoordenadaDto(-15.7942, -47.8822), "operador")
        }
    }

    private fun montar(servicoMembros: ServicoMembros?, inicio: String) {
        val entrada = mockk<EntradaViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoEntrada()) }
        val perfil = mockk<PerfilViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoPerfil(status = StatusPerfil.SUCESSO)) }
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        single<ArmazenamentoDeSessao> { sessao }
                        viewModel { entrada }
                        viewModel { perfil }
                        viewModel { (estabelecimento: EstabelecimentoDaVaga) ->
                            casasRecebidas += estabelecimento
                            EscalaDeEventoViewModel(
                                estabelecimento = estabelecimento,
                                buscarFuncoes = { listOf(FuncaoDto("f1", "Garçom", "Salão")) },
                                enviarEscala = { error("não deveria publicar") },
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
                    biometriaHabilitada = true,
                    servicoMembros = servicoMembros,
                )
            }
        }
        rule.runOnIdle { nav.navigate(inicio) }
    }

    private fun esperarTexto(texto: String) {
        rule.waitUntil(5_000) { rule.onAllNodesWithText(texto).fetchSemanticsNodes().isNotEmpty() }
    }

    @Test
    fun perfilDeMembroMostraPublicarEscalaEAbreARotaComOIdDaCasa() {
        montar(contratanteCom("casa-1", "casa-2"), Rotas.PERFIL)

        rule.waitUntil(5_000) { rule.onAllNodesWithTag(ENTRADA_PUBLICAR_ESCALA).fetchSemanticsNodes().isNotEmpty() }
        rule.onNodeWithTag(ENTRADA_PUBLICAR_ESCALA).performScrollTo().performClick()

        rule.runOnIdle {
            assertEquals(Rotas.PUBLICAR_ESCALA, nav.currentDestination?.route)
            assertEquals("casa-1", nav.currentBackStackEntry?.arguments?.getString("estabelecimentoId"))
        }
        esperarTexto(TextosEscala.TITULO)
    }

    @Test
    fun rotaDaEscalaLevaAoViewModelACasaLidaDoServidor() {
        montar(contratanteCom("casa-1"), Rotas.publicarEscala("casa-1"))

        esperarTexto(TextosEscala.TITULO)

        rule.runOnIdle {
            assertEquals(
                listOf(EstabelecimentoDaVaga("casa-1", "CLS 408, Bloco B, Loja 12", "Plano Piloto", CoordenadaDto(-15.7942, -47.8822))),
                casasRecebidas,
            )
        }
        esperarTexto(TextosEscala.ENDERECO.format("CLS 408, Bloco B, Loja 12"))
    }

    @Test
    fun perfilDeProfissionalNaoMostraPublicarEscala() {
        val profissional = mockk<ServicoMembros> {
            coEvery { listarMeusEstabelecimentos() } throws ErroDaApi(CodigoErroAPI.PERFIL_INCOMPATIVEL, "perfil_incompativel", null, "x")
        }
        montar(profissional, Rotas.PERFIL)
        rule.waitForIdle()

        rule.onAllNodesWithTag(ENTRADA_PUBLICAR_ESCALA).assertCountEquals(0)
    }

    @Test
    fun quemNaoEMembroVeOMotivoESemTentarNovamente() {
        val membros = mockk<ServicoMembros> {
            coEvery { meuEstabelecimento(any()) } throws ErroDaApi(CodigoErroAPI.SEM_PERMISSAO, "sem_permissao", null, "x")
        }
        montar(membros, Rotas.publicarEscala("casa-9"))

        esperarTexto(TextosPublicarVagaDaRota.SEM_PERMISSAO)

        rule.onAllNodesWithText("Tentar novamente").assertCountEquals(0)
        assertTrue(casasRecebidas.isEmpty())
    }

    @Test
    fun falhaDeCargaOferecaTentarNovamente() {
        var chamadas = 0
        val membros = mockk<ServicoMembros> {
            coEvery { meuEstabelecimento(any()) } answers {
                if (++chamadas == 1) {
                    throw IllegalStateException("corpo não é JSON")
                } else {
                    MeuEstabelecimentoDto(firstArg(), "Bar", "food_service", "CLS 408", "Plano Piloto", CoordenadaDto(-15.79, -47.88), "operador")
                }
            }
        }
        montar(membros, Rotas.publicarEscala("casa-1"))

        esperarTexto(TextosPublicarVagaDaRota.FALHA)
        rule.onAllNodesWithText("Tentar novamente")[0].performClick()

        esperarTexto(TextosEscala.TITULO)
        assertEquals(2, chamadas)
    }
}
