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
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
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

/** O que o leitor de tela diz do carregando sem mensagem: o mesmo texto do iOS (`EstadosDeTela.swift:60`). */
private const val ROTULO_CARREGANDO = "Carregando\u2026"

/**
 * Carregando de tela inteira ou de seção: o indicador em tinta e, se houver, uma frase curta do que
 * está sendo carregado, em apoio. Sem cartão e sem laranja.
 *
 * Para o leitor de tela é um elemento só, como no iOS (`.accessibilityElement(children: .ignore)` e `.accessibilityLabel("Carregando…")`): sem mensagem, lê
 * "Carregando…"; com mensagem, lê a mensagem, uma vez, e o indicador não é uma segunda parada (item 283). Um rótulo que o chamador já ponha no [modifier] vale
 * mais que o genérico.
 */
@Composable
fun EstadoCarregando(modifier: Modifier = Modifier, mensagem: String? = null) {
    val frase = mensagem?.takeIf { it.isNotBlank() }
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(
                start = FrilaEspacamento.grupo,
                end = FrilaEspacamento.grupo,
                top = FrilaEspacamento.respiro,
                bottom = FrilaEspacamento.grupo,
            )
            .then(if (frase == null) Modifier.clearAndSetSemantics { contentDescription = ROTULO_CARREGANDO } else Modifier),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
    ) {
        IndicadorCarregando(modifier = if (frase != null) Modifier.clearAndSetSemantics { } else Modifier)
        if (frase != null) {
            Text(text = frase, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave, textAlign = TextAlign.Center)
        }
    }
}
