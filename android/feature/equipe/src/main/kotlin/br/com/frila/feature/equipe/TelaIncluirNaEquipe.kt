package br.com.frila.feature.equipe

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.EstiloDoSelo
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.SeloDeStatus
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

/**
 * O bloco "Incluir na equipe" de um profissional que cumpriu turno na casa: o botão, ou o selo "Na equipe de confiança"
 * quando ele já está nela, e a recusa do servidor em texto do Frila, junto ao botão. É uma decisão curta que mora dentro
 * de outra tela (a do turno): por isso o botão é secundário, e o primário fica com quem a hospeda. Sem fiação: quem o
 * coloca numa tela é o L2-8.
 */
@Composable
fun ConteudoIncluirNaEquipe(
    estado: EstadoIncluirNaEquipe,
    nome: String,
    aoIncluir: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        estado.mensagemErro?.let { erro -> MensagemJuntoAoBotao(erro) }
        if (estado.situacao == SituacaoNaEquipe.NA_EQUIPE) {
            SeloDeStatus(
                texto = TextosEquipe.NA_EQUIPE,
                estilo = EstiloDoSelo.CONTORNO,
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
            )
        } else {
            BotaoSecundario(
                texto = if (estado.incluindo) TextosEquipe.INCLUINDO else TextosEquipe.INCLUIR,
                aoClicar = aoIncluir,
                habilitado = !estado.incluindo,
                modifier = Modifier.semantics { contentDescription = TextosEquipe.rotuloIncluir(nome) },
            )
        }
    }
}
