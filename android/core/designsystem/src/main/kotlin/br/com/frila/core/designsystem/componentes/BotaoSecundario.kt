package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/**
 * Botão secundário: superfície com fio de `borda`, cápsula de 48dp, rótulo em tinta (600, 16sp).
 * Para a ação auxiliar da tela ("Abrir no mapa") e para a ação de um estado vazio ou de erro.
 */
@Composable
fun BotaoSecundario(
    texto: String,
    aoClicar: () -> Unit,
    modifier: Modifier = Modifier,
    habilitado: Boolean = true,
) {
    val cores = FrilaTema.cores
    val interacao = remember { MutableInteractionSource() }
    val pressionado by interacao.collectIsPressedAsState()

    OutlinedButton(
        onClick = aoClicar,
        enabled = habilitado,
        modifier = modifier
            .sizeIn(
                minWidth = FrilaMetricas.alvoMinimo,
                minHeight = FrilaMetricas.alvoMinimo,
            )
            .heightIn(min = FrilaMetricas.alturaBotao)
            .widthIn(min = FrilaMetricas.alvoMinimo)
            .focoAcessivelFrila(forma = CircleShape),
        shape = CircleShape,
        border = BorderStroke(1.dp, cores.borda),
        colors = ButtonDefaults.outlinedButtonColors(
            containerColor = if (pressionado) cores.superficiePressionada else cores.superficie,
            contentColor = cores.tinta,
            disabledContainerColor = cores.superficie,
            disabledContentColor = cores.tintaSuave,
        ),
        contentPadding = PaddingValues(horizontal = FrilaEspacamento.bloco, vertical = FrilaEspacamento.item),
        interactionSource = interacao,
    ) {
        Text(text = texto, style = FrilaTipo.rotuloSecundario, textAlign = TextAlign.Center)
    }
}
