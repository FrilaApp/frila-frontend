package br.com.frila.core.designsystem.tema

import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/** Espaços do desenho do Fabrício (grade de 8), com os mesmos nomes do iOS. */
object FrilaEspacamento {
    /** Linhas do mesmo dado; ícone do selo. */
    val junto: Dp = 4.dp

    /** Ícone e texto; entre linhas de dado; mensagem e botão. */
    val item: Dp = 8.dp

    /** Padding de cartão; entre cartões; acima e abaixo da divisória. */
    val bloco: Dp = 16.dp

    /** Margem lateral da tela; do título ao cartão; entre blocos de um detalhe. */
    val grupo: Dp = 24.dp

    /** Acima de seção e das ações discretas. */
    val secao: Dp = 32.dp

    /** Acima do estado vazio. */
    val respiro: Dp = 48.dp

    // Nomes de antes do redesign. Código novo usa os nomes acima.
    val fio: Dp = 2.dp
    val minimo: Dp = junto
    val pequeno: Dp = item
    val compacto: Dp = 12.dp
    val faixa: Dp = 14.dp
    val medio: Dp = bloco
    val grande: Dp = grupo
    val enorme: Dp = secao
}
