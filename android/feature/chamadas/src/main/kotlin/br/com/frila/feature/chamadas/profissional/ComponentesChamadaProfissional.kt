package br.com.frila.feature.chamadas.profissional

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas

/** Barra do topo das telas do profissional: título como cabeçalho e "Voltar" com alvo mínimo. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun BarraDoTopoChamada(titulo: String, aoVoltar: () -> Unit) {
    CenterAlignedTopAppBar(
        title = {
            Text(
                text = titulo,
                style = MaterialTheme.typography.titleLarge,
                modifier = Modifier.semantics { heading() },
            )
        },
        navigationIcon = {
            IconButton(
                onClick = aoVoltar,
                modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = TextosChamadaProfissional.ROTULO_VOLTAR,
                )
            }
        },
    )
}

/** A linha inteira liga e desliga (não só o botão), como o `Toggle` do iOS. */
@Composable
internal fun LinhaComChave(
    titulo: String,
    ligado: Boolean,
    aoMudar: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    habilitado: Boolean = true,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = FrilaMetricas.alvoMinimo)
            .toggleable(value = ligado, enabled = habilitado, role = Role.Switch, onValueChange = aoMudar),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
    ) {
        Text(text = titulo, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
        Switch(checked = ligado, onCheckedChange = null, enabled = habilitado)
    }
}

/** Escolha de uma opção entre poucas: o par do `Picker` do iOS, em linhas com `RadioButton` de alvo mínimo. */
@Composable
internal fun <T> EscolhaUnica(
    titulo: String,
    opcoes: List<Pair<T, String>>,
    selecionada: T,
    aoEscolher: (T) -> Unit,
    modifier: Modifier = Modifier,
    habilitado: Boolean = true,
) {
    Column(modifier = modifier.fillMaxWidth()) {
        Text(
            text = titulo,
            style = MaterialTheme.typography.titleSmall,
            modifier = Modifier.semantics { heading() },
        )
        Column(modifier = Modifier.selectableGroup()) {
            opcoes.forEach { (valor, rotulo) ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = FrilaMetricas.alvoMinimo)
                        .selectable(
                            selected = valor == selecionada,
                            enabled = habilitado,
                            role = Role.RadioButton,
                            onClick = { aoEscolher(valor) },
                        )
                        .padding(vertical = FrilaEspacamento.minimo),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
                ) {
                    RadioButton(selected = valor == selecionada, onClick = null, enabled = habilitado)
                    Text(text = rotulo, style = MaterialTheme.typography.bodyLarge)
                }
            }
        }
    }
}
