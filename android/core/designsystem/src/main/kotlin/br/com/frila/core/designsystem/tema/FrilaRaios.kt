package br.com.frila.core.designsystem.tema

import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Raios do desenho do Fabrício, nos valores nominais: cartão 24, elemento dentro de cartão 16, selo 8.
 * Tudo que se toca (botão, chip, busca) é cápsula; quem informa e não se toca (selo) tem canto pequeno.
 */
object FrilaRaios {
    /** Selo de status. */
    val selo: Dp = 8.dp

    /** Campo, bloco de aviso, grupo de linhas e o que fica dentro de um cartão. */
    val interno: Dp = 16.dp

    /** Cartão, diálogo e topo de folha. */
    val cartao: Dp = 24.dp

    /** Só o cartão de vaga com botão dentro: par concêntrico com o botão de raio 16 (20 de respiro + 16). */
    val cartaoDeVaga: Dp = 36.dp

    /** Cápsula. */
    val total: Dp = 999.dp

    // Nomes de antes do redesign, apontando para os valores novos. Código novo usa os nomes acima.
    val pequeno: Dp = selo
    val medio: Dp = interno
    val grande: Dp = cartao
}
