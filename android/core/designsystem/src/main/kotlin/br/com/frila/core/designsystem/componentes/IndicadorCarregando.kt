package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaCores

/** Indicador de carregamento (spinner) com o acento da marca (`BrandAccent`). */
@Composable
fun IndicadorCarregando(modifier: Modifier = Modifier) {
    val cor = if (isSystemInDarkTheme()) FrilaCores.brandAccentDark else FrilaCores.brandAccentLight

    CircularProgressIndicator(
        modifier = modifier,
        color = cor,
        strokeWidth = 2.dp,
    )
}
