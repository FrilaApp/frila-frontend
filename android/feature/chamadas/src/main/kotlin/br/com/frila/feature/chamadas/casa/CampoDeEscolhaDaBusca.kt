package br.com.frila.feature.chamadas.casa

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaRaios
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/** Uma opção do [CampoDeEscolha]: o texto e o que acontece ao escolhê-la. */
internal class OpcaoDeEscolha(val texto: String, val aoEscolher: () -> Unit)

/**
 * Campo de escolha de um catálogo longo (serviço, região): rótulo acima, caixa de 48dp em superfície com contorno
 * `bordaControle` e raio 16, igual ao `CampoDeTexto`, e um menu com as opções. Para listas curtas a escolha é uma
 * lista com check; aqui o catálogo é grande demais para ficar na tela. Componente do módulo: sobe ao design system
 * quando outra tela precisar dele.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun CampoDeEscolha(
    rotulo: String,
    valor: String?,
    dica: String,
    aberto: Boolean,
    aoMudarAberto: (Boolean) -> Unit,
    opcoes: List<OpcaoDeEscolha>,
    modifier: Modifier = Modifier,
) {
    val cores = FrilaTema.cores
    val forma = RoundedCornerShape(FrilaRaios.interno)
    ExposedDropdownMenuBox(expanded = aberto, onExpandedChange = aoMudarAberto) {
        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
            Text(text = rotulo, style = FrilaTipo.rotuloDeGrupo, color = cores.tintaSuave)
            Row(
                modifier = modifier
                    .menuAnchor()
                    .fillMaxWidth()
                    .heightIn(min = FrilaMetricas.alturaCampo)
                    .background(cores.superficie, forma)
                    .border(1.dp, cores.bordaControle, forma)
                    .padding(horizontal = FrilaEspacamento.bloco, vertical = FrilaEspacamento.compacto),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
            ) {
                Text(
                    text = valor ?: dica,
                    style = FrilaTipo.corpo,
                    color = if (valor == null) cores.tintaSuave else cores.tinta,
                    modifier = Modifier.weight(1f),
                )
                ExposedDropdownMenuDefaults.TrailingIcon(expanded = aberto)
            }
        }
        ExposedDropdownMenu(expanded = aberto, onDismissRequest = { aoMudarAberto(false) }) {
            opcoes.forEach { opcao ->
                DropdownMenuItem(
                    text = { Text(text = opcao.texto, style = FrilaTipo.corpo, color = cores.tinta) },
                    onClick = {
                        opcao.aoEscolher()
                        aoMudarAberto(false)
                    },
                )
            }
        }
    }
}
