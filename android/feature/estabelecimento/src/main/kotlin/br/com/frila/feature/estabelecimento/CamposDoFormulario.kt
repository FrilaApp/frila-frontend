package br.com.frila.feature.estabelecimento

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaRaios
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

// Peças deste formulário que o sistema de design ainda não tem. Quando subirem para `core/designsystem`, esta cópia sai.

/**
 * A barra de topo de uma tela de formulário: só o voltar, que pode ficar desligado enquanto o envio roda.
 * É a `FrilaBarraDeTopo` com `habilitado`, que o componente do sistema ainda não tem.
 */
@Composable
internal fun BarraDeTopoDoFormulario(
    aoVoltar: () -> Unit,
    rotuloDoVoltar: String,
    modifier: Modifier = Modifier,
    habilitado: Boolean = true,
) {
    val cores = FrilaTema.cores
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(cores.fundo)
            .heightIn(min = FrilaMetricas.alvoMinimo)
            .padding(horizontal = FrilaEspacamento.compacto),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(onClick = aoVoltar, enabled = habilitado, modifier = Modifier.size(FrilaMetricas.alvoMinimo)) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = rotuloDoVoltar,
                tint = if (habilitado) cores.tinta else cores.tintaSuave,
                modifier = Modifier.size(24.dp),
            )
        }
    }
}

/**
 * Campo que abre uma escolha (folha) em vez de receber texto: o mesmo desenho do `CampoDeTexto` (rótulo
 * acima, caixa de 48dp, contorno `bordaControle`, raio 16), com a seta para baixo no fim. O rótulo e o valor
 * formam um alvo só para o leitor de tela. O erro vem escrito embaixo, em tinta; sem erro, vem o apoio.
 */
@Composable
internal fun CampoDeSelecao(
    rotulo: String,
    valor: String,
    aoClicar: () -> Unit,
    modifier: Modifier = Modifier,
    habilitado: Boolean = true,
    apoio: String? = null,
    erro: String? = null,
) {
    val cores = FrilaTema.cores
    val forma = RoundedCornerShape(FrilaRaios.interno)
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(enabled = habilitado, role = Role.Button, onClick = aoClicar)
                .semantics { if (erro != null) error(erro) },
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
        ) {
            Text(text = rotulo, style = FrilaTipo.rotuloDeGrupo, color = cores.tintaSuave)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = FrilaMetricas.alturaCampo)
                    .background(cores.superficie, forma)
                    .border(width = if (erro != null) 2.dp else 1.dp, color = if (erro != null) cores.tinta else cores.bordaControle, shape = forma)
                    .padding(horizontal = FrilaEspacamento.bloco, vertical = FrilaEspacamento.compacto),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
            ) {
                Text(
                    text = valor,
                    style = FrilaTipo.corpo,
                    color = if (habilitado) cores.tinta else cores.tintaSuave,
                    modifier = Modifier.weight(1f),
                )
                Icon(
                    imageVector = Icons.Default.ArrowDropDown,
                    contentDescription = null,
                    tint = if (habilitado) cores.tinta else cores.tintaSuave,
                    modifier = Modifier.size(24.dp),
                )
            }
        }
        if (erro != null) {
            Text(text = erro, style = FrilaTipo.apoio, color = cores.tinta)
        } else if (apoio != null) {
            Text(text = apoio, style = FrilaTipo.apoio, color = cores.tintaSuave)
        }
    }
}
