package br.com.frila.core.designsystem.tema

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

internal val EsquemaClaro = lightColorScheme(
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

internal val EsquemaEscuro = darkColorScheme(
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

val ColorScheme.brandAccent: Color
    get() = if (primary == FrilaCores.brandPrimaryDark) {
        FrilaCores.brandAccentDark
    } else {
        FrilaCores.brandAccentLight
    }

val ColorScheme.warning: Color
    get() = if (primary == FrilaCores.brandPrimaryDark) {
        FrilaCores.warningDark
    } else {
        FrilaCores.warningLight
    }

val ColorScheme.hairline: Color
    get() = if (primary == FrilaCores.brandPrimaryDark) {
        FrilaCores.hairlineDark
    } else {
        FrilaCores.hairlineLight
    }

val ColorScheme.controlBorder: Color
    get() = if (primary == FrilaCores.brandPrimaryDark) {
        FrilaCores.controlBorderDark
    } else {
        FrilaCores.controlBorderLight
    }

val ColorScheme.surfaceElevated: Color
    get() = if (primary == FrilaCores.brandPrimaryDark) {
        FrilaCores.surfaceElevatedDark
    } else {
        FrilaCores.surfaceElevatedLight
    }

internal fun ColorScheme.comCoresCriticasFrila(temaEscuro: Boolean): ColorScheme = copy(
    primary = if (temaEscuro) FrilaCores.brandPrimaryDark else FrilaCores.brandPrimaryLight,
    onPrimary = if (temaEscuro) FrilaCores.brandOnPrimaryDark else FrilaCores.brandOnPrimaryLight,
    error = if (temaEscuro) FrilaCores.dangerDark else FrilaCores.dangerLight,
)

/** Tema raiz do app: esquema de cores claro/escuro automático pelo sistema, tipografia Frila. */
@Composable
fun FrilaTheme(
    temaEscuro: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit,
) {
    val context = LocalContext.current
    val esquemaDeCores = if (dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val esquemaDinamico = if (temaEscuro) {
            dynamicDarkColorScheme(context)
        } else {
            dynamicLightColorScheme(context)
        }
        esquemaDinamico.comCoresCriticasFrila(temaEscuro)
    } else if (temaEscuro) {
        EsquemaEscuro
    } else {
        EsquemaClaro
    }

    MaterialTheme(
        colorScheme = esquemaDeCores,
        typography = FrilaTypography,
        content = content,
    )
}
