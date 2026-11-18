package br.com.frila.feature.turnos.contratante

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
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
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.IndicadorCarregando
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
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
 * O código de chegada na tela do turno da casa: cartão com seis dígitos grandes, legíveis de longe, a validade que
 * resta e os estados informativos (sem QR nesta etapa, como o iOS). A casa só mostra o código: nada de laranja aqui.
 */
@Composable
fun ConteudoDoCartaoDoCodigo(
    estado: EstadoCartaoDoCodigo,
    aoTentarDeNovo: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // `Indisponivel` (chave desligada) e `JaVerificado` (a tela do turno já mostra o selo): nada a mostrar.
    if (estado.estado == EstadoDoCodigoDaCasa.Indisponivel || estado.estado == EstadoDoCodigoDaCasa.JaVerificado) return
    CartaoFrila(modifier = modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
        ) {
            Text(
                text = TextosCodigoDaCasa.TITULO,
                style = FrilaTipo.nome,
                color = FrilaTema.cores.tinta,
                modifier = Modifier.semantics { heading() },
            )
            when (val atual = estado.estado) {
                EstadoDoCodigoDaCasa.Carregando -> Progresso(TextosCodigoDaCasa.CARREGANDO)
                EstadoDoCodigoDaCasa.SemCodigoParaEsteCheckin -> Informativo(TextosCodigoDaCasa.SEM_CODIGO_PARA_ESTE_CHECKIN)
                is EstadoDoCodigoDaCasa.Mostrando -> {
                    Text(text = TextosCodigoDaCasa.EXPLICACAO, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave)
                    Text(
                        text = atual.codigo,
                        style = FrilaTipo.valorEmDestaque.copy(letterSpacing = 6.sp),
                        color = FrilaTema.cores.tinta,
                        maxLines = 1,
                        textAlign = TextAlign.Center,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = FrilaEspacamento.item)
                            .semantics { contentDescription = TextosCodigoDaCasa.codigoPorExtenso(atual.codigo) },
                    )
                    if (estado.renovando) {
                        Progresso(TextosCodigoDaCasa.GERANDO_OUTRO)
                    } else {
                        Text(
                            text = TextosCodigoDaCasa.VALIDADE.format(CodigoDaCasaViewModel.formatar(estado.segundosRestantes)),
                            style = FrilaTipo.apoio,
                            color = FrilaTema.cores.tintaSuave,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
                EstadoDoCodigoDaCasa.ForaDaJanela -> Informativo(TextosCodigoDaCasa.FORA_DA_JANELA)
                EstadoDoCodigoDaCasa.Encerrado -> Informativo(TextosCodigoDaCasa.ENCERRADO)
                EstadoDoCodigoDaCasa.Falhou -> {
                    Text(text = TextosCodigoDaCasa.FALHOU, style = FrilaTipo.corpo, color = FrilaTema.cores.tinta)
                    BotaoSecundario(
                        texto = TextosCodigoDaCasa.TENTAR_DE_NOVO,
                        aoClicar = aoTentarDeNovo,
                    )
                }
                EstadoDoCodigoDaCasa.Indisponivel, EstadoDoCodigoDaCasa.JaVerificado -> Unit
            }
        }
    }
}

@Composable
private fun Informativo(texto: String) {
    Text(text = texto, style = FrilaTipo.corpo, color = FrilaTema.cores.tinta)
}

@Composable
private fun Progresso(texto: String) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IndicadorCarregando(modifier = Modifier.size(20.dp))
        Text(text = texto, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave)
    }
}
