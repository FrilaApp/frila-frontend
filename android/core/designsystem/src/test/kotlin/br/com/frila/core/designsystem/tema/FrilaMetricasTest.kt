package br.com.frila.core.designsystem.tema

import androidx.compose.ui.unit.dp
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class FrilaMetricasTest {

    @Test
    fun `alvoMinimo e exatamente 48dp - inegociavel, alvo do Material 3 Android`() {
        // Este valor nunca pode regredir para 44dp (o da HIG do iOS): ver
        // docs/android/02-tokens-material3.md §5 e o comentário em FrilaMetricas.kt.
        assertEquals(48.dp, FrilaMetricas.alvoMinimo)
    }

    @Test
    fun `alturas do desenho - botao e campo 48, presenca 64, chip 36, selo 28`() {
        assertEquals(48.dp, FrilaMetricas.alturaBotao)
        assertEquals(48.dp, FrilaMetricas.alturaCampo)
        assertEquals(64.dp, FrilaMetricas.alturaBotaoDePresenca)
        assertEquals(36.dp, FrilaMetricas.alturaChip)
        assertEquals(28.dp, FrilaMetricas.alturaSelo)
    }

    @Test
    fun `nenhum botao fica abaixo do alvo de toque`() {
        assertTrue(FrilaMetricas.alturaBotao >= FrilaMetricas.alvoMinimo)
        assertTrue(FrilaMetricas.alturaBotaoDePresenca >= FrilaMetricas.alvoMinimo)
    }

    @Test
    fun `raios nominais do desenho - cartao 24, interno 16, selo 8`() {
        assertEquals(24.dp, FrilaRaios.cartao)
        assertEquals(16.dp, FrilaRaios.interno)
        assertEquals(8.dp, FrilaRaios.selo)
    }

    @Test
    fun `espacos do desenho - 4, 8, 16, 24, 32 e 48`() {
        assertEquals(4.dp, FrilaEspacamento.junto)
        assertEquals(8.dp, FrilaEspacamento.item)
        assertEquals(16.dp, FrilaEspacamento.bloco)
        assertEquals(24.dp, FrilaEspacamento.grupo)
        assertEquals(32.dp, FrilaEspacamento.secao)
        assertEquals(48.dp, FrilaEspacamento.respiro)
    }
}
