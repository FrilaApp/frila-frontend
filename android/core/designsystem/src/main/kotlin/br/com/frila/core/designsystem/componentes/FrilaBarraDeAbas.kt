package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.layout.Column
import androidx.compose.material.icons.materialIcon
import androidx.compose.material.icons.materialPath
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/** Uma aba da barra: o rótulo, o ícone e quantos itens precisam da pessoa (some com zero). */
data class AbaFrila(
    val rotulo: String,
    val icone: ImageVector,
    val pendencias: Int = 0,
)

/**
 * Barra de abas das telas RAIZ (a navegação do Material, que é o cromo do sistema: não se redesenha).
 * Só as raízes têm barra; as telas abertas por cima a escondem.
 *
 * Aba ativa: o ÍCONE em laranja de ação e o rótulo em tinta, mais pesado (laranja não serve para
 * texto). Inativas em tinta suave. Sem a pílula de seleção do Material. O aviso de pendência é em
 * tinta com texto claro, porque o produto não usa vermelho.
 */
@Composable
fun FrilaBarraDeAbas(
    abas: List<AbaFrila>,
    selecionada: Int,
    aoSelecionar: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val cores = FrilaTema.cores

    Column(modifier = modifier) {
        FrilaDivisoria(cor = cores.bordaNav)
        NavigationBar(
            containerColor = cores.superficie,
            contentColor = cores.tinta,
            tonalElevation = 0.dp,
        ) {
            abas.forEachIndexed { indice, aba ->
                val ativa = indice == selecionada
                NavigationBarItem(
                    selected = ativa,
                    onClick = { aoSelecionar(indice) },
                    icon = {
                        if (aba.pendencias > 0) {
                            val falado = if (aba.pendencias == 1) "1 item precisa de você" else "${aba.pendencias} itens precisam de você"
                            BadgedBox(
                                badge = {
                                    Badge(
                                        containerColor = cores.tinta,
                                        contentColor = cores.sobreTinta,
                                        modifier = Modifier.semantics { contentDescription = falado },
                                    ) { Text(aba.pendencias.toString()) }
                                },
                            ) { Icon(imageVector = aba.icone, contentDescription = null) }
                        } else {
                            Icon(imageVector = aba.icone, contentDescription = null)
                        }
                    },
                    label = {
                        Text(
                            text = aba.rotulo,
                            style = FrilaTipo.legenda.copy(fontWeight = if (ativa) FontWeight.Bold else FontWeight.Medium),
                            maxLines = 1,
                        )
                    },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = cores.acao,
                        selectedTextColor = cores.tinta,
                        indicatorColor = Color.Transparent,
                        unselectedIconColor = cores.tintaSuave,
                        unselectedTextColor = cores.tintaSuave,
                    ),
                )
            }
        }
    }
}

/** A maleta da aba Vagas (o "work" do Material, que não vem no conjunto básico de ícones). */
val IconeMaleta: ImageVector by lazy {
    materialIcon(name = "Frila.Maleta") {
        materialPath {
            moveTo(20f, 6f)
            horizontalLineToRelative(-4f)
            verticalLineTo(4f)
            curveToRelative(0f, -1.11f, -0.89f, -2f, -2f, -2f)
            horizontalLineToRelative(-4f)
            curveToRelative(-1.11f, 0f, -2f, 0.89f, -2f, 2f)
            verticalLineToRelative(2f)
            horizontalLineTo(4f)
            curveToRelative(-1.11f, 0f, -1.99f, 0.89f, -1.99f, 2f)
            lineTo(2f, 19f)
            curveToRelative(0f, 1.11f, 0.89f, 2f, 2f, 2f)
            horizontalLineToRelative(16f)
            curveToRelative(1.11f, 0f, 2f, -0.89f, 2f, -2f)
            verticalLineTo(8f)
            curveToRelative(0f, -1.11f, -0.89f, -2f, -2f, -2f)
            close()
            moveTo(14f, 6f)
            horizontalLineToRelative(-4f)
            verticalLineTo(4f)
            horizontalLineToRelative(4f)
            verticalLineToRelative(2f)
            close()
        }
    }
}
