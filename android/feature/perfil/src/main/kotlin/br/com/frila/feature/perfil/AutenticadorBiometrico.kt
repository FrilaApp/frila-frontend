package br.com.frila.feature.perfil

import android.content.Context
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity

/** RN15: autenticadores aceitos para desbloqueio rápido — biometria forte ou PIN/padrão do aparelho. */
private const val AUTENTICADORES_PERMITIDOS =
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

    fun verificarDisponibilidade(contexto: Context): DisponibilidadeBiometrica {
        val resultado = BiometricManager.from(contexto).canAuthenticate(AUTENTICADORES_PERMITIDOS)
        return when (resultado) {
            BiometricManager.BIOMETRIC_SUCCESS -> DisponibilidadeBiometrica.DISPONIVEL
            BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> DisponibilidadeBiometrica.SEM_HARDWARE
            BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> DisponibilidadeBiometrica.HARDWARE_INDISPONIVEL
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> DisponibilidadeBiometrica.NAO_CADASTRADA
            else -> DisponibilidadeBiometrica.INDISPONIVEL
        }
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
        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Ativar desbloqueio rápido")
            .setSubtitle("Confirme sua identidade para ativar")
            .setAllowedAuthenticators(AUTENTICADORES_PERMITIDOS)
            .build()
        prompt.authenticate(info)
    }
}
