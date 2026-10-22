package br.com.frila.core.designsystem.tema

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private val EsquemaClaro = lightColorScheme(
    primary = FrilaCores.brandPrimaryLight,
    onPrimary = FrilaCores.brandOnPrimaryLight,
    background = FrilaCores.surfaceLight,
    onBackground = FrilaCores.textPrimaryLight,
    surface = FrilaCores.surfaceElevatedLight,
    onSurface = FrilaCores.textPrimaryLight,
    surfaceVariant = FrilaCores.surfaceElevatedLight,
    onSurfaceVariant = FrilaCores.textSecondaryLight,
    error = FrilaCores.dangerLight,
    outline = FrilaCores.controlBorderLight,
    outlineVariant = FrilaCores.hairlineLight,
    tertiary = FrilaCores.successLight,
)

private val EsquemaEscuro = darkColorScheme(
    primary = FrilaCores.brandPrimaryDark,
    onPrimary = FrilaCores.brandOnPrimaryDark,
    background = FrilaCores.surfaceDark,
    onBackground = FrilaCores.textPrimaryDark,
    surface = FrilaCores.surfaceElevatedDark,
    onSurface = FrilaCores.textPrimaryDark,
    surfaceVariant = FrilaCores.surfaceElevatedDark,
    onSurfaceVariant = FrilaCores.textSecondaryDark,
    error = FrilaCores.dangerDark,
    outline = FrilaCores.controlBorderDark,
    outlineVariant = FrilaCores.hairlineDark,
    tertiary = FrilaCores.successDark,
)

/** Tema raiz do app: esquema de cores claro/escuro automático pelo sistema, tipografia Frila. */
@Composable
fun FrilaTheme(
    temaEscuro: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val esquemaDeCores = if (temaEscuro) EsquemaEscuro else EsquemaClaro

    MaterialTheme(
        colorScheme = esquemaDeCores,
        typography = FrilaTypography,
        content = content,
    )
}
