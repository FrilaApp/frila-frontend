package br.com.frila.feature.vagas.painel

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
// Cancelar a vaga inteira, em baixíssima fidelidade e só com componentes nativos, para a regra poder ser testada no
// emulador. Os apoios do fim do arquivo servem também às outras telas provisórias deste pacote.

/** Liga o [CancelarVagaViewModel] ao [ConteudoCancelarVaga]. [aoFechar] recebe `true` se a vaga foi cancelada. */
@Composable
fun TelaCancelarVaga(viewModel: CancelarVagaViewModel, aoFechar: (cancelou: Boolean) -> Unit, modifier: Modifier = Modifier) {
    val estado by viewModel.estado.collectAsState()
    ConteudoCancelarVaga(
        estado = estado,
        motivos = viewModel.motivos,
        aoEscolherMotivo = viewModel::escolherMotivo,
        aoMudarDetalhes = viewModel::mudarDetalhes,
        aoConfirmar = { viewModel.confirmar() },
        aoFechar = { aoFechar(estado.concluida) },
        modifier = modifier,
    )
}

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
@Composable
fun ConteudoCancelarVaga(
    estado: EstadoCancelarVaga,
    motivos: List<MotivoDeCancelamentoDaVaga>,
    aoEscolherMotivo: (MotivoDeCancelamentoDaVaga) -> Unit,
    aoMudarDetalhes: (String) -> Unit,
    aoConfirmar: () -> Unit,
    aoFechar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    ColunaDaTela(TextosCancelarVaga.TITULO, modifier) {
        if (estado.concluida) {
            Text(TextosCancelarVaga.CANCELADA, modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite })
            BotaoPrimario(TextosCancelarVaga.FECHAR, aoFechar, Modifier.fillMaxWidth())
            return@ColunaDaTela
        }
        Text(estado.aviso)
        Text(TextosCancelarVaga.MOTIVO_TITULO, style = MaterialTheme.typography.titleMedium, modifier = Modifier.semantics { heading() })
        Column(Modifier.selectableGroup()) {
            motivos.forEach { motivo ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = FrilaMetricas.alvoMinimo)
                        .selectable(
                            selected = estado.motivo == motivo,
                            enabled = !estado.enviando,
                            role = Role.RadioButton,
                            onClick = { aoEscolherMotivo(motivo) },
                        ),
                ) {
                    RadioButton(selected = estado.motivo == motivo, onClick = null)
                    Text(motivo.texto)
                }
            }
        }
        OutlinedTextField(
            value = estado.detalhes,
            onValueChange = aoMudarDetalhes,
            enabled = !estado.enviando,
            label = {
                Text(if (estado.motivo?.exigeDetalhes == true) TextosCancelarVaga.DETALHES_OBRIGATORIOS else TextosCancelarVaga.DETALHES_OPCIONAIS)
            },
            modifier = Modifier.fillMaxWidth(),
        )
        estado.erro?.let { TextoDeErro(it) }
        if (estado.enviando) TextoDeAndamento(TextosCancelarVaga.ENVIANDO)
        BotaoPrimario(TextosCancelarVaga.CONFIRMAR, aoConfirmar, Modifier.fillMaxWidth(), habilitado = estado.podeConfirmar)
        BotaoSecundario(TextosCancelarVaga.VOLTAR, aoFechar, Modifier.fillMaxWidth(), habilitado = !estado.enviando)
    }
}

@Composable
internal fun ColunaDaTela(titulo: String, modifier: Modifier, conteudo: @Composable () -> Unit) {
    Column(
        modifier = modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(FrilaEspacamento.medio),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.compacto),
    ) {
        Text(titulo, style = MaterialTheme.typography.titleLarge, modifier = Modifier.semantics { heading() })
        conteudo()
    }
}

@Composable
internal fun TextoDeErro(texto: String) {
    Text(texto, color = MaterialTheme.colorScheme.error, modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite })
}

@Composable
internal fun TextoDeAndamento(texto: String) {
    Text(texto, modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite })
}
