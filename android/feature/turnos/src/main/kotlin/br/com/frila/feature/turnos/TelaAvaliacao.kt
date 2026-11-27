package br.com.frila.feature.turnos

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
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

private const val PERGUNTA = "Você trabalharia nesse local de novo?"
private const val SIM = "Sim, trabalharia"
private const val NAO = "Não trabalharia"

/**
 * Avaliação binária de turno (RF15/RN07/RNF10, T5 do desenho): a pergunta é o título e a resposta é a ação, então a
 * tela não tem botão laranja. Sim ou não, nunca nota; a escolha grava no toque e tem um voto por lado do turno
 * (depois de gravada, uma resposta diferente é recusada). Cada opção respeita o alvo mínimo de 48dp.
 *
 * O desenho põe o cartão de status do turno abaixo da escolha; esta tela só recebe o `turnoId`, sem os dados do
 * turno, então o cartão fica de fora até a rota passar o turno.
 */
@Composable
fun TelaAvaliacao(
    turnoId: String,
    viewModel: AvaliacaoViewModel,
    aoVoltar: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    LaunchedEffect(turnoId, viewModel) { viewModel.observar(turnoId) }
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    // A opção tocada fica marcada enquanto o voto é enviado (sem indicador girando); sem envio, nada marcado.
    var emEnvio by remember { mutableStateOf<Boolean?>(null) }
    val avaliar = { resposta: Boolean ->
        emEnvio = resposta
        viewModel.avaliar(turnoId, resposta)
        Unit
    }

    Scaffold(
        modifier = modifier,
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
                StatusAvaliacao.SUCESSO -> ConfirmacaoDeAvaliacao(resposta = estado.respostaRegistrada, aoVoltar = aoVoltar)
                StatusAvaliacao.JA_AVALIADO -> JaAvaliado(resposta = estado.respostaRegistrada, aoVoltar = aoVoltar)
                StatusAvaliacao.ERRO -> PerguntaDeAvaliacao(
                    escolha = null,
                    aoResponder = avaliar,
                    mensagemErro = estado.mensagemErro ?: "Não foi possível registrar sua avaliação.",
                )
                StatusAvaliacao.ENVIANDO -> PerguntaDeAvaliacao(escolha = emEnvio, aoResponder = {}, habilitada = false)
                StatusAvaliacao.OCIOSO -> PerguntaDeAvaliacao(escolha = null, aoResponder = avaliar)
            }
        }
    }
}

@Composable
private fun PerguntaDeAvaliacao(
    escolha: Boolean?,
    aoResponder: (Boolean) -> Unit,
    mensagemErro: String? = null,
    habilitada: Boolean = true,
) {
    TituloDaTela(PERGUNTA)
    Text(
        text = "A avaliação é só sim ou não, e é anônima para o estabelecimento.",
        style = FrilaTipo.apoio,
        color = FrilaTema.cores.tintaSuave,
    )
    EscolhaBinaria(
        rotuloSim = SIM,
        rotuloNao = NAO,
        escolha = escolha,
        aoEscolher = aoResponder,
        habilitada = habilitada,
    )
    // Erro de uma ação: escrito logo abaixo da escolha que o disparou; tocar de novo tenta outra vez.
    mensagemErro?.let { MensagemDeAcao(texto = it) }
}

@Composable
private fun ConfirmacaoDeAvaliacao(resposta: Boolean?, aoVoltar: () -> Unit) {
    TituloDaTela("Avaliação registrada")
    Text(
        text = if (resposta == true) "Você recomendou este local." else "Você não recomendou este local.",
        style = FrilaTipo.corpo,
        color = FrilaTema.cores.tinta,
        modifier = Modifier.semantics {
            liveRegion = LiveRegionMode.Polite
        },
    )
    BotaoSecundario(texto = "Voltar", aoClicar = aoVoltar, modifier = Modifier.fillMaxWidth())
}

/** 409 `avaliacao_ja_registrada`: a pergunta já foi respondida deste lado do turno; mostra a resposta gravada, se o servidor a devolveu, e nenhum botão de avaliar. */
@Composable
private fun JaAvaliado(resposta: Boolean?, aoVoltar: () -> Unit) {
    TituloDaTela("Turno já avaliado")
    Text(
        text = when (resposta) {
            true -> "A avaliação registrada: você recomendou este local."
            false -> "A avaliação registrada: você não recomendou este local."
            null -> "Este turno já tem uma avaliação registrada."
        },
        style = FrilaTipo.corpo,
        color = FrilaTema.cores.tinta,
        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
    )
    BotaoSecundario(texto = "Voltar", aoClicar = aoVoltar, modifier = Modifier.fillMaxWidth())
}

@Composable
internal fun AvaliacaoNaFila(aoVoltar: () -> Unit) {
    TituloDaTela("Avaliação guardada")
    Text(
        text = TextosDaFilaDeAvaliacao.NA_FILA,
        style = FrilaTipo.corpo,
        color = FrilaTema.cores.tinta,
        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
    )
    BotaoSecundario(texto = "Voltar", aoClicar = aoVoltar, modifier = Modifier.fillMaxWidth())
}
