package br.com.frila.core.designsystem.tema

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

/**
 * A paleta do Frila nos papéis do Material 3, para os componentes do Material já nascerem no desenho:
 * - `primary` é a TINTA, não o laranja: seleção, foco, cursor, interruptor e texto de botão do Material
 *   ficam em tinta ("escolhido" é tinta). O laranja só aparece no `BotaoPrimario`, que o usa direto.
 * - `error` também é tinta: problema não tem cor. A mensagem diz o que falhou e o que fazer.
 * - `secondaryContainer` é tinta com texto claro: o chip marcado do Material sai como o do desenho.
 * - `outline` é o contorno de campo e `outlineVariant` o fio de cartões e divisórias.
 * - As superfícies de contêiner ficam sem o tom lilás padrão do Material.
 */
private fun esquemaDe(paleta: PaletaFrila, escuro: Boolean): ColorScheme {
    val base = if (escuro) darkColorScheme() else lightColorScheme()
    return base.copy(
        primary = paleta.tinta,
        onPrimary = paleta.sobreTinta,
        primaryContainer = paleta.superficiePressionada,
        onPrimaryContainer = paleta.tinta,
        inversePrimary = paleta.sobreTinta,
        secondary = paleta.tinta,
        onSecondary = paleta.sobreTinta,
        secondaryContainer = paleta.tinta,
        onSecondaryContainer = paleta.sobreTinta,
        tertiary = paleta.tinta,
        onTertiary = paleta.sobreTinta,
        tertiaryContainer = paleta.superficiePressionada,
        onTertiaryContainer = paleta.tinta,
        background = paleta.fundo,
        onBackground = paleta.tinta,
        surface = paleta.superficie,
        onSurface = paleta.tinta,
        surfaceVariant = paleta.superficie,
        onSurfaceVariant = paleta.tintaSuave,
        surfaceTint = Color.Transparent,
        inverseSurface = paleta.tinta,
        inverseOnSurface = paleta.sobreTinta,
        error = paleta.tinta,
        onError = paleta.sobreTinta,
        errorContainer = paleta.superficiePressionada,
        onErrorContainer = paleta.tinta,
        outline = paleta.bordaControle,
        outlineVariant = paleta.borda,
        scrim = FrilaCores.tintaClaro,
        surfaceBright = paleta.superficie,
        surfaceDim = paleta.fundo,
        surfaceContainerLowest = paleta.superficie,
        surfaceContainerLow = paleta.superficie,
        surfaceContainer = paleta.superficie,
        surfaceContainerHigh = paleta.superficie,
        surfaceContainerHighest = paleta.superficiePressionada,
    )
}

internal val EsquemaClaro = esquemaDe(PaletaClara, escuro = false)

internal val EsquemaEscuro = esquemaDe(PaletaEscura, escuro = true)

/**
 * Modo OLED (RNF10): só `background` vira preto puro. `surface`/`surfaceVariant` permanecem em
 * `superficieEscuro` de propósito — é o contraste entre o preto puro do fundo e o cinza quase-preto
 * dos cartões que separa os dois; igualar apagaria essa hierarquia.
 */
internal val EsquemaEscuroOled = EsquemaEscuro.copy(
    background = FrilaCores.fundoOled,
)

/** Com as cores do papel de parede (Material You), a tinta e a regra "problema não tem cor" continuam do Frila. */
internal fun ColorScheme.comCoresCriticasFrila(temaEscuro: Boolean): ColorScheme {
    val paleta = if (temaEscuro) PaletaEscura else PaletaClara
    return copy(
        primary = paleta.tinta,
        onPrimary = paleta.sobreTinta,
        error = paleta.tinta,
        onError = paleta.sobreTinta,
    )
}

/**
 * Formas do Material no desenho do Frila: campo e menu em 16, chip em cápsula (tudo que se toca é
 * cápsula), cartão, diálogo e folha em 24.
 */
internal val FormasFrila = Shapes(
    extraSmall = RoundedCornerShape(FrilaRaios.interno),
    small = CircleShape,
    medium = RoundedCornerShape(FrilaRaios.cartao),
    large = RoundedCornerShape(FrilaRaios.cartao),
    extraLarge = RoundedCornerShape(FrilaRaios.cartao),
)

/**
 * Tema raiz do app: paleta clara/escura automática pelo sistema, tipografia e formas do Frila.
 *
 * `dynamicColor` (Material You, API 31+) gera o esquema a partir do papel de parede do aparelho
 * e sempre aplica [comCoresCriticasFrila] por cima; a paleta do Frila (`FrilaTema.cores`) não muda.
 * `modoOled` (RNF10) só tem efeito no escuro — dynamic ou não — e troca só o fundo para preto puro.
 */
@Composable
fun FrilaTheme(
    temaEscuro: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = false,
    modoOled: Boolean = false,
    content: @Composable () -> Unit,
) {
    val context = LocalContext.current
    val oled = temaEscuro && modoOled
    val esquemaDeCores = if (dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val esquemaDinamico = if (temaEscuro) {
            dynamicDarkColorScheme(context)
        } else {
            dynamicLightColorScheme(context)
        }
        val comCriticas = esquemaDinamico.comCoresCriticasFrila(temaEscuro)
        if (oled) comCriticas.copy(background = FrilaCores.fundoOled) else comCriticas
    } else if (oled) {
        EsquemaEscuroOled
    } else if (temaEscuro) {
        EsquemaEscuro
    } else {
        EsquemaClaro
    }
    val paleta = when {
        oled -> PaletaEscuraOled
        temaEscuro -> PaletaEscura
        else -> PaletaClara
    }

    CompositionLocalProvider(LocalPaletaFrila provides paleta) {
        MaterialTheme(
            colorScheme = esquemaDeCores,
            typography = FrilaTypography,
            shapes = FormasFrila,
            content = content,
        )
    }
}
