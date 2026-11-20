package br.com.frila.app

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.PerfilProfissionalDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.rede.ServicoConta
import br.com.frila.core.rede.ServicoPerfil
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.StatusConectividade
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.perfil.EstadoPerfil
import br.com.frila.feature.perfil.EstadoTelaHistorico
import br.com.frila.feature.perfil.HistoricoDeTurnosViewModel
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.StatusPerfil
import io.mockk.every
import io.mockk.mockk
import java.time.LocalDate
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

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = android.app.Application::class, qualifiers = "w411dp-h891dp")
class AppNavegacaoHistoricoTurnosTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste()

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private val estadoPerfil = MutableStateFlow(
        EstadoPerfil(
            status = StatusPerfil.SUCESSO,
            perfil = PerfilProfissionalDto(
                id = "p-1",
                usuarioId = "u-1",
                funcoes = emptyList(),
                reputacao = ReputacaoDto(0, 0, null, 0, 0),
            ),
        ),
    )
    private val perfilVm = mockk<PerfilViewModel>(relaxed = true) {
        every { estado } returns estadoPerfil
    }

    private val hoje = LocalDate.of(2026, 10, 3)
    private val estadoHistorico = MutableStateFlow(
        EstadoTelaHistorico(
            inicioEscolhido = LocalDate.of(2026, 10, 1),
            fimEscolhido = hoje,
            hoje = hoje,
        ),
    )
    private val historicoVm = mockk<HistoricoDeTurnosViewModel>(relaxed = true) {
        every { estado } returns estadoHistorico
    }

    private lateinit var navController: NavHostController

    private fun abrirPerfil() {
        val entradaVm = mockk<EntradaViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoEntrada())
        }
        val armazenamento = mockk<ArmazenamentoDeSessao>(relaxed = true)
        every { armazenamento.estaAutenticado() } returns false
        every { armazenamento.isBiometriaAtivada() } returns false

        rule.setContent {
            navController = rememberNavController()
            KoinApplication(application = {
                modules(
                    module {
                        single { mockk<ServicoAutenticacao>(relaxed = true) }
                        single { mockk<ServicoPerfil>(relaxed = true) }
                        single { mockk<ServicoTurnos>(relaxed = true) }
                        single { mockk<ServicoVagas>(relaxed = true) }
                        single { mockk<ServicoConta>(relaxed = true) }
                        single { armazenamento }
                        viewModel { entradaVm }
                        viewModel { perfilVm }
                        viewModel { historicoVm }
                    },
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
        rule.runOnUiThread {
            navController.navigate(Rotas.PERFIL)
        }
        rule.waitForIdle()
    }

    @Test
    fun `atalho de historico de turnos no perfil navega para a tela correspondente e volta`() {
        abrirPerfil()

        rule.onNodeWithTag("perfil-historico-turnos").performScrollTo().performClick()
        rule.waitForIdle()

        val rotaAtual = rule.runOnUiThread<String?> { navController.currentDestination?.route }
        assertEquals(Rotas.HISTORICO_TURNOS, rotaAtual)
    }
}
