package br.com.frila.core.designsystem.tema

import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Raios de borda do Design System.
 *
 * `grande` e `total` seguem o valor explicitamente pedido para o módulo Android (16.dp e
 * 999.dp), não o valor medido no iOS. MEDIDO em `iOS/Sources/Apresentacao/DesignTokens.swift`
 * (`FrilaRaio`): `grande` vale **20**pt lá (usado em `radiusGroupedCard`/`cartaoFrila()`), e não
 * existe um raio `total`/pill — o maior valor do enum iOS é `folha` (28pt, topo de bottom
 * sheet). Ficam aqui os dois valores lado a lado para quem for alinhar os dois design systems
 * decidir qual prevalece; por ora o Android usa os valores pedidos para este módulo.
 */
object FrilaRaios {
    val pequeno: Dp = 8.dp
    val medio: Dp = 12.dp
    val grande: Dp = 16.dp

    /** Pill / círculo total (ex.: chip, botão arredondado por completo). */
    val total: Dp = 999.dp
}
