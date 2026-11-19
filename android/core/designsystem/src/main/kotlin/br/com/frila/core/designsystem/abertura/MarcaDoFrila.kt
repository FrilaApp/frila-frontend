package br.com.frila.core.designsystem.abertura

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.tema.FrilaTema

/**
 * Uma letra do rótulo "Frila". O `r` e o `i` se encaixam: o punho do `r` entra no recorte do `i`, e os dedos do `i`
 * passam por cima dele. É o aperto de mão que a abertura anima.
 */
internal enum class ParteDaMarca(private val caminhoSvg: String, val parImpar: Boolean = false) {
    F(CaminhosDaMarca.F),
    R(CaminhosDaMarca.R),
    I(CaminhosDaMarca.I),
    PINGO(CaminhosDaMarca.PINGO),
    L(CaminhosDaMarca.L),

    /** O `a` tem o furo do bojo: precisa de preenchimento par-ímpar. */
    A(CaminhosDaMarca.A, parImpar = true),
    ;

    /** O contorno da letra no espaço do SVG do rótulo. Montado uma vez; não o altere. */
    val caminho: Path by lazy {
        PathParser().parsePathString(caminhoSvg).toPath().apply {
            fillType = if (parImpar) PathFillType.EvenOdd else PathFillType.NonZero
        }
    }

    companion object {
        /** Tamanho do rótulo inteiro no espaço do SVG. */
        const val LARGURA = 1311f
        const val ALTURA = 439f

        /** Centro do pingo do `i`, de onde a abertura se abre para o app. */
        val centroDoPingo = Offset(675f, 60.5f)
        const val RAIO_DO_PINGO = 58f
    }
}

/** Desenha o rótulo inteiro, numa cor só, dentro de um retângulo de `largura` x `altura` pixels com a origem em `topoEsquerdo`. */
internal fun DrawScope.desenharRotulo(cor: Color, topoEsquerdo: Offset, largura: Float, altura: Float) {
    val escala = minOf(largura / ParteDaMarca.LARGURA, altura / ParteDaMarca.ALTURA)
    withTransform({
        translate(topoEsquerdo.x, topoEsquerdo.y)
        scale(escala, escala, pivot = Offset.Zero)
    }) {
        ParteDaMarca.entries.forEach { parte -> drawPath(parte.caminho, cor) }
    }
}

/**
 * O rótulo "Frila" inteiro, numa cor só, na proporção do SVG. A abertura termina nele; a tela de entrada o usa como
 * marca. Imagem com o nome "Frila" para o leitor de tela. Para a abertura voar até ele, marque-o com
 * [destinoDoRotuloDaAbertura].
 */
@Composable
fun RotuloDaMarca(
    modifier: Modifier = Modifier,
    cor: Color = FrilaTema.cores.tinta,
) {
    val nome = "Frila"
    Canvas(
        modifier = modifier
            .aspectRatio(ParteDaMarca.LARGURA / ParteDaMarca.ALTURA)
            .semantics {
                contentDescription = nome
                role = Role.Image
            },
    ) {
        desenharRotulo(cor, Offset.Zero, size.width, size.height)
    }
}
