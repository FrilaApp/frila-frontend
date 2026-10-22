package br.com.frila.core.designsystem.tema

import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/** Espaçamento do Design System, 1:1 com `FrilaEspaco` do iOS (pt→dp, mesma base de densidade). */
object FrilaEspacamento {
    /** Entre título e subtítulo de um mesmo bloco. */
    val fio: Dp = 2.dp
    val minimo: Dp = 4.dp
    val pequeno: Dp = 8.dp

    /** Entre cartões de uma lista e dentro de grupos. */
    val compacto: Dp = 12.dp

    /** Entre as faixas de um cartão (cabeçalho, linhas, divisória). */
    val faixa: Dp = 14.dp
    val medio: Dp = 16.dp
    val grande: Dp = 24.dp
    val enorme: Dp = 32.dp
}
