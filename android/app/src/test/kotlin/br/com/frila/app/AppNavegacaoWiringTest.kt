package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.rede.StatusConectividade
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.perfil.EstadoPerfil
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.VerificacaoIdentidadeViewModel
import br.com.frila.feature.perfil.EstadoVerificacaoIdentidade
import br.com.frila.feature.perfil.StatusPerfil
import br.com.frila.feature.turnos.MeusTurnosViewModel
import br.com.frila.feature.vagas.feed.EstadoFeed
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.vagas.feed.StatusFeed
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
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

private const val MENSAGEM_OFFLINE = "Sem conexão com a internet. Verifique sua rede."

private fun armazenamentoSemSessao(): ArmazenamentoDeSessao {
    val armazenamento = mockk<ArmazenamentoDeSessao>()
    every { armazenamento.estaAutenticado() } returns false
    // AppNavegacao constrói o GuardaBiometrico incondicionalmente, não só no ramo autenticado.
    every { armazenamento.isBiometriaAtivada() } returns false
    return armazenamento
}

/**
 * RNF01 (ressalva do Shisui, PR #604) e RN15 (Cartão 69): prova as amarrações reais de
 * navegação e segurança em [AppNavegacao].
 *
 * `KoinApplication(application = { modules(...) })` em vez de `startKoin`/`stopKoin` globais:
 * o `GlobalContext` do Koin é um singleton de JVM — MEDIDO: dois `@Test` usando `startKoin`/
 * `stopKoin` globais nesta suíte produziam `ClosedScopeException` de forma não-determinística
 * (ora na primeira classe, ora na segunda), porque o `Test` do Gradle reusa a mesma JVM para
 * várias classes de teste. `KoinApplication` cria uma instância de Koin isolada por composição,
 * via `CompositionLocal`, sem tocar o `GlobalContext` — elimina a interferência entre testes.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AppNavegacaoWiringTest {

    @get:Rule
    val rule = createComposeRule()

    private fun conteudoDeTeste(monitorDeConectividade: MonitorDeConectividadeFalso) {
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        single { mockk<ServicoAutenticacao>(relaxed = true) }
                        viewModel { EntradaViewModel(get()) }
                    },
                )
            }) {
                AppNavegacao(
                    armazenamentoDeSessao = armazenamentoSemSessao(),
                    monitorDeConectividade = monitorDeConectividade,
                )
            }
        }
    }

    @Test
    fun `banner aparece quando AppNavegacao recebe monitor SEM_CONEXAO`() {
        conteudoDeTeste(MonitorDeConectividadeFalso(StatusConectividade.SEM_CONEXAO))

        rule.onNodeWithText(MENSAGEM_OFFLINE).assertExists()
    }

    @Test
    fun `banner nao aparece quando AppNavegacao recebe monitor CONECTADO`() {
        conteudoDeTeste(MonitorDeConectividadeFalso(StatusConectividade.CONECTADO))

        rule.onNodeWithText(MENSAGEM_OFFLINE).assertDoesNotExist()
    }

    @Test
    fun `remover o listener do GuardaBiometrico no AppNavegacao quebra a interceptacao de rota protegida`() {
        val armazenamento = mockk<ArmazenamentoDeSessao>(relaxed = true)
        every { armazenamento.estaAutenticado() } returns true
        every { armazenamento.isBiometriaAtivada() } returns true

        lateinit var navController: NavHostController

        val feedViewModel = mockk<FeedVagasViewModel>(relaxed = true)
        every { feedViewModel.estado } returns MutableStateFlow(EstadoFeed(status = StatusFeed.SUCESSO))

        rule.setContent {
            navController = rememberNavController()
            KoinApplication(application = {
                modules(
                    module {
                        single { mockk<ServicoAutenticacao>(relaxed = true) }
                        single { armazenamento }
                        viewModel { EntradaViewModel(get()) }
                        viewModel { feedViewModel }
                    },
                )
            }) {
                AppNavegacao(
                    armazenamentoDeSessao = armazenamento,
                    monitorDeConectividade = MonitorDeConectividadeFalso(StatusConectividade.CONECTADO),
                    navController = navController,
                )
            }
        }
        rule.waitForIdle()

        // Estado inicial com biometria ativa: rotaInicial direciona para DESBLOQUEIO
        assertEquals(Rotas.DESBLOQUEIO, navController.currentDestination?.route)
        rule.onNodeWithText("Confirme sua identidade para continuar").assertExists()

        // Tenta navegar para rota protegida (FEED) com a sessão ainda bloqueada
        rule.runOnUiThread {
            navController.navigate(Rotas.FEED)
        }
        rule.waitForIdle()

        // COM o listener instalado por instalarGuardaBiometrico no AppNavegacao:
        // o listener intercepta e redireciona de volta para Rotas.DESBLOQUEIO.
        // SE o listener for removido do AppNavegacao (mutação):
        // o destino ficaria em Rotas.FEED e este teste falharia imediatamente!
        assertEquals(Rotas.DESBLOQUEIO, navController.currentDestination?.route)
        rule.onNodeWithText("Confirme sua identidade para continuar").assertExists()
    }

    @Test
    fun `deep link no AppNavegacao nao renderiza tela protegida antes do desbloqueio biometrico`() {
        val armazenamento = mockk<ArmazenamentoDeSessao>(relaxed = true)
        every { armazenamento.estaAutenticado() } returns true
        every { armazenamento.isBiometriaAtivada() } returns true

        lateinit var navController: NavHostController

        rule.setContent {
            navController = rememberNavController()
            KoinApplication(application = {
                modules(
                    module {
                        single { mockk<ServicoAutenticacao>(relaxed = true) }
                        single { armazenamento }
                        viewModel { EntradaViewModel(get()) }
                        viewModel { mockk<MeusTurnosViewModel>(relaxed = true) }
                    },
                )
            }) {
                AppNavegacao(
                    armazenamentoDeSessao = armazenamento,
                    monitorDeConectividade = MonitorDeConectividadeFalso(StatusConectividade.CONECTADO),
                    navController = navController,
                )
            }
        }
        rule.waitForIdle()

        // Simula navegação direta para rota protegida de turnos
        rule.runOnUiThread {
            navController.navigate(Rotas.MEUS_TURNOS)
        }
        rule.waitForIdle()

        // Interceptado para DESBLOQUEIO; conteúdo protegido não foi renderizado
        assertEquals(Rotas.DESBLOQUEIO, navController.currentDestination?.route)
        rule.onNodeWithText("Meus turnos").assertDoesNotExist()
        rule.onNodeWithText("Confirme sua identidade para continuar").assertExists()
    }

    @Test
    fun `entrar com outra conta na tela de desbloqueio chama liberarAposLimparSessao e permite login limpo`() {
        val armazenamento = mockk<ArmazenamentoDeSessao>(relaxed = true)
        every { armazenamento.estaAutenticado() } returns true
        every { armazenamento.isBiometriaAtivada() } returns true

        lateinit var navController: NavHostController

        rule.setContent {
            navController = rememberNavController()
            KoinApplication(application = {
                modules(
                    module {
                        single { mockk<ServicoAutenticacao>(relaxed = true) }
                        single { armazenamento }
                        viewModel { EntradaViewModel(get()) }
                    },
                )
            }) {
                AppNavegacao(
                    armazenamentoDeSessao = armazenamento,
                    monitorDeConectividade = MonitorDeConectividadeFalso(StatusConectividade.CONECTADO),
                    navController = navController,
                )
            }
        }
        rule.waitForIdle()

        assertEquals(Rotas.DESBLOQUEIO, navController.currentDestination?.route)

        // Clica em "Entrar com outra conta"
        rule.onNodeWithText("Entrar com outra conta").performClick()
        rule.waitForIdle()

        verify(exactly = 1) { armazenamento.limparSessao() }
        assertEquals(Rotas.ENTRADA, navController.currentDestination?.route)
        rule.onNodeWithText("Bem-vindo ao Frila").assertExists()
    }

    @Test
    fun `aoDeslogar no perfil chama liberarAposLimparSessao e redireciona para ENTRADA`() {
        val armazenamento = mockk<ArmazenamentoDeSessao>(relaxed = true)
        every { armazenamento.estaAutenticado() } returns true
        every { armazenamento.isBiometriaAtivada() } returns false

        lateinit var navController: NavHostController
        val feedViewModel = mockk<FeedVagasViewModel>(relaxed = true)
        every { feedViewModel.estado } returns MutableStateFlow(EstadoFeed(status = StatusFeed.SUCESSO))
        val perfilViewModel = mockk<PerfilViewModel>(relaxed = true)
        every { perfilViewModel.estado } returns MutableStateFlow(EstadoPerfil(status = StatusPerfil.SUCESSO))
        val seloViewModel = mockk<VerificacaoIdentidadeViewModel>(relaxed = true)
        every { seloViewModel.estado } returns MutableStateFlow(EstadoVerificacaoIdentidade())

        rule.setContent {
            navController = rememberNavController()
            KoinApplication(application = {
                modules(
                    module {
                        single { mockk<ServicoAutenticacao>(relaxed = true) }
                        single { armazenamento }
                        viewModel { EntradaViewModel(get()) }
                        viewModel { feedViewModel }
                        viewModel { perfilViewModel }
                        viewModel { seloViewModel }
                    },
                )
            }) {
                AppNavegacao(
                    armazenamentoDeSessao = armazenamento,
                    monitorDeConectividade = MonitorDeConectividadeFalso(StatusConectividade.CONECTADO),
                    navController = navController,
                )
            }
        }
        rule.waitForIdle()

        // Navega até o perfil
        rule.runOnUiThread {
            navController.navigate(Rotas.PERFIL)
        }
        rule.waitForIdle()

        assertEquals(Rotas.PERFIL, navController.currentDestination?.route)

        // Clica no botão "Sair da conta"
        rule.onNodeWithText("Sair da conta").performScrollTo().performClick()
        rule.waitForIdle()

        assertEquals(Rotas.ENTRADA, navController.currentDestination?.route)
        rule.onNodeWithText("Bem-vindo ao Frila").assertExists()
    }
}
