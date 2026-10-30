package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.perfil.DisponibilidadeBiometrica
import io.mockk.mockk
import io.mockk.verify
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * RN15: gate real de desbloqueio de sessão quando a biometria está ativada. MEDIDO (Shisui,
 * PR #591): antes desta tela, `isBiometriaAtivada()` só pintava o toggle no perfil — nada
 * consumia a flag de verdade na reabertura do app.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class TelaDesbloqueioBiometricoTest {

    @get:Rule
    val rule = createComposeRule()

    @Test
    fun autenticacaoComSucessoChamaAoDesbloquearSemLimparSessao() {
        val armazenamento: ArmazenamentoDeSessao = mockk(relaxed = true)
        var desbloqueouChamado = false

        rule.setContent {
            FrilaTheme {
                TelaDesbloqueioBiometrico(
                    armazenamentoDeSessao = armazenamento,
                    aoDesbloquear = { desbloqueouChamado = true },
                    aoEntrarComOutraConta = {},
                    verificarDisponibilidadeBiometrica = { DisponibilidadeBiometrica.DISPONIVEL },
                    autenticarBiometria = { _, aoSucesso, _ -> aoSucesso() },
                )
            }
        }
        rule.waitForIdle()

        assertTrue(desbloqueouChamado)
        verify(exactly = 0) { armazenamento.limparSessao() }
    }

    @Test
    fun falhaNaAutenticacaoMostraErroEBotaoDeTentarDeNovo() {
        val armazenamento: ArmazenamentoDeSessao = mockk(relaxed = true)

        rule.setContent {
            FrilaTheme {
                TelaDesbloqueioBiometrico(
                    armazenamentoDeSessao = armazenamento,
                    aoDesbloquear = {},
                    aoEntrarComOutraConta = {},
                    verificarDisponibilidadeBiometrica = { DisponibilidadeBiometrica.DISPONIVEL },
                    autenticarBiometria = { _, _, aoErro -> aoErro("Não foi possível confirmar sua identidade.") },
                )
            }
        }
        rule.waitForIdle()

        rule.onNodeWithText("Não foi possível confirmar sua identidade.").assertIsDisplayed()
        rule.onNodeWithText("Desbloquear").assertIsDisplayed()
    }

    @Test
    fun entrarComOutraContaLimpaSessaoAntesDeNavegar() {
        val armazenamento: ArmazenamentoDeSessao = mockk(relaxed = true)
        var entrouComOutraConta = false

        rule.setContent {
            FrilaTheme {
                TelaDesbloqueioBiometrico(
                    armazenamentoDeSessao = armazenamento,
                    aoDesbloquear = {},
                    aoEntrarComOutraConta = { entrouComOutraConta = true },
                    verificarDisponibilidadeBiometrica = { DisponibilidadeBiometrica.DISPONIVEL },
                    autenticarBiometria = { _, _, aoErro -> aoErro("cancelado") },
                )
            }
        }
        rule.waitForIdle()

        rule.onNodeWithText("Entrar com outra conta").performClick()
        rule.waitForIdle()

        verify(exactly = 1) { armazenamento.limparSessao() }
        assertTrue(entrouComOutraConta)
    }

    @Test
    fun semHardwareDisponivelMostraBotaoDeDesbloquearManual() {
        val armazenamento: ArmazenamentoDeSessao = mockk(relaxed = true)
        var autenticarFoiChamado = false

        rule.setContent {
            FrilaTheme {
                TelaDesbloqueioBiometrico(
                    armazenamentoDeSessao = armazenamento,
                    aoDesbloquear = {},
                    aoEntrarComOutraConta = {},
                    verificarDisponibilidadeBiometrica = { DisponibilidadeBiometrica.SEM_HARDWARE },
                    autenticarBiometria = { _, _, _ -> autenticarFoiChamado = true },
                )
            }
        }
        rule.waitForIdle()

        // Sem hardware disponível, a tela não dispara o prompt sozinha na montagem.
        assertTrue(!autenticarFoiChamado)
        rule.onNodeWithText("Entrar com outra conta").assertIsDisplayed()
    }
}
