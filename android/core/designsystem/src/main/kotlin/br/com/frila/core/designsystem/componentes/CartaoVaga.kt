package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaRaios

/**
 * Cartão de vaga: fundo `SurfaceElevated`, contorno `Hairline` de 1dp, raio 12dp
 * (`FrilaRaios.medio`) — zero-shadow, igual ao `cartaoFrila()` do iOS.
 */
@Composable
fun CartaoVaga(
    modifier: Modifier = Modifier,
    forma: Shape = RoundedCornerShape(FrilaRaios.medio),
    conteudo: @Composable () -> Unit,
) {
    Column(
        modifier = modifier
            .background(MaterialTheme.colorScheme.surface, shape = forma)
            .border(BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant), shape = forma)
            .padding(FrilaEspacamento.medio),
    ) {
        conteudo()
    }
}
