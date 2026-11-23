package br.com.frila.feature.perfil

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
@Composable
fun TelaAparencia(
    temaEscuro: Boolean,
    aoEscolher: (Boolean) -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
    salvando: Boolean = false,
    falhou: Boolean = false,
) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = FrilaTema.cores.fundo,
        topBar = { BarraDeTopoDoPerfil(aoVoltar) },
    ) { preenchimento ->
        Column(
            modifier = Modifier.fillMaxSize().padding(preenchimento)
                .verticalScroll(rememberScrollState()).padding(FrilaEspacamento.grupo),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
        ) {
            TituloDaTela(stringResource(R.string.aparencia_titulo))
            Text(stringResource(R.string.aparencia_explicacao), style = FrilaTipo.corpo)
            Column(Modifier.selectableGroup()) {
                listOf(false to R.string.aparencia_claro, true to R.string.aparencia_escuro).forEach { (escuro, texto) ->
                    Row(
                        modifier = Modifier.fillMaxWidth().heightIn(min = FrilaMetricas.alvoMinimo)
                            .selectable(
                                selected = temaEscuro == escuro,
                                enabled = !salvando,
                                role = Role.RadioButton,
                                onClick = { aoEscolher(escuro) },
                            ),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        RadioButton(selected = temaEscuro == escuro, onClick = null, enabled = !salvando)
                        Text(stringResource(texto), style = FrilaTipo.corpo)
                    }
                }
            }
            if (falhou) {
                Text(
                    stringResource(R.string.aparencia_erro),
                    style = FrilaTipo.corpo,
                    modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
                )
            }
        }
    }
}
