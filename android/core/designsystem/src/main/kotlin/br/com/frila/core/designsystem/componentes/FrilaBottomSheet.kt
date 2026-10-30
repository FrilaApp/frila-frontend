package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SheetState
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.paneTitle
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaRaios

/**
 * Puxador visual de arrastar do [FrilaBottomSheet] (RNF10). Decorativo: `clearAndSetSemantics { }`
 * remove qualquer semântica própria (incluindo a de `ModalBottomSheet` para o drag handle
 * padrão), para o TalkBack não anunciar nada ao focar nele — paridade com `accessibilityHidden`
 * do puxador no iOS (`iOS/Sources/Apresentacao/DesignSystem/Componentes.swift:676`).
 *
 * A área de toque total tem [FrilaMetricas.alvoMinimo] (48dp) de altura, mesmo que a barra
 * visual em si seja só 5dp — o alvo de arrasto precisa ser generoso, só a semântica é que é
 * escondida.
 */
@Composable
fun FrilaDragHandle(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(FrilaMetricas.alvoMinimo)
            .clearAndSetSemantics { },
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .width(36.dp)
                .height(5.dp)
                .background(
                    color = MaterialTheme.colorScheme.outlineVariant,
                    shape = RoundedCornerShape(FrilaRaios.total),
                ),
        )
    }
}

/**
 * Bottom sheet padronizado do Design System (RNF10, cartão 9X49Nr0l) — encapsula
 * `ModalBottomSheet` com os tokens Frila e a semântica de acessibilidade que a implementação
 * crua (ver histórico de `TelaFeedVagas.kt`) não tinha: puxador decorativo oculto do TalkBack,
 * `paneTitle` para o painel, cabeçalho com trait `heading()`, e botão de fechar com alvo mínimo
 * de 48dp. Paridade com `FolhaFrila` do iOS
 * (`iOS/Sources/Apresentacao/DesignSystem/Componentes.swift:676-695`).
 *
 * `aoFechar` é separado de [onDismissRequest] de propósito: [onDismissRequest] é chamado pelo
 * `ModalBottomSheet` em qualquer dismissal (swipe, toque fora, voltar); `aoFechar` é
 * especificamente a ação do botão "Fechar" visível — por padrão as duas coincidem, mas um
 * chamador pode querer, por exemplo, confirmar antes de fechar pelo botão.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FrilaBottomSheet(
    onDismissRequest: () -> Unit,
    modifier: Modifier = Modifier,
    sheetState: SheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
    titulo: String? = null,
    aoFechar: (() -> Unit)? = onDismissRequest,
    dragHandle: @Composable (() -> Unit)? = { FrilaDragHandle() },
    forma: Shape = RoundedCornerShape(
        topStart = FrilaRaios.grande,
        topEnd = FrilaRaios.grande,
        bottomStart = 0.dp,
        bottomEnd = 0.dp,
    ),
    corContainer: Color = MaterialTheme.colorScheme.surface,
    corConteudo: Color = MaterialTheme.colorScheme.onSurface,
    corScrim: Color = Color.Black.copy(alpha = 0.4f),
    elevacaoTonal: Dp = 0.dp,
    conteudo: @Composable ColumnScope.() -> Unit,
) {
    ModalBottomSheet(
        onDismissRequest = onDismissRequest,
        modifier = modifier.semantics { paneTitle = titulo ?: "Folha modal" },
        sheetState = sheetState,
        shape = forma,
        containerColor = corContainer,
        contentColor = corConteudo,
        tonalElevation = elevacaoTonal,
        scrimColor = corScrim,
        dragHandle = dragHandle,
    ) {
        Column {
            if (titulo != null || aoFechar != null) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = FrilaEspacamento.medio),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    if (titulo != null) {
                        Text(
                            text = titulo,
                            style = MaterialTheme.typography.titleMedium,
                            modifier = Modifier
                                .weight(1f)
                                .semantics { heading() },
                        )
                    } else {
                        Box(modifier = Modifier.weight(1f))
                    }
                    if (aoFechar != null) {
                        IconButton(
                            onClick = aoFechar,
                            modifier = Modifier.size(FrilaMetricas.alvoMinimo),
                        ) {
                            Icon(imageVector = Icons.Default.Close, contentDescription = "Fechar")
                        }
                    }
                }
            }
            conteudo()
        }
    }
}
