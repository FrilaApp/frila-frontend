package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaCores
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaRaios

/**
 * Tons de alerta e feedback do Frila (paridade direta com `AvisoFrila` do iOS / Cartão nliiRfQg).
 */
enum class TomAviso {
    ERRO,
    ALERTA,
    INFORMATIVO,
    SUCESSO,
}

/**
 * Faixa / banner de aviso contextual para mensagens transientes ou inline (RNF10).
 *
 * Utiliza 12% de opacidade da cor do tom no fundo, contorno hairline e ícones padronizados.
 */
@Composable
fun AvisoFrila(
    tom: TomAviso,
    mensagem: String,
    modifier: Modifier = Modifier,
    titulo: String? = null,
    aoDispensar: (() -> Unit)? = null,
) {
    val escuro = isSystemInDarkTheme()
    val corDestaque = when (tom) {
        TomAviso.ERRO -> if (escuro) FrilaCores.dangerDark else FrilaCores.dangerLight
        TomAviso.ALERTA -> if (escuro) FrilaCores.warningDark else FrilaCores.warningLight
        TomAviso.SUCESSO -> if (escuro) FrilaCores.successDark else FrilaCores.successLight
        TomAviso.INFORMATIVO -> if (escuro) FrilaCores.brandAccentDark else FrilaCores.brandAccentLight
    }

    val corFundo = corDestaque.copy(alpha = 0.12f)
    val corBorda = corDestaque.copy(alpha = 0.25f)

    val iconePadrao: ImageVector = when (tom) {
        TomAviso.ERRO -> Icons.Default.Warning
        TomAviso.ALERTA -> Icons.Default.Warning
        TomAviso.SUCESSO -> Icons.Default.Check
        TomAviso.INFORMATIVO -> Icons.Default.Info
    }

    val prefixoAcessibilidade = when (tom) {
        TomAviso.ERRO -> "Erro: "
        TomAviso.ALERTA -> "Aviso: "
        TomAviso.SUCESSO -> "Sucesso: "
        TomAviso.INFORMATIVO -> "Informação: "
    }

    Surface(
        modifier = modifier
            .fillMaxWidth()
            .semantics {
                liveRegion = LiveRegionMode.Polite
                contentDescription = "$prefixoAcessibilidade${titulo?.let { "$it. " } ?: ""}$mensagem"
            },
        shape = RoundedCornerShape(FrilaRaios.medio),
        color = corFundo,
        border = BorderStroke(1.dp, corBorda),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(FrilaEspacamento.compacto),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.compacto),
        ) {
            Icon(
                imageVector = iconePadrao,
                contentDescription = null,
                tint = corDestaque,
                modifier = Modifier.size(24.dp),
            )
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo),
            ) {
                if (!titulo.isNullOrBlank()) {
                    Text(
                        text = titulo,
                        style = MaterialTheme.typography.titleSmall,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                }
                Text(
                    text = mensagem,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                )
            }
            if (aoDispensar != null) {
                IconButton(
                    onClick = aoDispensar,
                    modifier = Modifier.size(FrilaMetricas.alvoMinimo),
                ) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Fechar aviso",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}
