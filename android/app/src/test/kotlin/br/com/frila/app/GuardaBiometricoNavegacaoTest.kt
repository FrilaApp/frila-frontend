package br.com.frila.app

import android.app.Application
import androidx.compose.material3.Text
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

private const val ROTA_PROTEGIDA = "protegida_de_teste"

/**
 * Integração real com `NavHostController` (RN15, MEDIDO Shisui PR #591): prova que
 * [instalarGuardaBiometrico] intercepta QUALQUER mudança de destino — não só a decidida por
 * `rotaInicial()` — exatamente o mecanismo que um deep link usa para entrar numa rota
 * autenticada pulando a tela de abertura. Grafo mínimo com rotas falsas (não as telas reais do
 * app, que exigiriam Koin completo) — o que está sob teste é o listener, não as telas.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class GuardaBiometricoNavegacaoTest {

    @get:Rule
    val rule = createComposeRule()

    private fun montarGrafoDeTeste(guarda: GuardaBiometrico, destinoInicial: String): NavHostController {
        lateinit var navController: NavHostController
        rule.setContent {
            navController = rememberNavController()
            DisposableEffect(navController) {
                val listener = instalarGuardaBiometrico(navController, guarda)
                onDispose { navController.removeOnDestinationChangedListener(listener) }
            }
            NavHost(navController = navController, startDestination = destinoInicial) {
                composable(ROTA_PROTEGIDA) { Text("Protegida") }
                composable(Rotas.DESBLOQUEIO) { Text("Desbloqueio") }
                composable(Rotas.ENTRADA) { Text("Entrada") }
            }
        }
        rule.waitForIdle()
        return navController
    }

    @Test
    fun `entrada direta numa rota protegida com sessao travada e redirecionada para DESBLOQUEIO`() {
        val guarda = GuardaBiometrico(sessaoDesbloqueadaInicial = false)

        // Simula o efeito de um deep link: o NavHost abre diretamente na rota autenticada, sem
        // passar por rotaInicial()/ENTRADA — exatamente o caminho que o Shisui mediu no app real.
        val navController = montarGrafoDeTeste(guarda, destinoInicial = ROTA_PROTEGIDA)

        assertEquals(Rotas.DESBLOQUEIO, navController.currentDestination?.route)
    }

    @Test
    fun `entrada na mesma rota protegida com sessao ja desbloqueada nao e redirecionada`() {
        val guarda = GuardaBiometrico(sessaoDesbloqueadaInicial = true)

        val navController = montarGrafoDeTeste(guarda, destinoInicial = ROTA_PROTEGIDA)

        assertEquals(ROTA_PROTEGIDA, navController.currentDestination?.route)
    }

    @Test
    fun `entrada pela rota ENTRADA nunca e redirecionada, mesmo travada`() {
        val guarda = GuardaBiometrico(sessaoDesbloqueadaInicial = false)

        val navController = montarGrafoDeTeste(guarda, destinoInicial = Rotas.ENTRADA)

        assertEquals(Rotas.ENTRADA, navController.currentDestination?.route)
    }
}
