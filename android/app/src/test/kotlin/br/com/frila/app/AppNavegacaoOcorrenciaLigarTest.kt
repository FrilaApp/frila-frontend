package br.com.frila.app

import android.app.Application
import android.content.Intent
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.dominio.modelo.MotivoOcorrencia
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.turnos.OcorrenciaTurnoViewModel
import br.com.frila.feature.turnos.TextosOcorrencia
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpStatusCode
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * Cartão wGwOqAWW (item 201): na rota real da Ocorrência, "Risco de segurança" leva ao discador de verdade. Abre a rota, escolhe
 * o motivo, toca "Ligar 190" e "Ligar 180" e confere o `ACTION_DIAL` com `tel:` e o número, que o app dispara pela navegação.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AppNavegacaoOcorrenciaLigarTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // C0-6b: testReleaseUnitTest

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private lateinit var nav: NavHostController
    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } returns false
    }

    private fun montar() {
        val entrada = mockk<EntradaViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoEntrada())
        }
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        viewModel { entrada }
                        viewModel { (turnoId: String) ->
                            OcorrenciaTurnoViewModel(
                                turnoId = turnoId,
                                servicoTurnos = ServicoTurnos(
                                    ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = MockEngine { respond("{}", HttpStatusCode.OK) }),
                                ),
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
                )
            }
        }
        rule.runOnIdle { nav.navigate(Rotas.ocorrencia("turno-1")) }
    }

    private fun discadorAberto(): Intent? = shadowOf(RuntimeEnvironment.getApplication()).nextStartedActivity

    @Test
    fun riscoDeSegurancaLevaAoDiscadorComOs190E180() {
        montar()
        rule.runOnIdle { assertEquals(Rotas.OCORRENCIA, nav.currentDestination?.route) }
        rule.onNodeWithText(MotivoOcorrencia.RISCO_SEGURANCA.descricao).performScrollTo().performClick()

        rule.onNodeWithText(TextosOcorrencia.LIGAR_190).performScrollTo().performClick()
        val ligou190 = discadorAberto()
        assertNotNull("tocar em Ligar 190 deve abrir o discador", ligou190)
        assertEquals(Intent.ACTION_DIAL, ligou190!!.action)
        assertEquals("tel:190", ligou190.data.toString())

        rule.onNodeWithText(TextosOcorrencia.LIGAR_180).performScrollTo().performClick()
        val ligou180 = discadorAberto()
        assertNotNull("tocar em Ligar 180 deve abrir o discador", ligou180)
        assertEquals(Intent.ACTION_DIAL, ligou180!!.action)
        assertEquals("tel:180", ligou180.data.toString())
        assertTrue(ligou180.flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0)
    }

    @Test
    fun outroMotivoNaoOfereceLigarNemAbreODiscador() {
        montar()

        rule.onNodeWithText(MotivoOcorrencia.OUTRO.descricao).performScrollTo().performClick()

        rule.onNodeWithText(TextosOcorrencia.LIGAR_190).assertDoesNotExist()
        assertNull(discadorAberto())
    }
}
