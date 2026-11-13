package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.turnos.EstadoMeusTurnos
import br.com.frila.feature.turnos.MeusTurnosViewModel
import br.com.frila.feature.turnos.StatusMeusTurnos
import br.com.frila.feature.turnos.TextosTurnoNaoEncontrado
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

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AppNavegacaoTurnoNaoEncontradoIntegracaoTest {

    @get:Rule
    val rule = createComposeRule()

    private lateinit var nav: NavHostController

    @Test
    fun rotaTurnoAvisoComTurnoAusenteExibeTelaTurnoNaoEncontradoERecupera() {
        val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
            every { estaAutenticado() } returns false
            every { isBiometriaAtivada() } returns false
        }
        val entrada = mockk<EntradaViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoEntrada())
        }
        val turnosViewModel = mockk<MeusTurnosViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(
                EstadoMeusTurnos(
                    status = StatusMeusTurnos.SUCESSO,
                    agendados = emptyList(),
                    historicoCompleto = emptyList(),
                ),
            )
            every { carregar() } returns mockk(relaxed = true)
        }

        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        viewModel { entrada }
                        viewModel { turnosViewModel }
                    },
                )
            }) {
                nav = rememberNavController()
                AppNavegacao(
                    armazenamentoDeSessao = sessao,
                    monitorDeConectividade = MonitorDeConectividadeFalso(),
                    navController = nav,
                )
            }
        }

        // Navega para o deep link / rota com um turno que não pertence à conta
        rule.runOnIdle {
            nav.navigate(Rotas.turnoAviso("turno-outro-usuario-123"))
        }

        // Prova que a TelaTurnoNaoEncontrado é renderizada
        rule.onNodeWithText(TextosTurnoNaoEncontrado.NAO_ENCONTRADO_TITULO)
            .assertIsDisplayed()

        rule.onNodeWithText(TextosTurnoNaoEncontrado.NAO_ENCONTRADO_MENSAGEM)
            .assertIsDisplayed()
        verify(exactly = 1) { turnosViewModel.carregar() }

        // Aciona o botão de recuperação "Ver meus turnos"
        rule.onNodeWithText(TextosTurnoNaoEncontrado.BOTAO_VER_MEUS_TURNOS)
            .performClick()

        // Prova que recuperou navegando para Meus Turnos
        rule.runOnIdle {
            assertEquals(Rotas.MEUS_TURNOS, nav.currentDestination?.route)
        }
        verify(exactly = 2) { turnosViewModel.carregar() }
    }
}
