package br.com.frila.app.capturas.r1

import android.app.Application
import androidx.compose.ui.test.junit4.createComposeRule
import br.com.frila.app.RegistraActivityDeTeste
import br.com.frila.app.TelaDesbloqueioBiometrico
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.perfil.DisponibilidadeBiometrica
import io.mockk.mockk
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** Prints da tela de desbloqueio por biometria (lote R1), no claro. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], application = Application::class, qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasR1DesbloqueioTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste()

    @get:Rule(order = 1)
    val compose = createComposeRule()

    private fun tela(disponibilidade: DisponibilidadeBiometrica, erro: String?) = compose.setContent {
        FrilaTheme(temaEscuro = false) {
            TelaDesbloqueioBiometrico(
                aoDesbloquear = {},
                aoEntrarComOutraConta = {},
                armazenamentoDeSessao = mockk<ArmazenamentoDeSessao>(relaxed = true),
                verificarDisponibilidadeBiometrica = { disponibilidade },
                autenticarBiometria = { _, _, aoErro -> erro?.let(aoErro) },
            )
        }
    }

    @Test
    fun `01 desbloqueio - falhou e tenta de novo`() {
        tela(DisponibilidadeBiometrica.DISPONIVEL, "Não foi possível confirmar sua identidade.")
        compose.capturar("r1-23-desbloqueio-erro")
    }

    @Test
    fun `02 desbloqueio - sem biometria no aparelho`() {
        tela(DisponibilidadeBiometrica.SEM_HARDWARE, null)
        compose.capturar("r1-24-desbloqueio-indisponivel")
    }

    @Test
    @Config(sdk = [34], application = Application::class, qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `03 desbloqueio - fonte em 200 por cento`() {
        tela(DisponibilidadeBiometrica.DISPONIVEL, "Não foi possível confirmar sua identidade.")
        compose.capturar("r1-25-desbloqueio-fonte-200")
    }
}
