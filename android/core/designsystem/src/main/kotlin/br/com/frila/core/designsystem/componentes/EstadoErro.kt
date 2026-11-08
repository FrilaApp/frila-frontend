package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaEspacamento

/**
 * Componente padronizado de erro de tela inteira ou seção do Frila (RNF10).
 *
 * Comunica falhas de rede, operações não concluídas ou erros de processamento,
 * oferecendo botão acessível com alvo de toque >= 48dp para retentativa.
 */
@Composable
fun EstadoErro(
    modifier: Modifier = Modifier,
    titulo: String = "Algo deu errado",
    mensagem: String? = "Não foi possível carregar as informações. Verifique sua conexão e tente novamente.",
    textoBotao: String = "Tentar novamente",
    aoTentarNovamente: (() -> Unit)? = null,
) {
    val descricaoErro = mensagem ?: titulo

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(FrilaEspacamento.grande)
            .semantics { error(descricaoErro) },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio, Alignment.CenterVertically),
    ) {
        Icon(
            imageVector = Icons.Default.Warning,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.error,
            modifier = Modifier.size(48.dp),
        )
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
        if (aoTentarNovamente != null) {
            BotaoPrimario(
                texto = textoBotao,
                aoClicar = aoTentarNovamente,
                modifier = Modifier.padding(top = FrilaEspacamento.pequeno),
            )
        }
    }
}
