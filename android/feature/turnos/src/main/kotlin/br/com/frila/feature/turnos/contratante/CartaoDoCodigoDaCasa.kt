package br.com.frila.feature.turnos.contratante

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Liga o [CodigoDaCasaViewModel] ao [ConteudoDoCartaoDoCodigo]: gera o código ao abrir, conta a validade a cada
 * segundo e relê o código a cada 5 s para saber se o profissional já confirmou (como o iOS).
 */
@Composable
fun CartaoDoCodigoDaCasa(viewModel: CodigoDaCasaViewModel, modifier: Modifier = Modifier) {
    val estado by viewModel.estado.collectAsState()
    val escopo = rememberCoroutineScope()
    LaunchedEffect(viewModel) {
        viewModel.carregar()
        var segundos = 0
        while (true) {
            delay(1_000)
            segundos++
            viewModel.passo()
            if (segundos % 5 == 0) viewModel.verificarConfirmacao()
        }
    }
    ConteudoDoCartaoDoCodigo(
        estado = estado,
        aoTentarDeNovo = { escopo.launch { viewModel.tentarDeNovo() } },
        modifier = modifier,
    )
}

/**
 * O código de chegada na tela do turno da casa: seis dígitos legíveis, a validade que resta e os estados
 * informativos (sem QR nesta etapa, como o iOS).
 */
// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
@Composable
fun ConteudoDoCartaoDoCodigo(
    estado: EstadoCartaoDoCodigo,
    aoTentarDeNovo: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // `Indisponivel` (chave desligada) e `JaVerificado` (a tela do turno já mostra o selo): nada a mostrar.
    if (estado.estado == EstadoDoCodigoDaCasa.Indisponivel || estado.estado == EstadoDoCodigoDaCasa.JaVerificado) return
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
    ) {
        Text(
            text = TextosCodigoDaCasa.TITULO,
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.semantics { heading() },
        )
        when (val atual = estado.estado) {
            EstadoDoCodigoDaCasa.Carregando -> Progresso(TextosCodigoDaCasa.CARREGANDO)
            EstadoDoCodigoDaCasa.SemCodigoParaEsteCheckin -> Informativo(TextosCodigoDaCasa.SEM_CODIGO_PARA_ESTE_CHECKIN)
            is EstadoDoCodigoDaCasa.Mostrando -> {
                Text(
                    text = TextosCodigoDaCasa.EXPLICACAO,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = atual.codigo,
                    style = MaterialTheme.typography.displayMedium,
                    letterSpacing = 4.sp,
                    maxLines = 1,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .semantics { contentDescription = TextosCodigoDaCasa.codigoPorExtenso(atual.codigo) },
                )
                if (estado.renovando) {
                    Progresso(TextosCodigoDaCasa.GERANDO_OUTRO)
                } else {
                    Text(
                        text = TextosCodigoDaCasa.VALIDADE.format(CodigoDaCasaViewModel.formatar(estado.segundosRestantes)),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
            EstadoDoCodigoDaCasa.ForaDaJanela -> Informativo(TextosCodigoDaCasa.FORA_DA_JANELA)
            EstadoDoCodigoDaCasa.Encerrado -> Informativo(TextosCodigoDaCasa.ENCERRADO)
            EstadoDoCodigoDaCasa.Falhou -> {
                Text(
                    text = TextosCodigoDaCasa.FALHOU,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.error,
                )
                BotaoSecundario(
                    texto = TextosCodigoDaCasa.TENTAR_DE_NOVO,
                    aoClicar = aoTentarDeNovo,
                )
            }
            EstadoDoCodigoDaCasa.Indisponivel, EstadoDoCodigoDaCasa.JaVerificado -> Unit
        }
    }
}

@Composable
private fun Informativo(texto: String) {
    Text(text = texto, style = MaterialTheme.typography.bodyMedium)
}

@Composable
private fun Progresso(texto: String) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
        Text(text = texto, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
