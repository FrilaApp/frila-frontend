package br.com.frila.core.designsystem.tema

import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Métricas de componente. `alvoMinimo` é a diretriz de alvo de toque do **Android/Material 3**
 * (48dp) — diferente dos 44pt da HIG da Apple usados no `FrilaMetrica.alvoMinimo` do iOS. O
 * Android não replica o número do iOS, replica o papel do token com o piso correto da própria
 * plataforma (ver `docs/android/02-tokens-material3.md` §5). Este valor é inegociável.
 */
object FrilaMetricas {
    val alvoMinimo: Dp = 48.dp
    val alturaBotao: Dp = 52.dp
}
