package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/** Indicador de carregamento, em tinta: o laranja é só do botão que avança. */
@Composable
fun IndicadorCarregando(modifier: Modifier = Modifier) {
    val cores = FrilaTema.cores

    CircularProgressIndicator(
        modifier = modifier,
        color = cores.tinta,
        trackColor = cores.borda,
        strokeWidth = 2.dp,
    )
}

/**
 * Carregando de tela inteira ou de seção: o indicador em tinta e, se houver, uma frase curta do que
 * está sendo carregado, em apoio. Sem cartão e sem laranja.
 */
@Composable
fun EstadoCarregando(modifier: Modifier = Modifier, mensagem: String? = null) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(
                start = FrilaEspacamento.grupo,
                end = FrilaEspacamento.grupo,
                top = FrilaEspacamento.respiro,
                bottom = FrilaEspacamento.grupo,
            ),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
    ) {
        IndicadorCarregando()
        if (!mensagem.isNullOrBlank()) {
            Text(text = mensagem, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave, textAlign = TextAlign.Center)
        }
    }
}
