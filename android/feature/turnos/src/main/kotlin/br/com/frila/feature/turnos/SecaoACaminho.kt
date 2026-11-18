package br.com.frila.feature.turnos

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private val FUSO_DO_A_CAMINHO: ZoneId = ZoneId.of("America/Sao_Paulo")
private val FORMATO_HORA: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm").withZone(FUSO_DO_A_CAMINHO)

/**
 * "Estou a caminho" no cartão do turno confirmado (US14, RF12; L2-1): o botão dentro da janela, o aviso já feito com a
 * hora de Brasília, ou nada fora da janela. Não substitui o check-in. A recusa do servidor aparece logo acima do botão,
 * em texto do Frila, e o botão continua para tentar de novo.
 *
 * O botão é o primário da tela (o desenho dá o laranja ao "Estou a caminho" no dia do turno); enquanto o aviso é
 * enviado, fica no lugar, desligado, sem indicador girando.
 */
@Composable
fun SecaoACaminho(
    turno: ItemTurno,
    avisando: Boolean,
    mensagemErro: String?,
    aoAvisar: () -> Unit,
    agora: Instant,
    modifier: Modifier = Modifier,
) {
    val avisouEm = turno.aCaminhoEm
    val oferecer = podeAvisarACaminho(turno, agora)
    if (avisouEm == null && !oferecer) return
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        if (avisouEm != null) {
            Text(
                text = TextosACaminho.avisou(FORMATO_HORA.format(avisouEm)),
                style = FrilaTipo.corpo,
                color = FrilaTema.cores.tinta,
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
            )
        }
        mensagemErro?.let { MensagemDeAcao(texto = it) }
        if (avisouEm == null) {
            BotaoDeAcaoDoTurno(
                texto = if (avisando) TextosACaminho.AVISANDO else TextosACaminho.BOTAO,
                aoClicar = aoAvisar,
                destaque = true,
                habilitado = !avisando,
            )
        }
    }
}
