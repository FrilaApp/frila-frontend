package br.com.frila.core.designsystem.tema

import androidx.compose.ui.unit.dp
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class FrilaMetricasTest {

    @Test
    fun `alvoMinimo e exatamente 48dp - inegociavel, alvo do Material 3 Android`() {
        // Este valor nunca pode regredir para 44dp (o da HIG do iOS): ver
        // docs/android/02-tokens-material3.md §5 e o comentário em FrilaMetricas.kt.
        assertEquals(48.dp, FrilaMetricas.alvoMinimo)
    }

    @Test
    fun `alturaBotao e 52dp`() {
        assertEquals(52.dp, FrilaMetricas.alturaBotao)
    }

    @Test
    fun `alturaBotao e maior que alvoMinimo`() {
        assertEquals(true, FrilaMetricas.alturaBotao > FrilaMetricas.alvoMinimo)
    }
}
