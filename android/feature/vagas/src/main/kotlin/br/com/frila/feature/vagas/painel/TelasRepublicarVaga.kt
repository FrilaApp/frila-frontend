package br.com.frila.feature.vagas.painel

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.feature.vagas.publicacao.FUSO_DA_VAGA
import br.com.frila.feature.vagas.publicacao.dataParaSeletorUtcMs
import br.com.frila.feature.vagas.publicacao.formatarData
import br.com.frila.feature.vagas.publicacao.formatarHora
import br.com.frila.feature.vagas.publicacao.trocarData
import br.com.frila.feature.vagas.publicacao.trocarHora
import java.time.Instant

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
// Republicar a vaga com outro horário e republicar em urgência as posições vazias, em baixíssima fidelidade e só com
// componentes nativos, para a regra poder ser testada no emulador.

/** Liga o [RepublicarVagaViewModel] ao [ConteudoRepublicarVaga]. [aoFechar] recebe o id da vaga nova, ou `null` se não republicou. */
@Composable
fun TelaRepublicarVaga(viewModel: RepublicarVagaViewModel, aoFechar: (novaVagaId: String?) -> Unit, modifier: Modifier = Modifier) {
    val estado by viewModel.estado.collectAsState()
    ConteudoRepublicarVaga(
        estado = estado,
        aoMudarInicio = viewModel::mudarInicio,
        aoMudarFim = viewModel::mudarFim,
        aoConfirmar = { viewModel.republicar() },
        aoFechar = { aoFechar(estado.vagaPublicadaId) },
        modifier = modifier,
    )
}

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
@Composable
fun ConteudoRepublicarVaga(
    estado: EstadoRepublicarVaga,
    aoMudarInicio: (Instant) -> Unit,
    aoMudarFim: (Instant) -> Unit,
    aoConfirmar: () -> Unit,
    aoFechar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    ColunaDaTela(TextosRepublicarVaga.TITULO, modifier) {
        if (estado.vagaPublicadaId != null) {
            Text(TextosRepublicarVaga.SUCESSO, modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite })
            BotaoPrimario(TextosRepublicarVaga.OK, aoFechar, Modifier.fillMaxWidth())
            return@ColunaDaTela
        }
        Text(TextosRepublicarVaga.SUBTITULO)
        SeletorDeInstante(TextosRepublicarVaga.INICIO, estado.inicio, estado.erroInicio, estado.podeMudarHorario, aoMudarInicio)
        SeletorDeInstante(TextosRepublicarVaga.TERMINO, estado.fim, estado.erroFim, estado.podeMudarHorario, aoMudarFim)
        estado.mensagemErro?.let { TextoDeErro(it) }
        if (estado.enviando) TextoDeAndamento(TextosRepublicarVaga.ENVIANDO)
        BotaoPrimario(
            texto = if (estado.camposBloqueados) TextosRepublicarVaga.TENTAR_NOVAMENTE else TextosRepublicarVaga.CONFIRMAR,
            aoClicar = aoConfirmar,
            modifier = Modifier.fillMaxWidth(),
            habilitado = estado.podeConfirmar,
        )
        BotaoSecundario(TextosRepublicarVaga.CANCELAR, aoFechar, Modifier.fillMaxWidth(), habilitado = !estado.enviando)
    }
}

/** Liga o [RepublicarPosicoesRestantesViewModel] ao [DialogoRepublicarPosicoesRestantes]. */
@Composable
fun TelaRepublicarPosicoesRestantes(viewModel: RepublicarPosicoesRestantesViewModel, aoFechar: () -> Unit) {
    val estado by viewModel.estado.collectAsState()
    DialogoRepublicarPosicoesRestantes(estado = estado, aoConfirmar = { viewModel.executar() }, aoFechar = aoFechar)
}

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
/** A confirmação do atalho: diz que a urgência confirma o primeiro profissional na hora, e mostra a recusa do servidor. */
@Composable
fun DialogoRepublicarPosicoesRestantes(estado: EstadoRepublicarPosicoesRestantes, aoConfirmar: () -> Unit, aoFechar: () -> Unit) {
    AlertDialog(
        onDismissRequest = aoFechar,
        title = { Text(TextosRepublicarPosicoesRestantes.CONFIRMACAO_TITULO, modifier = Modifier.semantics { heading() }) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
                Text(TextosRepublicarPosicoesRestantes.botao(estado.posicoesRestantes))
                Text(TextosRepublicarPosicoesRestantes.CONFIRMACAO_MENSAGEM)
                if (estado.carregando) TextoDeAndamento(TextosRepublicarPosicoesRestantes.REPUBLICANDO)
                estado.erro?.let { TextoDeErro(it) }
            }
        },
        confirmButton = {
            TextButton(onClick = aoConfirmar, enabled = !estado.carregando && estado.vagaPublicadaId == null) {
                Text(TextosRepublicarPosicoesRestantes.CONFIRMAR)
            }
        },
        dismissButton = { TextButton(onClick = aoFechar) { Text(TextosRepublicarPosicoesRestantes.CANCELAR) } },
    )
}

/** Data e hora de um instante, cada uma num botão que abre o seletor nativo do Material 3 (como em Publicar vaga). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SeletorDeInstante(titulo: String, instante: Instant, erro: String?, habilitado: Boolean, aoMudar: (Instant) -> Unit) {
    var escolhendoData by rememberSaveable { mutableStateOf(false) }
    var escolhendoHora by rememberSaveable { mutableStateOf(false) }
    val data = formatarData(instante)
    val hora = formatarHora(instante)
    val rotuloData = TextosRepublicarVaga.DATA_DE.format(titulo.lowercase())
    val rotuloHora = TextosRepublicarVaga.HORA_DE.format(titulo.lowercase())

    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo)) {
        Text(titulo, style = MaterialTheme.typography.labelLarge)
        Row(horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
            BotaoSecundario(data, { escolhendoData = true }, Modifier.weight(1f).semantics { contentDescription = "$rotuloData: $data" }, habilitado)
            BotaoSecundario(hora, { escolhendoHora = true }, Modifier.weight(1f).semantics { contentDescription = "$rotuloHora: $hora" }, habilitado)
        }
        erro?.let { TextoDeErro(it) }
    }

    if (escolhendoData) {
        val seletor = rememberDatePickerState(initialSelectedDateMillis = dataParaSeletorUtcMs(instante))
        DatePickerDialog(
            onDismissRequest = { escolhendoData = false },
            confirmButton = {
                TextButton(onClick = {
                    seletor.selectedDateMillis?.let { aoMudar(trocarData(instante, it)) }
                    escolhendoData = false
                }) { Text(TextosRepublicarVaga.OK) }
            },
            dismissButton = { TextButton(onClick = { escolhendoData = false }) { Text(TextosRepublicarVaga.CANCELAR) } },
        ) { DatePicker(state = seletor, title = { Text(rotuloData, modifier = Modifier.padding(FrilaEspacamento.medio)) }) }
    }

    if (escolhendoHora) {
        val local = instante.atZone(FUSO_DA_VAGA)
        val seletor = rememberTimePickerState(initialHour = local.hour, initialMinute = local.minute, is24Hour = true)
        AlertDialog(
            onDismissRequest = { escolhendoHora = false },
            title = { Text(rotuloHora, modifier = Modifier.semantics { heading() }) },
            text = { TimePicker(state = seletor) },
            confirmButton = {
                TextButton(onClick = {
                    aoMudar(trocarHora(instante, seletor.hour, seletor.minute))
                    escolhendoHora = false
                }) { Text(TextosRepublicarVaga.OK) }
            },
            dismissButton = { TextButton(onClick = { escolhendoHora = false }) { Text(TextosRepublicarVaga.CANCELAR) } },
        )
    }
}
