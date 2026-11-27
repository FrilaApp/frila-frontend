package br.com.frila.core.designsystem.componentes

import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag

/** Os textos da confirmação de saída, os mesmos do iOS (`PerfisDaConta.swift`, `FolhaDeConfirmacaoDeSaida`). */
object TextosConfirmarSaida {
    const val TITULO = "Sair da conta?"
    const val EXPLICACAO = "Encerra a sessão neste aparelho. Você pode entrar de novo quando quiser."
    const val CANCELAR = "Cancelar"
    const val SAIR = "Sair"

    /** Os mesmos identificadores de acessibilidade do iOS. */
    const val TAG_CANCELAR = "botao-cancelar-saida-dialogo"
    const val TAG_SAIR = "botao-confirmar-saida-dialogo"
}

/**
 * A confirmação de "Sair da conta", a mesma no Perfil e na conta suspensa. Quem chama guarda se está aberta: o diálogo
 * só avisa a escolha. Fechar por fora (voltar, tocar fora) conta como Cancelar.
 */
@Composable
fun DialogoConfirmarSaida(
    aoCancelar: () -> Unit,
    aoConfirmar: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = aoCancelar,
        title = { Text(TextosConfirmarSaida.TITULO) },
        text = { Text(TextosConfirmarSaida.EXPLICACAO) },
        confirmButton = {
            TextButton(onClick = aoConfirmar, modifier = Modifier.testTag(TextosConfirmarSaida.TAG_SAIR)) {
                Text(TextosConfirmarSaida.SAIR)
            }
        },
        dismissButton = {
            TextButton(onClick = aoCancelar, modifier = Modifier.testTag(TextosConfirmarSaida.TAG_CANCELAR)) {
                Text(TextosConfirmarSaida.CANCELAR)
            }
        },
    )
}
