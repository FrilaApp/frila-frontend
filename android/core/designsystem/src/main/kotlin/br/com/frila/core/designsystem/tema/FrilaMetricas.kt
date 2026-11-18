package br.com.frila.core.designsystem.tema

import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Alturas do desenho do Fabrício. São mínimos: o texto cresce com o tamanho de fonte do sistema.
 * `alvoMinimo` é o alvo de toque do Material 3 (48dp), igual ao alvo do desenho. Este valor é inegociável.
 */
object FrilaMetricas {
    val alvoMinimo: Dp = 48.dp

    /** Botão primário e secundário, campo e linha de lista. */
    val alturaBotao: Dp = 48.dp
    val alturaCampo: Dp = 48.dp

    /** "MARCAR PRESENÇA". */
    val alturaBotaoDePresenca: Dp = 64.dp

    /** Chip: 36 de desenho dentro de um alvo de 48. */
    val alturaChip: Dp = 36.dp

    val alturaSelo: Dp = 28.dp

    /** Caixa de dígito do código: o passo da grade acima do campo, para o dígito respirar. */
    val alturaCaixaDeCodigo: Dp = 56.dp
}
