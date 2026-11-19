package br.com.frila.feature.entrada.entrada

import android.content.res.Resources
import android.graphics.BitmapFactory
import androidx.annotation.DrawableRes
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext

/**
 * Um PNG do app decodificado só até o tamanho de que a tela precisa: a arte da Turma tem 1376 x 880 px na densidade
 * mais alta, mas numa tela menor (ou nos testes, na densidade de base) metade ou um quarto disso já enche o espaço, e
 * o bitmap inteiro é memória que não aparece. `larguraAlvoPx` é a largura, em pixels, em que a imagem vai ser
 * desenhada; a decodificação corta pela metade (`inSampleSize`, potência de 2) enquanto o resultado ainda cobrir o alvo.
 *
 * Roda na composição, como o `painterResource` que substitui; devolve nulo se o recurso não decodifica.
 */
@Composable
internal fun rememberImagemAmostrada(@DrawableRes recurso: Int, larguraAlvoPx: Int): ImageBitmap? {
    val recursos = LocalContext.current.resources
    return remember(recurso, larguraAlvoPx, recursos) { decodificarAmostrada(recursos, recurso, larguraAlvoPx) }
}

internal fun decodificarAmostrada(recursos: Resources, @DrawableRes recurso: Int, larguraAlvoPx: Int): ImageBitmap? {
    // Os pixels do arquivo da densidade escolhida, sem a escala automática da densidade (o desenho já ajusta o tamanho).
    val medida = BitmapFactory.Options().apply {
        inJustDecodeBounds = true
        inScaled = false
    }
    BitmapFactory.decodeResource(recursos, recurso, medida)
    var amostra = 1
    if (larguraAlvoPx > 0) {
        while (medida.outWidth / (amostra * 2) >= larguraAlvoPx) amostra *= 2
    }
    val opcoes = BitmapFactory.Options().apply {
        inScaled = false
        inSampleSize = amostra
    }
    return BitmapFactory.decodeResource(recursos, recurso, opcoes)?.asImageBitmap()
}
