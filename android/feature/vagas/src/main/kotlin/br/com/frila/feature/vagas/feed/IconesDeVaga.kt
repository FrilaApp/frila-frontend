package br.com.frila.feature.vagas.feed

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.unit.dp

/**
 * Os ícones de linha de dado da vaga que o conjunto básico do Material não traz (a maleta da função e a
 * camisa do traje). Só máscara: quem desenha dá a cor (tinta) e o tamanho (20dp na linha de dado).
 * Os que o conjunto traz (calendário, lugar) vêm de `Icons.Default`.
 */
private fun icone(nome: String, caminho: String): ImageVector =
    ImageVector.Builder(
        name = nome,
        defaultWidth = 24.dp,
        defaultHeight = 24.dp,
        viewportWidth = 24f,
        viewportHeight = 24f,
    ).addPath(
        pathData = PathParser().parsePathString(caminho).toNodes(),
        fill = SolidColor(Color.Black),
    ).build()

/** A maleta: a função da vaga. */
internal val IconeFuncao: ImageVector by lazy {
    icone(
        nome = "Frila.Funcao",
        caminho = "M20,6h-4L16,4c0,-1.11 -0.89,-2 -2,-2h-4c-1.11,0 -2,0.89 -2,2v2L4,6c-1.11,0 -1.99,0.89 -1.99,2L2,19" +
            "c0,1.11 0.89,2 2,2h16c1.11,0 2,-0.89 2,-2L22,8c0,-1.11 -0.89,-2 -2,-2zM14,6h-4L10,4h4v2z",
    )
}

/** A camisa: o traje que a casa pede. */
internal val IconeCamisa: ImageVector by lazy {
    icone(
        nome = "Frila.Camisa",
        caminho = "M8,3L12,5L16,3L22,6L20,11L17,10L17,21L7,21L7,10L4,11L2,6Z",
    )
}
