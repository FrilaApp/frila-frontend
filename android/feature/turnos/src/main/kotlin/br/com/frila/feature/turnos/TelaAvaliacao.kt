package br.com.frila.feature.turnos

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.tema.FrilaEspacamento

/**
 * Avaliação binária de turno (RF15/RN07/RNF10): "Você trabalharia nesse local de novo?". Sim
 * ou não, nunca nota — e os dois botões respeitam o alvo mínimo de toque de 48dp
 * (`BotaoPrimario`/`BotaoSecundario` já embutem `FrilaMetricas.alvoMinimo`).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TelaAvaliacao(
    turnoId: String,
    viewModel: AvaliacaoViewModel,
    aoVoltar: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()

    Scaffold(
        modifier = modifier,
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text("Avaliar turno", modifier = Modifier.semantics { heading() }) },
            )
        },
    ) { paddingInterno ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingInterno)
                .verticalScroll(rememberScrollState())
                .padding(FrilaEspacamento.grande),
            contentAlignment = Alignment.Center,
        ) {
            when (estado.status) {
                StatusAvaliacao.ENVIANDO -> CircularProgressIndicator()
                StatusAvaliacao.SUCESSO -> ConfirmacaoDeAvaliacao(resposta = estado.respostaRegistrada, aoVoltar = aoVoltar)
                StatusAvaliacao.ERRO -> ErroDeAvaliacao(
                    mensagem = estado.mensagemErro,
                    aoTentarNovamente = { resposta -> viewModel.avaliar(turnoId, resposta) },
                )
                StatusAvaliacao.OCIOSO -> PerguntaDeAvaliacao(
                    aoResponder = { resposta -> viewModel.avaliar(turnoId, resposta) },
                )
            }
        }
    }
}

@Composable
private fun PerguntaDeAvaliacao(aoResponder: (Boolean) -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
    ) {
        Text(
            text = "Você trabalharia nesse local de novo?",
            style = MaterialTheme.typography.headlineSmall,
            textAlign = TextAlign.Center,
            modifier = Modifier.semantics { heading() },
        )
        Text(
            text = "A avaliação é só sim ou não, e é anônima para o estabelecimento.",
            style = MaterialTheme.typography.bodyMedium,
            textAlign = TextAlign.Center,
        )
        BotaoPrimario(
            texto = "Sim, trabalharia",
            aoClicar = { aoResponder(true) },
            modifier = Modifier.fillMaxWidth(),
        )
        BotaoSecundario(
            texto = "Não trabalharia",
            aoClicar = { aoResponder(false) },
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun ConfirmacaoDeAvaliacao(resposta: Boolean?, aoVoltar: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
    ) {
        Text(
            text = "Avaliação registrada",
            style = MaterialTheme.typography.headlineSmall,
            textAlign = TextAlign.Center,
            modifier = Modifier.semantics { heading() },
        )
        Text(
            text = if (resposta == true) "Você recomendou este local." else "Você não recomendou este local.",
            style = MaterialTheme.typography.bodyMedium,
            textAlign = TextAlign.Center,
            modifier = Modifier.semantics {
                liveRegion = LiveRegionMode.Polite
            },
        )
        BotaoPrimario(texto = "Voltar", aoClicar = aoVoltar, modifier = Modifier.fillMaxWidth())
    }
}

@Composable
private fun ErroDeAvaliacao(mensagem: String?, aoTentarNovamente: (Boolean) -> Unit) {
    val textoErro = mensagem ?: "Não foi possível registrar sua avaliação."
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
    ) {
        Text(
            text = textoErro,
            style = MaterialTheme.typography.bodyMedium,
            textAlign = TextAlign.Center,
            modifier = Modifier.semantics {
                liveRegion = LiveRegionMode.Assertive
                error(textoErro)
            },
        )
        Text(
            text = "Você trabalharia nesse local de novo?",
            style = MaterialTheme.typography.titleMedium,
            textAlign = TextAlign.Center,
            modifier = Modifier.semantics { heading() },
        )
        BotaoPrimario(
            texto = "Sim, trabalharia",
            aoClicar = { aoTentarNovamente(true) },
            modifier = Modifier.fillMaxWidth(),
        )
        BotaoSecundario(
            texto = "Não trabalharia",
            aoClicar = { aoTentarNovamente(false) },
            modifier = Modifier.fillMaxWidth(),
        )
    }
}
