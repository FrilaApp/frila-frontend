package br.com.frila.feature.perfil

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/*
 * Linhas que o perfil usa dentro de um `FrilaGrupoDeLinhas` e que o design system ainda não tem: a de interruptor e a de
 * valor sem toque. Moram aqui, no módulo do perfil, até subirem para `core/designsystem` (ver o retorno do lote R4a).
 */

/**
 * Linha com interruptor: o rótulo à esquerda e o `Switch` à direita. A linha inteira é o alvo (48dp no mínimo), não só o
 * interruptor, e anuncia-se como interruptor. Quem chama põe `testTag` e `stateDescription` em [modifier], se precisar.
 * Desligada ([habilitada] falso), o rótulo vai em tinta suave.
 */
@Composable
internal fun LinhaDeInterruptor(
    rotulo: String,
    ativada: Boolean,
    aoAlternar: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    habilitada: Boolean = true,
    subtitulo: String? = null,
) {
    val cores = FrilaTema.cores
    Row(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = FrilaMetricas.alvoMinimo)
            .toggleable(value = ativada, enabled = habilitada, role = Role.Switch, onValueChange = aoAlternar)
            .padding(horizontal = FrilaEspacamento.bloco, vertical = FrilaEspacamento.item),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
    ) {
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.fio)) {
            Text(
                text = rotulo,
                style = FrilaTipo.rotuloSecundario,
                color = if (habilitada) cores.tinta else cores.tintaSuave,
            )
            if (!subtitulo.isNullOrBlank()) {
                Text(text = subtitulo, style = FrilaTipo.apoio, color = cores.tintaSuave)
            }
        }
        Switch(checked = ativada, onCheckedChange = null, enabled = habilitada)
    }
}

/**
 * Linha de leitura: o rótulo à esquerda e o valor à direita, em tinta suave. Não se toca; é a "Permissão no sistema" do
 * bloco de notificações, por exemplo. [modificadorDoValor] leva a semântica do valor (o estado dito ao leitor de tela).
 */
@Composable
internal fun LinhaDeValor(
    rotulo: String,
    valor: String,
    modifier: Modifier = Modifier,
    modificadorDoValor: Modifier = Modifier,
) {
    val cores = FrilaTema.cores
    Row(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = FrilaMetricas.alvoMinimo)
            .padding(horizontal = FrilaEspacamento.bloco, vertical = FrilaEspacamento.item),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
    ) {
        Text(
            text = rotulo,
            style = FrilaTipo.rotuloSecundario,
            color = cores.tinta,
            modifier = Modifier.weight(1f),
        )
        Text(text = valor, style = FrilaTipo.corpo, color = cores.tintaSuave, modifier = modificadorDoValor)
    }
}
