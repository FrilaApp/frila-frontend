package br.com.frila.app

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.rede.StatusConectividade
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.perfil.ApresentacaoERegioesViewModel
import br.com.frila.feature.perfil.EstadoApresentacaoERegioes
import br.com.frila.feature.perfil.EtapaDaFoto
import br.com.frila.feature.perfil.FotoDePerfilViewModel
import br.com.frila.feature.perfil.TextosApresentacaoERegioes
import br.com.frila.feature.perfil.TextosDaFotoDePerfil
import br.com.frila.feature.vagas.feed.EstadoFeed
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.vagas.feed.StatusFeed
import io.mockk.every
import io.mockk.mockk
import java.io.File
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

/** L1-7c: as rotas "Apresentação e regiões" e "Foto de perfil" existem no grafo, e as chaves `perfil_rico` e `foto_de_perfil` (as do servidor) chegam até lá. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = android.app.Application::class)
class AppNavegacaoPerfilRicoTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste()

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private fun abrirRota(rota: String, vararg viewModels: org.koin.core.module.Module) {
        val armazenamento = mockk<ArmazenamentoDeSessao>(relaxed = true)
        every { armazenamento.estaAutenticado() } returns true
        every { armazenamento.isBiometriaAtivada() } returns false
        val feed = mockk<FeedVagasViewModel>(relaxed = true)
        every { feed.estado } returns MutableStateFlow(EstadoFeed(status = StatusFeed.SUCESSO))
        lateinit var navController: NavHostController
        rule.setContent {
            navController = rememberNavController()
            KoinApplication(application = {
                modules(
                    listOf(
                        module {
                            single { mockk<ServicoAutenticacao>(relaxed = true) }
                            single { armazenamento }
                            viewModel { EntradaViewModel(get()) }
                            viewModel { feed }
                        },
                    ) + viewModels,
                )
            }) {
                AppNavegacao(
                    armazenamentoDeSessao = armazenamento,
                    monitorDeConectividade = MonitorDeConectividadeFalso(StatusConectividade.CONECTADO),
                    navController = navController,
                    servicoMembros = null,
                )
            }
        }
        rule.waitForIdle()
        rule.runOnUiThread { navController.navigate(rota) }
        rule.waitForIdle()
    }

    @Test
    fun `a rota Apresentacao e regioes mostra a tela do ViewModel injetado`() {
        val vm = mockk<ApresentacaoERegioesViewModel>(relaxed = true)
        every { vm.estado } returns MutableStateFlow(EstadoApresentacaoERegioes())
        abrirRota(Rotas.APRESENTACAO, module { viewModel { vm } })
        rule.onNodeWithText(TextosApresentacaoERegioes.TITULO).assertExists()
    }

    @Test
    fun `a rota Foto de perfil mostra a tela com o botao de escolher`() {
        val vm = mockk<FotoDePerfilViewModel>(relaxed = true)
        every { vm.etapa } returns MutableStateFlow(EtapaDaFoto.Parada)
        abrirRota(Rotas.FOTO_DE_PERFIL, module { viewModel { vm } })
        rule.onNodeWithText(TextosDaFotoDePerfil.ESCOLHER_FOTO).assertExists()
    }

    @Test
    fun `as chaves perfil_rico e foto_de_perfil vao da MainActivity ao AppNavegacao e dali aos atalhos do perfil`() {
        val navegacao = File("src/main/kotlin/br/com/frila/app/AppNavegacao.kt").readText()
        val principal = File("src/main/kotlin/br/com/frila/app/MainActivity.kt").readText()
        listOf("perfilRicoHabilitado", "fotoDePerfilHabilitada").forEach { chave ->
            assertTrue("$chave tem de estar no AppNavegacao", chave in navegacao)
            assertTrue("$chave tem de ser passada pela MainActivity", chave in principal)
        }
        assertTrue("o atalho da apresentação tem de abrir a rota", "aoAbrirApresentacao = " in navegacao && "Rotas.APRESENTACAO" in navegacao)
        assertTrue("o atalho da foto tem de abrir a rota", "aoAbrirFotoDePerfil = " in navegacao && "Rotas.FOTO_DE_PERFIL" in navegacao)
    }
}
