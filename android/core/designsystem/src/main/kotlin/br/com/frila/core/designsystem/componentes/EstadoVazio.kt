package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaEspacamento

/**
 * Estado vazio padronizado do Frila (RNF10 / Cartão nliiRfQg).
 *
 * Utilizado quando não há dados a exibir (lista vazia, busca sem resultados, filtros restritivos).
 * Garante alinhamento centralizado, tipografia semântica TalkBack e alvo interativo mínimo de 48dp
 * caso uma ação de recuperação seja configurada.
 */
@Composable
fun EstadoVazio(
    titulo: String,
    modifier: Modifier = Modifier,
    mensagem: String? = null,
    icone: ImageVector? = Icons.Default.Info,
    rotuloIcone: String? = null,
    textoAcao: String? = null,
    aoClicarAcao: (() -> Unit)? = null,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(FrilaEspacamento.grande),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio, Alignment.CenterVertically),
    ) {
        if (icone != null) {
            Icon(
                imageVector = icone,
                contentDescription = rotuloIcone,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(48.dp),
            )
        }
        Text(
            text = titulo,
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onBackground,
            textAlign = TextAlign.Center,
            modifier = Modifier.semantics { heading() },
        )
        if (!mensagem.isNullOrBlank()) {
            Text(
                text = mensagem,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
        if (!textoAcao.isNullOrBlank() && aoClicarAcao != null) {
            BotaoSecundario(
                texto = textoAcao,
                aoClicar = aoClicarAcao,
                modifier = Modifier.padding(top = FrilaEspacamento.pequeno),
            )
        }
    }
}
