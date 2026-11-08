package br.com.frila.feature.perfil

import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity

/** RN15: autenticadores aceitos para desbloqueio rápido — biometria forte ou PIN/padrão do aparelho. */
internal const val AUTENTICADORES_PERMITIDOS =
    BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.DEVICE_CREDENTIAL

/** Disponibilidade de autenticação biométrica/credencial neste aparelho (RN15). */
enum class DisponibilidadeBiometrica { DISPONIVEL, SEM_HARDWARE, HARDWARE_INDISPONIVEL, NAO_CADASTRADA, INDISPONIVEL }

/**
 * Ponte fina para `androidx.biometric` (RN15). Fica em `feature:perfil` — não em
 * `core:seguranca`, que é módulo JVM puro — porque é aqui que o toggle vive na UI
 * ([TelaPerfil]). A ativação em si (persistir a flag) é responsabilidade do
 * [PerfilViewModel]/`ArmazenamentoDeSessao`; este objeto só verifica hardware e dispara o prompt.
 */
object AutenticadorBiometrico {

    fun verificarDisponibilidade(
        contexto: Context,
        sdkInt: Int = Build.VERSION.SDK_INT,
    ): DisponibilidadeBiometrica {
        if (sdkInt >= Build.VERSION_CODES.R) {
            val resultado = BiometricManager.from(contexto).canAuthenticate(AUTENTICADORES_PERMITIDOS)
            return traduzirResultado(resultado)
        }

        // RN15 / Android 9-10 (API 28-29): BiometricManager.canAuthenticate não suporta
        // a combinação BIOMETRIC_STRONG or DEVICE_CREDENTIAL (retorna BIOMETRIC_ERROR_UNSUPPORTED).
        // Consultamos o hardware biométrico e a credencial do dispositivo (PIN/padrão) separadamente.
        val keyguardManager = contexto.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        val temCredencial = keyguardManager?.isDeviceSecure == true

        val resultadoBiometria = BiometricManager.from(contexto)
            .canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_WEAK)

        return when {
            resultadoBiometria == BiometricManager.BIOMETRIC_SUCCESS || temCredencial -> DisponibilidadeBiometrica.DISPONIVEL
            resultadoBiometria == BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> DisponibilidadeBiometrica.NAO_CADASTRADA
            resultadoBiometria == BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> DisponibilidadeBiometrica.SEM_HARDWARE
            resultadoBiometria == BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> DisponibilidadeBiometrica.HARDWARE_INDISPONIVEL
            else -> DisponibilidadeBiometrica.INDISPONIVEL
        }
    }

    private fun traduzirResultado(resultado: Int): DisponibilidadeBiometrica = when (resultado) {
        BiometricManager.BIOMETRIC_SUCCESS -> DisponibilidadeBiometrica.DISPONIVEL
        BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> DisponibilidadeBiometrica.SEM_HARDWARE
        BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> DisponibilidadeBiometrica.HARDWARE_INDISPONIVEL
        BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> DisponibilidadeBiometrica.NAO_CADASTRADA
        else -> DisponibilidadeBiometrica.INDISPONIVEL
    }

    fun criarPromptInfo(sdkInt: Int = Build.VERSION.SDK_INT): BiometricPrompt.PromptInfo {
        val builder = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Ativar desbloqueio rápido")
            .setSubtitle("Confirme sua identidade para ativar")

        if (sdkInt >= Build.VERSION_CODES.R) {
            builder.setAllowedAuthenticators(AUTENTICADORES_PERMITIDOS)
        } else {
            // API 28-29: setAllowedAuthenticators com DEVICE_CREDENTIAL não é compatível.
            // setDeviceCredentialAllowed(true) habilita fallback para PIN/padrão/senha
            // e dispensa o botão negativo explícito.
            @Suppress("DEPRECATION")
            builder.setDeviceCredentialAllowed(true)
        }
        return builder.build()
    }

    /**
     * Exige confirmação biométrica/credencial antes de ativar o desbloqueio rápido (RN15) — a
     * flag só deve ligar depois que o profissional provou que consegue se autenticar, nunca
     * antes. [aoErro] recebe o texto já pronto para exibição (vindo do próprio Android).
     */
    fun autenticar(activity: FragmentActivity, aoSucesso: () -> Unit, aoErro: (String) -> Unit) {
        val executor = ContextCompat.getMainExecutor(activity)
        val prompt = BiometricPrompt(
            activity,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    aoSucesso()
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    aoErro(errString.toString())
                }
            },
        )
        val info = criarPromptInfo()
        prompt.authenticate(info)
    }
}
