package br.com.frila.feature.conta

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas

/**
 * Bloqueio de conta suspensa (RN13, `403 sem_permissao` com `details: conta_suspensa`; paridade
 * com `TelaContaSuspensa.swift`). Não há navegação para fora da tela além de falar com o suporte
 * ou sair da conta: a conta suspensa não usa o app.
 *
 * O Android ainda não tem `situacao_da_conta` nem `contestar_suspensao`, então a tela não
 * contesta: o canal é o e-mail do suporte. [motivo] e [desde] vêm de quem chama, já formatados, e
 * somem quando nulos. [emailSuporte] também vem de quem chama (`EnderecosOficiais.padrao`).
 */
@Composable
fun TelaContaSuspensa(
    emailSuporte: String,
    aoContatarSuporte: (String) -> Unit,
    aoSair: () -> Unit,
    modifier: Modifier = Modifier,
    motivo: String? = null,
    desde: String? = null,
) {
    Scaffold(modifier = modifier.fillMaxSize()) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.medio, vertical = FrilaEspacamento.grande),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
        ) {
            Text(
                text = TextosContaSuspensa.TITULO,
                style = MaterialTheme.typography.headlineSmall,
                modifier = Modifier.semantics {
                    heading()
                    liveRegion = LiveRegionMode.Polite
                },
            )
            Text(
                text = TextosContaSuspensa.SUBTITULO,
                style = MaterialTheme.typography.bodyLarge,
            )
            Text(
                text = TextosContaSuspensa.AVISO_PRINCIPAL,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.error,
            )

            if (motivo != null || desde != null) {
                Text(
                    text = TextosContaSuspensa.SECAO_MOTIVO,
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.semantics { heading() },
                )
                motivo?.let { Informacao(TextosContaSuspensa.MOTIVO_TITULO, it) }
                desde?.let { Informacao(TextosContaSuspensa.DESDE_TITULO, it) }
            }

            Text(
                text = TextosContaSuspensa.SECAO_SUPORTE,
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.semantics { heading() },
            )
            Text(
                text = TextosContaSuspensa.PRAZO_SUPORTE,
                style = MaterialTheme.typography.bodyMedium,
            )
            Text(
                text = emailSuporte,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            BotaoPrimario(
                texto = TextosContaSuspensa.BOTAO_SUPORTE,
                aoClicar = { aoContatarSuporte(emailSuporte) },
                modifier = Modifier.fillMaxWidth(),
            )
            TextButton(
                onClick = aoSair,
                modifier = Modifier
                    .fillMaxWidth()
                    .sizeIn(minHeight = FrilaMetricas.alvoMinimo),
            ) {
                Text(TextosContaSuspensa.BOTAO_SAIR, style = MaterialTheme.typography.titleSmall)
            }
        }
    }
}

@Composable
private fun Informacao(titulo: String, valor: String) {
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.fio)) {
        Text(
            text = titulo,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(text = valor, style = MaterialTheme.typography.bodyMedium)
    }
}
