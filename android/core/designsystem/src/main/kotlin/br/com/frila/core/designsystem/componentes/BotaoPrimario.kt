package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import br.com.frila.core.designsystem.tema.FrilaMetricas

/**
 * Botão principal do Frila: altura 52dp (`FrilaMetricas.alturaBotao`), alvo de toque mínimo
 * 48dp (`FrilaMetricas.alvoMinimo`), preenchimento `primary`/`onPrimary` do tema
 * (BrandPrimary/BrandOnPrimary — quase preto no claro, quase branco no escuro).
 */
@Composable
fun BotaoPrimario(
    texto: String,
    aoClicar: () -> Unit,
    modifier: Modifier = Modifier,
    habilitado: Boolean = true,
) {
    Button(
        onClick = aoClicar,
        enabled = habilitado,
        modifier = modifier
            .heightIn(min = FrilaMetricas.alturaBotao)
            .widthIn(min = FrilaMetricas.alvoMinimo),
        colors = ButtonDefaults.buttonColors(
            containerColor = MaterialTheme.colorScheme.primary,
            contentColor = MaterialTheme.colorScheme.onPrimary,
        ),
    ) {
        Text(text = texto, style = MaterialTheme.typography.titleSmall)
    }
}
