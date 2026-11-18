package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/**
 * Chip do Frila: cápsula de 36dp de desenho dentro de um alvo de 48dp. Solto: superfície, fio de
 * `borda`, texto em tinta. MARCADO: tinta com texto claro (escolhido é tinta, nunca laranja).
 *
 * Chip é só para filtro e seleção múltipla; com `escolhaUnica`, vale como opção de um grupo em que
 * só uma fica marcada (motivo do cancelamento). Escolha única em formulário é lista com check
 * ([FrilaLinhaDeOpcao]).
 */
@Composable
fun ChipFrila(
    texto: String,
    selecionado: Boolean,
    aoClicar: () -> Unit,
    modifier: Modifier = Modifier,
    habilitado: Boolean = true,
    escolhaUnica: Boolean = false,
) {
    val cores = FrilaTema.cores
    val interacao = remember { MutableInteractionSource() }
    val pressionado by interacao.collectIsPressedAsState()
    val fundo = when {
        selecionado && pressionado -> cores.tintaPressionada
        selecionado -> cores.tinta
        pressionado -> cores.superficiePressionada
        else -> cores.superficie
    }
    val toque = if (escolhaUnica) {
        Modifier.selectable(
            selected = selecionado,
            interactionSource = interacao,
            indication = null,
            enabled = habilitado,
            role = Role.RadioButton,
            onClick = aoClicar,
        )
    } else {
        Modifier.toggleable(
            value = selecionado,
            interactionSource = interacao,
            indication = null,
            enabled = habilitado,
            role = Role.Checkbox,
            onValueChange = { aoClicar() },
        )
    }

    Box(
        modifier = modifier
            .sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo)
            .focoAcessivelFrila(forma = CircleShape)
            .then(toque),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .heightIn(min = FrilaMetricas.alturaChip)
                .background(fundo, CircleShape)
                .then(if (selecionado) Modifier else Modifier.border(1.dp, cores.borda, CircleShape))
                .padding(horizontal = FrilaEspacamento.bloco, vertical = FrilaEspacamento.item),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = texto,
                style = FrilaTipo.chip,
                color = if (selecionado) cores.sobreTinta else cores.tinta,
            )
        }
    }
}
