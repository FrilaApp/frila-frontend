package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaRaios
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/**
 * Tons de alerta e feedback do Frila (paridade direta com `AvisoFrila` do iOS / Cartão nliiRfQg).
 */
enum class TomAviso {
    ERRO,
    ALERTA,
    INFORMATIVO,
    SUCESSO,
}

/**
 * Bloco de aviso contextual (RNF10), no desenho do Fabrício: preenchimento neutro, raio 16, ícone e
 * texto em tinta. Problema não tem cor: o tom vai no ícone e no prefixo falado, nunca em vermelho,
 * verde ou amarelo lavado. Erro de uma ação fica junto ao botão ([MensagemJuntoAoBotao]), não aqui.
 */
@Composable
fun AvisoFrila(
    tom: TomAviso,
    mensagem: String,
    modifier: Modifier = Modifier,
    titulo: String? = null,
    aoDispensar: (() -> Unit)? = null,
) {
    val cores = FrilaTema.cores

    val iconePadrao: ImageVector = when (tom) {
        TomAviso.ERRO -> Icons.Default.Warning
        TomAviso.ALERTA -> Icons.Default.Warning
        TomAviso.SUCESSO -> Icons.Default.Check
        TomAviso.INFORMATIVO -> Icons.Default.Info
    }

    val prefixoAcessibilidade = when (tom) {
        TomAviso.ERRO -> "Erro: "
        TomAviso.ALERTA -> "Aviso: "
        TomAviso.SUCESSO -> "Sucesso: "
        TomAviso.INFORMATIVO -> "Informação: "
    }

    Surface(
        modifier = modifier
            .fillMaxWidth()
            .semantics {
                liveRegion = LiveRegionMode.Polite
                contentDescription = "$prefixoAcessibilidade${titulo?.let { "$it. " } ?: ""}$mensagem"
            },
        shape = RoundedCornerShape(FrilaRaios.interno),
        color = cores.superficiePressionada,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(FrilaEspacamento.bloco),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
        ) {
            Icon(
                imageVector = iconePadrao,
                contentDescription = null,
                tint = cores.tinta,
                modifier = Modifier.size(24.dp),
            )
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto),
            ) {
                if (!titulo.isNullOrBlank()) {
                    Text(
                        text = titulo,
                        style = FrilaTipo.rotuloSecundario,
                        color = cores.tinta,
                    )
                }
                Text(
                    text = mensagem,
                    style = FrilaTipo.corpo,
                    color = cores.tinta,
                )
            }
            if (aoDispensar != null) {
                IconButton(
                    onClick = aoDispensar,
                    modifier = Modifier.size(FrilaMetricas.alvoMinimo),
                ) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Fechar aviso",
                        tint = cores.tintaSuave,
                    )
                }
            }
        }
    }
}
