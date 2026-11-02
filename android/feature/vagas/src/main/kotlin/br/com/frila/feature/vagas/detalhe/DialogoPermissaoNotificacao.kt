package br.com.frila.feature.vagas.detalhe

import androidx.compose.foundation.layout.sizeIn
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.tema.FrilaMetricas

/**
 * Diálogo contextual explicativo exibido antes de requisitar a permissão POST_NOTIFICATIONS
 * em tempo de execução no Android 13+ (API 33+).
 *
 * Explica ao usuário o valor das notificações para seus turnos confirmados antes do diálogo
 * do sistema ser acionado.
 */
@Composable
fun DialogoPermissaoNotificacao(
    aoConfirmar: () -> Unit,
    aoDispensar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    AlertDialog(
        onDismissRequest = aoDispensar,
        modifier = modifier.testTag("dialogo-permissao-notificacao"),
        title = {
            Text(
                text = "Ativar notificações de turnos",
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.semantics { heading() },
            )
        },
        text = {
            Text(
                text = "Receba avisos imediatos sobre confirmações de presença, lembretes de início de turno " +
                    "e chamados de vagas urgentes para você não perder nenhum compromisso.",
                style = MaterialTheme.typography.bodyMedium,
            )
        },
        confirmButton = {
            TextButton(
                onClick = aoConfirmar,
                modifier = Modifier
                    .testTag("botao-ativar-notificacoes")
                    .sizeIn(
                        minWidth = FrilaMetricas.alvoMinimo,
                        minHeight = FrilaMetricas.alvoMinimo,
                    ),
            ) {
                Text(
                    text = "Ativar notificações",
                    color = MaterialTheme.colorScheme.primary,
                )
            }
        },
        dismissButton = {
            TextButton(
                onClick = aoDispensar,
                modifier = Modifier
                    .testTag("botao-agora-nao-notificacoes")
                    .sizeIn(
                        minWidth = FrilaMetricas.alvoMinimo,
                        minHeight = FrilaMetricas.alvoMinimo,
                    ),
            ) {
                Text(
                    text = "Agora não",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        },
    )
}
