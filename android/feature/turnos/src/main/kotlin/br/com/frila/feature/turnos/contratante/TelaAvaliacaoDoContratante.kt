// TELA PROVISÓRIA (sistema do Fabrício): ele revê depois
package br.com.frila.feature.turnos.contratante

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.feature.turnos.AvaliacaoNaFila
import br.com.frila.feature.turnos.AvaliacaoViewModel
import br.com.frila.feature.turnos.EscolhaBinaria
import br.com.frila.feature.turnos.MensagemDeAcao
import br.com.frila.feature.turnos.R
import br.com.frila.feature.turnos.StatusAvaliacao

/**
 * Avaliação do profissional pelo contratante (Item #27 da Paridade / `DestinoAvaliacaoDoContratante` do iOS).
 * Uma pergunta só: "Chamaria este profissional de novo?" (sim ou não, nunca nota de 1 a 5).
 * Resposta anônima para a reputação do profissional no Frila.
 */
@Composable
fun TelaAvaliacaoDoContratante(
    turnoId: String,
    viewModel: AvaliacaoViewModel,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    LaunchedEffect(turnoId, viewModel) { viewModel.observar(turnoId) }
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    var emEnvio by remember { mutableStateOf<Boolean?>(null) }
    val avaliar = { resposta: Boolean ->
        emEnvio = resposta
        viewModel.avaliar(turnoId, resposta)
        Unit
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = FrilaTema.cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = aoVoltar) },
    ) { paddingInterno ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingInterno)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.grupo),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
        ) {
            when (estado.status) {
                StatusAvaliacao.NA_FILA -> AvaliacaoNaFila(aoVoltar)
                StatusAvaliacao.SUCESSO -> ConfirmacaoAvaliacaoContratante(
                    resposta = estado.respostaRegistrada,
                    aoVoltar = aoVoltar,
                )
                StatusAvaliacao.JA_AVALIADO -> JaAvaliadoContratante(
                    resposta = estado.respostaRegistrada,
                    aoVoltar = aoVoltar,
                )
                StatusAvaliacao.ERRO -> PerguntaAvaliacaoContratante(
                    escolha = null,
                    aoResponder = avaliar,
                    mensagemErro = estado.mensagemErro ?: stringResource(R.string.avaliacao_contratante_explicacao),
                )
                StatusAvaliacao.ENVIANDO -> PerguntaAvaliacaoContratante(
                    escolha = emEnvio,
                    aoResponder = {},
                    habilitada = false,
                )
                StatusAvaliacao.OCIOSO -> PerguntaAvaliacaoContratante(
                    escolha = null,
                    aoResponder = avaliar,
                )
            }
        }
    }
}

@Composable
private fun PerguntaAvaliacaoContratante(
    escolha: Boolean?,
    aoResponder: (Boolean) -> Unit,
    mensagemErro: String? = null,
    habilitada: Boolean = true,
) {
    TituloDaTela(
        texto = stringResource(R.string.avaliacao_contratante_pergunta),
        modifier = Modifier
            .semantics { heading() }
            .testTag("pergunta-avaliacao-contratante"),
    )
    Text(
        text = stringResource(R.string.avaliacao_contratante_explicacao),
        style = FrilaTipo.apoio,
        color = FrilaTema.cores.tintaSuave,
    )
    EscolhaBinaria(
        rotuloSim = stringResource(R.string.avaliacao_contratante_sim),
        rotuloNao = stringResource(R.string.avaliacao_contratante_nao),
        escolha = escolha,
        aoEscolher = aoResponder,
        habilitada = habilitada,
    )
    mensagemErro?.let { MensagemDeAcao(texto = it) }
}

/** 409 `avaliacao_ja_registrada` (a casa ou outro membro já avaliou este lado do turno): sem botões, com a resposta gravada se o servidor a devolveu. */
@Composable
private fun JaAvaliadoContratante(
    resposta: Boolean?,
    aoVoltar: () -> Unit,
) {
    TituloDaTela(
        texto = stringResource(R.string.avaliacao_contratante_ja_avaliado),
        modifier = Modifier.semantics { heading() },
    )
    Text(
        text = when (resposta) {
            true -> stringResource(R.string.avaliacao_contratante_ja_avaliado_sim)
            false -> stringResource(R.string.avaliacao_contratante_ja_avaliado_nao)
            null -> stringResource(R.string.avaliacao_contratante_ja_avaliado_sem_resposta)
        },
        style = FrilaTipo.corpo,
        color = FrilaTema.cores.tinta,
        modifier = Modifier.semantics {
            liveRegion = LiveRegionMode.Polite
        },
    )
    BotaoSecundario(
        texto = stringResource(R.string.avaliacao_contratante_voltar),
        aoClicar = aoVoltar,
        modifier = Modifier
            .fillMaxWidth()
            .testTag("voltar-avaliacao-contratante"),
    )
}

@Composable
private fun ConfirmacaoAvaliacaoContratante(
    resposta: Boolean?,
    aoVoltar: () -> Unit,
) {
    TituloDaTela(
        texto = stringResource(R.string.avaliacao_contratante_sucesso),
        modifier = Modifier.semantics { heading() },
    )
    Text(
        text = if (resposta == true) {
            stringResource(R.string.avaliacao_contratante_sucesso_sim)
        } else {
            stringResource(R.string.avaliacao_contratante_sucesso_nao)
        },
        style = FrilaTipo.corpo,
        color = FrilaTema.cores.tinta,
        modifier = Modifier.semantics {
            liveRegion = LiveRegionMode.Polite
        },
    )
    BotaoSecundario(
        texto = stringResource(R.string.avaliacao_contratante_voltar),
        aoClicar = aoVoltar,
        modifier = Modifier
            .fillMaxWidth()
            .testTag("voltar-avaliacao-contratante"),
    )
}
