package br.com.frila.app

import android.app.Application
import android.net.Uri
import androidx.datastore.preferences.core.emptyPreferences
import kotlinx.coroutines.flow.flowOf
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ChamadaDetalheDto
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.EstabelecimentoDaContaDto
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.PerfilProfissionalDetalhadoDto
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.chamadas.profissional.ChamadaRecebidaViewModel
import br.com.frila.feature.chamadas.profissional.EditarServicosViewModel
import br.com.frila.feature.chamadas.profissional.PreferenciasChamadaViewModel
import br.com.frila.feature.chamadas.profissional.TextosChamadaProfissional
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.perfil.ApresentacaoERegioesViewModel
import br.com.frila.feature.perfil.EstadoApresentacaoERegioes
import br.com.frila.feature.perfil.EstadoPerfil
import br.com.frila.feature.perfil.EtapaDaFoto
import br.com.frila.feature.perfil.FotoDePerfilViewModel
import br.com.frila.feature.perfil.SituacaoDaFoto
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.StatusPerfil
import br.com.frila.feature.perfil.TextosApresentacaoERegioes
import br.com.frila.feature.perfil.TextosDaFotoDePerfil
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
 * Comportamento (pedido do O2): com a chave `foto_de_perfil` desligada a tela de foto não abre pelo perfil do profissional no Android (0 atalhos
 * `perfil-foto`, e a rota não é a atual); ligada, o atalho aparece e abre a tela. O mesmo para `perfil_rico` e "Apresentação e regiões". Só o
 * profissional vê os atalhos: contratante com casa não vê nenhum, mesmo com as chaves ligadas. Roda no [AppNavegacao] real, não no texto do código.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AppNavegacaoFotoDePerfilChaveTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // C0-6b: testReleaseUnitTest

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private lateinit var nav: NavHostController
    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } returns false
    }

    private fun montar(fotoDePerfil: Boolean, perfilRico: Boolean, servicoMembros: ServicoMembros? = null) {
        val entrada = mockk<EntradaViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoEntrada()) }
        val perfilVm = mockk<PerfilViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoPerfil(status = StatusPerfil.SUCESSO))
        }
        val fotoVm = mockk<FotoDePerfilViewModel>(relaxed = true) {
            every { etapa } returns MutableStateFlow(EtapaDaFoto.Parada)
            every { situacao } returns MutableStateFlow(SituacaoDaFoto())
        }
        val apresentacaoVm = mockk<ApresentacaoERegioesViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoApresentacaoERegioes())
        }
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        single { PreferenciasAparencia(mockk { every { data } returns flowOf(emptyPreferences()) }) }
                        viewModel { entrada }
                        viewModel { perfilVm }
                        viewModel { fotoVm }
                        viewModel { apresentacaoVm }
                    },
                )
            }) {
                nav = rememberNavController()
                AppNavegacao(
                    armazenamentoDeSessao = sessao,
                    monitorDeConectividade = MonitorDeConectividadeFalso(),
                    navController = nav,
                    fotoDePerfilHabilitada = fotoDePerfil,
                    perfilRicoHabilitado = perfilRico,
                    servicoMembros = servicoMembros,
                )
            }
        }
        rule.runOnIdle { nav.navigate(Rotas.PERFIL) }
        rule.waitForIdle()
    }

    private fun rotaAtual() = nav.currentDestination?.route

    @Test
    fun comAChaveDaFotoDesligadaOPerfilNaoTemOAtalhoEATelaDeFotoNaoAbre() {
        montar(fotoDePerfil = false, perfilRico = true)

        rule.onAllNodesWithTag("perfil-foto").assertCountEquals(0)
        rule.onAllNodesWithText(TextosDaFotoDePerfil.ESCOLHER_FOTO).assertCountEquals(0)
        rule.runOnIdle { assertEquals(Rotas.PERFIL, rotaAtual()) }
    }

    @Test
    fun comAChaveDaFotoLigadaOAtalhoApareceEAbreATelaDeFoto() {
        montar(fotoDePerfil = true, perfilRico = false)

        rule.onNodeWithTag("perfil-foto").performScrollTo().performClick()

        rule.runOnIdle { assertEquals(Rotas.FOTO_DE_PERFIL, rotaAtual()) }
        rule.onNodeWithText(TextosDaFotoDePerfil.ESCOLHER_FOTO).assertExists()
    }

    @Test
    fun comAChavePerfilRicoDesligadaNaoHaAtalhoDeApresentacao() {
        montar(fotoDePerfil = false, perfilRico = false)
        rule.onAllNodesWithTag("perfil-apresentacao").assertCountEquals(0)
    }

    @Test
    fun comAChavePerfilRicoLigadaOAtalhoDeApresentacaoAbreATela() {
        montar(fotoDePerfil = false, perfilRico = true)

        rule.onNodeWithTag("perfil-apresentacao").performScrollTo().performClick()

        rule.runOnIdle { assertEquals(Rotas.APRESENTACAO, rotaAtual()) }
        rule.onNodeWithText(TextosApresentacaoERegioes.TITULO).assertExists()
    }

    @Test
    fun contratanteComCasaNaoVeOsAtalhosDoProfissionalMesmoComAsChavesLigadas() {
        val membros = mockk<ServicoMembros> {
            coEvery { listarMeusEstabelecimentos() } returns
                listOf(EstabelecimentoDaContaDto(id = "casa-1", nome = "Casa 1", papel = "administrador"))
        }
        montar(fotoDePerfil = true, perfilRico = true, servicoMembros = membros)

        rule.onAllNodesWithTag("perfil-foto").assertCountEquals(0)
        rule.onAllNodesWithTag("perfil-apresentacao").assertCountEquals(0)
        abrirAparencia()
    }

    @Test fun profissionalAbreAparenciaSemChavesDePerfil() {
        montar(fotoDePerfil = false, perfilRico = false)
        abrirAparencia()
    }

    private fun abrirAparencia() {
        rule.onNodeWithTag("perfil-aparencia").performScrollTo().performClick()
        rule.waitForIdle()
        rule.runOnIdle { assertEquals(Rotas.APARENCIA, rotaAtual()) }
        rule.onAllNodesWithText("Claro").assertCountEquals(1)
        rule.onAllNodesWithText("Escuro").assertCountEquals(1)
    }
}
