package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/**
 * O grupo ancorado embaixo das telas de entrada, de formulário e de decisão (vai no `bottomBar` do
 * `Scaffold`): um fio em cima, o conteúdo e o botão primário, com 8dp entre eles. Sobe com o teclado.
 * A [MensagemJuntoAoBotao] e o texto do que o toque faz vão dentro do grupo, ANTES do botão.
 */
@Composable
fun RodapeAncorado(
    modifier: Modifier = Modifier,
    conteudo: @Composable ColumnScope.() -> Unit,
) {
    val cores = FrilaTema.cores
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(cores.fundo)
            .navigationBarsPadding()
            .imePadding(),
    ) {
        FrilaDivisoria(cor = cores.bordaNav)
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(
                    start = FrilaEspacamento.grupo,
                    end = FrilaEspacamento.grupo,
                    top = FrilaEspacamento.bloco,
                    bottom = FrilaEspacamento.item,
                ),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
            content = conteudo,
        )
    }
}

/**
 * Mensagem junto ao botão: o erro ou o resultado de uma ação, logo acima do botão que a disparou.
 * Em tinta, no corpo, sem vermelho, sem ícone e sem cartão (problema não tem cor). Diz o que falhou
 * e o que fazer. O leitor de tela anuncia quando ela aparece ou muda.
 */
@Composable
fun MensagemJuntoAoBotao(texto: String, modifier: Modifier = Modifier) {
    Text(
        text = texto,
        style = FrilaTipo.corpo,
        color = FrilaTema.cores.tinta,
        modifier = modifier
            .fillMaxWidth()
            .semantics { liveRegion = LiveRegionMode.Polite },
    )
}

/**
 * Barra de topo das telas abertas por cima de uma raiz: só o voltar e, se houver, ações à direita,
 * sobre o fundo da tela. Sem título por padrão: o título é conteúdo da tela ([TituloDaTela]). As
 * telas raiz não têm barra nem título de página. Já recua para baixo da barra de status.
 */
@Composable
fun FrilaBarraDeTopo(
    modifier: Modifier = Modifier,
    aoVoltar: (() -> Unit)? = null,
    titulo: String? = null,
    acoes: @Composable RowScope.() -> Unit = {},
) {
    val cores = FrilaTema.cores
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(cores.fundo)
            // O app desenha de borda a borda no Android 15+: a barra recua para baixo da barra de status, como a do Material.
            .windowInsetsPadding(WindowInsets.statusBars)
            .heightIn(min = FrilaMetricas.alvoMinimo)
            // 12 + (48 − 24) / 2 = 24: o desenho da seta alinha com a margem lateral da tela.
            .padding(horizontal = FrilaEspacamento.compacto),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (aoVoltar != null) {
            IconButton(onClick = aoVoltar, modifier = Modifier.size(FrilaMetricas.alvoMinimo)) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Voltar",
                    tint = cores.tinta,
                    modifier = Modifier.size(24.dp),
                )
            }
        }
        Text(
            text = titulo.orEmpty(),
            style = FrilaTipo.nome,
            color = cores.tinta,
            maxLines = 1,
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = if (aoVoltar == null) FrilaEspacamento.compacto else FrilaEspacamento.junto)
                .then(if (titulo != null) Modifier.semantics { heading() } else Modifier),
        )
        acoes()
    }
}
