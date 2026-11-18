package br.com.frila.feature.equipe

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.tema.FrilaEspacamento

/** Liga o [IncluirNaEquipeViewModel] ao [ConteudoIncluirNaEquipe]. */
@Composable
fun IncluirNaEquipe(
    viewModel: IncluirNaEquipeViewModel,
    nome: String,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregar() }
    ConteudoIncluirNaEquipe(estado = estado, nome = nome, aoIncluir = { viewModel.incluir() }, modifier = modifier)
}

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
/**
 * O bloco "Incluir na equipe" de um profissional que cumpriu turno na casa: o botão, ou "Na equipe de confiança"
 * quando ele já está nela, e a recusa do servidor em texto do Frila. Sem fiação: quem o coloca numa tela é o L2-8.
 */
@Composable
fun ConteudoIncluirNaEquipe(
    estado: EstadoIncluirNaEquipe,
    nome: String,
    aoIncluir: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
        if (estado.situacao == SituacaoNaEquipe.NA_EQUIPE) {
            Text(
                text = TextosEquipe.NA_EQUIPE,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
            )
        } else {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
                BotaoSecundario(
                    texto = if (estado.incluindo) TextosEquipe.INCLUINDO else TextosEquipe.INCLUIR,
                    aoClicar = aoIncluir,
                    habilitado = !estado.incluindo,
                    modifier = Modifier.semantics { contentDescription = TextosEquipe.rotuloIncluir(nome) },
                )
                if (estado.incluindo) CircularProgressIndicator(modifier = Modifier.size(24.dp))
            }
        }
        estado.mensagemErro?.let { erro ->
            Text(
                text = erro,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.error,
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
            )
        }
    }
}
