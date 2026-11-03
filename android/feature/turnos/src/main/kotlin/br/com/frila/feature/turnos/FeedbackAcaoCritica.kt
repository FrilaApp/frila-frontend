package br.com.frila.feature.turnos

import android.provider.Settings
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalView

/** Complementa o feedback visual sem forçar vibração quando o usuário a desativou. */
@Composable
internal fun lembrarFeedbackAcaoCritica(): () -> Unit {
    val feedback = LocalHapticFeedback.current
    val view = LocalView.current
    return remember(feedback, view) {
        {
            // Consulta no toque: respeita mudanças nas configurações com a tela já aberta.
            if (view.isHapticFeedbackEnabled && Settings.System.getInt(
                    view.context.contentResolver,
                    Settings.System.HAPTIC_FEEDBACK_ENABLED,
                    0,
                ) == 1
            ) {
                // Compose delega à View Android, que ignora a solicitação sem motor háptico.
                feedback.performHapticFeedback(HapticFeedbackType.LongPress)
            }
        }
    }
}
