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

/**
 * Modo OLED (RNF10): só `background` vira preto puro. `surface`/`surfaceVariant` permanecem em
 * `surfaceElevatedDark` (#1C1C1A) de propósito — é o contraste entre o preto puro do fundo e o
 * cinza quase-preto dos cartões que dá a elevação visual; igualar os dois apagaria essa hierarquia.
 */
internal val EsquemaEscuroOled = EsquemaEscuro.copy(
    background = FrilaCores.surfaceOled,
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

/**
 * Tema raiz do app: esquema de cores claro/escuro automático pelo sistema, tipografia Frila.
 *
 * `dynamicColor` (Material You, API 31+) gera o esquema a partir do papel de parede do aparelho
 * e sempre aplica [comCoresCriticasFrila] por cima, para que marca e cores semânticas (perigo)
 * nunca fiquem reféns da paleta extraída do usuário. `modoOled` (RNF10) só tem efeito no escuro
 * — dynamic ou não — e troca só o `background` para preto puro.
 */
@Composable
fun FrilaTheme(
    temaEscuro: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = false,
    modoOled: Boolean = false,
    content: @Composable () -> Unit,
) {
    val context = LocalContext.current
    val esquemaDeCores = if (dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val esquemaDinamico = if (temaEscuro) {
            dynamicDarkColorScheme(context)
        } else {
            dynamicLightColorScheme(context)
        }
        val comCriticas = esquemaDinamico.comCoresCriticasFrila(temaEscuro)
        if (temaEscuro && modoOled) {
            comCriticas.copy(background = FrilaCores.surfaceOled)
        } else {
            comCriticas
        }
    } else if (temaEscuro && modoOled) {
        EsquemaEscuroOled
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
