package br.com.frila.feature.turnos

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import java.time.Instant

/**
 * O check-out do turno (L1-4). Aparece com o check-in feito e o check-out ainda não, até 60 min depois do fim; feito,
 * só diz que foi registrado. TELA PROVISÓRIA: substituir pelo high-fi do Fabrício.
 */
// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
@Composable
internal fun SecaoDeCheckout(
    turno: ItemTurno,
    criarCheckinViewModel: @Composable (turno: ItemTurno) -> CheckinViewModel,
    agora: Instant,
) {
    val viewModel = criarCheckinViewModel(turno)
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    val feito = turno.checkoutEm != null || estado.checkout == StatusCheckout.FEITO
    val checkinFeito = estado.comprovante != null || turno.comprovante != null
    Column(
        modifier = Modifier.padding(top = FrilaEspacamento.pequeno),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo),
    ) {
        when {
            feito -> Text(TextosCheckoutECodigo.CHECKOUT_FEITO, style = MaterialTheme.typography.bodySmall)
            estado.checkout == StatusCheckout.REGISTRANDO ->
                Text(TextosCheckoutECodigo.CHECKOUT_REGISTRANDO, style = MaterialTheme.typography.bodySmall)
            RegraDePresenca.podeFazerCheckout(checkinFeito, checkoutFeito = false, fim = turno.fim, agora = agora) -> {
                val comErro = estado.checkout == StatusCheckout.ERRO
                if (comErro) {
                    Text(
                        text = estado.mensagemErroCheckout ?: TextosCheckoutECodigo.CHECKOUT_ERRO_PADRAO,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
                    )
                }
                BotaoSecundario(
                    texto = if (comErro) TextosCheckoutECodigo.BOTAO_CHECKOUT_TENTAR_DE_NOVO else TextosCheckoutECodigo.BOTAO_CHECKOUT,
                    aoClicar = { viewModel.fazerCheckout() },
                )
            }
        }
    }
}
