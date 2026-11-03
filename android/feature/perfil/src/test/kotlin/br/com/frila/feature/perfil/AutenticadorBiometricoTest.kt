package br.com.frila.feature.perfil

import android.app.Application
import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadow.api.Shadow
import org.robolectric.shadows.ShadowBiometricManager
import org.robolectric.shadows.ShadowKeyguardManager

/**
 * RN15 (Cartão 69): prova que a configuração de autenticadores é compatível com API 28-29 e 30+.
 * Na API 28-29, BiometricPrompt.PromptInfo.Builder não tolera BIOMETRIC_STRONG or DEVICE_CREDENTIAL
 * em setAllowedAuthenticators (exceção ou não-suportado); usa setDeviceCredentialAllowed(true).
 * Da mesma forma, BiometricManager.canAuthenticate na API 28-29 não suporta a flag combinada,
 * necessitando verificação apartada entre hardware biométrico e credencial segura do sistema.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AutenticadorBiometricoTest {

    private val contexto: Context
        get() = ApplicationProvider.getApplicationContext()

    @Test
    fun `criarPromptInfo na API 30+ configura allowedAuthenticators combinados`() {
        val info = AutenticadorBiometrico.criarPromptInfo(sdkInt = Build.VERSION_CODES.R)

        assertNotNull(info)
        assertEquals(AUTENTICADORES_PERMITIDOS, info.allowedAuthenticators)
        assertEquals("Ativar desbloqueio rápido", info.title)
    }

    @Test
    fun `criarPromptInfo na API 29 Android 10 usa setDeviceCredentialAllowed sem falhar`() {
        val info = AutenticadorBiometrico.criarPromptInfo(sdkInt = Build.VERSION_CODES.Q)

        assertNotNull(info)
        @Suppress("DEPRECATION")
        assertTrue(info.isDeviceCredentialAllowed)
        assertEquals("Ativar desbloqueio rápido", info.title)
    }

    @Test
    fun `criarPromptInfo na API 28 Android 9 usa setDeviceCredentialAllowed sem falhar`() {
        val info = AutenticadorBiometrico.criarPromptInfo(sdkInt = Build.VERSION_CODES.P)

        assertNotNull(info)
        @Suppress("DEPRECATION")
        assertTrue(info.isDeviceCredentialAllowed)
        assertEquals("Ativar desbloqueio rápido", info.title)
    }

    @Test
    fun `verificarDisponibilidade na API 28 e 29 com credencial de tela configurada retorna DISPONIVEL`() {
        val keyguardManager = contexto.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val shadowKeyguard: ShadowKeyguardManager = shadowOf(keyguardManager)
        shadowKeyguard.setIsDeviceSecure(true)

        val disponibilidadeApi28 = AutenticadorBiometrico.verificarDisponibilidade(
            contexto = contexto,
            sdkInt = Build.VERSION_CODES.P,
        )
        val disponibilidadeApi29 = AutenticadorBiometrico.verificarDisponibilidade(
            contexto = contexto,
            sdkInt = Build.VERSION_CODES.Q,
        )

        assertEquals(DisponibilidadeBiometrica.DISPONIVEL, disponibilidadeApi28)
        assertEquals(DisponibilidadeBiometrica.DISPONIVEL, disponibilidadeApi29)
    }

    @Test
    fun `verificarDisponibilidade na API 28 e 29 sem credencial e sem hardware retorna SEM_HARDWARE`() {
        val keyguardManager = contexto.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        shadowOf(keyguardManager).setIsDeviceSecure(false)

        val frameworkBiometricManager = contexto.getSystemService(android.hardware.biometrics.BiometricManager::class.java)
        if (frameworkBiometricManager != null) {
            val shadowBiometric = Shadow.extract<ShadowBiometricManager>(frameworkBiometricManager)
            shadowBiometric.setCanAuthenticate(false)
        }

        val disponibilidade = AutenticadorBiometrico.verificarDisponibilidade(
            contexto = contexto,
            sdkInt = Build.VERSION_CODES.Q,
        )

        assertEquals(DisponibilidadeBiometrica.SEM_HARDWARE, disponibilidade)
    }

    @Test
    fun `verificarDisponibilidade na API 30+ com hardware habilitado retorna DISPONIVEL`() {
        val frameworkBiometricManager = contexto.getSystemService(android.hardware.biometrics.BiometricManager::class.java)
        if (frameworkBiometricManager != null) {
            val shadowBiometric = Shadow.extract<ShadowBiometricManager>(frameworkBiometricManager)
            shadowBiometric.setCanAuthenticate(true)
        }

        val disponibilidade = AutenticadorBiometrico.verificarDisponibilidade(
            contexto = contexto,
            sdkInt = Build.VERSION_CODES.R,
        )

        assertEquals(DisponibilidadeBiometrica.DISPONIVEL, disponibilidade)
    }

    @Test
    fun `verificarDisponibilidade na API 30+ sem hardware retorna SEM_HARDWARE`() {
        val frameworkBiometricManager = contexto.getSystemService(android.hardware.biometrics.BiometricManager::class.java)
        if (frameworkBiometricManager != null) {
            val shadowBiometric = Shadow.extract<ShadowBiometricManager>(frameworkBiometricManager)
            shadowBiometric.setCanAuthenticate(false)
        }

        val disponibilidade = AutenticadorBiometrico.verificarDisponibilidade(
            contexto = contexto,
            sdkInt = Build.VERSION_CODES.R,
        )

        assertEquals(DisponibilidadeBiometrica.SEM_HARDWARE, disponibilidade)
    }
}
